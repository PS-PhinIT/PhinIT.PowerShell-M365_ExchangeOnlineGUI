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

function Get-AutoReplyStatusAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][string]$UserIdentity
    )

    if (-not (Confirm-ExchangeConnection)) { return }
    Update-StatusBar -Message "Lade Status der Abwesenheitsnotizen..." -Type Info

    try {
        $mailboxes = @()
        if (-not [string]::IsNullOrWhiteSpace($UserIdentity)) {
            $mailboxes = Get-Mailbox -Identity $UserIdentity -ErrorAction Stop
        } else {
            $mailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox
        }

        $statusList = [System.Collections.Generic.List[object]]::new()
        foreach ($mailbox in $mailboxes) {
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

        if ($null -ne $script:dgAutoReplyStatus) {
            $script:dgAutoReplyStatus.ItemsSource = $statusList
        }
        
        $activeCount = ($statusList | Where-Object { $_.AutoReplyState -eq $true }).Count
        Update-StatusBar -Message "$($statusList.Count) Statusinformationen geladen ($activeCount aktive Abwesenheitsnotizen)." -Type Success
    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_
        Write-Log "Fehler in Get-AutoReplyStatusAction: $errorMsg" -Type Error
        Update-StatusBar -Message "Fehler beim Laden der Statusinformationen." -Type Error
    }
}

function Set-AutoReplyAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$UserIdentity,
        [Parameter(Mandatory = $true)][datetime]$StartDate,
        [Parameter(Mandatory = $true)][datetime]$EndDate,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not (Confirm-ExchangeConnection)) { return }
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
            
            Update-StatusBar -Message "Abwesenheitsnotiz für $UserIdentity erfolgreich aktiviert." -Type Success
            Get-AutoReplyStatusAction -UserIdentity $UserIdentity # Status aktualisieren
        }
    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_
        Write-Log "Fehler in Set-AutoReplyAction für '$UserIdentity': $errorMsg" -Type Error
        Update-StatusBar -Message "Fehler beim Aktivieren der Abwesenheitsnotiz für $UserIdentity." -Type Error
    }
}

function Disable-AutoReplyAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$UserIdentity
    )

    if (-not (Confirm-ExchangeConnection)) { return }
    Update-StatusBar -Message "Deaktiviere Abwesenheitsnotiz für $UserIdentity..." -Type Info

    try {
        $actionDescription = "Abwesenheitsnotiz für '$UserIdentity' deaktivieren."
        if ($PSCmdlet.ShouldProcess($UserIdentity, $actionDescription)) {
            Set-MailboxAutoReplyConfiguration -Identity $UserIdentity -AutoReplyState Disabled -ErrorAction Stop
            Update-StatusBar -Message "Abwesenheitsnotiz für $UserIdentity erfolgreich deaktiviert." -Type Success
            Get-AutoReplyStatusAction -UserIdentity $UserIdentity # Status aktualisieren
        }
    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_
        Write-Log "Fehler in Disable-AutoReplyAction für '$UserIdentity': $errorMsg" -Type Error
        Update-StatusBar -Message "Fehler beim Deaktivieren der Abwesenheitsnotiz für $UserIdentity." -Type Error
    }
}

