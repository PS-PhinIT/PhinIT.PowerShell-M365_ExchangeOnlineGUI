# =====================================================================
# easyEXO - Modul: Posteingangsregeln
# Datei: src/Modules/Features/InboxRules.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# -------------------------------------------------
# Abschnitt: Inbox Rules-Funktionen
# -------------------------------------------------

function Get-InboxRulesAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserIdentity
    )
    
    try {
        Write-Log "Rufe Inbox Rules ab für Benutzer: $UserIdentity" -Type "Info"
        
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange Online verbunden."
        }
        
        # Status aktualisieren
        if ($null -ne $script:txtStatus) {
            Update-GuiText -TextElement $script:txtStatus -Message "Lade Inbox Rules für $UserIdentity..."
        }
        
        # Inbox Rules abrufen
        $inboxRules = Get-InboxRule -Mailbox $UserIdentity -ErrorAction Stop
        
        # Daten für die Anzeige aufbereiten
        $rulesForGrid = foreach ($rule in $inboxRules) {
            # Bedingungen sammeln
            $conditions = @()
            if ($rule.From) {
                $conditions += "Von: $($rule.From -join ', ')"
            }
            if ($rule.FromAddressContainsWords) {
                $conditions += "Absender enthält: $($rule.FromAddressContainsWords -join ', ')"
            }
            if ($rule.SubjectContainsWords) {
                $conditions += "Betreff enthält: $($rule.SubjectContainsWords -join ', ')"
            }
            if ($rule.BodyContainsWords) {
                $conditions += "Text enthält: $($rule.BodyContainsWords -join ', ')"
            }
            if ($rule.ReceivedAfterDate) {
                $conditions += "Empfangen nach: $($rule.ReceivedAfterDate)"
            }
            if ($rule.ReceivedBeforeDate) {
                $conditions += "Empfangen vor: $($rule.ReceivedBeforeDate)"
            }
            if ($rule.WithImportance) {
                $conditions += "Wichtigkeit: $($rule.WithImportance)"
            }
            if ($rule.HasAttachment) {
                $conditions += "Hat Anhang: $($rule.HasAttachment)"
            }
            
            # Aktionen sammeln
            $actions = @()
            if ($rule.MoveToFolder) {
                $actions += "Verschieben in Ordner: $($rule.MoveToFolder)"
            }
            if ($rule.CopyToFolder) {
                $actions += "Kopieren in Ordner: $($rule.CopyToFolder)"
            }
            if ($rule.ForwardTo) {
                $actions += "Weiterleiten an: $($rule.ForwardTo -join ', ')"
            }
            if ($rule.ForwardAsAttachmentTo) {
                $actions += "Als Anhang weiterleiten an: $($rule.ForwardAsAttachmentTo -join ', ')"
            }
            if ($rule.RedirectTo) {
                $actions += "Umleiten an: $($rule.RedirectTo -join ', ')"
            }
            if ($rule.MarkAsRead) {
                $actions += "Als gelesen markieren: $($rule.MarkAsRead)"
            }
            if ($rule.MarkImportance) {
                $actions += "Wichtigkeit setzen: $($rule.MarkImportance)"
            }
            if ($rule.DeleteMessage) {
                $actions += "Nachricht löschen: $($rule.DeleteMessage)"
            }
            if ($rule.StopProcessingRules) {
                $actions += "Weitere Regeln stoppen: $($rule.StopProcessingRules)"
            }
            
            # Objekt für DataGrid erstellen
            [PSCustomObject]@{
                Identity = $rule.Identity
                Name = $rule.Name
                Description = $rule.Description
                Enabled = $rule.Enabled
                Priority = $rule.Priority
                Conditions = $conditions -join '; '
                Actions = $actions -join '; '
            }
        }
        
        # Daten in das DataGrid laden
        if ($null -ne $script:dgInboxRules) {
            $script:dgInboxRules.Dispatcher.Invoke([action]{
                $script:dgInboxRules.ItemsSource = $rulesForGrid
            }, "Normal")
        }
        
        Write-Log "Inbox Rules erfolgreich geladen: $($rulesForGrid.Count) Regeln" -Type "Success"
        
        # Status aktualisieren
        if ($null -ne $script:txtStatus) {
            Update-GuiText -TextElement $script:txtStatus -Message "Inbox Rules geladen: $($rulesForGrid.Count) Regeln für $UserIdentity gefunden."
        }
        
        Log-Action "Inbox Rules abgerufen für $UserIdentity - $($rulesForGrid.Count) Regeln"
        return $rulesForGrid
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Abrufen der Inbox Rules: $errorMsg" -Type "Error"
        
        if ($null -ne $script:txtStatus) {
            Update-GuiText -TextElement $script:txtStatus -Message "Fehler beim Laden der Inbox Rules: $errorMsg"
        }
        
        Log-Action "Fehler beim Abrufen der Inbox Rules für $UserIdentity - $errorMsg"
        return @()
    }
}

