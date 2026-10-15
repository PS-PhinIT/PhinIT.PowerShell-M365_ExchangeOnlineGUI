# =====================================================================
# easyEXO - Modul: Kalenderberechtigungen
# Datei: src/Modules/Features/Calendar.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# -------------------------------------------------
# Abschnitt: Kalenderberechtigungen
# -------------------------------------------------
function Get-CalendarPermission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MailboxUser
    )
    
    try {
        # Eingabevalidierung
        if (-not (Validate-Email -Email $MailboxUser)) {
            throw "Ungültige E-Mail-Adresse für Postfach."
        }
        
        Write-Log  "Rufe Kalenderberechtigungen ab für: $MailboxUser" -Type "Info"
        
        # Prüfe deutsche und englische Kalenderordner
        $permissions = $null
        try {
            # Versuche mit deutschem Pfad
            $identity = "${MailboxUser}:\Kalender"
            Write-Log  "Versuche deutschen Kalenderpfad: $identity" -Type "Info"
            $permissions = Get-MailboxFolderPermission -Identity $identity -ErrorAction Stop
        } 
        catch {
            try {
                # Versuche mit englischem Pfad
                $identity = "${MailboxUser}:\Calendar"
                Write-Log  "Versuche englischen Kalenderpfad: $identity" -Type "Info"
                $permissions = Get-MailboxFolderPermission -Identity $identity -ErrorAction Stop
            } 
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log  "Beide Kalenderpfade fehlgeschlagen: $errorMsg" -Type "Error"
                throw "Kalenderordner konnte nicht gefunden werden. Weder 'Kalender' noch 'Calendar' sind zugänglich."
            }
        }
        
        Write-Log  "Kalenderberechtigungen abgerufen: $($permissions.Count) Einträge gefunden" -Type "Success"
        Update-StatusBar -Message "Kalenderberechtigungen abgerufen" -Type "Success"
        Log-Action "Kalenderberechtigungen für $MailboxUser erfolgreich abgerufen: $($permissions.Count) Einträge."
        return $permissions
    } 
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Abrufen der Kalenderberechtigungen: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Abrufen der Kalenderberechtigungen: $errorMsg"
        throw $errorMsg
    }
}

# Funktion für das Anzeigen aller Kalenderberechtigungen
function Show-CalendarPermissions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MailboxUser
    )
    
    try {
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange verbunden. Bitte stellen Sie zuerst eine Verbindung her."
        }
        
        # Prüfe, ob eine gültige E-Mail-Adresse eingegeben wurde
        if (-not (Validate-Email -Email $MailboxUser)) {
            throw "Bitte geben Sie eine gültige E-Mail-Adresse ein."
        }
        
        # Status aktualisieren
        if ($null -ne $script:txtStatus) {
            $script:txtStatus.Text = "Rufe Kalenderberechtigungen ab..."
        }
        
        # Versuche Kalenderberechtigungen abzurufen
        $permissions = Get-CalendarPermission -MailboxUser $MailboxUser
        
        # Aufbereiten der Berechtigungsdaten für die DataGrid-Anzeige
        $permissionsForGrid = @()
        foreach ($permission in $permissions) {
            # Extrahiere die relevanten Informationen und erstelle ein neues Objekt
            $permObj = [PSCustomObject]@{
                User = $permission.User.DisplayName
                AccessRights = ($permission.AccessRights -join ", ")
                IsInherited = $permission.IsInherited
            }
            $permissionsForGrid += $permObj
        }
        
        # Aktualisiere das DataGrid mit den aufbereiteten Daten
        if ($null -ne $script:lstCalendarPermissions) {
            $script:lstCalendarPermissions.Dispatcher.Invoke([Action]{
                $script:lstCalendarPermissions.ItemsSource = $permissionsForGrid
            }, "Normal")
        }
        
        # Status aktualisieren
        if ($null -ne $script:txtStatus) {
            $script:txtStatus.Text = "Kalenderberechtigungen erfolgreich abgerufen."
        }
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Anzeigen der Kalenderberechtigungen: $errorMsg" -Type "Error"
        
        if ($null -ne $script:txtStatus) {
            $script:txtStatus.Text = "Fehler: $errorMsg"
        }
        
        return $false
    }
}

