# =====================================================================
# easyEXO - Modul: Automatische Antworten (Abwesenheitsnotizen)
# Datei: src/Modules/Features/AutoReply.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# -------------------------------------------------
# Abschnitt: AutoReply-Funktionen
# -------------------------------------------------

# Zerlegt eine Eingabe mit mehreren Adressen (getrennt durch ; , oder Zeilenumbruch)
function Split-AutoReplyIdentities {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    return @($Text -split '[;,\r\n]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
}

# Prüft die Datumsauswahl und liefert Start-/Endzeit für Set-MailboxAutoReplyConfiguration.
# Die Abwesenheit endet am Ende des gewählten Endtags (00:00 Uhr des Folgetags).
function Get-AutoReplyDateRange {
    [CmdletBinding()]
    param()

    $start = $null
    $end = $null
    if ($null -ne $script:dpAutoReplyStart) { $start = $script:dpAutoReplyStart.SelectedDate }
    if ($null -ne $script:dpAutoReplyEnd) { $end = $script:dpAutoReplyEnd.SelectedDate }

    if ($null -eq $start -or $null -eq $end) {
        $null = Show-MessageBox -Message "Bitte Start- und Enddatum auswählen." -Title "Fehlende Eingabe" -Type Warning
        return $null
    }
    $startDate = ([datetime]$start).Date
    $endDate = ([datetime]$end).Date
    if ($endDate -lt $startDate) {
        $null = Show-MessageBox -Message "Das Enddatum liegt vor dem Startdatum." -Title "Ungültiger Zeitraum" -Type Warning
        return $null
    }
    if ($endDate.AddDays(1) -le (Get-Date)) {
        $null = Show-MessageBox -Message "Der gewählte Zeitraum liegt in der Vergangenheit." -Title "Ungültiger Zeitraum" -Type Warning
        return $null
    }

    return [PSCustomObject]@{
        StartTime    = $startDate
        EndTime      = $endDate.AddDays(1)
        StartDisplay = $startDate.ToString("d")
        EndDisplay   = $endDate.ToString("d")
    }
}

# Ersetzt {StartDate}/{EndDate} und übernimmt Zeilenumbrüche als <br> (die Notiz wird als HTML angezeigt)
function Format-AutoReplyMessage {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        $DateRange
    )

    $text = [string]$Message
    $text = $text -replace '(?i)\{StartDate\}', $DateRange.StartDisplay
    $text = $text -replace '(?i)\{EndDate\}', $DateRange.EndDisplay
    $text = $text -replace '(?i)(<br\s*/?>)?\r?\n', '<br>'
    return $text
}