function New-InboxRuleAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserIdentity,
        
        [Parameter(Mandatory = $true)]
        [string]$RuleName,
        
        [Parameter(Mandatory = $true)]
        [string]$FromAddress,
        
        [Parameter(Mandatory = $false)]
        [string]$TargetFolder = "Inbox",
        
        [Parameter(Mandatory = $false)]
        [bool]$MarkAsRead = $false
    )
    
    try {
        Write-Log "Erstelle neue Inbox Rule: $RuleName für $UserIdentity" -Type "Info"
        
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange Online verbunden."
        }
        
        # Parameter für die Regel aufbauen
        $ruleParams = @{
            Mailbox = $UserIdentity
            Name = $RuleName
            From = $FromAddress
            ErrorAction = "Stop"
        }
        
        # Zielordner setzen (falls nicht Inbox)
        if ($TargetFolder -ne "Inbox") {
            $fullFolderPath = "$($UserIdentity):\$($TargetFolder)"
            $ruleParams.Add("MoveToFolder", $fullFolderPath)
        }
        
        # Als gelesen markieren
        if ($MarkAsRead) {
            $ruleParams.Add("MarkAsRead", $true)
        }
        
        # Inbox Rule erstellen
        $newRule = New-InboxRule @ruleParams
        
        Write-Log "Inbox Rule '$RuleName' erfolgreich erstellt für $UserIdentity" -Type "Success"
        Log-Action "Inbox Rule erstellt: $RuleName für $UserIdentity"
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Erstellen der Inbox Rule: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Erstellen der Inbox Rule $RuleName für $UserIdentity`: $errorMsg"
        throw "Fehler beim Erstellen der Regel: $errorMsg"
    }
}

function Set-InboxRuleStateAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserIdentity,
        
        [Parameter(Mandatory = $true)]
        [string]$RuleIdentity,
        
        [Parameter(Mandatory = $true)]
        [bool]$Enabled
    )
    
    try {
        $state = if ($Enabled) { "aktiviert" } else { "deaktiviert" }
        Write-Log "Setze Inbox Rule auf Status $state`: $RuleIdentity für $UserIdentity" -Type "Info"
        
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange Online verbunden."
        }
        
        # Inbox Rule Status ändern - nur Identity verwenden (enthält bereits die Mailbox-Information)
        if ($Enabled) {
            Enable-InboxRule -Identity "$UserIdentity\$RuleIdentity" -ErrorAction Stop
        }
        else {
            Disable-InboxRule -Identity "$UserIdentity\$RuleIdentity" -ErrorAction Stop
        }
        
        Write-Log "Inbox Rule '$RuleIdentity' erfolgreich $state für $UserIdentity" -Type "Success"
        Log-Action "Inbox Rule '$RuleIdentity' wurde $state für $UserIdentity"
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        $statusMsg = if ($Enabled) { "Aktivieren" } else { "Deaktivieren" }
        Write-Log "Fehler beim $statusMsg der Inbox Rule '$RuleIdentity': $errorMsg" -Type "Error"
        Log-Action "Fehler beim $statusMsg der Inbox Rule '$RuleIdentity' für $UserIdentity`: $errorMsg"
        throw "Fehler beim $statusMsg der Regel: $errorMsg"
    }
}

