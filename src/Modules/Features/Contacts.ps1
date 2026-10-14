# =====================================================================
# easyEXO - Modul: Kontakte (MailContacts / MailUsers)
# Datei: src/Modules/Features/Contacts.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# Implementiert die Hauptfunktionen für den Kontakte-Tab
function Update-ExoContact {
    [CmdletBinding()]
    param()
    
    try {
        $name = $script:txtContactName.Text.Trim()
        $email = $script:txtContactEmail.Text.Trim()
        
        if ([string]::IsNullOrEmpty($name) -or [string]::IsNullOrEmpty($email)) {
            Show-MessageBox -Message "Bitte geben Sie einen Namen und eine E-Mail-Adresse ein." -Title "Fehlende Angaben" -Type "Warning"
            return
        }
        
        # Stellen Sie sicher, dass wir mit Exchange verbunden sind
        if (!(Confirm-ExchangeConnection)) {
            Show-MessageBox -Message "Bitte zuerst mit Exchange Online verbinden." -Title "Nicht verbunden" -Type "Warning"
            return
        }
        
        if ($script:dgContacts.SelectedItem) {
            $contactObj = $script:dgContacts.SelectedItem
            $contactId = $contactObj.Identity
            
            Write-StatusMessage "Aktualisiere Kontakt $contactId..."
            
            # Exchange-Befehle ausführen
            Set-MailContact -Identity $contactId -Name $name -ExternalEmailAddress $email -ErrorAction Stop
            
            Write-StatusMessage "Kontakt $name erfolgreich aktualisiert."
            Show-MessageBox -Message "Der Kontakt $name wurde erfolgreich aktualisiert." -Title "Kontakt aktualisiert" -Type "Info"
            
            # Kontakte aktualisieren
            Search-ExoContacts
            
            # Felder leeren
            $script:txtContactName.Text = ""
            $script:txtContactEmail.Text = ""
        }
        else {
            Show-MessageBox -Message "Bitte wählen Sie zuerst einen Kontakt aus der Liste aus." -Title "Kein Kontakt ausgewählt" -Type "Warning"
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-StatusMessage "Fehler beim Aktualisieren des Kontakts: $errorMsg"
        Show-MessageBox -Message "Fehler beim Aktualisieren des Kontakts: $errorMsg" -Title "Fehler" -Type "Error"
    }
}

function Search-ExoContacts {
    [CmdletBinding()]
    param()
    
    try {
        $searchTerm = $txtContactSearch.Text.Trim()
        
        if ([string]::IsNullOrEmpty($searchTerm)) {
            Show-MessageBox -Message "Bitte geben Sie einen Suchbegriff ein." -Title "Fehlende Angaben" -Type "Warning"
            return
        }
        
        # Stellen Sie sicher, dass wir mit Exchange verbunden sind
        if (!(Confirm-ExchangeConnection)) {
            Show-MessageBox -Message "Bitte zuerst mit Exchange Online verbinden." -Title "Nicht verbunden" -Type "Warning"
            return
        }
        
        Write-StatusMessage "Suche nach Kontakten mit '$searchTerm'..."
        
        # Exchange-Befehle ausführen
        $safeSearchTerm = ConvertTo-OPathValue -Value $searchTerm
        $contacts = Get-MailContact -Filter "Name -like '*$safeSearchTerm*' -or EmailAddresses -like '*$safeSearchTerm*'" -ResultSize Unlimited | 
            Select-Object Name, DisplayName, PrimarySmtpAddress, ExternalEmailAddress, Department, Title
        
        # Daten zum DataGrid hinzufügen
        $script:dgContacts.Dispatcher.Invoke([action]{
            $script:dgContacts.ItemsSource = $contacts
        }, "Normal")
        
        Write-StatusMessage "Suche abgeschlossen. $($contacts.Count) Kontakte gefunden."
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-StatusMessage "Fehler bei der Kontaktsuche: $errorMsg"
        Show-MessageBox -Message "Fehler bei der Kontaktsuche: $errorMsg" -Title "Fehler" -Type "Error"
    }
}

function Initialize-ContactsTab {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log  "Initialisiere Kontakte-Tab" -Type "Info"
        
        # UI-Elemente referenzieren
        $txtContactName = Get-XamlElement -ElementName "txtContactName" -Required
        $txtContactAlias = Get-XamlElement -ElementName "txtContactAlias" -Required
        $txtContactExternalEmail = Get-XamlElement -ElementName "txtContactExternalEmail" -Required
        $btnCreateContact = Get-XamlElement -ElementName "btnCreateContact" -Required
        
        $txtUpdateContactName = Get-XamlElement -ElementName "txtUpdateContactName" -Required
        $txtUpdateContactEmail = Get-XamlElement -ElementName "txtUpdateContactEmail" -Required
        $btnUpdateContact = Get-XamlElement -ElementName "btnUpdateContact" -Required

        $txtContactSearch = Get-XamlElement -ElementName "txtContactSearch" -Required
        $btnShowMailContacts = Get-XamlElement -ElementName "btnShowMailContacts" -Required
        $btnShowMailUsers = Get-XamlElement -ElementName "btnShowMailUsers" -Required
        $btnRemoveContact = Get-XamlElement -ElementName "btnRemoveContact" -Required
        
        $lstContacts = Get-XamlElement -ElementName "lstContacts" -Required
        $btnExportContacts = Get-XamlElement -ElementName "btnExportContacts" -Required

        
        # Globale Variablen setzen
        $script:txtContactName = $txtContactName
        $script:txtContactAlias = $txtContactAlias
        $script:txtContactExternalEmail = $txtContactExternalEmail
        $script:txtUpdateContactName = $txtUpdateContactName
        $script:txtUpdateContactEmail = $txtUpdateContactEmail
        $script:btnUpdateContact = $btnUpdateContact
        $script:txtContactSearch = $txtContactSearch
        $script:btnShowMailContacts = $btnShowMailContacts # Hinzugefügt, um die Variable im Skript-Scope verfügbar zu machen
        $script:lstContacts = $lstContacts
        
        # Event-Handler für Buttons registrieren
        Register-EventHandler -Control $btnCreateContact -Handler {
            try {
                if (!(Confirm-ExchangeConnection)) {
                    Show-MessageBox -Message "Bitte zuerst mit Exchange Online verbinden." -Title "Nicht verbunden" -Type "Warning" 
                    return
                }

                $contactName = $script:txtContactName.Text.Trim()
                $contactAlias = $script:txtContactAlias.Text.Trim() 
                $externalEmail = $script:txtContactExternalEmail.Text.Trim()

                if ([string]::IsNullOrEmpty($contactName) -or [string]::IsNullOrEmpty($contactAlias) -or [string]::IsNullOrEmpty($externalEmail)) {
                    Show-MessageBox -Message "Bitte füllen Sie alle erforderlichen Felder aus." -Title "Fehlende Angaben" -Type "Warning"
                    return
                }

                Update-StatusBar -Message "Erstelle externen Kontakt $contactName..."

                New-MailContact -Name $contactAlias `
                              -DisplayName $contactName `
                              -ExternalEmailAddress $externalEmail `
                              -ErrorAction Stop

                Update-StatusBar -Message "Externer Kontakt erfolgreich erstellt: $contactName" -Type "Success"
                Show-MessageBox -Message "Der externe Kontakt $contactName wurde erfolgreich erstellt." -Title "Erfolg" -Type "Info"

                # Felder zurücksetzen
                $script:txtContactName.Text = ""
                $script:txtContactAlias.Text = ""
                $script:txtContactExternalEmail.Text = ""

                # Liste aktualisieren
                $btnShowMailContacts.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))

            } catch {
                $errorMsg = $_.Exception.Message
                Update-StatusBar -Message "Fehler beim Erstellen des Kontakts: $errorMsg" -Type "Error"
                Show-MessageBox -Message "Fehler beim Erstellen des Kontakts: $errorMsg" -Title "Fehler" -Type "Error"
            }
        } -ControlName "btnCreateContact"

        # Event-Handler für Kontaktauswahl in der Liste mit Register-EventHandler
        Register-EventHandler -Control $script:lstContacts -Handler {
            try {
                $selectedContact = $script:lstContacts.SelectedItem
                if ($null -ne $selectedContact) {
                    # Felder mit aktuellen Werten befüllen
                    $script:txtUpdateContactName.Text = $selectedContact.DisplayName
                    $script:txtUpdateContactEmail.Text = ($selectedContact.ExternalEmailAddress -replace "SMTP:", "")
                    
                    # Update-Button aktivieren
                    $script:btnUpdateContact.IsEnabled = $true
                } else {
                    # Felder leeren und Button deaktivieren wenn keine Auswahl
                    $script:txtUpdateContactName.Text = ""
                    $script:txtUpdateContactEmail.Text = ""
                    $script:btnUpdateContact.IsEnabled = $false
                }
            } catch {
                Write-Log "Fehler beim Befüllen der Update-Felder: $($_.Exception.Message)" -Type "Error"
                Update-StatusBar -Message "Fehler beim Laden der Kontaktdetails" -Type "Error"
            }
        } -EventName "SelectionChanged" -ControlName "lstContacts"

        # Event-Handler für Update-Button
        Register-EventHandler -Control $script:btnUpdateContact -Handler {
            try {
                if (!(Confirm-ExchangeConnection)) {
                    Show-MessageBox -Message "Bitte zuerst mit Exchange Online verbinden." -Title "Nicht verbunden" -Type "Warning"
                    return
                }

                $selectedContact = $script:lstContacts.SelectedItem
                if ($null -eq $selectedContact) {
                    Show-MessageBox -Message "Bitte wählen Sie einen Kontakt aus." -Title "Keine Auswahl" -Type "Warning"
                    return
                }

                $newName = $script:txtUpdateContactName.Text.Trim()
                $newEmail = $script:txtUpdateContactEmail.Text.Trim()

                if ([string]::IsNullOrEmpty($newName) -or [string]::IsNullOrEmpty($newEmail)) {
                    Show-MessageBox -Message "Bitte füllen Sie alle Felder aus." -Title "Fehlende Angaben" -Type "Warning"
                    return
                }

                Update-StatusBar -Message "Aktualisiere Kontakt $($selectedContact.DisplayName)..."

                # Kontakt aktualisieren
                Set-MailContact -Identity $selectedContact.PrimarySmtpAddress `
                              -DisplayName $newName `
                              -ExternalEmailAddress "SMTP:$newEmail" `
                              -ErrorAction Stop

                Show-MessageBox -Message "Der Kontakt wurde erfolgreich aktualisiert." -Title "Erfolg" -Type "Info"

                # Liste aktualisieren
                $script:btnShowMailContacts.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))

            } catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Aktualisieren des Kontakts: $errorMsg" -Type "Error"
                Update-StatusBar -Message "Fehler beim Aktualisieren des Kontakts" -Type "Error"
                Show-MessageBox -Message "Fehler beim Aktualisieren des Kontakts: $errorMsg" -Title "Fehler" -Type "Error"
            }
        } -ControlName "btnUpdateContact"
        
        Register-EventHandler -Control $btnShowMailContacts -Handler {
            # Verbindungsprüfung - nur bei Bedarf
            if (-not $script:isConnected) {
                [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Keine Verbindung", 
                    [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                return
            }
            
            $script:txtStatus.Text = "Lade MailContacts..."
            try {
                # Versuche einen einfachen Exchange-Befehl zur Verbindungsprüfung
                Get-OrganizationConfig -ErrorAction Stop | Out-Null
                
                # Exchange-Befehle ausführen
                $contacts = Get-Recipient -RecipientType MailContact -ResultSize Unlimited | 
                    Select-Object DisplayName, PrimarySmtpAddress, ExternalEmailAddress, RecipientTypeDetails
                
                # Als Array behandeln
                if ($null -ne $contacts -and -not ($contacts -is [Array])) {
                    $contacts = @($contacts)
                }
                
                $script:lstContacts.ItemsSource = $contacts
                $script:txtStatus.Text = "$($contacts.Count) MailContacts gefunden"
            }
            catch {
                $errorMsg = $_.Exception.Message
                
                # Wenn der Fehler auf eine abgelaufene Verbindung hindeutet
                if ($errorMsg -like "*Connect-ExchangeOnline*" -or 
                    $errorMsg -like "*session*" -or 
                    $errorMsg -like "*authentication*") {
                    
                    # Status korrigieren
                    $script:isConnected = $false
                    $script:txtConnectionStatus.Text = "Nicht verbunden"
                    $script:txtConnectionStatus.Foreground = $script:disconnectedBrush
                    
                    [System.Windows.MessageBox]::Show("Die Verbindung zu Exchange Online ist unterbrochen. Bitte stellen Sie die Verbindung erneut her.", 
                        "Verbindungsfehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                }
                else {
                    $script:txtStatus.Text = "Fehler beim Laden der MailContacts: $errorMsg"
                    [System.Windows.MessageBox]::Show("Fehler beim Laden der MailContacts: $errorMsg", 
                        "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
            }
        } -ControlName "btnShowMailContacts"
        
        Write-Log  "Event-Handler für btnShowMailUsers registrieren" -Type "Info"

        Register-EventHandler -Control $btnShowMailUsers -Handler {
            # Überprüfe, ob wir mit Exchange verbunden sind
            if (-not (Confirm-ExchangeConnection)) {
                Show-MessageBox -Message "Bitte zuerst mit Exchange Online verbinden." -Title "Nicht verbunden" -Type "Warning"
                return
            }
            
            $script:txtStatus.Text = "Lade MailUsers..."
            try {
                $users = Get-MailUser -ResultSize Unlimited | 
                    Select-Object DisplayName, PrimarySmtpAddress, ExternalEmailAddress, RecipientTypeDetails
                
                $script:lstContacts.ItemsSource = $users
                $script:txtStatus.Text = "$($users.Count) MailUsers gefunden"
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler beim Laden der MailUsers: $errorMsg"
                Show-MessageBox -Message "Fehler beim Laden der MailUsers: $errorMsg" -Title "Fehler" -Type "Error"
            }
        } -ControlName "btnShowMailUsers"
        
        Register-EventHandler -Control $btnRemoveContact -Handler {
                if ($null -eq $script:lstContacts.SelectedItem) {
                    Show-MessageBox -Message "Bitte wählen Sie zuerst einen Kontakt aus." -Title "Kein Kontakt ausgewählt" -Type "Warning"
                    return
                }
                
                $selectedContact = $script:lstContacts.SelectedItem
                $contactType = $selectedContact.RecipientTypeDetails
                $contactName = $selectedContact.DisplayName
                $contactEmail = $selectedContact.PrimarySmtpAddress
                
                $confirmResult = Show-MessageBox -Message "Sind Sie sicher, dass Sie den Kontakt '$contactName' löschen möchten?" `
                    -Title "Kontakt löschen" -Type "YesNo"
                
                if ($confirmResult -eq "Yes") {
                    try {
                        $script:txtStatus.Text = "Lösche Kontakt $contactName..."
                        
                        if ($contactType -like "*MailContact*") {
                            Remove-MailContact -Identity $contactEmail -Confirm:$false -ErrorAction Stop
                        }
                        elseif ($contactType -like "*MailUser*") {
                            Remove-MailUser -Identity $contactEmail -Confirm:$false -ErrorAction Stop
                        }
                        
                        $script:txtStatus.Text = "Kontakt $contactName erfolgreich gelöscht"
                        Show-MessageBox -Message "Der Kontakt '$contactName' wurde erfolgreich gelöscht." -Title "Kontakt gelöscht" -Type "Info"
                        
                        # Liste aktualisieren
                        if ($contactType -like "*MailContact*") {
                            $btnShowMailContacts.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
                        }
                        else {
                            $btnShowMailUsers.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
                        }
                    }
                    catch {
                        $errorMsg = $_.Exception.Message
                        $script:txtStatus.Text = "Fehler beim Löschen des Kontakts: $errorMsg"
                        Show-MessageBox -Message "Fehler beim Löschen des Kontakts: $errorMsg" -Title "Fehler" -Type "Error"
                    }
            }
        } -ControlName "btnRemoveContact"
        
        Register-EventHandler -Control $btnExportContacts -Handler {
                if ($script:lstContacts.Items.Count -eq 0) {
                    Show-MessageBox -Message "Es gibt keine Kontakte zum Exportieren." -Title "Keine Daten" -Type "Info"
                    return
                }
                
                $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
                $saveFileDialog.Filter = "CSV-Dateien (*.csv)|*.csv"
                $saveFileDialog.Title = "Kontakte exportieren"
                $saveFileDialog.FileName = "Kontakte_Export_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                
                if ($saveFileDialog.ShowDialog() -eq $true) {
                    try {
                        $script:txtStatus.Text = "Exportiere Kontakte nach $($saveFileDialog.FileName)..."
                        $script:lstContacts.ItemsSource | ConvertTo-SafeCsvObject | Export-Csv -Path $saveFileDialog.FileName -NoTypeInformation -Encoding UTF8 -Delimiter ";"
                        $script:txtStatus.Text = "Kontakte erfolgreich exportiert: $($saveFileDialog.FileName)"
                        Show-MessageBox -Message "Die Kontakte wurden erfolgreich nach '$($saveFileDialog.FileName)' exportiert." -Title "Export erfolgreich" -Type "Info"
                    }
                    catch {
                        $errorMsg = $_.Exception.Message
                        $script:txtStatus.Text = "Fehler beim Exportieren der Kontakte: $errorMsg"
                        Show-MessageBox -Message "Fehler beim Exportieren der Kontakte: $errorMsg" -Title "Fehler" -Type "Error"
                    }
                }
        } -ControlName "btnExportContacts"

        $null = Register-HelpLink -ElementName "helpLinkContacts" -Topic "Contacts"
        
        return $true
            }
            catch {
                $errorMsg = $_.Exception.Message
        return $false
    }
}