# -------------------------------------------------
# Abschnitt: Verwaltung der Standard und Anonym Berechtigungen
# -------------------------------------------------
function Set-DefaultCalendarPermission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MailboxUser,
        
        [Parameter(Mandatory = $true)]
        [string]$AccessRights
    )
    
    try {
        # Eingabevalidierung
        if (-not (Validate-Email -Email $MailboxUser)) {
            throw "Ungültige E-Mail-Adresse für Postfach."
        }
        
        Write-Log  "Setze Standard-Kalenderberechtigungen für: $MailboxUser auf: $AccessRights" -Type "Info"
        
        # Prüfe deutsche und englische Kalenderordner
        $identityDE = "${MailboxUser}:\Kalender"
        $identityEN = "${MailboxUser}:\Calendar"
        $identity = $null
        
        # Prüfe, welcher Pfad existiert
        try {
            if (Get-MailboxFolderPermission -Identity $identityDE -User Default -ErrorAction SilentlyContinue) {
                $identity = $identityDE
                Write-Log  "Deutscher Kalenderpfad gefunden: $identity" -Type "Info"
            } else {
                $identity = $identityEN
                Write-Log  "Englischer Kalenderpfad wird verwendet: $identity" -Type "Info"
            }
        } catch {
            $identity = $identityEN
            Write-Log  "Fehler beim Prüfen des deutschen Pfads, verwende englischen Pfad: $identity" -Type "Warning"
        }
        
        # Standard-Berechtigungen setzen
        Write-Log  "Aktualisiere Standard-Berechtigungen für: $identity" -Type "Info"
        Set-MailboxFolderPermission -Identity $identity -User Default -AccessRights $AccessRights -ErrorAction Stop
        
        Write-Log  "Standard-Kalenderberechtigungen erfolgreich gesetzt" -Type "Success"
        Log-Action "Standard-Kalenderberechtigungen für $MailboxUser auf $AccessRights gesetzt"
        return $true
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Setzen der Standard-Kalenderberechtigungen: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Setzen der Standard-Kalenderberechtigungen: $errorMsg"
        throw $errorMsg
    }
}

function Set-AnonymousCalendarPermission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MailboxUser,
        
        [Parameter(Mandatory = $true)]
        [string]$AccessRights
    )
    
    try {
        # Eingabevalidierung
        if (-not (Validate-Email -Email $MailboxUser)) {
            throw "Ungültige E-Mail-Adresse für Postfach."
        }
        
        Write-Log  "Setze Anonym-Kalenderberechtigungen für: $MailboxUser auf: $AccessRights" -Type "Info"
        
        # Prüfe deutsche und englische Kalenderordner
        $identityDE = "${MailboxUser}:\Kalender"
        $identityEN = "${MailboxUser}:\Calendar"
        $identity = $null
        
        # Prüfe, welcher Pfad existiert
        try {
            if (Get-MailboxFolderPermission -Identity $identityDE -User Anonymous -ErrorAction SilentlyContinue) {
                $identity = $identityDE
                Write-Log  "Deutscher Kalenderpfad gefunden: $identity" -Type "Info"
            } else {
                $identity = $identityEN
                Write-Log  "Englischer Kalenderpfad wird verwendet: $identity" -Type "Info"
            }
        } catch {
            $identity = $identityEN
            Write-Log  "Fehler beim Prüfen des deutschen Pfads, verwende englischen Pfad: $identity" -Type "Warning"
        }
        
        # Anonym-Berechtigungen setzen
        Write-Log  "Aktualisiere Anonymous-Berechtigungen für: $identity" -Type "Info"
        Set-MailboxFolderPermission -Identity $identity -User Anonymous -AccessRights $AccessRights -ErrorAction Stop
        
        Write-Log  "Anonymous-Kalenderberechtigungen erfolgreich gesetzt" -Type "Success"
        Log-Action "Anonymous-Kalenderberechtigungen für $MailboxUser auf $AccessRights gesetzt"
        return $true
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Setzen der Anonymous-Kalenderberechtigungen: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Setzen der Anonymous-Kalenderberechtigungen: $errorMsg"
        throw $errorMsg
    }
}