function Remove-InboxRuleAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserIdentity,
        
        [Parameter(Mandatory = $true)]
        [string]$RuleIdentity
    )
    
    try {
        Write-Log "Lösche Inbox Rule: $RuleIdentity für $UserIdentity" -Type "Info"
        
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange Online verbunden."
        }
        
        # Inbox Rule löschen - nur Identity verwenden
        Remove-InboxRule -Identity "$UserIdentity\$RuleIdentity" -Confirm:$false -ErrorAction Stop
        
        Write-Log "Inbox Rule '$RuleIdentity' erfolgreich gelöscht für $UserIdentity" -Type "Success"
        Log-Action "Inbox Rule '$RuleIdentity' wurde gelöscht für $UserIdentity"
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Löschen der Inbox Rule '$RuleIdentity': $errorMsg" -Type "Error"
        Log-Action "Fehler beim Löschen der Inbox Rule '$RuleIdentity' für $UserIdentity`: $errorMsg"
        throw "Fehler beim Löschen der Regel: $errorMsg"
    }
}

function Move-InboxRuleAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserIdentity,
        
        [Parameter(Mandatory = $true)]
        [string]$RuleIdentity,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Up", "Down")]
        [string]$Direction
    )
    
    try {
        $directionText = if ($Direction -eq "Up") { "nach oben" } else { "nach unten" }
        Write-Log "Verschiebe Inbox Rule $directionText`: $RuleIdentity für $UserIdentity" -Type "Info"
        
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange Online verbunden."
        }
        
        # Aktuelle Regeln abrufen, um die Priorität zu bestimmen
        $currentRules = Get-InboxRule -Mailbox $UserIdentity | Sort-Object Priority
        $currentRule = $currentRules | Where-Object { $_.Identity -eq $RuleIdentity }
        
        if (-not $currentRule) {
            throw "Regel nicht gefunden: $RuleIdentity"
        }
        
        $currentPriority = $currentRule.Priority
        $newPriority = $currentPriority
        
        if ($Direction -eq "Up") {
            # Die niedrigste Priorität ist 0. Set-InboxRule erwartet 1 als niedrigsten Wert.
            # Get-InboxRule gibt Priorität 0 zurück, aber Set-InboxRule -Priority 0 schlägt fehl.
            # Wir gehen davon aus, dass die Prioritäten bei 1 beginnen.
            if ($currentPriority -gt 1) {
                $newPriority = $currentPriority - 1
            }
        }
        elseif ($Direction -eq "Down") {
            $maxPriority = ($currentRules | Measure-Object Priority -Maximum).Maximum
            if ($currentPriority -lt $maxPriority) {
                $newPriority = $currentPriority + 1
            }
        }
        
        if ($newPriority -ne $currentPriority) {
            # Inbox Rule Priorität ändern - nur Identity verwenden
            Set-InboxRule -Identity "$UserIdentity\$RuleIdentity" -Priority $newPriority -ErrorAction Stop
            
            Write-Log "Inbox Rule '$RuleIdentity' erfolgreich $directionText verschoben für $UserIdentity" -Type "Success"
            Log-Action "Inbox Rule '$RuleIdentity' wurde $directionText verschoben für $UserIdentity (Priorität: $currentPriority -> $newPriority)"
            
            return $true
        }
        else {
            Write-Log "Inbox Rule kann nicht weiter $directionText verschoben werden" -Type "Warning"
            Show-MessageBox -Message "Die Regel befindet sich bereits ganz oben oder ganz unten in der Liste." -Title "Verschieben nicht möglich" -Type Info
            return $false
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Verschieben der Inbox Rule '$RuleIdentity': $errorMsg" -Type "Error"
        Log-Action "Fehler beim Verschieben der Inbox Rule '$RuleIdentity' für $UserIdentity`: $errorMsg"
        throw "Fehler beim Verschieben der Regel: $errorMsg"
    }
}

