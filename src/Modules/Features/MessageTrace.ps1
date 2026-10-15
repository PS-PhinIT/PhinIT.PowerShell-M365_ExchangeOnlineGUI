# =====================================================================
# easyEXO - Modul: Nachrichtenverfolgung (Get-MessageTraceV2 mit Fallback)
# Datei: src/Modules/Features/MessageTrace.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# -------------------------------------------------
# Abschnitt: MessageTrace-Funktionen
# -------------------------------------------------

# Maximale Anzahl Ergebnisse pro Abfrage (Get-MessageTraceV2: -ResultSize, Get-MessageTrace: -PageSize)
$script:MessageTraceResultLimit = 5000

# Formatiert einen Zeitstempel der Nachrichtenverfolgung (UTC) in lokaler Zeit
function Format-MessageTraceLocalTime {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        $Value
    )

    if ($null -eq $Value -or "$Value" -eq "") { return "-" }
    $dateValue = [datetime]::MinValue
    if ($Value -is [datetime]) {
        $dateValue = $Value
    }
    elseif (-not [datetime]::TryParse("$Value", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$dateValue)) {
        return "$Value"
    }
    # Exchange liefert UTC; nur nicht bereits lokale Werte umrechnen
    if ($dateValue.Kind -ne [System.DateTimeKind]::Local) {
        $dateValue = [datetime]::SpecifyKind($dateValue, [System.DateTimeKind]::Utc).ToLocalTime()
    }
    return $dateValue.ToString('dd.MM.yyyy HH:mm:ss')
}