# -------------------------------------------------
# Abschnitt: Standardberechtigungen für alle Postfächer
# -------------------------------------------------
# Gibt $true nur zurück, wenn alle Postfächer fehlerfrei bearbeitet wurden (kein Fehler, kein Abbruch).
# Die detaillierte Statusmeldung (Erfolgreich/Fehler) wird in der Statusleiste angezeigt.
function Set-DefaultCalendarPermissionForAll {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessRights
    )
    
    $totalCount = 0
    $successCount = 0
    $errorCount = 0
    $cancelled = $false
    
    Start-UIBusy -Message "Setze Standard-Kalenderberechtigungen für alle Postfächer..." -Title "Kalenderberechtigungen" -Cancelable
    try {
        Write-Log  "Setze Standard-Kalenderberechtigungen für alle Postfächer auf: $AccessRights" -Type "Info"
        Update-StatusBar -Message "Setze Standard-Kalenderberechtigungen für alle Postfächer..." -Type Info
        
        # Alle Mailboxen abrufen
        Write-Log  "Rufe alle Mailboxen ab" -Type "Info"
        $mailboxes = @(Get-Mailbox -ResultSize Unlimited -ErrorAction Stop | Step-UIProgress -Activity "Lade Postfachliste")
        $totalCount = $mailboxes.Count
        
        Write-Log  "$totalCount Mailboxen gefunden" -Type "Info"
        
        $progressIndex = 0
        foreach ($mailbox in $mailboxes) {
            $progressIndex++
            Update-UIBusy -Message "Setze Standard-Kalenderberechtigungen" -Current $progressIndex -Total $totalCount
            # Abbruch nur zwischen zwei Postfächern prüfen (außerhalb des Fehlerzählers)
            Assert-UINotCancelled
            
            $mailboxAddress = "$($mailbox.PrimarySmtpAddress)"
            try {
                Write-Log  "Bearbeite Postfach $progressIndex/$totalCount - $mailboxAddress" -Type "Info"
                
                $null = Set-DefaultCalendarPermission -MailboxUser $mailboxAddress -AccessRights $AccessRights
                $successCount++
                Write-Log  "Standard-Kalenderberechtigungen erfolgreich für $mailboxAddress gesetzt" -Type "Success"
            }
            catch {
                $errorCount++
                $errorMsg = $_.Exception.Message
                Write-Log  "Fehler bei Postfach $mailboxAddress - $errorMsg" -Type "Error"
                Log-Action "Fehler beim Setzen der Standard-Kalenderberechtigungen für $mailboxAddress`: $errorMsg"
            }
        }
    }
    catch {
        if ($script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException]) {
            $cancelled = $true
        }
        else {
            $errorMsg = $_.Exception.Message
            Write-Log  "Fehler beim Setzen der Standard-Kalenderberechtigungen für alle - $errorMsg" -Type "Error"
            Update-StatusBar -Message "Fehler: $errorMsg" -Type Error
            Log-Action "Fehler beim Setzen der Standard-Kalenderberechtigungen für alle: $errorMsg"
            return $false
        }
    }
    finally {
        Stop-UIBusy
    }
    
    if ($cancelled) {
        $statusMessage = "Setzen der Standard-Kalenderberechtigungen abgebrochen. Erfolgreich: $successCount, Fehler: $errorCount, nicht bearbeitet: $($totalCount - $successCount - $errorCount)"
        $statusType = "Warning"
    }
    elseif ($errorCount -gt 0) {
        $statusMessage = "Standard-Kalenderberechtigungen für alle Postfächer gesetzt. Erfolgreich: $successCount, Fehler: $errorCount"
        $statusType = "Warning"
    }
    else {
        $statusMessage = "Standard-Kalenderberechtigungen für alle Postfächer gesetzt. Erfolgreich: $successCount, Fehler: 0"
        $statusType = "Success"
    }
    
    Update-StatusBar -Message $statusMessage -Type $statusType
    Write-Log  $statusMessage -Type $statusType
    Log-Action $statusMessage
    
    return (-not $cancelled -and $errorCount -eq 0)
}