function Export-InboxRulesAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserIdentity,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        Write-Log "Exportiere Inbox Rules für $UserIdentity nach: $FilePath" -Type "Info"
        
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange Online verbunden."
        }
        
        # Inbox Rules abrufen
        $inboxRules = Get-InboxRule -Mailbox $UserIdentity | Select-Object Name, Description, Enabled, Priority,
            From, FromAddressContainsWords, SubjectContainsWords, BodyContainsWords,
            MoveToFolder, CopyToFolder, ForwardTo, RedirectTo, MarkAsRead, DeleteMessage
        
        # Bestimme Exportformat basierend auf Dateiendung
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        
        switch ($extension) {
            ".csv" {
                $inboxRules | ConvertTo-SafeCsvObject | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8 -Delimiter ";"
            }
            ".xml" {
                $inboxRules | Export-Clixml -Path $FilePath -Encoding UTF8
            }
            default {
                # Fallback zu CSV
                $inboxRules | ConvertTo-SafeCsvObject | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8 -Delimiter ";"
            }
        }
        
        Write-Log "Inbox Rules erfolgreich exportiert: $($inboxRules.Count) Regeln" -Type "Success"
        Log-Action "Inbox Rules exportiert für $UserIdentity nach: $FilePath ($($inboxRules.Count) Regeln)"
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Exportieren der Inbox Rules: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Exportieren der Inbox Rules für $UserIdentity`: $errorMsg"
        throw "Fehler beim Exportieren der Regeln: $errorMsg"
    }
}

function Get-MailboxFoldersAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserIdentity
    )
    
    try {
        Write-Log "Rufe Postfach-Ordner ab für: $UserIdentity" -Type "Info"
        
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange Online verbunden."
        }
        
        # Postfach-Ordnerstatistiken abrufen
        $folders = Get-MailboxFolderStatistics -Identity $UserIdentity | 
                   Where-Object { $_.FolderType -ne "Root" } |
                   Select-Object @{Name="DisplayName"; Expression={$_.FolderPath.Replace("\", " \ ") -replace "/", " / "}}, @{Name="Identity"; Expression={$_.FolderPath}} |
                   Sort-Object DisplayName
        
        Write-Log "Postfach-Ordner erfolgreich abgerufen: $($folders.Count) Ordner" -Type "Success"
        Log-Action "Postfach-Ordner abgerufen für $UserIdentity`: $($folders.Count) Ordner"
        
        return $folders
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Abrufen der Postfach-Ordner: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Abrufen der Postfach-Ordner für $UserIdentity`: $errorMsg"
        return @()
    }
}

function Refresh-InboxRuleUserDropdown {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Aktualisiere Benutzerliste für Inbox Rules" -Type "Info"
        
        # Sicherstellen, dass das ComboBox-Element über den $script-Scope verfügbar ist
        if ($null -eq $script:cmbInboxRuleUser) {
            $script:cmbInboxRuleUser = Get-XamlElement -ElementName "cmbInboxRuleUser"
            if ($null -eq $script:cmbInboxRuleUser) {
                $errorMsg = "ComboBox 'cmbInboxRuleUser' konnte nicht gefunden werden."
                Write-Log $errorMsg -Type "Error"
                Show-MessageBox -Message $errorMsg -Title "UI Fehler" -Type Error
                return
            }
        }

        $script:cmbInboxRuleUser.Dispatcher.Invoke({
            $script:cmbInboxRuleUser.ItemsSource = $null
            $script:cmbInboxRuleUser.Items.Clear()
        }, "Normal") | Out-Null
        
        if (-not $script:isConnected) {
            Write-Log "Keine Exchange-Verbindung für Benutzerabfrage" -Type "Warning"
            return $false
        }
        
        # Alle Postfächer abrufen
        $mailboxes = Get-Mailbox -ResultSize Unlimited | 
                     Where-Object { $_.RecipientTypeDetails -eq "UserMailbox" } |
                     Select-Object DisplayName, PrimarySmtpAddress |
                     Sort-Object DisplayName

        $script:cmbInboxRuleUser.Dispatcher.Invoke({
            if ($null -ne $mailboxes -and $mailboxes.Count -gt 0) {
                foreach ($mailbox in $mailboxes) {
                    $item = New-Object System.Windows.Controls.ComboBoxItem
                    $item.Content = "$($mailbox.DisplayName) ($($mailbox.PrimarySmtpAddress))"
                    $item.Tag = $mailbox.PrimarySmtpAddress
                    $item.ToolTip = "E-Mail: $($mailbox.PrimarySmtpAddress)"
                    [void]$script:cmbInboxRuleUser.Items.Add($item)
                }

                if ($script:cmbInboxRuleUser.Items.Count -gt 0) {
                    $script:cmbInboxRuleUser.SelectedIndex = -1 # Keine Auswahl
                }
                
                $statusMsg = "Benutzerliste aktualisiert: $($mailboxes.Count) Benutzer geladen."
                Write-Log $statusMsg -Type "Success"
                Update-GuiText -TextElement $script:txtStatus -Message $statusMsg
            }
            else {
                $statusMsg = "Keine Benutzerpostfächer gefunden."
                Write-Log $statusMsg -Type "Warning"
                Update-GuiText -TextElement $script:txtStatus -Message $statusMsg
                
                $placeholderItem = New-Object System.Windows.Controls.ComboBoxItem
                $placeholderItem.Content = "-- Keine Postfächer gefunden --"
                $placeholderItem.IsEnabled = $false
                [void]$script:cmbInboxRuleUser.Items.Add($placeholderItem)
            }
        }, "Normal") | Out-Null
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Aktualisieren der Benutzerliste für Inbox Rules: $errorMsg" -Type "Error"
        Show-MessageBox -Message "Fehler beim Laden der Benutzer: $errorMsg" -Title "Fehler" -Type Error
        return $false
    }
}

function Initialize-InboxRulesTab {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Initialisiere Inbox Rules-Tab..." -Type "Info"

        # UI-Elemente referenzieren
        $cmbInboxRuleUser = Get-XamlElement -ElementName "cmbInboxRuleUser"
        $btnLoadInboxRules = Get-XamlElement -ElementName "btnLoadInboxRules"
        $txtInboxRuleName = Get-XamlElement -ElementName "txtInboxRuleName"
        $txtFromAddress = Get-XamlElement -ElementName "txtFromAddress"
        $cmbTargetFolder = Get-XamlElement -ElementName "cmbTargetFolder"
        $chkMarkAsRead = Get-XamlElement -ElementName "chkMarkAsRead"
        $btnCreateInboxRule = Get-XamlElement -ElementName "btnCreateInboxRule"
        $dgInboxRules = Get-XamlElement -ElementName "dgInboxRules"
        $btnRefreshInboxRules = Get-XamlElement -ElementName "btnRefreshInboxRules"
        $btnEnableInboxRule = Get-XamlElement -ElementName "btnEnableInboxRule"
        $btnDisableInboxRule = Get-XamlElement -ElementName "btnDisableInboxRule"
        $btnDeleteInboxRule = Get-XamlElement -ElementName "btnDeleteInboxRule"
        $btnMoveRuleUp = Get-XamlElement -ElementName "btnMoveRuleUp"
        $btnMoveRuleDown = Get-XamlElement -ElementName "btnMoveRuleDown"
        $btnExportInboxRules = Get-XamlElement -ElementName "btnExportInboxRules"

        # Globale Variablen setzen
        $script:cmbInboxRuleUser = $cmbInboxRuleUser
        $script:txtInboxRuleName = $txtInboxRuleName
        $script:txtFromAddress = $txtFromAddress
        $script:cmbTargetFolder = $cmbTargetFolder
        $script:chkMarkAsRead = $chkMarkAsRead
        $script:dgInboxRules = $dgInboxRules

        # Event-Handler für "Load Rules" Button (🔄)
        Register-EventHandler -Control $btnLoadInboxRules -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                $userIdentity = $script:cmbInboxRuleUser.Text
                if ([string]::IsNullOrWhiteSpace($userIdentity)) {
                    Show-MessageBox -Message "Bitte geben Sie einen Benutzer an." -Title "Keine Auswahl" -Type Warning
                    return
                }
                
                Get-InboxRulesAction -UserIdentity $userIdentity
                
                $folders = Get-MailboxFoldersAction -UserIdentity $userIdentity
                if ($null -ne $script:cmbTargetFolder) {
                    $script:cmbTargetFolder.Items.Clear()
                    
                    $inboxItem = New-Object System.Windows.Controls.ComboBoxItem
                    $inboxItem.Content = "Inbox"
                    $inboxItem.Tag = "Inbox"
                    $script:cmbTargetFolder.Items.Add($inboxItem)
                    
                    foreach ($folder in $folders) {
                        $item = New-Object System.Windows.Controls.ComboBoxItem
                        $item.Content = $folder.DisplayName
                        $item.Tag = $folder.Identity
                        $script:cmbTargetFolder.Items.Add($item)
                    }
                    
                    $script:cmbTargetFolder.SelectedIndex = 0
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Laden der Inbox Rules: $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnLoadInboxRules"

        # Event-Handler für "Create Rule" Button
        Register-EventHandler -Control $btnCreateInboxRule -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                $userIdentity = $script:cmbInboxRuleUser.Text
                if ([string]::IsNullOrWhiteSpace($userIdentity)) {
                    Show-MessageBox -Message "Bitte geben Sie einen Benutzer an." -Title "Keine Auswahl" -Type Warning
                    return
                }

                if ([string]::IsNullOrWhiteSpace($script:txtInboxRuleName.Text)) {
                    Show-MessageBox -Message "Bitte geben Sie einen Namen für die Regel ein." -Title "Fehlende Angabe" -Type Warning
                    return
                }

                if ([string]::IsNullOrWhiteSpace($script:txtFromAddress.Text)) {
                    Show-MessageBox -Message "Bitte geben Sie eine Absenderadresse ein." -Title "Fehlende Angabe" -Type Warning
                    return
                }

                $ruleName = $script:txtInboxRuleName.Text.Trim()
                $fromAddress = $script:txtFromAddress.Text.Trim()
                $targetFolder = if ($null -ne $script:cmbTargetFolder.SelectedItem) { $script:cmbTargetFolder.SelectedItem.Content.ToString() } else { "Inbox" }
                $markAsRead = $script:chkMarkAsRead.IsChecked

                $result = New-InboxRuleAction -UserIdentity $userIdentity -RuleName $ruleName -FromAddress $fromAddress -TargetFolder $targetFolder -MarkAsRead $markAsRead

                if ($result) {
                    $script:txtStatus.Text = "Inbox Rule '$ruleName' erfolgreich erstellt."
                    $script:txtInboxRuleName.Text = ""
                    $script:txtFromAddress.Text = ""
                    $script:chkMarkAsRead.IsChecked = $false
                    Get-InboxRulesAction -UserIdentity $userIdentity
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Erstellen der Inbox Rule: $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnCreateInboxRule"

        # Event-Handler für "Refresh" Button
        Register-EventHandler -Control $btnRefreshInboxRules -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                $userIdentity = $script:cmbInboxRuleUser.Text
                if ([string]::IsNullOrWhiteSpace($userIdentity)) {
                    Show-MessageBox -Message "Bitte geben Sie einen Benutzer an." -Title "Keine Auswahl" -Type Warning
                    return
                }

                Get-InboxRulesAction -UserIdentity $userIdentity
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Aktualisieren der Inbox Rules: $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnRefreshInboxRules"

        # Event-Handler für "Enable" Button
        Register-EventHandler -Control $btnEnableInboxRule -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                $selectedRule = $script:dgInboxRules.SelectedItem
                if ($null -eq $selectedRule) {
                    Show-MessageBox -Message "Bitte wählen Sie eine Regel aus der Liste aus." -Title "Keine Auswahl" -Type Warning
                    return
                }

                $userIdentity = $script:cmbInboxRuleUser.Text
                if ([string]::IsNullOrWhiteSpace($userIdentity)) {
                    Show-MessageBox -Message "Kein Benutzer angegeben, für den die Regel aktiviert werden soll." -Title "Fehler" -Type Error
                    return
                }

                $result = Set-InboxRuleStateAction -UserIdentity $userIdentity -RuleIdentity $selectedRule.Identity -Enabled $true

                if ($result) {
                    $script:txtStatus.Text = "Inbox Rule '$($selectedRule.Name)' wurde aktiviert."
                    Get-InboxRulesAction -UserIdentity $userIdentity
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Aktivieren der Inbox Rule: $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnEnableInboxRule"

        # Event-Handler für "Disable" Button
        Register-EventHandler -Control $btnDisableInboxRule -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                $selectedRule = $script:dgInboxRules.SelectedItem
                if ($null -eq $selectedRule) {
                    Show-MessageBox -Message "Bitte wählen Sie eine Regel aus der Liste aus." -Title "Keine Auswahl" -Type Warning
                    return
                }

                $userIdentity = $script:cmbInboxRuleUser.Text
                if ([string]::IsNullOrWhiteSpace($userIdentity)) {
                    Show-MessageBox -Message "Kein Benutzer angegeben, für den die Regel deaktiviert werden soll." -Title "Fehler" -Type Error
                    return
                }

                $result = Set-InboxRuleStateAction -UserIdentity $userIdentity -RuleIdentity $selectedRule.Identity -Enabled $false

                if ($result) {
                    $script:txtStatus.Text = "Inbox Rule '$($selectedRule.Name)' wurde deaktiviert."
                    Get-InboxRulesAction -UserIdentity $userIdentity
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Deaktivieren der Inbox Rule: $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnDisableInboxRule"

        # Event-Handler für "Delete" Button
        Register-EventHandler -Control $btnDeleteInboxRule -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                $selectedRule = $script:dgInboxRules.SelectedItem
                if ($null -eq $selectedRule) {
                    Show-MessageBox -Message "Bitte wählen Sie eine Regel aus der Liste aus." -Title "Keine Auswahl" -Type Warning
                    return
                }

                $confirmResult = Show-MessageBox -Message "Sind Sie sicher, dass Sie die Inbox Rule '$($selectedRule.Name)' löschen möchten?" -Title "Löschen bestätigen" -Type Question

                if ($confirmResult -eq "Yes") {
                    $userIdentity = $script:cmbInboxRuleUser.Text
                    if ([string]::IsNullOrWhiteSpace($userIdentity)) {
                        Show-MessageBox -Message "Kein Benutzer angegeben, für den die Regel gelöscht werden soll." -Title "Fehler" -Type Error
                        return
                    }

                    $result = Remove-InboxRuleAction -UserIdentity $userIdentity -RuleIdentity $selectedRule.Identity

                    if ($result) {
                        $script:txtStatus.Text = "Inbox Rule '$($selectedRule.Name)' wurde gelöscht."
                        Get-InboxRulesAction -UserIdentity $userIdentity
                    }
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Löschen der Inbox Rule - $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnDeleteInboxRule"

        # Event-Handler für "Move Up" Button
        Register-EventHandler -Control $btnMoveRuleUp -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                $selectedRule = $script:dgInboxRules.SelectedItem
                if ($null -eq $selectedRule) {
                    Show-MessageBox -Message "Bitte wählen Sie eine Regel aus der Liste aus." -Title "Keine Auswahl" -Type Warning
                    return
                }

                $userIdentity = $script:cmbInboxRuleUser.Text
                if ([string]::IsNullOrWhiteSpace($userIdentity)) {
                    Show-MessageBox -Message "Kein Benutzer angegeben, für den die Regel verschoben werden soll." -Title "Fehler" -Type Error
                    return
                }

                $result = Move-InboxRuleAction -UserIdentity $userIdentity -RuleIdentity $selectedRule.Identity -Direction "Up"

                if ($result) {
                    $script:txtStatus.Text = "Inbox Rule '$($selectedRule.Name)' wurde nach oben verschoben."
                    Get-InboxRulesAction -UserIdentity $userIdentity
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Verschieben der Inbox Rule: $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnMoveRuleUp"

        # Event-Handler für "Move Down" Button
        Register-EventHandler -Control $btnMoveRuleDown -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                $selectedRule = $script:dgInboxRules.SelectedItem
                if ($null -eq $selectedRule) {
                    Show-MessageBox -Message "Bitte wählen Sie eine Regel aus der Liste aus." -Title "Keine Auswahl" -Type Warning
                    return
                }

                $userIdentity = $script:cmbInboxRuleUser.Text
                if ([string]::IsNullOrWhiteSpace($userIdentity)) {
                    Show-MessageBox -Message "Kein Benutzer angegeben, für den die Regel verschoben werden soll." -Title "Fehler" -Type Error
                    return
                }

                $result = Move-InboxRuleAction -UserIdentity $userIdentity -RuleIdentity $selectedRule.Identity -Direction "Down"

                if ($result) {
                    $script:txtStatus.Text = "Inbox Rule '$($selectedRule.Name)' wurde nach unten verschoben."
                    Get-InboxRulesAction -UserIdentity $userIdentity
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Verschieben der Inbox Rule: $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnMoveRuleDown"

         Register-EventHandler -Control $btnExportInboxRules -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                $userIdentity = $script:cmbInboxRuleUser.Text
                if ([string]::IsNullOrWhiteSpace($userIdentity)) {
                    Show-MessageBox -Message "Bitte geben Sie einen Benutzer an." -Title "Keine Auswahl" -Type Warning
                    return
                }

                # Datei-Dialog für Export
                $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
                $saveDialog.Filter = "CSV-Dateien (*.csv)|*.csv|XML-Dateien (*.xml)|*.xml|Alle Dateien (*.*)|*.*"
                $saveDialog.Title = "Inbox Rules exportieren"
                $saveDialog.FileName = "InboxRules_$($userIdentity.Replace('@', '_'))_$(Get-Date -Format 'yyyyMMdd')"

                if ($saveDialog.ShowDialog() -eq $true) {
                    $result = Export-InboxRulesAction -UserIdentity $userIdentity -FilePath $saveDialog.FileName

                    if ($result) {
                        $script:txtStatus.Text = "Inbox Rules erfolgreich exportiert nach - $($saveDialog.FileName)"
                        Show-MessageBox -Message "Inbox Rules wurden erfolgreich exportiert." -Title "Export erfolgreich" -Type Info
                    }
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Exportieren der Inbox Rules - $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnExportInboxRules"

        Write-Log "Inbox Rules-Tab erfolgreich initialisiert" -Type "Success"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Initialisieren des Inbox Rules-Tabs - $errorMsg" -Type "Error"
        return $false
    }
}