function Get-AutoReplyStatusAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][string[]]$UserIdentity
    )

    if (-not (Confirm-ExchangeConnection)) { return }
    Update-StatusBar -Message "Lade Status der Abwesenheitsnotizen..." -Type Info

    $statusList = [System.Collections.Generic.List[object]]::new()
    $cancelled = $false
    Start-UIBusy -Message "Lade Status der Abwesenheitsnotizen..." -Title "Automatische Antworten" -Cancelable
    try {
        $mailboxes = @()
        $identities = @($UserIdentity | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($identities.Count -gt 0) {
            $mailboxes = @(foreach ($identity in $identities) {
                try { Get-Mailbox -Identity $identity -ErrorAction Stop }
                catch { Write-Log "Postfach '$identity' nicht gefunden: $($_.Exception.Message)" -Type Warning }
            })
        } else {
            $mailboxes = @(Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox -ErrorAction Stop | Step-UIProgress -Activity "Lade Postfachliste")
        }

        $total = $mailboxes.Count
        $index = 0
        foreach ($mailbox in $mailboxes) {
            $index++
            Update-UIBusy -Message "Lese Abwesenheitsnotizen" -Current $index -Total $total
            Assert-UINotCancelled
            try {
                $config = Get-MailboxAutoReplyConfiguration -Identity $mailbox.UserPrincipalName -ErrorAction Stop
                
                # Bestimme die Anzeige für StartTime und EndTime basierend auf den tatsächlichen Werten
                $startTimeDisplay = "-"
                $endTimeDisplay = "-"
                
                if ($config.StartTime -and $config.StartTime -ne [DateTime]::MinValue) {
                    $startTimeDisplay = Get-Date $config.StartTime -Format "g"
                }
                
                if ($config.EndTime -and $config.EndTime -ne [DateTime]::MinValue) {
                    $endTimeDisplay = Get-Date $config.EndTime -Format "g"
                }
                
                # Prüfe, ob tatsächlich eine Abwesenheitsnotiz konfiguriert ist
                $hasAutoReply = $config.AutoReplyState -ne "Disabled"
                $internalMessage = if ($hasAutoReply -and -not [string]::IsNullOrWhiteSpace($config.InternalMessage)) { 
                    $config.InternalMessage 
                } else { 
                    "Keine Abwesenheitsnotiz konfiguriert" 
                }
                
                $statusList.Add([PSCustomObject]@{
                    DisplayName       = $mailbox.DisplayName
                    UserPrincipalName = $mailbox.UserPrincipalName
                    AutoReplyState    = $hasAutoReply
                    StartTime         = $startTimeDisplay
                    EndTime           = $endTimeDisplay
                    InternalMessage   = $internalMessage
                })
            }
            catch {
                # Einzelnen Benutzer-Fehler behandeln, aber fortfahren
                $statusList.Add([PSCustomObject]@{
                    DisplayName       = $mailbox.DisplayName
                    UserPrincipalName = $mailbox.UserPrincipalName
                    AutoReplyState    = $false
                    StartTime         = "-"
                    EndTime           = "-"
                    InternalMessage   = "Fehler beim Abrufen der Konfiguration"
                })
                Write-Log "Fehler beim Abrufen der AutoReply-Konfiguration für $($mailbox.UserPrincipalName): $($_.Exception.Message)" -Type Warning
            }
        }
    } catch {
        if ($script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException]) {
            $cancelled = $true
        }
        else {
            $errorMsg = Get-FormattedError -ErrorRecord $_
            Write-Log "Fehler in Get-AutoReplyStatusAction: $errorMsg" -Type Error
            Update-StatusBar -Message "Fehler beim Laden der Statusinformationen." -Type Error
            return
        }
    } finally {
        Stop-UIBusy
    }

    if ($null -ne $script:dgAutoReplyStatus) {
        $script:dgAutoReplyStatus.ItemsSource = $statusList.ToArray()
    }
    
    $activeCount = @($statusList | Where-Object { $_.AutoReplyState -eq $true }).Count
    $message = "$($statusList.Count) Statusinformationen geladen ($activeCount aktive Abwesenheitsnotizen)."
    if ($cancelled) { $message = "Abgebrochen - Teilergebnis: $message" }
    Update-StatusBar -Message $message -Type $(if ($cancelled) { "Warning" } else { "Success" })
}