function Start-MessageTraceAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }

    Update-StatusBar -Message "Nachrichtensuche wird gestartet..." -Type "Info"

    $params = @{
        ErrorAction = 'Stop'
    }

    if (-not [string]::IsNullOrWhiteSpace($script:txtTraceSender.Text)) { $params.SenderAddress = $script:txtTraceSender.Text.Trim() }
    if (-not [string]::IsNullOrWhiteSpace($script:txtTraceRecipient.Text)) { $params.RecipientAddress = $script:txtTraceRecipient.Text.Trim() }
    # Get-MessageTrace ist abgekündigt - bevorzugt Get-MessageTraceV2 verwenden (ExchangeOnlineManagement >= 3.7.0)
    $useTraceV2 = $null -ne (Get-Command -Name Get-MessageTraceV2 -ErrorAction SilentlyContinue)
    $subjectFilter = $null
    if (-not [string]::IsNullOrWhiteSpace($script:txtTraceSubject.Text)) {
        $subjectFilter = $script:txtTraceSubject.Text.Trim()
        if ($useTraceV2) {
            $params.Subject = $subjectFilter
            $params.SubjectFilterType = 'Contains'
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($script:txtTraceMessageId.Text)) { $params.MessageId = $script:txtTraceMessageId.Text.Trim() }
    if ($null -ne $script:dpTraceStart.SelectedDate) { $params.StartDate = $script:dpTraceStart.SelectedDate.Date }
    if ($null -ne $script:dpTraceEnd.SelectedDate) {
        # DatePicker liefert Mitternacht - den End-Tag vollständig einschließen (höchstens bis jetzt)
        $endDate = $script:dpTraceEnd.SelectedDate.Date.AddDays(1)
        $now = Get-Date
        if ($endDate -gt $now) { $endDate = $now }
        $params.EndDate = $endDate
    }
    
    $selectedStatus = $script:cmbTraceStatus.SelectedItem.Content
    if ($selectedStatus -ne "Alle") {
        # Übersetze deutsche Status-Werte in englische für Get-MessageTrace
        $statusMapping = @{
            "Zugestellt" = "Delivered"
            "Fehlgeschlagen" = "Failed"
            "Ausstehend" = "Pending"
            "Unter Quarantäne" = "Quarantined"
        }
        
        if ($statusMapping.ContainsKey($selectedStatus)) {
            $params.Status = $statusMapping[$selectedStatus]
        }
        else {
            # Falls ein unbekannter Status ausgewählt wurde, logge eine Warnung
            Write-Log "Unbekannter Message Trace Status: $selectedStatus" -Type "Warning"
        }
    }

    if ($params.ContainsKey('StartDate') -and $params.ContainsKey('EndDate') -and $params.EndDate -le $params.StartDate) {
        Show-MessageBox -Message "Das Enddatum muss nach dem Startdatum liegen." -Title "Ungültiger Zeitraum" -Type "Warning"
        Update-StatusBar -Message "Nachrichtensuche abgebrochen: ungültiger Zeitraum." -Type "Warning"
        return
    }

    # Der End-Tag zählt vollständig mit (Ende = folgender Tag 00:00 bzw. jetzt)
    if ($useTraceV2 -and $params.ContainsKey('StartDate') -and $params.ContainsKey('EndDate') -and
        (($params.EndDate - $params.StartDate).TotalDays -gt 10)) {
        Show-MessageBox -Message "Get-MessageTraceV2 unterstützt maximal 10 Tage pro Abfrage (einschließlich End-Tag). Bitte den Zeitraum verkleinern." -Title "Zeitraum zu groß" -Type "Warning"
        Update-StatusBar -Message "Nachrichtensuche abgebrochen: Zeitraum größer als 10 Tage." -Type "Warning"
        return
    }

    if ($useTraceV2) {
        $params.ResultSize = $script:MessageTraceResultLimit
    } else {
        $params.PageSize = $script:MessageTraceResultLimit
    }

    $traceResults = @()
    $limitReached = $false
    Start-UIBusy -Message "Nachrichtensuche läuft..." -Title "Nachrichtenverfolgung" -Cancelable
    try {
        if ($useTraceV2) {
            $traceResults = @(Get-MessageTraceV2 @params | Step-UIProgress -Activity "Lade Nachrichten")
        } else {
            $traceResults = @(Get-MessageTrace @params | Step-UIProgress -Activity "Lade Nachrichten")
        }
        # Limit vor dem clientseitigen Betreff-Filter prüfen
        $limitReached = $traceResults.Count -ge $script:MessageTraceResultLimit
        if (-not $useTraceV2 -and $subjectFilter) {
            # Get-MessageTrace kennt keinen -Subject-Parameter - daher clientseitig filtern
            $traceResults = @($traceResults | Where-Object { $_.Subject -like "*$subjectFilter*" })
        }
    } catch {
        if ($script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException]) {
            Write-Log "Nachrichtensuche vom Benutzer abgebrochen." -Type "Info"
            Update-StatusBar -Message "Nachrichtensuche abgebrochen." -Type "Warning"
            return
        }
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler bei der Nachrichtensuche: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Fehler bei der Nachrichtensuche: $errorMsg" -Type "Error"
        Show-MessageBox -Message "Fehler bei der Nachrichtensuche: $errorMsg" -Title "Fehler" -Type "Error"
        return
    } finally {
        Stop-UIBusy
    }
    
    $script:dgMessageTrace.ItemsSource = $traceResults
    $resultCount = $traceResults.Count
    $script:txtTraceCount.Text = "Results: $resultCount"
    if ($limitReached) {
        $limitMsg = "Nachrichtensuche abgeschlossen. $resultCount Ergebnis(se) angezeigt - das Limit von $($script:MessageTraceResultLimit) Einträgen wurde erreicht, es gibt möglicherweise weitere Nachrichten. Bitte Filter oder Zeitraum eingrenzen."
        Write-Log $limitMsg -Type "Warning"
        Update-StatusBar -Message $limitMsg -Type "Warning"
    } else {
        Update-StatusBar -Message "Nachrichtensuche abgeschlossen. $resultCount Ergebnis(se) gefunden." -Type "Success"
    }
}