function Initialize-CalendarTab {
    [CmdletBinding()]
    param()
    
    try {
        
        # Referenzieren der UI-Elemente im Kalender-Tab
        $txtCalendarSource = Get-XamlElement -ElementName "txtCalendarSource"
        $txtCalendarTarget = Get-XamlElement -ElementName "txtCalendarTarget"
        $cmbCalendarPermission = Get-XamlElement -ElementName "cmbCalendarPermission"
        $btnAddCalendarPermission = Get-XamlElement -ElementName "btnAddCalendarPermission"
        $btnRemoveCalendarPermission = Get-XamlElement -ElementName "btnRemoveCalendarPermission"
        $txtCalendarMailboxUser = Get-XamlElement -ElementName "txtCalendarMailboxUser"
        $btnShowCalendarPermissions = Get-XamlElement -ElementName "btnShowCalendarPermissions"
        $cmbDefaultPermission = Get-XamlElement -ElementName "cmbDefaultPermission"
        $btnSetDefaultPermission = Get-XamlElement -ElementName "btnSetDefaultPermission"
        $btnSetAnonymousPermission = Get-XamlElement -ElementName "btnSetAnonymousPermission"
        $btnSetAllCalPermission = Get-XamlElement -ElementName "btnSetAllCalPermission"
        $lstCalendarPermissions = Get-XamlElement -ElementName "lstCalendarPermissions"
        $btnExportCalendarPermissions = Get-XamlElement -ElementName "btnExportCalendarPermissions"
        $helpLinkCalendar = Get-XamlElement -ElementName "helpLinkCalendar"
        
        # Globale Variablen für spätere Verwendung setzen
        $script:txtCalendarSource = $txtCalendarSource
        $script:txtCalendarTarget = $txtCalendarTarget
        $script:cmbCalendarPermission = $cmbCalendarPermission
        $script:txtCalendarMailboxUser = $txtCalendarMailboxUser
        $script:lstCalendarPermissions = $lstCalendarPermissions
        $script:cmbDefaultPermission = $cmbDefaultPermission
        
        # Berechtigungsstufen für Kalender hinzufügen
        $calendarPermissions = @(
            "Owner", 
            "PublishingEditor", 
            "Editor", 
            "PublishingAuthor", 
            "Author", 
            "NonEditingAuthor", 
            "Reviewer", 
            "Contributor", 
            "AvailabilityOnly", 
            "LimitedDetails", 
            "None"
        )
        
        foreach ($permission in $calendarPermissions) {
            $cmbCalendarPermission.Items.Add($permission) | Out-Null
            $cmbDefaultPermission.Items.Add($permission) | Out-Null
        }
        
        # Standardwerte setzen
        if ($cmbCalendarPermission.Items.Count -gt 0) {
            $cmbCalendarPermission.SelectedIndex = 6  # Reviewer als Standard
        }
        
        if ($cmbDefaultPermission.Items.Count -gt 0) {
            $cmbDefaultPermission.SelectedIndex = 8  # AvailabilityOnly als Standard
        }
        
        # Event-Handler für Kalender-Buttons registrieren
        Register-EventHandler -Control $btnAddCalendarPermission -Handler {
            try {
                # Prüfen, ob eine Exchange-Verbindung besteht
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.",
                        "Keine Verbindung",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                # Prüfen, ob alle erforderlichen Eingaben vorhanden sind
                if ([string]::IsNullOrWhiteSpace($script:txtCalendarSource.Text) -or 
                    [string]::IsNullOrWhiteSpace($script:txtCalendarTarget.Text) -or
                    $null -eq $script:cmbCalendarPermission.SelectedItem) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte geben Sie Quell- und Zielbenutzer an und wählen Sie eine Berechtigungsstufe.",
                        "Unvollständige Eingabe",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $sourceMailbox = $script:txtCalendarSource.Text
                $targetUser = $script:txtCalendarTarget.Text
                $permission = $script:cmbCalendarPermission.SelectedItem.ToString()
                
                # Liste der bekannten lokalisierten Kalendernamen
                $knownCalendarNames = @(
                    "Calendar",      # Englisch
                    "Kalender",      # Deutsch
                    "Calendrier",    # Französisch
                    "Calendario",    # Spanisch/Italienisch
                    "Agenda",        # Niederländisch
                    "Kalendarz"      # Polnisch
                )
                
                # Versuche den korrekten Kalenderordner zu finden
                try {
                    Write-Log "Suche Kalenderordner für Postfach $sourceMailbox" -Type Info
                    $mailboxFolders = Get-MailboxFolderStatistics -Identity $sourceMailbox -FolderScope Calendar
                    
                    if ($mailboxFolders) {
                        # Suche nach bekannten lokalisierten Kalendernamen
                        $calendarFolder = $mailboxFolders | Where-Object { 
                            $_.FolderType -eq "Calendar" -and
                            ($knownCalendarNames -contains $_.Name)
                        } | Select-Object -First 1
                        
                        if ($calendarFolder) {
                            $calendarFolderName = $calendarFolder.Name
                            Write-Log "Gefundener Kalenderordner: $calendarFolderName" -Type Info
                        } else {
                            # Fallback: Nimm den ersten Kalenderordner
                            $calendarFolder = $mailboxFolders | Where-Object { 
                                $_.FolderType -eq "Calendar" 
                            } | Select-Object -First 1
                            
                            if ($calendarFolder) {
                                $calendarFolderName = $calendarFolder.Name
                                Write-Log "Fallback-Kalenderordner gefunden: $calendarFolderName" -Type Warning
                            } else {
                                throw "Kein Kalenderordner gefunden"
                            }
                        }
                    } else {
                        throw "Keine Ordnerstatistiken verfügbar"
                    }
                    
                    # Kalenderberechtigung hinzufügen bzw. aktualisieren, falls der Benutzer bereits einen Eintrag hat
                    $calendarIdentity = "$sourceMailbox`:\$calendarFolderName"
                    $existingPermission = $null
                    try {
                        $existingPermission = Get-MailboxFolderPermission -Identity $calendarIdentity -User $targetUser -ErrorAction Stop
                    }
                    catch {
                        # Kein bestehender Eintrag für diesen Benutzer
                        $existingPermission = $null
                    }
                    
                    if ($null -ne $existingPermission) {
                        Write-Log "Aktualisiere bestehende Berechtigung: $targetUser auf $sourceMailbox\$calendarFolderName ($permission)" -Type Info
                        Set-MailboxFolderPermission -Identity $calendarIdentity -User $targetUser -AccessRights $permission -ErrorAction Stop
                        $successMessage = "Kalenderberechtigung erfolgreich aktualisiert."
                        Log-Action "Kalenderberechtigung aktualisiert: $sourceMailbox -> $targetUser ($permission)"
                    }
                    else {
                        Write-Log "Füge Berechtigung hinzu: $targetUser auf $sourceMailbox\$calendarFolderName ($permission)" -Type Info
                        $null = Add-MailboxFolderPermission -Identity $calendarIdentity -User $targetUser -AccessRights $permission -ErrorAction Stop
                        $successMessage = "Kalenderberechtigung erfolgreich hinzugefügt."
                        Log-Action "Kalenderberechtigung hinzugefügt: $sourceMailbox -> $targetUser ($permission)"
                    }
                    Write-Log $successMessage -Type Success
                    
                    # Aktualisiere die Berechtigungsliste
                    if ($script:txtCalendarMailboxUser.Text -eq $sourceMailbox) {
                        $null = Show-CalendarPermissions -MailboxUser $sourceMailbox
                    }
                    $script:txtStatus.Text = $successMessage
                }
                catch {
                    $errorMsg = $_.Exception.Message
                    Write-Log "Fehler beim Hinzufügen der Kalenderberechtigung: $errorMsg" -Type Error
                    $script:txtStatus.Text = "Fehler: $errorMsg"
                    throw
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Kritischer Fehler: $errorMsg" -Type Error
                $script:txtStatus.Text = "Kritischer Fehler: $errorMsg"
            }
        } -ControlName "btnAddCalendarPermission"
        
        Register-EventHandler -Control $btnRemoveCalendarPermission -Handler {
            try {
                # Prüfen, ob eine Exchange-Verbindung besteht
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.",
                        "Keine Verbindung",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                # Prüfen, ob alle erforderlichen Eingaben vorhanden sind
                if ([string]::IsNullOrWhiteSpace($script:txtCalendarSource.Text) -or 
                    [string]::IsNullOrWhiteSpace($script:txtCalendarTarget.Text)) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte geben Sie Quellpostfach und Zielbenutzer an.",
                        "Unvollständige Eingabe",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $sourceMailbox = $script:txtCalendarSource.Text.Trim()
                $targetUser = $script:txtCalendarTarget.Text.Trim()

                $confirmResult = Show-MessageBox -Message "Möchten Sie die Kalenderberechtigung von '$targetUser' auf den Kalender von '$sourceMailbox' wirklich entfernen?" -Title "Entfernen bestätigen" -Type "Question"
                if ($confirmResult -ne "Yes") {
                    $script:txtStatus.Text = "Entfernen der Kalenderberechtigung abgebrochen."
                    return
                }
                
                try {
                    # Kalenderberechtigung entfernen
                    $calendarFolders = Get-MailboxFolderStatistics -Identity $sourceMailbox -FolderScope Calendar
                    $defaultCalendar = $calendarFolders | Where-Object { $_.FolderType -eq "Calendar" } | Select-Object -First 1
                    
                    if ($defaultCalendar) {
                        $calendarPath = "$sourceMailbox`:\$($defaultCalendar.Name)"
                        # Remove-MailboxFolderPermission liefert keine Rückgabe - Fehler werden per -ErrorAction Stop ausgelöst
                        Remove-MailboxFolderPermission -Identity $calendarPath -User $targetUser -Confirm:$false -ErrorAction Stop
                        $script:txtStatus.Text = "Kalenderberechtigung erfolgreich entfernt."
                        Log-Action "Kalenderberechtigung entfernt: $sourceMailbox -> $targetUser"
                        # Aktualisiere die Berechtigungsliste
                        if ($script:txtCalendarMailboxUser.Text -eq $sourceMailbox) {
                            Show-CalendarPermissions -Mailbox $sourceMailbox
                        }
                    } else {
                        throw "Es wurde kein Standardkalender im Postfach '$sourceMailbox' gefunden."
                    }
                }
                catch {
                    Write-Log "Fehler beim Entfernen der Kalenderberechtigung: $($_.Exception.Message)" -Type Error
                    throw
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Kritischer Fehler: $errorMsg" -Type Error
                $script:txtStatus.Text = "Fehler: " + $errorMsg
            }
        } -ControlName "btnRemoveCalendarPermission"
        
        Register-EventHandler -Control $btnShowCalendarPermissions -Handler {
            try {
                # Prüfen, ob eine Exchange-Verbindung besteht
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.",
                        "Keine Verbindung",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                # Prüfen, ob ein Benutzer angegeben wurde
                if ([string]::IsNullOrWhiteSpace($script:txtCalendarMailboxUser.Text)) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte geben Sie einen Benutzer an, dessen Kalenderberechtigungen angezeigt werden sollen.",
                        "Unvollständige Eingabe",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $mailbox = $script:txtCalendarMailboxUser.Text
                
                # Kalenderberechtigungen anzeigen (Show-CalendarPermissions setzt im Fehlerfall selbst die Fehlermeldung)
                $showResult = Show-CalendarPermissions -MailboxUser $mailbox
                
                if ($showResult -eq $true) {
                    $script:txtStatus.Text = "Kalenderberechtigungen für $mailbox wurden geladen."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnShowCalendarPermissions"
        
        Register-EventHandler -Control $btnSetDefaultPermission -Handler {
            try {
                # Prüfen, ob eine Exchange-Verbindung besteht
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.",
                        "Keine Verbindung",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                # Prüfen, ob alle erforderlichen Eingaben vorhanden sind
                if ([string]::IsNullOrWhiteSpace($script:txtCalendarSource.Text) -or 
                    $null -eq $script:cmbDefaultPermission.SelectedItem) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte geben Sie einen Quellbenutzer an und wählen Sie eine Standard-Berechtigungsstufe.",
                        "Unvollständige Eingabe",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $sourceMailbox = $script:txtCalendarSource.Text
                $permission = $script:cmbDefaultPermission.SelectedItem.ToString()
                
                # Standard-Kalenderberechtigung setzen
                $result = Set-DefaultCalendarPermission -Mailbox $sourceMailbox -AccessRight $permission
                
                if ($result) {
                    $script:txtStatus.Text = "Standard-Kalenderberechtigung erfolgreich gesetzt."
                    # Aktualisiere die Berechtigungsliste, wenn der aktuelle Benutzer angezeigt wird
                    if ($script:txtCalendarMailboxUser.Text -eq $sourceMailbox) {
                        Show-CalendarPermissions -Mailbox $sourceMailbox
                    }
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnSetDefaultPermission"
        
        Register-EventHandler -Control $btnSetAnonymousPermission -Handler {
            try {
                # Prüfen, ob eine Exchange-Verbindung besteht
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.",
                        "Keine Verbindung",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                # Prüfen, ob alle erforderlichen Eingaben vorhanden sind
                if ([string]::IsNullOrWhiteSpace($script:txtCalendarSource.Text) -or 
                    $null -eq $script:cmbDefaultPermission.SelectedItem) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte geben Sie einen Quellbenutzer an und wählen Sie eine Berechtigungsstufe für anonyme Benutzer.",
                        "Unvollständige Eingabe",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $sourceMailbox = $script:txtCalendarSource.Text
                $permission = $script:cmbDefaultPermission.SelectedItem.ToString()
                
                # Anonyme Kalenderberechtigung setzen
                $result = Set-AnonymousCalendarPermission -Mailbox $sourceMailbox -AccessRight $permission
                
                if ($result) {
                    $script:txtStatus.Text = "Anonyme Kalenderberechtigung erfolgreich gesetzt."
                    # Aktualisiere die Berechtigungsliste, wenn der aktuelle Benutzer angezeigt wird
                    if ($script:txtCalendarMailboxUser.Text -eq $sourceMailbox) {
                        Show-CalendarPermissions -Mailbox $sourceMailbox
                    }
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnSetAnonymousPermission"
        
        Register-EventHandler -Control $btnSetAllCalPermission -Handler {
            try {
                # Prüfen, ob eine Exchange-Verbindung besteht
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.",
                        "Keine Verbindung",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                # Sicherheitsabfrage
                $result = [System.Windows.MessageBox]::Show(
                    "Diese Aktion setzt die Standard-Kalenderberechtigungen für ALLE Postfächer in der Organisation. Möchten Sie fortfahren?",
                    "Massenänderung bestätigen",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Warning)
                
                if ($result -eq [System.Windows.MessageBoxResult]::No) {
                    return
                }
                
                # Prüfen, ob eine Berechtigungsstufe ausgewählt wurde
                if ($null -eq $script:cmbDefaultPermission.SelectedItem) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte wählen Sie eine Standard-Berechtigungsstufe.",
                        "Unvollständige Eingabe",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $permission = $script:cmbDefaultPermission.SelectedItem.ToString()
                
                # Standard-Kalenderberechtigung für alle Postfächer setzen
                # Die detaillierte Statusmeldung (Erfolgreich/Fehler) setzt die Funktion selbst - hier nicht überschreiben
                $null = Set-DefaultCalendarPermissionForAll -AccessRights $permission
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnSetAllCalPermission"
        
        Register-EventHandler -Control $btnExportCalendarPermissions -Handler {
            try {
                # Prüfen, ob Daten zum Exportieren vorhanden sind
                if ($null -eq $script:lstCalendarPermissions.Items -or $script:lstCalendarPermissions.Items.Count -eq 0) {
                    [System.Windows.MessageBox]::Show(
                        "Es sind keine Kalenderberechtigungen zum Exportieren vorhanden. Bitte zeigen Sie zuerst die Berechtigungen eines Benutzers an.",
                        "Keine Daten",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                # Speicherort für die CSV-Datei auswählen
                $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
                $saveDialog.Filter = "CSV-Dateien (*.csv)|*.csv|Alle Dateien (*.*)|*.*"
                $saveDialog.Title = "Kalenderberechtigungen exportieren"
                $saveDialog.FileName = "Kalenderberechtigungen_$($script:txtCalendarMailboxUser.Text)_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                
                $result = $saveDialog.ShowDialog()
                
                if ($result -eq $true) {
                    $exportPath = $saveDialog.FileName
                    
                    # Daten aus dem DataGrid extrahieren und als CSV exportieren
                    $script:lstCalendarPermissions.Items | 
                        Select-Object User, AccessRights, IsInherited | ConvertTo-SafeCsvObject | 
                        Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8
                    
                    $script:txtStatus.Text = "Kalenderberechtigungen wurden nach $exportPath exportiert."
                    
                    # Erfolgsmeldung anzeigen
                    [System.Windows.MessageBox]::Show(
                        "Die Kalenderberechtigungen wurden erfolgreich nach '$exportPath' exportiert.",
                        "Export erfolgreich",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Information
                    )
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnExportCalendarPermissions"
        
        # Hilfe-Link initialisieren
        if ($null -ne $helpLinkCalendar) {
            $helpLinkCalendar.Add_MouseLeftButtonDown({
                Show-HelpDialog -Topic "Calendar"
            })
            
            $helpLinkCalendar.Add_MouseEnter({
                $this.TextDecorations = [System.Windows.TextDecorations]::Underline
                $this.Cursor = [System.Windows.Input.Cursors]::Hand
            })
            
            $helpLinkCalendar.Add_MouseLeave({
                $this.TextDecorations = $null
                $this.Cursor = [System.Windows.Input.Cursors]::Arrow
            })
        }
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        return $false
    }
}