function Set-AutoReplyAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$UserIdentity,
        [Parameter(Mandatory = $true)][datetime]$StartDate,
        [Parameter(Mandatory = $true)][datetime]$EndDate,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Message,
        # Status nach dem Setzen nicht neu laden (Massenbearbeitung)
        [switch]$NoRefresh
    )

    if (-not (Confirm-ExchangeConnection)) { return $false }
    Update-StatusBar -Message "Aktiviere Abwesenheitsnotiz für $UserIdentity..." -Type Info

    try {
        $actionDescription = "Abwesenheitsnotiz für '$UserIdentity' von $StartDate bis $EndDate aktivieren."
        if ($PSCmdlet.ShouldProcess($UserIdentity, $actionDescription)) {
            Set-MailboxAutoReplyConfiguration -Identity $UserIdentity `
                -AutoReplyState Scheduled `
                -StartTime $StartDate `
                -EndTime $EndDate `
                -InternalMessage $Message `
                -ExternalMessage $Message `
                -ExternalAudience All `
                -ErrorAction Stop
            
            Log-Action "Abwesenheitsnotiz für $UserIdentity aktiviert ($StartDate - $EndDate)"
            Update-StatusBar -Message "Abwesenheitsnotiz für $UserIdentity erfolgreich aktiviert." -Type Success
            if (-not $NoRefresh) { $null = Get-AutoReplyStatusAction -UserIdentity $UserIdentity } # Status aktualisieren
        }
        return $true
    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_
        Write-Log "Fehler in Set-AutoReplyAction für '$UserIdentity': $errorMsg" -Type Error
        Update-StatusBar -Message "Fehler beim Aktivieren der Abwesenheitsnotiz für $UserIdentity." -Type Error
        if ($NoRefresh) { throw }
        $null = Show-MessageBox -Message "Die Abwesenheitsnotiz für '$UserIdentity' konnte nicht aktiviert werden: $errorMsg" -Title "Fehler" -Type Error
        return $false
    }
}

# Aktiviert dieselbe Abwesenheitsnotiz für mehrere Benutzer
function Invoke-AutoReplyBulkAction {
    [CmdletBinding()]
    param(
        [string[]]$Identities
    )

    if (-not (Confirm-ExchangeConnection)) {
        $null = Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
        return
    }

    $targets = @($Identities | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($targets.Count -eq 0 -and $null -ne $script:dgAutoReplyStatus) {
        $targets = @(Get-SelectedGridItems -DataGrid $script:dgAutoReplyStatus | ForEach-Object { [string]$_.UserPrincipalName } | Where-Object { $_ } | Select-Object -Unique)
    }
    if ($targets.Count -eq 0) {
        $targets = @(Split-AutoReplyIdentities -Text ([string]$script:txtAutoReplyUser.Text))
    }
    if ($targets.Count -eq 0) {
        $null = Show-MessageBox -Message "Bitte Benutzer in der Statusliste markieren (Strg/Umschalt) oder mehrere Adressen im Feld 'Benutzer' eingeben (getrennt durch ; oder ,)." -Title "Keine Benutzer" -Type Info
        return
    }

    $range = Get-AutoReplyDateRange
    if ($null -eq $range) { return }
    $message = Format-AutoReplyMessage -Message ([string]$script:txtAutoReplyMessage.Text) -DateRange $range
    if ([string]::IsNullOrWhiteSpace($message)) {
        $null = Show-MessageBox -Message "Bitte eine Nachricht eingeben." -Title "Fehlende Eingabe" -Type Warning
        return
    }

    $preview = ($targets | Select-Object -First 10) -join "`n"
    if ($targets.Count -gt 10) { $preview += "`n... und $($targets.Count - 10) weitere" }
    $answer = Show-MessageBox -Message "Abwesenheitsnotiz ($($range.StartDisplay) - $($range.EndDisplay)) für $($targets.Count) Benutzer aktivieren?`n`n$preview" -Title "Masseneinrichtung" -Type "YesNo"
    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $ok = New-Object 'System.Collections.Generic.List[string]'
    $errors = New-Object 'System.Collections.Generic.List[string]'
    Start-UIBusy -Message "Aktiviere Abwesenheitsnotizen..." -Title "Masseneinrichtung" -Cancelable
    try {
        $index = 0
        foreach ($identity in $targets) {
            $index++
            Update-UIBusy -Message "Aktiviere Abwesenheitsnotizen" -Current $index -Total $targets.Count
            Assert-UINotCancelled
            try {
                $null = Set-AutoReplyAction -UserIdentity $identity -StartDate $range.StartTime -EndDate $range.EndTime -Message $message -NoRefresh
                $ok.Add($identity)
            }
            catch {
                $errors.Add("${identity}: $($_.Exception.Message)")
            }
        }
    }
    catch {
        if (-not ($script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException])) {
            $errors.Add($_.Exception.Message)
        }
    }
    finally {
        Stop-UIBusy
    }

    Write-Log "Masseneinrichtung Abwesenheitsnotiz: $($ok.Count) erfolgreich, $($errors.Count) Fehler." -Type $(if ($errors.Count -gt 0) { "Warning" } else { "Success" })
    if ($errors.Count -gt 0) {
        $null = Show-MessageBox -Message "$($ok.Count) von $($targets.Count) Abwesenheitsnotizen aktiviert. Fehler:`n`n$(($errors | Select-Object -First 10) -join "`n")" -Title "Masseneinrichtung" -Type Warning
    }
    else {
        $null = Show-MessageBox -Message "$($ok.Count) Abwesenheitsnotizen wurden aktiviert." -Title "Masseneinrichtung" -Type Info
    }
    if ($ok.Count -gt 0) { Get-AutoReplyStatusAction -UserIdentity $ok.ToArray() }
}

function Disable-AutoReplyAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$UserIdentity,
        # Status nach dem Deaktivieren nicht neu laden (Massenbearbeitung)
        [switch]$NoRefresh
    )

    if (-not (Confirm-ExchangeConnection)) { return $false }
    Update-StatusBar -Message "Deaktiviere Abwesenheitsnotiz für $UserIdentity..." -Type Info

    try {
        $actionDescription = "Abwesenheitsnotiz für '$UserIdentity' deaktivieren."
        if ($PSCmdlet.ShouldProcess($UserIdentity, $actionDescription)) {
            Set-MailboxAutoReplyConfiguration -Identity $UserIdentity -AutoReplyState Disabled -ErrorAction Stop
            Log-Action "Abwesenheitsnotiz für $UserIdentity deaktiviert"
            Update-StatusBar -Message "Abwesenheitsnotiz für $UserIdentity erfolgreich deaktiviert." -Type Success
            if (-not $NoRefresh) { $null = Get-AutoReplyStatusAction -UserIdentity $UserIdentity } # Status aktualisieren
        }
        return $true
    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_
        Write-Log "Fehler in Disable-AutoReplyAction für '$UserIdentity': $errorMsg" -Type Error
        Update-StatusBar -Message "Fehler beim Deaktivieren der Abwesenheitsnotiz für $UserIdentity." -Type Error
        if ($NoRefresh) { throw }
        $null = Show-MessageBox -Message "Die Abwesenheitsnotiz für '$UserIdentity' konnte nicht deaktiviert werden: $errorMsg" -Title "Fehler" -Type Error
        return $false
    }
}

function Export-AutoReplyStatusAction {
    [CmdletBinding()]
    param()

    try {
        $data = @($script:dgAutoReplyStatus.ItemsSource)
        if ($data.Count -eq 0) {
            Show-MessageBox -Message "Es sind keine Daten zum Exportieren vorhanden." -Title "Keine Daten" -Type Info
            return
        }

        $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveFileDialog.Filter = "CSV-Dateien (*.csv)|*.csv|Alle Dateien (*.*)|*.*"
        $saveFileDialog.FileName = "AutoReplyStatus_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        
        if ($saveFileDialog.ShowDialog() -eq $true) {
            $filePath = $saveFileDialog.FileName
            $data | ConvertTo-SafeCsvObject | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8 -Delimiter ";"
            Update-StatusBar -Message "Daten erfolgreich nach '$filePath' exportiert." -Type Success
            Show-MessageBox -Message "Die Daten wurden erfolgreich exportiert." -Title "Export erfolgreich" -Type Info
        }
    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_
        Write-Log "Fehler in Export-AutoReplyStatusAction: $errorMsg" -Type Error
        Update-StatusBar -Message "Fehler beim Exportieren der Daten." -Type Error
    }
}

function Initialize-AutoReplyTab {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Initialisiere Auto Reply-Tab..." -Type "Info"

        # UI-Elemente referenzieren
        $script:txtAutoReplyUser = Get-XamlElement -ElementName "txtAutoReplyUser"
        $script:dpAutoReplyStart = Get-XamlElement -ElementName "dpAutoReplyStart"
        $script:dpAutoReplyEnd = Get-XamlElement -ElementName "dpAutoReplyEnd"
        $script:txtAutoReplyMessage = Get-XamlElement -ElementName "txtAutoReplyMessage"
        $script:btnSetAutoReply = Get-XamlElement -ElementName "btnSetAutoReply"
        $script:btnDisableAutoReply = Get-XamlElement -ElementName "btnDisableAutoReply"
        $script:dgAutoReplyStatus = Get-XamlElement -ElementName "dgAutoReplyStatus"
        $script:btnRefreshAutoReply = Get-XamlElement -ElementName "btnRefreshAutoReply"
        $script:btnBulkAutoReply = Get-XamlElement -ElementName "btnBulkAutoReply"
        $script:btnExportAutoReply = Get-XamlElement -ElementName "btnExportAutoReply"

        # Standardwerte setzen
        if ($null -ne $script:dpAutoReplyStart) { $script:dpAutoReplyStart.SelectedDate = (Get-Date).Date }
        if ($null -ne $script:dpAutoReplyEnd) { $script:dpAutoReplyEnd.SelectedDate = (Get-Date).Date.AddDays(7) }

        # Event-Handler registrieren
        $null = Register-EventHandler -Control $script:btnSetAutoReply -Handler {
            try {
                $users = @(Split-AutoReplyIdentities -Text ([string]$script:txtAutoReplyUser.Text))
                if ($users.Count -eq 0) {
                    Show-MessageBox -Message "Bitte wählen Sie einen Benutzer aus oder geben Sie eine E-Mail-Adresse ein." -Title "Fehlende Eingabe" -Type Warning
                    return
                }
                if ($users.Count -gt 1) {
                    # Mehrere Adressen: über die Masseneinrichtung (mit Bestätigung und Fortschritt)
                    Invoke-AutoReplyBulkAction -Identities $users
                    return
                }
                $range = Get-AutoReplyDateRange
                if ($null -eq $range) { return }
                $message = Format-AutoReplyMessage -Message ([string]$script:txtAutoReplyMessage.Text) -DateRange $range
                if ([string]::IsNullOrWhiteSpace($message)) {
                    Show-MessageBox -Message "Bitte eine Nachricht eingeben." -Title "Fehlende Eingabe" -Type Warning
                    return
                }
                $null = Set-AutoReplyAction -UserIdentity $users[0] -StartDate $range.StartTime -EndDate $range.EndTime -Message $message
            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_
                Write-Log "Fehler im btnSetAutoReply Handler: $errorMsg" -Type Error
                Update-StatusBar -Message "Fehler: $($_.Exception.Message)" -Type Error
            }
        } -ControlName "btnSetAutoReply"

        $null = Register-EventHandler -Control $script:btnDisableAutoReply -Handler {
            try {
                $users = @(Split-AutoReplyIdentities -Text ([string]$script:txtAutoReplyUser.Text))
                if ($users.Count -eq 0) {
                    $users = @(Get-SelectedGridItems -DataGrid $script:dgAutoReplyStatus | ForEach-Object { [string]$_.UserPrincipalName } | Where-Object { $_ })
                }
                if ($users.Count -eq 0) {
                    Show-MessageBox -Message "Bitte wählen Sie einen Benutzer aus oder geben Sie eine E-Mail-Adresse ein." -Title "Fehlende Eingabe" -Type Warning
                    return
                }
                if ($users.Count -eq 1) {
                    $null = Disable-AutoReplyAction -UserIdentity $users[0]
                    return
                }

                $answer = Show-MessageBox -Message "Abwesenheitsnotiz für $($users.Count) Benutzer deaktivieren?" -Title "Deaktivieren" -Type "YesNo"
                if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }

                # Mehrere Benutzer: ohne Zwischenaktualisierung deaktivieren, danach einmal alle Benutzer neu laden
                $ok = New-Object 'System.Collections.Generic.List[string]'
                $errors = New-Object 'System.Collections.Generic.List[string]'
                $cancelled = $false
                Start-UIBusy -Message "Deaktiviere Abwesenheitsnotizen..." -Title "Automatische Antworten" -Cancelable
                try {
                    $index = 0
                    foreach ($user in $users) {
                        $index++
                        Update-UIBusy -Message "Deaktiviere Abwesenheitsnotizen" -Current $index -Total $users.Count
                        Assert-UINotCancelled
                        try {
                            if (Disable-AutoReplyAction -UserIdentity $user -NoRefresh) {
                                $ok.Add($user)
                            }
                            else {
                                $errors.Add("${user}: nicht deaktiviert")
                            }
                        }
                        catch {
                            $errors.Add("${user}: $($_.Exception.Message)")
                        }
                    }
                }
                catch {
                    if ($script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException]) {
                        $cancelled = $true
                    }
                    else {
                        $errors.Add($_.Exception.Message)
                    }
                }
                finally {
                    Stop-UIBusy
                }

                Write-Log "Abwesenheitsnotizen deaktiviert: $($ok.Count) erfolgreich, $($errors.Count) Fehler$(if ($cancelled) { ', abgebrochen' })." -Type $(if ($errors.Count -gt 0) { "Warning" } else { "Success" })
                if ($errors.Count -gt 0) {
                    $null = Show-MessageBox -Message "$($ok.Count) von $($users.Count) Abwesenheitsnotizen deaktiviert. Fehler:`n`n$(($errors | Select-Object -First 10) -join "`n")" -Title "Deaktivieren" -Type Warning
                }
                Get-AutoReplyStatusAction -UserIdentity $users
            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_
                Write-Log "Fehler im btnDisableAutoReply Handler: $errorMsg" -Type Error
                Update-StatusBar -Message "Fehler: $($_.Exception.Message)" -Type Error
            }
        } -ControlName "btnDisableAutoReply"

        $null = Register-EventHandler -Control $script:btnRefreshAutoReply -Handler {
            try {
                # Ohne Benutzerangabe wird der Status aller Benutzerpostfächer geladen
                $users = @(Split-AutoReplyIdentities -Text ([string]$script:txtAutoReplyUser.Text))
                if ($users.Count -eq 0) {
                    Get-AutoReplyStatusAction
                } else {
                    Get-AutoReplyStatusAction -UserIdentity $users
                }
            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_
                Write-Log "Fehler im btnRefreshAutoReply Handler: $errorMsg" -Type Error
                Update-StatusBar -Message "Fehler beim Aktualisieren: $($_.Exception.Message)" -Type Error
            }
        } -ControlName "btnRefreshAutoReply"

        $null = Register-EventHandler -Control $script:btnExportAutoReply -Handler {
            try {
                Export-AutoReplyStatusAction
            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_
                Write-Log "Fehler im btnExportAutoReply Handler: $errorMsg" -Type Error
                Update-StatusBar -Message "Fehler beim Export: $($_.Exception.Message)" -Type Error
            }
        } -ControlName "btnExportAutoReply"
        
        $null = Register-EventHandler -Control $script:btnBulkAutoReply -Handler {
            Invoke-AutoReplyBulkAction
        } -ControlName "btnBulkAutoReply"

        $null = Register-HelpLink -ElementName "helpLinkAutoReply" -Topic "AutoReply"

        Write-Log "Auto Reply-Tab erfolgreich initialisiert." -Type "Success"
        return $true
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_
        Write-Log "Fehler beim Initialisieren des Auto Reply-Tabs: $errorMsg" -Type "Error"
        return $false
    }
}