function Export-MessageTraceAction {
    [CmdletBinding()]
    param()

    $dataToExport = $script:dgMessageTrace.ItemsSource
    if ($null -eq $dataToExport -or $dataToExport.Count -eq 0) {
        Show-MessageBox -Message "Es sind keine Daten zum Exportieren vorhanden." -Title "Keine Daten" -Type "Warning"
        return
    }

    $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
    $saveFileDialog.Filter = "CSV-Dateien (*.csv)|*.csv"
    $saveFileDialog.FileName = "MessageTrace_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    
    if ($saveFileDialog.ShowDialog() -eq $true) {
        $exportPath = $saveFileDialog.FileName
        $dataToExport | ConvertTo-SafeCsvObject | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8 -Delimiter ";"
        Update-StatusBar -Message "Ergebnisse erfolgreich nach '$exportPath' exportiert." -Type "Success"
        Show-MessageBox -Message "Die Ergebnisse wurden erfolgreich exportiert." -Title "Export erfolgreich" -Type "Info"
    }
}

function Show-DetailedMessageTraceAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }

    $selectedTrace = $script:dgMessageTrace.SelectedItem
    if ($null -eq $selectedTrace) {
        Show-MessageBox -Message "Bitte wählen Sie einen Eintrag aus der Ergebnisliste aus." -Title "Keine Auswahl" -Type "Warning"
        return
    }

    Update-StatusBar -Message "Lade umfassende detaillierte Informationen für die ausgewählte Nachricht..." -Type "Info"
    
    try {
        # Sammle alle verfügbaren Informationen
        # Get-MessageTraceDetail ist abgekündigt - bevorzugt Get-MessageTraceDetailV2 verwenden (ExchangeOnlineManagement >= 3.7.0)
        if (Get-Command -Name Get-MessageTraceDetailV2 -ErrorAction SilentlyContinue) {
            $details = Get-MessageTraceDetailV2 -MessageTraceId $selectedTrace.MessageTraceId -RecipientAddress $selectedTrace.RecipientAddress -ErrorAction Stop
        } else {
            $details = Get-MessageTraceDetail -MessageTraceId $selectedTrace.MessageTraceId -RecipientAddress $selectedTrace.RecipientAddress -ErrorAction Stop
        }
        
        # Umfassende Detailinformationen zusammenstellen
        $detailString = "=== UMFASSENDE NACHRICHTENVERFOLGUNG - MAXIMALE DETAILTIEFE ===`n"
        $detailString += "Generiert am: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')`n"
        $detailString += "Analysiert von: $($env:USERNAME) auf $($env:COMPUTERNAME)`n"
        $detailString += "PowerShell Version: $($PSVersionTable.PSVersion)`n"
        $detailString += "Exchange Online Management Module: $(Get-Module ExchangeOnlineManagement -ListAvailable | Select-Object -First 1 | Select-Object -ExpandProperty Version)`n"
        $detailString += "================================================================`n`n"
        
        # SEKTION 1: Grundlegende Nachrichteninformationen
        $detailString += "█ SEKTION 1: GRUNDLEGENDE NACHRICHTENINFORMATIONEN`n"
        $detailString += "================================================================`n"
        $detailString += "Absender (From): $($selectedTrace.SenderAddress)`n"
        $detailString += "Empfänger (To): $($selectedTrace.RecipientAddress)`n"
        $detailString += "Betreff (Subject): $($selectedTrace.Subject)`n"
        $detailString += "Nachrichtengröße: $($selectedTrace.Size) Bytes ($([math]::Round($selectedTrace.Size/1024, 2)) KB)`n"
        $detailString += "Status: $($selectedTrace.Status)`n"
        $detailString += "Empfangen: $($selectedTrace.Received) (UTC)`n"
        $detailString += "Lokale Zeit: $(Format-MessageTraceLocalTime -Value $selectedTrace.Received)`n"
        $detailString += "Message-ID: $($selectedTrace.MessageId)`n"
        $detailString += "Message Trace ID: $($selectedTrace.MessageTraceId)`n"
        
        # Zusätzliche Basis-Eigenschaften
        if ($selectedTrace.FromIP) { $detailString += "Absender-IP: $($selectedTrace.FromIP)`n" }
        if ($selectedTrace.ToIP) { $detailString += "Empfänger-IP: $($selectedTrace.ToIP)`n" }
        if ($selectedTrace.Index) { $detailString += "Index: $($selectedTrace.Index)`n" }
        
        $detailString += "`n"
        
        # SEKTION 2: Netzwerk- und Routing-Informationen
        $detailString += "█ SEKTION 2: NETZWERK- UND ROUTING-INFORMATIONEN`n"
        $detailString += "================================================================`n"
        
        # IP-Adress-Analyse
        if ($selectedTrace.FromIP) {
            try {
                $ipInfo = Resolve-DnsName $selectedTrace.FromIP -ErrorAction SilentlyContinue
                if ($ipInfo) {
                    $detailString += "Absender-IP Reverse DNS: $($ipInfo.NameHost)`n"
                }
            } catch {
                $detailString += "Absender-IP Reverse DNS: Nicht auflösbar`n"
            }
        }
        
        # Geolocation-Informationen (falls verfügbar)
        if ($selectedTrace.FromIP -and $selectedTrace.FromIP -notmatch "^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.)" ) {
            $detailString += "Absender-IP Typ: Öffentliche IP-Adresse`n"
            $detailString += "Hinweis: Externe Absender-IP erkannt`n"
        } elseif ($selectedTrace.FromIP) {
            $detailString += "Absender-IP Typ: Private/Interne IP-Adresse`n"
        }
        
        $detailString += "`n"
        
        # SEKTION 3: Detaillierte Ereignisverfolgung
        $detailString += "█ SEKTION 3: DETAILLIERTE EREIGNISVERFOLGUNG`n"
        $detailString += "================================================================`n"
        
        if ($details -and $details.Count -gt 0) {
            $eventCounter = 1
            $totalEvents = $details.Count
            $detailString += "Anzahl der verfolgten Ereignisse: $totalEvents`n`n"
            
            foreach ($traceEvent in $details) {
                $detailString += "┌─ EREIGNIS $eventCounter von $totalEvents ─────────────────────────────────────┐`n"
                $detailString += "│ Zeitstempel: $($traceEvent.Date) (UTC)`n"
                $detailString += "│ Lokale Zeit: $(Format-MessageTraceLocalTime -Value $traceEvent.Date)`n"
                $detailString += "│ Ereignistyp: $($traceEvent.Event)`n"
                $detailString += "│ Durchgeführte Aktion: $($traceEvent.Action)`n"
                $detailString += "│ Detailbeschreibung: $($traceEvent.Detail)`n"
                
                # Alle verfügbaren Event-Eigenschaften
                $traceEvent.PSObject.Properties | ForEach-Object {
                    if ($_.Name -notin @('Date', 'Event', 'Action', 'Detail') -and $null -ne $_.Value -and $_.Value -ne "") {
                        $detailString += "│ $($_.Name): $($_.Value)`n"
                    }
                }
                
                # Ereignis-spezifische Analyse
                switch ($traceEvent.Event) {
                    "RECEIVE" { $detailString += "│ ► Nachricht wurde vom Exchange-System empfangen`n" }
                    "SEND" { $detailString += "│ ► Nachricht wurde vom Exchange-System gesendet`n" }
                    "DELIVER" { $detailString += "│ ► Nachricht wurde erfolgreich zugestellt`n" }
                    "FAIL" { $detailString += "│ ► FEHLER: Nachrichtenzustellung fehlgeschlagen`n" }
                    "DEFER" { $detailString += "│ ► Nachrichtenzustellung wurde verzögert`n" }
                    "RESOLVE" { $detailString += "│ ► Empfängeradresse wurde aufgelöst`n" }
                    "REDIRECT" { $detailString += "│ ► Nachricht wurde umgeleitet`n" }
                    "EXPAND" { $detailString += "│ ► Verteilergruppe wurde erweitert`n" }
                }
                
                $detailString += "└────────────────────────────────────────────────────────────────┘`n`n"
                $eventCounter++
            }
        } else {
            $detailString += "⚠️ Keine detaillierten Ereignisse verfügbar.`n"
            $detailString += "Mögliche Gründe:`n"
            $detailString += "- Nachricht ist zu alt (>10 Tage)`n"
            $detailString += "- Unvollständige Protokollierung`n"
            $detailString += "- Eingeschränkte Berechtigungen`n`n"
        }
        
        # SEKTION 4: Vollständige Objekteigenschaften
        $detailString += "█ SEKTION 4: VOLLSTÄNDIGE OBJEKTEIGENSCHAFTEN`n"
        $detailString += "================================================================`n"
        $detailString += "Alle verfügbaren Eigenschaften der Message Trace:`n`n"
        
        $propertyCounter = 1
        $selectedTrace.PSObject.Properties | Sort-Object Name | ForEach-Object {
            $value = if ($null -eq $_.Value) { "<NULL>" } elseif ($_.Value -eq "") { "<LEER>" } else { $_.Value }
            $detailString += "[$propertyCounter] $($_.Name): $value`n"
            $propertyCounter++
        }
        
        # SEKTION 5: Technische Metadaten
        $detailString += "`n█ SEKTION 5: TECHNISCHE METADATEN UND ANALYSE`n"
        $detailString += "================================================================`n"
        $detailString += "Objekttyp: $($selectedTrace.GetType().FullName)`n"
        $detailString += "Anzahl Eigenschaften: $($selectedTrace.PSObject.Properties.Count)`n"
        $detailString += "Nachrichtenalter: $((Get-Date) - $selectedTrace.Received | Select-Object -ExpandProperty Days) Tage`n"
        
        # Größenanalyse
        if ($selectedTrace.Size -gt 0) {
            $sizeKB = [math]::Round($selectedTrace.Size/1024, 2)
            $sizeMB = [math]::Round($selectedTrace.Size/1048576, 2)
            $detailString += "Größenanalyse:`n"
            $detailString += "  - Bytes: $($selectedTrace.Size)`n"
            $detailString += "  - Kilobytes: $sizeKB KB`n"
            $detailString += "  - Megabytes: $sizeMB MB`n"
            
            if ($selectedTrace.Size -gt 25MB) {
                $detailString += "  - ⚠️ Große Nachricht (>25MB) - könnte Zustellungsprobleme verursachen`n"
            }
        }
        
        # SEKTION 6: Empfehlungen und nächste Schritte
        $detailString += "`n█ SEKTION 6: EMPFEHLUNGEN UND NÄCHSTE SCHRITTE`n"
        $detailString += "================================================================`n"
        
        switch ($selectedTrace.Status) {
            "Failed" {
                $detailString += "🔴 STATUS: FEHLGESCHLAGEN`n"
                $detailString += "Empfohlene Maßnahmen:`n"
                $detailString += "- Überprüfen Sie die Ereignisdetails auf spezifische Fehlermeldungen`n"
                $detailString += "- Kontrollieren Sie Spam-Filter und Mail-Flow-Regeln`n"
                $detailString += "- Prüfen Sie die Empfängeradresse auf Gültigkeit`n"
                $detailString += "- Verwenden Sie Get-MessageTrace mit erweiterten Parametern`n"
            }
            "Delivered" {
                $detailString += "🟢 STATUS: ERFOLGREICH ZUGESTELLT`n"
                $detailString += "Die Nachricht wurde erfolgreich zugestellt.`n"
            }
            "Pending" {
                $detailString += "🟡 STATUS: AUSSTEHEND`n"
                $detailString += "Die Nachricht wird noch verarbeitet oder ist in der Warteschlange.`n"
            }
            "Quarantined" {
                $detailString += "🟠 STATUS: UNTER QUARANTÄNE`n"
                $detailString += "Die Nachricht wurde von Sicherheitsfiltern blockiert.`n"
                $detailString += "Überprüfen Sie das Security & Compliance Center.`n"
            }
        }
        
        $detailString += "`n================================================================`n"
        $detailString += "Ende der detaillierten Analyse`n"
        $detailString += "================================================================`n"

        # Erstelle ein erweitertes Fenster für die umfassende Anzeige
        $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Umfassende Nachrichtenverfolgung" Height="800" Width="1200" WindowStartupLocation="CenterScreen">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <Border Grid.Row="0" Background="{DynamicResource HeaderBackgroundBrush}" Padding="10">
            <TextBlock Text="Umfassende Nachrichtenverfolgung - Maximale Detailtiefe" 
                       Foreground="{DynamicResource HeaderTextBrush}" FontSize="16" FontWeight="Bold" HorizontalAlignment="Center"/>
        </Border>
        
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" Margin="10">
            <TextBox TextWrapping="NoWrap" IsReadOnly="True" Name="txtDetails" FontFamily="Consolas" FontSize="10" 
                     Background="{DynamicResource SurfaceAltBrush}" Padding="15" BorderThickness="1" BorderBrush="{DynamicResource ControlBorderBrush}"
                     VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"/>
        </ScrollViewer>
        
        <Border Grid.Row="2" Background="{DynamicResource SurfaceHoverBrush}" Padding="10">
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                <Button Name="btnCopyToClipboard" Content="📋 In Zwischenablage kopieren" Padding="10,5" Margin="5" Style="{DynamicResource SecondaryButton}"/>
                <Button Name="btnSaveToFile" Content="💾 Als Datei speichern" Padding="10,5" Margin="5" Style="{DynamicResource SecondaryButton}"/>
                <Button Name="btnPrint" Content="🖨️ Drucken" Padding="10,5" Margin="5" Style="{DynamicResource SecondaryButton}"/>
                <Button Name="btnClose" Content="❌ Schließen" Padding="10,5" Margin="5"/>
            </StackPanel>
        </Border>
    </Grid>
</Window>
"@
        
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
        $null = Add-ThemeResource -Window $window
        # Betreff erst nach dem Laden setzen - externe Daten nie in das XAML-Markup einfügen (XAML-Injection)
        $window.Title = "Umfassende Nachrichtenverfolgung - $($selectedTrace.Subject)"
        $txtDetails = $window.FindName("txtDetails")
        $btnCopyToClipboard = $window.FindName("btnCopyToClipboard")
        $btnSaveToFile = $window.FindName("btnSaveToFile")
        $btnPrint = $window.FindName("btnPrint")
        $btnClose = $window.FindName("btnClose")
        
        $txtDetails.Text = $detailString
        
        # Event-Handler für Buttons
        $btnCopyToClipboard.Add_Click({
            [System.Windows.Clipboard]::SetText($txtDetails.Text)
            Show-MessageBox -Message "Umfassende Detailinformationen wurden in die Zwischenablage kopiert." -Title "Kopiert" -Type "Info"
        })
        
        $btnSaveToFile.Add_Click({
            $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
            $saveDialog.Filter = "Text-Dateien (*.txt)|*.txt|Log-Dateien (*.log)|*.log|Alle Dateien (*.*)|*.*"
            $saveDialog.FileName = "MessageTrace_Comprehensive_Details_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            
            if ($saveDialog.ShowDialog() -eq $true) {
                $txtDetails.Text | Out-File -FilePath $saveDialog.FileName -Encoding UTF8
                Show-MessageBox -Message "Umfassende Detailinformationen wurden erfolgreich gespeichert unter:`n$($saveDialog.FileName)" -Title "Gespeichert" -Type "Info"
            }
        })
        
        $btnPrint.Add_Click({
            try {
                $printDialog = New-Object System.Windows.Controls.PrintDialog
                if ($printDialog.ShowDialog() -eq $true) {
                    $flowDoc = New-Object System.Windows.Documents.FlowDocument
                    $para = New-Object System.Windows.Documents.Paragraph
                    $para.Inlines.Add($txtDetails.Text)
                    $flowDoc.Blocks.Add($para)
                    $printDialog.PrintDocument($flowDoc.DocumentPaginator, "Message Trace Details")
                    Show-MessageBox -Message "Druckauftrag wurde gesendet." -Title "Gedruckt" -Type "Info"
                }
            } catch {
                Show-MessageBox -Message "Fehler beim Drucken: $($_.Exception.Message)" -Title "Druckfehler" -Type "Error"
            }
        })
        
        $btnClose.Add_Click({
            $window.Close()
        })
        
        [void]$window.ShowDialog()

        Update-StatusBar -Message "Umfassende detaillierte Informationen erfolgreich angezeigt." -Type "Success"
        
    } catch {
        $errorMsg = "Fehler beim Laden der detaillierten Informationen: $($_.Exception.Message)"
        Write-Log $errorMsg -Type "Error"
        Show-MessageBox -Message $errorMsg -Title "Fehler" -Type "Error"
        Update-StatusBar -Message "Fehler beim Laden der Details." -Type "Error"
    }
}