function Export-AutoReplyStatusAction {
    [CmdletBinding()]
    param()

    try {
        $data = $script:dgAutoReplyStatus.ItemsSource
        if ($null -eq $data -or $data.Count -eq 0) {
            Show-MessageBox -Message "Es sind keine Daten zum Exportieren vorhanden." -Title "Keine Daten" -Type Info
            return
        }

        $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveFileDialog.Filter = "CSV-Dateien (*.csv)|*.csv|Alle Dateien (*.*)|*.*"
        $saveFileDialog.FileName = "AutoReplyStatus_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        
        if ($saveFileDialog.ShowDialog() -eq $true) {
            $filePath = $saveFileDialog.FileName
            $data | ConvertTo-SafeCsvObject | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
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
        if ($null -ne $script:dpAutoReplyStart) { $script:dpAutoReplyStart.SelectedDate = (Get-Date) }
        if ($null -ne $script:dpAutoReplyEnd) { $script:dpAutoReplyEnd.SelectedDate = (Get-Date).AddDays(7) }

        # Event-Handler registrieren
        Register-EventHandler -Control $script:btnSetAutoReply -Handler {
            try {
                $user = $script:txtAutoReplyUser.Text
                if ([string]::IsNullOrWhiteSpace($user)) {
                    Show-MessageBox -Message "Bitte wählen Sie einen Benutzer aus oder geben Sie eine E-Mail-Adresse ein." -Title "Fehlende Eingabe" -Type Warning
                    return
                }
                Set-AutoReplyAction -UserIdentity $user `
                    -StartDate $script:dpAutoReplyStart.SelectedDate `
                    -EndDate $script:dpAutoReplyEnd.SelectedDate `
                    -Message $script:txtAutoReplyMessage.Text
            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_
                Write-Log "Fehler im btnSetAutoReply Handler: $errorMsg" -Type Error
                Update-StatusBar -Message "Fehler: $($_.Exception.Message)" -Type Error
            }
        } -ControlName "btnSetAutoReply"

        Register-EventHandler -Control $script:btnDisableAutoReply -Handler {
            try {
                $user = $script:txtAutoReplyUser.Text
                if ([string]::IsNullOrWhiteSpace($user)) {
                    Show-MessageBox -Message "Bitte wählen Sie einen Benutzer aus oder geben Sie eine E-Mail-Adresse ein." -Title "Fehlende Eingabe" -Type Warning
                    return
                }
                Disable-AutoReplyAction -UserIdentity $user
            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_
                Write-Log "Fehler im btnDisableAutoReply Handler: $errorMsg" -Type Error
                Update-StatusBar -Message "Fehler: $($_.Exception.Message)" -Type Error
            }
        } -ControlName "btnDisableAutoReply"

        Register-EventHandler -Control $script:btnRefreshAutoReply -Handler {
            try {
                # Prüfen ob ein spezifischer Benutzer angegeben wurde
                $user = $script:txtAutoReplyUser.Text.Trim()
                if ([string]::IsNullOrWhiteSpace($user)) {
                    # Wenn kein Benutzer angegeben wurde, alle AutoReply-Status abrufen
                    Get-AutoReplyStatusAction
                } else {
                    # Wenn ein Benutzer angegeben wurde, nur dessen Status abrufen
                    Get-AutoReplyStatusAction -UserIdentity $user
                }
            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_
                Write-Log "Fehler im btnRefreshAutoReply Handler: $errorMsg" -Type Error
                Update-StatusBar -Message "Fehler beim Aktualisieren: $($_.Exception.Message)" -Type Error
            }
        } -ControlName "btnRefreshAutoReply"

        Register-EventHandler -Control $script:btnExportAutoReply -Handler {
            try {
                Export-AutoReplyStatusAction
            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_
                Write-Log "Fehler im btnExportAutoReply Handler: $errorMsg" -Type Error
                Update-StatusBar -Message "Fehler beim Export: $($_.Exception.Message)" -Type Error
            }
        } -ControlName "btnExportAutoReply"
        
        Register-EventHandler -Control $script:btnBulkAutoReply -Handler {
            Show-MessageBox -Message "Die Funktion für die Massenbearbeitung ist noch nicht implementiert." -Title "In Entwicklung" -Type Info
        } -ControlName "btnBulkAutoReply"


        Write-Log "Auto Reply-Tab erfolgreich initialisiert." -Type "Success"
        return $true
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_
        Write-Log "Fehler beim Initialisieren des Auto Reply-Tabs: $errorMsg" -Type "Error"
        return $false
    }
}