function Initialize-MessageTraceTab {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Initialisiere Message Trace-Tab..." -Type "Info"

        # UI-Elemente referenzieren
        $script:txtTraceSender = Get-XamlElement -ElementName "txtTraceSender"
        $script:txtTraceRecipient = Get-XamlElement -ElementName "txtTraceRecipient"
        $script:txtTraceSubject = Get-XamlElement -ElementName "txtTraceSubject"
        $script:txtTraceMessageId = Get-XamlElement -ElementName "txtTraceMessageId"
        $script:dpTraceStart = Get-XamlElement -ElementName "dpTraceStart"
        $script:dpTraceEnd = Get-XamlElement -ElementName "dpTraceEnd"
        $script:cmbTraceStatus = Get-XamlElement -ElementName "cmbTraceStatus"
        $script:btnStartTrace = Get-XamlElement -ElementName "btnStartTrace"
        $script:dgMessageTrace = Get-XamlElement -ElementName "dgMessageTrace"
        $script:btnExportTrace = Get-XamlElement -ElementName "btnExportTrace"
        $script:btnDetailedTrace = Get-XamlElement -ElementName "btnDetailedTrace"
        $script:btnClearTrace = Get-XamlElement -ElementName "btnClearTrace"
        $script:txtTraceCount = Get-XamlElement -ElementName "txtTraceCount"

        # Standardwerte setzen
        if ($null -ne $script:dpTraceStart) { $script:dpTraceStart.SelectedDate = (Get-Date).AddDays(-2) }
        if ($null -ne $script:dpTraceEnd) { $script:dpTraceEnd.SelectedDate = (Get-Date) }

        # Event-Handler registrieren
        Register-EventHandler -Control $script:btnStartTrace -Handler {
            try {
                Start-MessageTraceAction
            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_
                Write-Log "Fehler beim Starten der Nachrichtensuche: $errorMsg" -Type "Error"
                Update-StatusBar -Message "Fehler bei Nachrichtensuche: $($_.Exception.Message)" -Type Error
            }
        } -ControlName "btnStartTrace"

        Register-EventHandler -Control $script:btnExportTrace -Handler {
            try {
                Export-MessageTraceAction
            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_
                Write-Log "Fehler beim Exportieren der Nachrichtensuche: $errorMsg" -Type "Error"
                Update-StatusBar -Message "Fehler beim Export: $($_.Exception.Message)" -Type Error
            }
        } -ControlName "btnExportTrace"

        Register-EventHandler -Control $script:btnDetailedTrace -Handler {
            try {
                Show-DetailedMessageTraceAction
            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_
                Write-Log "Fehler beim Anzeigen der Detailansicht: $errorMsg" -Type "Error"
                Update-StatusBar -Message "Fehler bei Detailansicht: $($_.Exception.Message)" -Type Error
            }
        } -ControlName "btnDetailedTrace"

        Register-EventHandler -Control $script:btnClearTrace -Handler {
            try {
                if ($null -ne $script:dgMessageTrace) { $script:dgMessageTrace.ItemsSource = $null }
                if ($null -ne $script:txtTraceCount) { $script:txtTraceCount.Text = "Results: 0" }
                Update-StatusBar -Message "Ergebnisse der Nachrichtensuche gelöscht." -Type Info
            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_
                Write-Log "Fehler beim Löschen der Ergebnisse: $errorMsg" -Type "Error"
            }
        } -ControlName "btnClearTrace"

        Write-Log "Message Trace-Tab erfolgreich initialisiert." -Type "Success"
        return $true
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_
        Write-Log "Fehler beim Initialisieren des Message Trace-Tabs: $errorMsg" -Type "Error"
        return $false
    }
}
