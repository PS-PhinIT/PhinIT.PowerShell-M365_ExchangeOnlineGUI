# =====================================================================
# easyEXO - Modul: Gruppen / Verteilerlisten / Microsoft 365-Gruppen
# Datei: src/Modules/Features/Groups.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# Funktion zum Abrufen aller relevanten Exchange-Gruppentypen
function Get-AllGroupTypesAction {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Rufe alle relevanten Gruppen ab (Verteiler, E-Mail-aktivierte Sicherheitsgruppen, Microsoft 365-Gruppen)" -Type "Info"
        Update-StatusBar -Message "Rufe alle Gruppentypen ab..." -Type Info
        $allGroupsData = New-Object 'System.Collections.Generic.List[object]'

        # Verteilergruppen und E-Mail-aktivierte Sicherheitsgruppen
        # Get-DistributionGroup liefert sowohl Verteilergruppen als auch E-Mail-aktivierte Sicherheitsgruppen.
        # Ohne -ResultSize Unlimited liefert das Cmdlet höchstens 1000 Objekte.
        $distributionAndSecurityGroups = @(Get-DistributionGroup -ResultSize Unlimited -ErrorAction SilentlyContinue | Step-UIProgress -Activity "Lade Verteilergruppen")
        if ($distributionAndSecurityGroups.Count -gt 0) {
            $allGroupsData.AddRange([object[]]@($distributionAndSecurityGroups | ForEach-Object {
                [PSCustomObject]@{
                    DisplayName        = $_.DisplayName
                    PrimarySmtpAddress = $_.PrimarySmtpAddress
                    DistinguishedName  = $_.DistinguishedName # Eindeutige ID für Get-Unique
                    GroupType          = $_.GroupType # z.B. Distribution, Security
                    RecipientTypeDetails = $_.RecipientTypeDetails # z.B. MailUniversalDistributionGroup, MailUniversalSecurityGroup
                    # Speichere das ursprüngliche Objekt für vollen Zugriff, falls später benötigt
                    OriginalObject     = $_
                }
            }))
        } else {
            Write-Log "Keine Verteilergruppen oder E-Mail-aktivierte Sicherheitsgruppen gefunden oder Fehler beim Abruf." -Type Info # Kann auch Warning sein, je nach Erwartung
        }

        # Microsoft 365-Gruppen (Get-ExoUnifiedGroup ruft ohne Identity alle Gruppen mit -ResultSize Unlimited ab)
        $unifiedGroups = @(Get-ExoUnifiedGroup -ErrorAction SilentlyContinue)
        if ($unifiedGroups.Count -gt 0) {
            $allGroupsData.AddRange([object[]]@($unifiedGroups | ForEach-Object {
                [PSCustomObject]@{
                    DisplayName        = $_.DisplayName
                    PrimarySmtpAddress = $_.PrimarySmtpAddress
                    DistinguishedName  = $_.ExternalDirectoryObjectId # Eindeutige ID für Get-Unique bei M365 Gruppen
                    GroupType          = "UnifiedGroup" # Explizit für M365-Gruppen setzen
                    RecipientTypeDetails = $_.RecipientTypeDetails # z.B. GroupMailbox
                    OriginalObject     = $_
                }
            }))
        } else {
            Write-Log "Keine Microsoft 365-Gruppen gefunden oder Fehler beim Abruf." -Type Info
        }
        
        if ($allGroupsData.Count -eq 0) {
            Write-Log "Keine Gruppen (weder Verteiler/Sicherheit noch M365) gefunden." -Type Warning
            Update-StatusBar -Message "Keine Gruppen gefunden." -Type Warning
            return @()
        }

        # Sortieren nach Anzeigenamen. Get-Unique mit -AsString auf DistinguishedName, um Duplikate zu vermeiden.
        # Es ist sicherer, zuerst auf Eindeutigkeit zu prüfen und dann zu sortieren.
        # DistinguishedName sollte für DG/SecGroup eindeutig sein, ExternalDirectoryObjectId für UnifiedGroup.
        # Da wir beide in derselben Eigenschaft 'DistinguishedName' im PSCustomObject speichern, sollte dies funktionieren.
        $uniqueGroupsByDistinguishedName = $allGroupsData | Sort-Object -Property DistinguishedName -Unique
        $sortedGroups = @($uniqueGroupsByDistinguishedName | Sort-Object DisplayName)
        
        $statusMsg = "Abruf von $($sortedGroups.Count) Gruppen abgeschlossen."
        Write-Log $statusMsg -Type Success
        Update-StatusBar -Message $statusMsg -Type Success
        return $sortedGroups
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Abrufen der Gruppen: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Fehler beim Abrufen der Gruppen." -Type Error
        # Die alte Statuszeilenaktualisierung wird durch Update-StatusBar ersetzt
        # if ($null -ne $script:txtStatus) {
        #     $script:txtStatus.Text = "Fehler beim Abrufen der Gruppen: $errorMsg"
        # }
        Show-MessageBox -Message "Fehler beim Abrufen der Gruppen: $errorMsg" -Title "Fehler Gruppenabruf" -Type Error
        return @() # Leeres Array bei Fehler zurückgeben
    }
}

# Funktion zum Aktualisieren der ComboBox cmbSelectExistingGroup
function Refresh-ExistingGroupsDropdown {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Aktualisiere Gruppenliste in ComboBox 'cmbSelectExistingGroup'" -Type "Info"
        Update-StatusBar -Message "Aktualisiere Gruppen-Dropdown..." -Type Info
        
        if ($null -eq $script:cmbSelectExistingGroup) {
            # Versuch, es abzurufen, falls nicht bereits im Skript-Scope, obwohl es dort sein sollte.
            $script:cmbSelectExistingGroup = Get-XamlElement -ElementName "cmbSelectExistingGroup"
            if ($null -eq $script:cmbSelectExistingGroup) {
                $errorMsg = "ComboBox 'cmbSelectExistingGroup' konnte nicht gefunden werden. Stellen Sie sicher, dass sie in Initialize-GroupsTab referenziert wird."
                Write-Log $errorMsg -Type "Error"
                Update-StatusBar -Message "Fehler: Dropdown nicht gefunden." -Type Error
                Show-MessageBox -Message $errorMsg -Title "UI Fehler" -Type Error
                return
            }
        }

        $script:cmbSelectExistingGroup.ItemsSource = $null # Vorherige Bindung / Elemente löschen
        $script:cmbSelectExistingGroup.Items.Clear()   # Sicherstellen, dass sie wirklich leer ist
        
        Start-UIBusy -Message "Lade Gruppen..." -Title "Gruppenliste aktualisieren"
        try {
            $groups = @(Get-AllGroupTypesAction) # Diese Funktion hat bereits Logging und Status-Updates
        }
        finally {
            Stop-UIBusy
        }

        if ($groups.Count -gt 0) {
            foreach ($group in $groups) {
                $item = New-Object System.Windows.Controls.ComboBoxItem
                $item.Content = $group.DisplayName
                # Speichere das benutzerdefinierte Objekt (das OriginalObject enthält) in der Tag-Eigenschaft
                $item.Tag = $group 
                $item.ToolTip = "E-Mail: $($group.PrimarySmtpAddress)`nTyp: $($group.RecipientTypeDetails)"
                [void]$script:cmbSelectExistingGroup.Items.Add($item)
            }

            if ($script:cmbSelectExistingGroup.Items.Count -gt 0) {
                 $script:cmbSelectExistingGroup.SelectedIndex = -1 # Keine Auswahl
            }
            
            $statusMsg = "Gruppenliste aktualisiert. $($groups.Count) Gruppen geladen."
            Write-Log $statusMsg -Type "Success"
            Update-StatusBar -Message $statusMsg -Type Success
        }
        else {
            $statusMsg = "Keine Gruppen zum Anzeigen gefunden oder Fehler beim Laden."
            Write-Log $statusMsg -Type "Warning"
            Update-StatusBar -Message $statusMsg -Type Warning
            $placeholderItem = New-Object System.Windows.Controls.ComboBoxItem
            $placeholderItem.Content = "-- Keine Gruppen gefunden --"
            $placeholderItem.IsEnabled = $false # Nicht auswählbar machen
            [void]$script:cmbSelectExistingGroup.Items.Add($placeholderItem)
            $script:cmbSelectExistingGroup.SelectedIndex = 0
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        $logErrorMsg = "Fehler beim Aktualisieren der Gruppenliste in 'cmbSelectExistingGroup': $errorMsg"
        Write-Log $logErrorMsg -Type "Error"
        Update-StatusBar -Message "Fehler beim Aktualisieren der Gruppenliste." -Type Error
        Show-MessageBox -Message $logErrorMsg -Title "Fehler Dropdown-Aktualisierung" -Type Error
    }
}

#endregion EXOSettings Main Functions

function Get-ExoUnifiedGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Identity
    )

    $logIdentity = if ([string]::IsNullOrWhiteSpace($Identity)) { "*" } else { $Identity }
    Write-Log "Get-ExoUnifiedGroup: Aktion gestartet für Identity '$logIdentity'." -Type Info
    Update-StatusBar -Message "Rufe Microsoft 365-Gruppe(n) '$logIdentity' ab..." -Type Info

    try {
        if (-not $script:isConnected) {
            Show-MessageBox -Message "Sie sind nicht mit Exchange Online verbunden." -Title "Nicht verbunden" -Type Warning
            Update-StatusBar -Message "Nicht verbunden." -Type Warning
            return $null
        }

        $params = @{ ErrorAction = 'Stop' }
        if (-not [string]::IsNullOrWhiteSpace($Identity)) {
            $params['Identity'] = $Identity
        }
        else {
            # Ohne -ResultSize Unlimited liefert Get-UnifiedGroup höchstens 1000 Gruppen
            $params['ResultSize'] = 'Unlimited'
        }

        # Der eigentliche EXO-Cmdlet-Aufruf
        $groups = Get-UnifiedGroup @params
        
        if ($groups) {
            $count = if ($groups.Count) { $groups.Count } else { 1 }
            Write-Log "Get-ExoUnifiedGroup: $count Microsoft 365-Gruppe(n) für Identity '$logIdentity' erfolgreich abgerufen." -Type Success
            Update-StatusBar -Message "$count Microsoft 365-Gruppe(n) erfolgreich abgerufen." -Type Success
            return $groups
        } else {
            Write-Log "Get-ExoUnifiedGroup: Keine Microsoft 365-Gruppe(n) für Identity '$logIdentity' gefunden." -Type Warning
            Update-StatusBar -Message "Keine Microsoft 365-Gruppe(n) für '$logIdentity' gefunden." -Type Warning
            return @() # Leeres Array zurückgeben, wenn nichts gefunden wird
        }

    } catch {
        $errMsg = $_.Exception.Message
        Write-Log "Get-ExoUnifiedGroup: Fehler beim Abrufen der Microsoft 365-Gruppe(n) '$logIdentity': $errMsg" -Type Error
        Update-StatusBar -Message "Fehler beim Abrufen der Microsoft 365-Gruppe(n) '$logIdentity'." -Type Error
        return $null
    }
}

function Get-ExoGroupRecipientAction {
    <#
    .SYNOPSIS
    Ruft ein Gruppenobjekt basierend auf der Identity ab und ermittelt automatisch den Gruppentyp.
    
    .DESCRIPTION
    Diese Funktion versucht, eine Gruppe anhand ihrer Identity zu finden, indem sie verschiedene 
    Exchange Online Gruppentypen durchsucht (Unified Groups, Distribution Groups, Dynamic Distribution Groups).
    
    .PARAMETER Identity
    Die Identity der Gruppe (Name, Alias, E-Mail-Adresse oder Distinguished Name)
    
    .RETURNS
    Das gefundene Gruppenobjekt oder $null, wenn keine Gruppe gefunden wurde
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity
    )
    
    try {
        Write-Log "Get-ExoGroupRecipientAction: Suche Gruppe mit Identity '$Identity'" -Type "Debug"
        
        if (-not $script:isConnected) {
            Write-Log "Get-ExoGroupRecipientAction: Nicht mit Exchange Online verbunden" -Type "Warning"
            return $null
        }
        
        # Zuerst versuchen wir Get-Recipient für eine schnelle Typ-Ermittlung
        $recipient = $null
        try {
            $recipient = Get-Recipient -Identity $Identity -ErrorAction Stop
            Write-Log "Get-ExoGroupRecipientAction: Recipient gefunden - Typ: $($recipient.RecipientTypeDetails)" -Type "Debug"
        }
        catch {
            Write-Log "Get-ExoGroupRecipientAction: Recipient mit Identity '$Identity' nicht gefunden" -Type "Debug"
            return $null
        }
        
        if ($null -eq $recipient) {
            return $null
        }
        
        # Basierend auf dem RecipientTypeDetails den spezifischen Gruppentyp abrufen
        switch ($recipient.RecipientTypeDetails) {
            "GroupMailbox" {
                # Microsoft 365 Gruppe (Unified Group)
                try {
                    $group = Get-UnifiedGroup -Identity $Identity -ErrorAction Stop
                    Write-Log "Get-ExoGroupRecipientAction: Microsoft 365 Gruppe gefunden: $($group.DisplayName)" -Type "Debug"
                    return $group
                }
                catch {
                    Write-Log "Get-ExoGroupRecipientAction: Fehler beim Abrufen der Microsoft 365 Gruppe: $($_.Exception.Message)" -Type "Error"
                    return $null
                }
            }
            
            { $_ -in @("MailUniversalDistributionGroup", "MailNonUniversalGroup", "MailUniversalSecurityGroup") } {
                # Verteilerliste oder E-Mail-aktivierte Sicherheitsgruppe
                try {
                    $group = Get-DistributionGroup -Identity $Identity -ErrorAction Stop
                    Write-Log "Get-ExoGroupRecipientAction: Verteilergruppe gefunden: $($group.DisplayName)" -Type "Debug"
                    return $group
                }
                catch {
                    Write-Log "Get-ExoGroupRecipientAction: Fehler beim Abrufen der Verteilergruppe: $($_.Exception.Message)" -Type "Error"
                    return $null
                }
            }
            
            "DynamicDistributionGroup" {
                # Dynamische Verteilergruppe
                try {
                    $group = Get-DynamicDistributionGroup -Identity $Identity -ErrorAction Stop
                    Write-Log "Get-ExoGroupRecipientAction: Dynamische Verteilergruppe gefunden: $($group.DisplayName)" -Type "Debug"
                    return $group
                }
                catch {
                    Write-Log "Get-ExoGroupRecipientAction: Fehler beim Abrufen der dynamischen Verteilergruppe: $($_.Exception.Message)" -Type "Error"
                    return $null
                }
            }
            
            default {
                Write-Log "Get-ExoGroupRecipientAction: Unbekannter oder nicht unterstützter RecipientTypeDetails: $($recipient.RecipientTypeDetails)" -Type "Warning"
                return $null
            }
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Get-ExoGroupRecipientAction: Allgemeiner Fehler beim Abrufen der Gruppe '$Identity': $errorMsg" -Type "Error"
        return $null
    }
}

function Update-ExoGroupSettingsAction {
    [CmdletBinding(SupportsShouldProcess = $true)] # Hinzugefügt SupportsShouldProcess
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity,

        [Parameter(Mandatory = $false)]
        [AllowNull()] 
        [bool]$HiddenFromAddressListsEnabled,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [bool]$RequireSenderAuthenticationEnabled,
        
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [bool]$AllowExternalSenders 
    )

    Write-Log "Update-ExoGroupSettingsAction: Aktion gestartet für Gruppe '$Identity'." -Type Info
    Update-StatusBar -Message "Aktualisiere Einstellungen für Gruppe '$Identity'..." -Type Info

    try {
        if (-not $script:isConnected) {
            Show-MessageBox -Message "Sie sind nicht mit Exchange Online verbunden." -Title "Nicht verbunden" -Type Warning
            Update-StatusBar -Message "Nicht verbunden." -Type Warning
            return $false
        }

        $groupObject = Get-ExoGroupRecipientAction -Identity $Identity
        if (-not $groupObject) {
            Update-StatusBar -Message "Gruppe '$Identity' nicht gefunden oder Typ konnte nicht ermittelt werden." -Type Error
            return $false
        }
        $groupDisplayName = $groupObject.DisplayName # Für $ShouldProcess Nachricht
        $recipientType = $groupObject.RecipientTypeDetails

        $params = @{}
        if ($PSBoundParameters.ContainsKey('HiddenFromAddressListsEnabled')) {
            $params.HiddenFromAddressListsEnabled = $HiddenFromAddressListsEnabled
        }
        
        # Logik für RequireSenderAuthenticationEnabled und AllowExternalSenders
        # AllowExternalSenders ist oft eine Umkehrung von RequireSenderAuthenticationEnabled
        # Wenn beide gesetzt sind, muss entschieden werden, welcher Vorrang hat oder wie sie kombiniert werden.
        # Annahme: Wenn AllowExternalSenders gesetzt ist, leitet es RequireSenderAuthenticationEnabled ab.
        # Wenn RequireSenderAuthenticationEnabled explizit gesetzt ist und AllowExternalSenders nicht, wird ersteres verwendet.

        if ($PSBoundParameters.ContainsKey('AllowExternalSenders')) {
            $params.RequireSenderAuthenticationEnabled = -not $AllowExternalSenders
            # Wenn auch RequireSenderAuthenticationEnabled gesetzt wurde, könnte dies überschrieben werden.
            # Um dies zu vermeiden, könnte man prüfen, ob RequireSenderAuthenticationEnabled auch gebunden ist und dann eine Logik anwenden.
            # Für Einfachheit: AllowExternalSenders überschreibt, wenn gesetzt.
            if ($PSBoundParameters.ContainsKey('RequireSenderAuthenticationEnabled') -and ($params.RequireSenderAuthenticationEnabled -ne $RequireSenderAuthenticationEnabled) ) {
                 Write-Log "Update-ExoGroupSettingsAction: Konflikt zwischen AllowExternalSenders und RequireSenderAuthenticationEnabled. AllowExternalSenders ($AllowExternalSenders) hat Vorrang." -Type Warning
            }
        } elseif ($PSBoundParameters.ContainsKey('RequireSenderAuthenticationEnabled')) {
            $params.RequireSenderAuthenticationEnabled = $RequireSenderAuthenticationEnabled
        }


        if ($params.Count -eq 0) {
            Write-Log "Update-ExoGroupSettingsAction: Keine Parameter zum Aktualisieren für '$Identity' angegeben." -Type Info
            Update-StatusBar -Message "Keine Änderungen für '$Identity' angegeben." -Type Info
            return $true 
        }
        
        $actionDescription = "Gruppe '$groupDisplayName' (Identity: $Identity) mit folgenden Einstellungen aktualisieren:"
        foreach($key in $params.Keys) {
            $actionDescription += "`n- $key = $($params[$key])"
        }

        if ($PSCmdlet.ShouldProcess($groupDisplayName, $actionDescription)) {
            switch ($recipientType) {
                "GroupMailbox" { 
                    Set-UnifiedGroup -Identity $Identity @params -ErrorAction Stop
                }
                "MailUniversalDistributionGroup" { 
                    Set-DistributionGroup -Identity $Identity @params -ErrorAction Stop
                }
                "MailUniversalSecurityGroup" { 
                    Set-DistributionGroup -Identity $Identity @params -ErrorAction Stop 
                }
                "DynamicDistributionGroup" {
                    Set-DynamicDistributionGroup -Identity $Identity @params -ErrorAction Stop
                }
                default {
                    $errMsg = "Update-ExoGroupSettingsAction: Nicht unterstützter Gruppentyp '$recipientType' für Gruppe '$Identity'."
                    Write-Log $errMsg -Type Error
                    Show-MessageBox -Message $errMsg -Title "Nicht unterstützter Typ" -Type Warning
                    Update-StatusBar -Message "Nicht unterstützter Gruppentyp: $recipientType" -Type Warning
                    return $false
                }
            }
            $successMsg = "Einstellungen für Gruppe '$groupDisplayName' erfolgreich aktualisiert."
            Write-Log $successMsg -Type Success
            Update-StatusBar -Message $successMsg -Type Success
            if (Test-Path Function:\Log-Action) { Log-Action "Einstellungen für Gruppe '$groupDisplayName' (Identity: $Identity) aktualisiert." }
            return $true
        } else {
            Write-Log "Update-ExoGroupSettingsAction: Aktualisierung für '$groupDisplayName' vom Benutzer abgebrochen." -Type Info
            Update-StatusBar -Message "Aktualisierung für '$groupDisplayName' abgebrochen." -Type Info
            return $false
        }

    } catch {
        $errMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Unbekannter Fehler beim Aktualisieren der Gruppeneinstellungen."
        $groupNameForError = if ($groupDisplayName) { $groupDisplayName } else { $Identity }
        Write-Log "Fehler in Update-ExoGroupSettingsAction für Gruppe '$groupNameForError': $errMsg" -Type Error
        if (Test-Path Function:\Log-Action) { Log-Action "Fehler Update-ExoGroupSettingsAction '$groupNameForError': $errMsg" }
        Show-MessageBox -Message "Fehler beim Aktualisieren der Einstellungen für Gruppe '$groupNameForError':`n$($_.Exception.Message)" -Title "Fehler bei Aktualisierung" -Type Error
        Update-StatusBar -Message "Fehler beim Aktualisieren der Einstellungen für '$groupNameForError'." -Type Error
        return $false
    }
}

function New-ExoGroupAction {
    [CmdletBinding(SupportsShouldProcess = $true)] # Hinzugefügt SupportsShouldProcess
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupName,

        [Parameter(Mandatory = $true)]
        [string]$GroupEmail, 

        [Parameter(Mandatory = $true)]
        [ValidateSet("Distribution", "Security", "Microsoft365")] 
        [string]$GroupType,

        [Parameter(Mandatory = $false)]
        [string[]]$Members,

        [Parameter(Mandatory = $false)]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [string]$Owner 
    )

    Write-Log "New-ExoGroupAction: Aktion gestartet für neue Gruppe '$GroupName' (Typ: $GroupType)." -Type Info
    Update-StatusBar -Message "Erstelle Gruppe '$GroupName'..." -Type Info

    try {
        if (-not $script:isConnected) {
            Show-MessageBox -Message "Sie sind nicht mit Exchange Online verbunden." -Title "Nicht verbunden" -Type Warning
            Update-StatusBar -Message "Nicht verbunden." -Type Warning
            return $null
        }
        
        $alias = if ($GroupEmail.Contains("@")) { $GroupEmail.Split('@')[0] } else { $GroupEmail }
        if ([string]::IsNullOrWhiteSpace($alias)) {
            Write-Log "New-ExoGroupAction: Ungültige E-Mail '$GroupEmail' zur Alias-Generierung." -Type Error
            Show-MessageBox -Message "Die angegebene E-Mail-Adresse '$GroupEmail' ist ungültig für die Alias-Generierung." -Title "Ungültige Eingabe" -Type Error
            Update-StatusBar -Message "Ungültige E-Mail für Alias." -Type Error
            return $null
        }


        $commonParams = @{
            DisplayName = $GroupName
            Alias = $alias
        }
        
        $newGroup = $null
        $actionDescription = "Neue Gruppe '$GroupName' (E-Mail: '$GroupEmail', Typ: '$GroupType') erstellen"

        if ($PSCmdlet.ShouldProcess($GroupName, $actionDescription)) {
            switch ($GroupType) {
                "Distribution" {
                    $params = @{
                        Name = $GroupName # Oder Alias, je nach Konvention
                        Type = "Distribution" 
                        PrimarySmtpAddress = $GroupEmail
                        ErrorAction = 'Stop'
                    } + $commonParams
                    if (-not [string]::IsNullOrWhiteSpace($Description)) { $params.Notes = $Description }
                    if ($PSBoundParameters.ContainsKey('Owner') -and -not [string]::IsNullOrWhiteSpace($Owner)) {
                        $params.ManagedBy = $Owner
                    }
                    $newGroup = New-DistributionGroup @params
                }
                "Security" {
                     $params = @{
                        Name = $GroupName # Oder Alias
                        Type = "Security" 
                        PrimarySmtpAddress = $GroupEmail
                        ErrorAction = 'Stop'
                    } + $commonParams
                    if (-not [string]::IsNullOrWhiteSpace($Description)) { $params.Notes = $Description }
                    if ($PSBoundParameters.ContainsKey('Owner') -and -not [string]::IsNullOrWhiteSpace($Owner)) {
                        $params.ManagedBy = $Owner
                    }
                    $newGroup = New-DistributionGroup @params 
                }
                "Microsoft365" {
                    $params = @{
                        AccessType = "Private"
                        PrimarySmtpAddress = $GroupEmail
                    } + $commonParams
                    # New-UnifiedGroup: Beschreibung über -Notes, Besitzer über -Owner (genau ein Empfänger)
                    if (-not [string]::IsNullOrWhiteSpace($Description)) { $params.Notes = $Description }

                    if ($PSBoundParameters.ContainsKey('Owner') -and -not [string]::IsNullOrWhiteSpace($Owner)) {
                        $params.Owner = $Owner
                    } else {
                        try {
                            # Angemeldeten Benutzer (UPN der Exchange-Online-Verbindung) als Owner verwenden.
                            # Hinweis: Die abgekündigten Module AzureAD/MSOnline werden nicht mehr verwendet.
                            if (-not [string]::IsNullOrWhiteSpace($script:userPrincipalName)) {
                                $currentUserPrincipalName = Get-User -Identity $script:userPrincipalName -ErrorAction Stop | Select-Object -ExpandProperty UserPrincipalName
                                if(-not [string]::IsNullOrWhiteSpace($currentUserPrincipalName)){
                                    $params.Owner = $currentUserPrincipalName
                                    Write-Log "New-ExoGroupAction: Aktueller Benutzer '$currentUserPrincipalName' wird als Owner für M365-Gruppe '$GroupName' gesetzt." -Type Info
                                } else {
                                    Write-Log "New-ExoGroupAction: Owner für M365-Gruppe '$GroupName' konnte nicht aus aktuellem Benutzer '$($script:userPrincipalName)' ermittelt werden." -Type Warning
                                }
                            } else {
                                Write-Log "New-ExoGroupAction: Kein Owner für M365-Gruppe '$GroupName' angegeben und aktueller Benutzer nicht in UI verfügbar." -Type Warning
                            }
                        } catch {
                             Write-Log "New-ExoGroupAction: Fehler beim Ermitteln des aktuellen Benutzers als Owner für M365-Gruppe '$GroupName': $($_.Exception.Message)" -Type Warning
                        }
                    }
                    # New-UnifiedGroup erlaubt unter bestimmten Berechtigungen keinen -ErrorAction Parameter.
                    # Daher wird der Aufruf gekapselt, um Fehler explizit abzufangen.
                    try {
                        $newGroup = New-UnifiedGroup @params -ErrorAction Stop
                    }
                    catch {
                        # Wirft den Fehler erneut, damit er vom äußeren Catch-Block behandelt wird.
                        throw $_
                    }
                }
                default { # Sollte durch ValidateSet nicht erreicht werden
                    $errMsg = "New-ExoGroupAction: Nicht unterstützter Gruppentyp '$GroupType'."
                    Write-Log $errMsg -Type Error
                    Show-MessageBox -Message $errMsg -Title "Nicht unterstützter Typ" -Type Warning
                    Update-StatusBar -Message "Nicht unterstützter Gruppentyp: $GroupType" -Type Warning
                    return $null
                }
            }

            if ($newGroup) {
                $successMsg = "Gruppe '$($newGroup.DisplayName)' (Typ: $GroupType) erfolgreich erstellt."
                Write-Log $successMsg -Type Success
                Update-StatusBar -Message $successMsg -Type Success
                if (Test-Path Function:\Log-Action) { Log-Action "Gruppe '$($newGroup.DisplayName)' (Identity: $($newGroup.Identity)) erstellt." }

                if ($Members -and $Members.Count -gt 0) {
                    Write-Log "Füge Mitglieder zur neuen Gruppe '$($newGroup.DisplayName)' hinzu..." -Type Info
                    foreach ($member in $Members) {
                        if (-not [string]::IsNullOrWhiteSpace($member)) {
                            # Korrekte Parameter für Add-ExoGroupMemberAction
                            Add-ExoGroupMemberAction -Identity $newGroup.Identity -MemberIdentity $member -ErrorAction SilentlyContinue 
                        }
                    }
                }
                return $newGroup 
            } else {
                $errMsg = "Gruppe '$GroupName' konnte nicht erstellt werden. Überprüfen Sie die Exchange Online-Protokolle oder vorherige Fehlermeldungen."
                Write-Log $errMsg -Type Error
                Update-StatusBar -Message $errMsg -Type Error
                return $null
            }
        } else {
            Write-Log "New-ExoGroupAction: Erstellung der Gruppe '$GroupName' vom Benutzer abgebrochen." -Type Info
            Update-StatusBar -Message "Erstellung der Gruppe '$GroupName' abgebrochen." -Type Info
            return $null
        }

    } catch {
        $errMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Unbekannter Fehler beim Erstellen der Gruppe."
        Write-Log "Fehler in New-ExoGroupAction für Gruppe '$GroupName': $errMsg" -Type Error
        if (Test-Path Function:\Log-Action) { Log-Action "Fehler New-ExoGroupAction '$GroupName': $errMsg" }
        Show-MessageBox -Message "Fehler beim Erstellen der Gruppe '$GroupName':`n$($_.Exception.Message)" -Title "Fehler bei Erstellung" -Type Error
        Update-StatusBar -Message "Fehler beim Erstellen der Gruppe '$GroupName'." -Type Error
        return $null
    }
}

function Remove-ExoGroupAction {
    [CmdletBinding(SupportsShouldProcess = $true)] # Hinzugefügt SupportsShouldProcess
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity
    )
    
    $groupDisplayName = $Identity # Fallback, falls Objekt nicht geladen werden kann

    Write-Log "Remove-ExoGroupAction: Aktion gestartet für Gruppe '$Identity'." -Type Info
    Update-StatusBar -Message "Lösche Gruppe '$Identity'..." -Type Info

    try {
        if (-not $script:isConnected) {
            Show-MessageBox -Message "Sie sind nicht mit Exchange Online verbunden." -Title "Nicht verbunden" -Type Warning
            Update-StatusBar -Message "Nicht verbunden." -Type Warning
            return $false
        }

        $groupObject = Get-ExoGroupRecipientAction -Identity $Identity
        if (-not $groupObject) {
            # Gruppe existiert möglicherweise nicht mehr, was beim Löschen kein Fehler sein muss.
            Write-Log "Remove-ExoGroupAction: Gruppe '$Identity' nicht gefunden. Möglicherweise bereits gelöscht." -Type Warning
            Update-StatusBar -Message "Gruppe '$Identity' nicht gefunden (evtl. bereits gelöscht)." -Type Warning
            return $true # Betrachte "nicht gefunden" als Erfolg für einen Löschvorgang
        }
        $recipientType = $groupObject.RecipientTypeDetails
        $groupDisplayName = $groupObject.DisplayName # Aktualisiere mit dem korrekten DisplayName

        # Zeichenfolgen für ShouldProcess vorbereiten, um Parser-Probleme zu umgehen
        $shouldProcessTarget = "Gruppe '{0}' (Identity: {1}, Typ: {2})" -f $groupDisplayName, $groupObject.Identity, $recipientType
        $shouldProcessAction = "Endgültig löschen"

        if ($PSCmdlet.ShouldProcess($shouldProcessTarget, $shouldProcessAction)) {
            switch ($recipientType) {
                "GroupMailbox" { 
                    Remove-UnifiedGroup -Identity $groupObject.Identity -Confirm:$false -ErrorAction Stop
                }
                "MailUniversalDistributionGroup" { 
                    Remove-DistributionGroup -Identity $groupObject.Identity -Confirm:$false -ErrorAction Stop
                }
                "MailUniversalSecurityGroup" { 
                    Remove-DistributionGroup -Identity $groupObject.Identity -Confirm:$false -ErrorAction Stop
                }
                "DynamicDistributionGroup" {
                    Remove-DynamicDistributionGroup -Identity $groupObject.Identity -Confirm:$false -ErrorAction Stop
                }
                default {
                    $errMsg = "Remove-ExoGroupAction: Nicht unterstützter Gruppentyp '$recipientType' für Gruppe '$groupDisplayName' zum Löschen."
                    Write-Log $errMsg -Type Error
                    Show-MessageBox -Message $errMsg -Title "Nicht unterstützter Typ" -Type Warning
                    Update-StatusBar -Message "Nicht unterstützter Gruppentyp: $recipientType" -Type Warning
                    return $false
                }
            }
            $successMsg = "Gruppe '$groupDisplayName' erfolgreich gelöscht."
            Write-Log $successMsg -Type Success
            Update-StatusBar -Message $successMsg -Type Success
            if (Test-Path Function:\Log-Action) { Log-Action "Gruppe '$groupDisplayName' (Identity: $($groupObject.Identity)) gelöscht." }
            return $true
        } else {
            Write-Log "Remove-ExoGroupAction: Löschen der Gruppe '$groupDisplayName' vom Benutzer abgebrochen." -Type Info
            Update-StatusBar -Message "Löschen der Gruppe '$groupDisplayName' abgebrochen." -Type Info
            return $false
        }

    } catch {
        $errMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Unbekannter Fehler beim Löschen der Gruppe."
        Write-Log "Fehler in Remove-ExoGroupAction für Gruppe '$groupDisplayName': $errMsg" -Type Error
        if (Test-Path Function:\Log-Action) { Log-Action "Fehler Remove-ExoGroupAction '$groupDisplayName': $errMsg" }
        Show-MessageBox -Message "Fehler beim Löschen der Gruppe '$groupDisplayName':`n$($_.Exception.Message)" -Title "Fehler bei Löschung" -Type Error
        Update-StatusBar -Message "Fehler beim Löschen der Gruppe '$groupDisplayName'." -Type Error
        return $false
    }
}

function Add-ExoGroupMemberAction {
    [CmdletBinding(SupportsShouldProcess = $true)] # Hinzugefügt SupportsShouldProcess
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity, # Gruppen-Identität

        [Parameter(Mandatory = $true)]
        [string]$MemberIdentity # Benutzer/Mitglied-Identität
    )

    Write-Log "Add-ExoGroupMemberAction: Füge Mitglied '$MemberIdentity' zu Gruppe '$Identity' hinzu." -Type Info
    Update-StatusBar -Message "Füge '$MemberIdentity' zu '$Identity' hinzu..." -Type Info
    
    $groupDisplayName = $Identity # Fallback

    try {
        if (-not $script:isConnected) {
            Show-MessageBox -Message "Sie sind nicht mit Exchange Online verbunden." -Title "Nicht verbunden" -Type Warning
            Update-StatusBar -Message "Nicht verbunden." -Type Warning
            return $false
        }

        $group = Get-ExoGroupRecipientAction -Identity $Identity
        if (-not $group) {
            Update-StatusBar -Message "Gruppe '$Identity' nicht gefunden." -Type Error
            return $false
        }
        # Optional: $member = Get-Recipient -Identity $MemberIdentity -ErrorAction SilentlyContinue ...
        
        $recipientType = $group.RecipientTypeDetails
        $groupDisplayName = $group.DisplayName

        # Zeichenfolgen für ShouldProcess vorbereiten
        $shouldProcessTarget = "Mitglied '$MemberIdentity' zu Gruppe '$groupDisplayName' (Typ: $recipientType)"
        $shouldProcessAction = "Hinzufügen"

        if ($PSCmdlet.ShouldProcess($shouldProcessTarget, $shouldProcessAction)) {
            switch ($recipientType) {
                "GroupMailbox" { 
                    Add-UnifiedGroupLinks -Identity $Identity -LinkType Members -Links $MemberIdentity -Confirm:$false -ErrorAction Stop
                }
                "MailUniversalDistributionGroup" { 
                    Add-DistributionGroupMember -Identity $Identity -Member $MemberIdentity -Confirm:$false -ErrorAction Stop
                }
                "MailUniversalSecurityGroup" { 
                    Add-DistributionGroupMember -Identity $Identity -Member $MemberIdentity -Confirm:$false -ErrorAction Stop
                }
                "DynamicDistributionGroup" {
                     $errMsg = "Add-ExoGroupMemberAction: Mitglieder können nicht manuell zu dynamischen Verteilergruppen hinzugefügt werden (Gruppe '$groupDisplayName')."
                    Write-Log $errMsg -Type Warning
                    Show-MessageBox -Message $errMsg -Title "Aktion nicht unterstützt" -Type Warning
                    Update-StatusBar -Message "Mitglieder können nicht zu dynamischen Gruppen hinzugefügt werden." -Type Warning
                    return $false
                }
                default {
                    $errMsg = "Add-ExoGroupMemberAction: Mitglieder können nicht manuell zu Gruppentyp '$recipientType' (Gruppe '$groupDisplayName') hinzugefügt werden."
                    Write-Log $errMsg -Type Error
                    Show-MessageBox -Message $errMsg -Title "Nicht unterstützter Typ" -Type Warning
                    Update-StatusBar -Message "Mitglieder können nicht zu '$recipientType' hinzugefügt werden." -Type Warning
                    return $false
                }
            }
            $successMsg = "Mitglied '$MemberIdentity' erfolgreich zu Gruppe '$groupDisplayName' hinzugefügt."
            Write-Log $successMsg -Type Success
            Update-StatusBar -Message $successMsg -Type Success
            if (Test-Path Function:\Log-Action) { Log-Action "Mitglied '$MemberIdentity' zu Gruppe '$groupDisplayName' (Identity: $Identity) hinzugefügt." }
            return $true
        } else {
            Write-Log "Add-ExoGroupMemberAction: Hinzufügen von '$MemberIdentity' zu '$groupDisplayName' vom Benutzer abgebrochen." -Type Info
            Update-StatusBar -Message "Hinzufügen zu '$groupDisplayName' abgebrochen." -Type Info
            return $false
        }

    } catch {
        $errMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Unbekannter Fehler beim Hinzufügen des Gruppenmitglieds."
        Write-Log "Fehler in Add-ExoGroupMemberAction für Gruppe '$groupDisplayName', Mitglied '$MemberIdentity': $errMsg" -Type Error
        if (Test-Path Function:\Log-Action) { Log-Action "Fehler Add-ExoGroupMemberAction '$groupDisplayName'/'$MemberIdentity': $errMsg" }
        Show-MessageBox -Message "Fehler beim Hinzufügen von '$MemberIdentity' zu Gruppe '$groupDisplayName':`n$($_.Exception.Message)" -Title "Fehler bei Mitgliedschaft" -Type Error
        Update-StatusBar -Message "Fehler beim Hinzufügen zu '$groupDisplayName'." -Type Error
        return $false
    }
}

function Remove-ExoGroupMemberAction {
    [CmdletBinding(SupportsShouldProcess = $true)] # Hinzugefügt SupportsShouldProcess
    param(
        # Beibehaltung der ursprünglichen Parameternamen dieser Funktion
        [Parameter(Mandatory = $true)]
        [string]$GroupIdentity, 

        [Parameter(Mandatory = $true)]
        [string]$UserIdentity # Mitglied-Identität
    )

    Write-Log "Remove-ExoGroupMemberAction: Entferne Mitglied '$UserIdentity' aus Gruppe '$GroupIdentity'." -Type Info
    Update-StatusBar -Message "Entferne '$UserIdentity' aus '$GroupIdentity'..." -Type Info
    
    $groupDisplayName = $GroupIdentity # Fallback

    try {
        if (-not $script:isConnected) {
            Show-MessageBox -Message "Sie sind nicht mit Exchange Online verbunden." -Title "Nicht verbunden" -Type Warning
            Update-StatusBar -Message "Nicht verbunden." -Type Warning
            return $false
        }

        $group = Get-ExoGroupRecipientAction -Identity $GroupIdentity
        if (-not $group) {
            Update-StatusBar -Message "Gruppe '$GroupIdentity' nicht gefunden." -Type Error
            return $false
        }
        
        $recipientType = $group.RecipientTypeDetails
        $groupDisplayName = $group.DisplayName

        # Korrektur: $PSCmdlet.ShouldProcess verwenden und Ziel/Aktion trennen
        $shouldProcessTarget = "Mitglied '$UserIdentity' aus Gruppe '$groupDisplayName' (Typ: $recipientType)"
        $shouldProcessAction = "Entfernen"

        if ($PSCmdlet.ShouldProcess($shouldProcessTarget, $shouldProcessAction)) {
            switch ($recipientType) {
                "GroupMailbox" { 
                    Remove-UnifiedGroupLinks -Identity $GroupIdentity -LinkType Members -Links $UserIdentity -Confirm:$false -ErrorAction Stop
                }
                "MailUniversalDistributionGroup" { 
                    Remove-DistributionGroupMember -Identity $GroupIdentity -Member $UserIdentity -Confirm:$false -ErrorAction Stop
                }
                "MailUniversalSecurityGroup" { 
                    Remove-DistributionGroupMember -Identity $GroupIdentity -Member $UserIdentity -Confirm:$false -ErrorAction Stop
                }
                 "DynamicDistributionGroup" {
                     $errMsg = "Remove-ExoGroupMemberAction: Mitglieder können nicht manuell aus dynamischen Verteilergruppen entfernt werden (Gruppe '$groupDisplayName')."
                    Write-Log $errMsg -Type Warning
                    Show-MessageBox -Message $errMsg -Title "Aktion nicht unterstützt" -Type Warning
                    Update-StatusBar -Message "Mitglieder können nicht aus dynamischen Gruppen entfernt werden." -Type Warning
                    return $false
                }
                default {
                    $errMsg = "Remove-ExoGroupMemberAction: Mitglieder können nicht manuell aus Gruppentyp '$recipientType' (Gruppe '$groupDisplayName') entfernt werden."
                    Write-Log $errMsg -Type Error
                    Show-MessageBox -Message $errMsg -Title "Nicht unterstützter Typ" -Type Warning
                    Update-StatusBar -Message "Mitglieder können nicht aus '$recipientType' entfernt werden." -Type Warning
                    return $false
                }
            }
            $successMsg = "Mitglied '$UserIdentity' erfolgreich aus Gruppe '$groupDisplayName' entfernt."
            Write-Log $successMsg -Type Success
            Update-StatusBar -Message $successMsg -Type Success
            if (Test-Path Function:\Log-Action) { Log-Action "Mitglied '$UserIdentity' aus Gruppe '$groupDisplayName' (Identity: $GroupIdentity) entfernt." }
            return $true
        } else {
            Write-Log "Remove-ExoGroupMemberAction: Entfernen von '$UserIdentity' aus '$groupDisplayName' vom Benutzer abgebrochen." -Type Info
            Update-StatusBar -Message "Entfernen aus '$groupDisplayName' abgebrochen." -Type Info
            return $false
        }

    } catch {
        $errMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Unbekannter Fehler beim Entfernen des Gruppenmitglieds."
        Write-Log "Fehler in Remove-ExoGroupMemberAction für Gruppe '$groupDisplayName', Mitglied '$UserIdentity': $errMsg" -Type Error
        if (Test-Path Function:\Log-Action) { Log-Action "Fehler Remove-ExoGroupMemberAction '$groupDisplayName'/'$UserIdentity': $errMsg" }
        Show-MessageBox -Message "Fehler beim Entfernen von '$UserIdentity' aus Gruppe '$groupDisplayName':`n$($_.Exception.Message)" -Title "Fehler bei Mitgliedschaft" -Type Error
        Update-StatusBar -Message "Fehler beim Entfernen aus '$groupDisplayName'." -Type Error
        throw # Re-throw the exception so the calling code knows it failed
    }
}

function Get-ExoGroupMembersAction {
    [CmdletBinding()]
    param()

    $selectedItem = $null
    if ($null -ne $script:cmbSelectExistingGroup) {
        $selectedItem = $script:cmbSelectExistingGroup.SelectedItem
    }

    if ($null -ne $selectedItem) {
        $tagType = if ($selectedItem.Tag) { $selectedItem.Tag.GetType().Name } else { 'null' }
        Write-Log "Get-ExoGroupMembersAction: SelectedItem gefunden. Content: '$($selectedItem.Content)', Tag Type: $tagType" -Type Debug
        if ($null -ne $selectedItem.Tag) {
            Write-Log "Get-ExoGroupMembersAction: Tag Properties: $($selectedItem.Tag.PSObject.Properties.Name -join ', ')" -Type Debug
            if ($selectedItem.Tag.PSObject.Properties["Identity"]) {
                Write-Log "Get-ExoGroupMembersAction: Identity in Tag: '$($selectedItem.Tag.Identity)'" -Type Debug
            }
            if ($selectedItem.Tag.PSObject.Properties["OriginalObject"]) {
                Write-Log "Get-ExoGroupMembersAction: OriginalObject vorhanden, Type: $($selectedItem.Tag.OriginalObject.GetType().Name)" -Type Debug
                if ($selectedItem.Tag.OriginalObject.PSObject.Properties["Identity"]) {
                    Write-Log "Get-ExoGroupMembersAction: OriginalObject.Identity: '$($selectedItem.Tag.OriginalObject.Identity)'" -Type Debug
                }
            }
        }
    } else {
        Write-Log "Get-ExoGroupMembersAction: Kein SelectedItem gefunden." -Type Warning
        Update-StatusBar -Message "Keine Gruppe ausgewählt." -Type Warning
        return
    }

    $groupObject = $null
    $isValidSelection = $false

    if ($null -ne $selectedItem -and $null -ne $selectedItem.Tag) {
        $taggedObject = $selectedItem.Tag
        
        if ($taggedObject.PSObject.Properties["Identity"] -and 
            $taggedObject.PSObject.Properties["DisplayName"] -and 
            $taggedObject.PSObject.Properties["RecipientTypeDetails"]) {
            
            $groupObject = $taggedObject
            $isValidSelection = $true
            Write-Log "Get-ExoGroupMembersAction: Gültiges Gruppenobjekt im Tag gefunden." -Type Debug
        }
        elseif ($taggedObject.PSObject.Properties["OriginalObject"]) {
            $originalObject = $taggedObject.OriginalObject
            if ($originalObject.PSObject.Properties["Identity"] -and 
                $originalObject.PSObject.Properties["DisplayName"] -and 
                $originalObject.PSObject.Properties["RecipientTypeDetails"]) {
                
                $groupObject = $originalObject
                $isValidSelection = $true
                Write-Log "Get-ExoGroupMembersAction: Gültiges Gruppenobjekt im OriginalObject gefunden." -Type Debug
            }
        }
    }

    if (-not $isValidSelection -or $null -eq $groupObject) {
        Write-Log "Get-ExoGroupMembersAction: Ungültiges Gruppenobjekt oder fehlende Identity im Tag des ausgewählten Elements. Aktion wird abgebrochen." -Type Warning
        Update-StatusBar -Message "Ungültige Gruppenauswahl." -Type Warning
        return
    }

    $groupDisplayName = $groupObject.DisplayName
    $recipientType = $groupObject.RecipientTypeDetails
    $effectiveIdentityForExo = $null
    if ($groupObject.PSObject.Properties["DistinguishedName"] -and ![string]::IsNullOrEmpty($groupObject.DistinguishedName)) {
        $effectiveIdentityForExo = $groupObject.DistinguishedName
    } elseif ($groupObject.PSObject.Properties["Identity"] -and ![string]::IsNullOrEmpty($groupObject.Identity)) {
        $effectiveIdentityForExo = $groupObject.Identity
    } elseif ($groupObject.PSObject.Properties["PrimarySmtpAddress"] -and ![string]::IsNullOrEmpty($groupObject.PrimarySmtpAddress)) {
        $effectiveIdentityForExo = $groupObject.PrimarySmtpAddress
    } else {
        Write-Log "Get-ExoGroupMembersAction: Keine gültige Identity für EXO-Cmdlets gefunden." -Type Error
        Update-StatusBar -Message "Keine gültige Gruppen-Identity gefunden." -Type Error
        return
    }
    
    $members = @()
    $owners = @()
    $membersSuccessfullyRetrieved = $false

    Write-Log "Get-ExoGroupMembersAction: Verarbeite Gruppe '$groupDisplayName' (Identity: '$effectiveIdentityForExo', Typ: '$recipientType')" -Type Info
    Update-StatusBar -Message "Lade Mitglieder für '$groupDisplayName'..." -Type Info
    Start-UIBusy -Message "Lade Mitglieder und Einstellungen für '$groupDisplayName'..." -Title "Gruppenmitglieder"

    try {
        if (-not $script:isConnected) {
            Write-Log "Get-ExoGroupMembersAction: Keine Verbindung zu Exchange Online." -Type Warning
            Update-StatusBar -Message "Keine Verbindung zu Exchange Online." -Type Warning
            return
        }

        try {
            if ($recipientType -eq "GroupMailbox") {
                try {
                    $members = Get-UnifiedGroupLinks -Identity $effectiveIdentityForExo -LinkType Members -ResultSize Unlimited -ErrorAction Stop
                    $owners = Get-UnifiedGroupLinks -Identity $effectiveIdentityForExo -LinkType Owners -ResultSize Unlimited -ErrorAction Stop
                    Write-Log "Get-ExoGroupMembersAction: Verwende Get-UnifiedGroupLinks für Microsoft 365 Gruppe." -Type Debug
                } catch {
                    if ($groupObject.PSObject.Properties["PrimarySmtpAddress"] -and $effectiveIdentityForExo -ne $groupObject.PrimarySmtpAddress) {
                        Write-Log "Get-ExoGroupMembersAction: Fallback zu PrimarySmtpAddress für UnifiedGroupLinks." -Type Debug
                        $members = Get-UnifiedGroupLinks -Identity $groupObject.PrimarySmtpAddress -LinkType Members -ResultSize Unlimited -ErrorAction Stop
                        $owners = Get-UnifiedGroupLinks -Identity $groupObject.PrimarySmtpAddress -LinkType Owners -ResultSize Unlimited -ErrorAction Stop
                    } else {
                        throw $_
                    }
                }
            } elseif ($recipientType -in ("MailUniversalDistributionGroup", "MailUniversalSecurityGroup", "MailNonUniversalGroup")) {
                try {
                    $members = Get-DistributionGroupMember -Identity $effectiveIdentityForExo -ResultSize Unlimited -ErrorAction Stop
                    Write-Log "Get-ExoGroupMembersAction: Verwende Get-DistributionGroupMember für Verteilergruppe." -Type Debug
                } catch {
                    if ($groupObject.PSObject.Properties["PrimarySmtpAddress"] -and $effectiveIdentityForExo -ne $groupObject.PrimarySmtpAddress) {
                        Write-Log "Get-ExoGroupMembersAction: Fallback zu PrimarySmtpAddress für DistributionGroupMember." -Type Debug
                        $members = Get-DistributionGroupMember -Identity $groupObject.PrimarySmtpAddress -ResultSize Unlimited -ErrorAction Stop
                    } else {
                        throw $_
                    }
                }
            } elseif ($recipientType -eq "DynamicDistributionGroup") {
                $members = @()
                Write-Log "Get-ExoGroupMembersAction: Dynamische Verteilergruppe - keine festen Mitglieder." -Type Info
            } else {
                Write-Log "Get-ExoGroupMembersAction: Unbekannter oder nicht unterstützter Gruppentyp '$recipientType' für Mitgliederabruf." -Type Warning
                Show-MessageBox -Message "Der Gruppentyp '$recipientType' wird für den Mitgliederabruf aktuell nicht vollständig unterstützt." -Title "Hinweis" -Type Info
            }
            
            if ($null -ne $members) { 
                $membersSuccessfullyRetrieved = $true
                Write-Log "Get-ExoGroupMembersAction: $($members.Count) Mitglieder-Objekte für '$groupDisplayName' abgerufen." -Type Debug
            } else {
                Write-Log "Get-ExoGroupMembersAction: Keine Mitglieder-Objekte für '$groupDisplayName' zurückgegeben (Cmdlet lieferte null oder Fehler)." -Type Debug
                $members = @() 
            }
        } catch {
            $errorMsg = $_.Exception.Message
            Write-Log "Get-ExoGroupMembersAction: Fehler beim Abrufen der Mitglieder für '$groupDisplayName': $errorMsg" -Type Error
            Show-MessageBox -Message "Fehler beim Abrufen der Gruppenmitglieder für '$groupDisplayName': $errorMsg" -Title "Fehler Mitgliederabruf" -Type Error
        }

        # UI aktualisieren - Mitgliederliste
        if ($null -ne $script:lstGroupMembers) {
            # Erstelle eine Liste für die DataGrid-Anzeige
            $displayList = New-Object 'System.Collections.Generic.List[object]'
            $ownerAddresses = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
            
            # Zuerst Besitzer hinzufügen (falls vorhanden)
            if (@($owners).Count -gt 0) {
                foreach ($owner in $owners) {
                    if (-not [string]::IsNullOrEmpty([string]$owner.PrimarySmtpAddress)) { [void]$ownerAddresses.Add([string]$owner.PrimarySmtpAddress) }
                    $displayItem = [PSCustomObject]@{
                        DisplayName = "$($owner.DisplayName) (Besitzer)"
                        PrimarySmtpAddress = $owner.PrimarySmtpAddress
                        RecipientType = if ($owner.RecipientType) { "$($owner.RecipientType) - Besitzer" } else { "Besitzer" }
                        HiddenFromAddressListsEnabled = $owner.HiddenFromAddressListsEnabled
                    }
                    $displayList.Add($displayItem)
                }
            }

            # Dann normale Mitglieder hinzufügen
            if ($membersSuccessfullyRetrieved -and @($members).Count -gt 0) {
                foreach ($member in $members) {
                    # Prüfen ob das Mitglied nicht bereits als Besitzer aufgelistet wurde
                    if (-not $ownerAddresses.Contains([string]$member.PrimarySmtpAddress)) {
                        $displayItem = [PSCustomObject]@{
                            DisplayName = $member.DisplayName
                            PrimarySmtpAddress = $member.PrimarySmtpAddress
                            RecipientType = $member.RecipientType
                            HiddenFromAddressListsEnabled = $member.HiddenFromAddressListsEnabled
                        }
                        $displayList.Add($displayItem)
                    }
                }
            } elseif ($recipientType -eq "DynamicDistributionGroup") {
                $displayItem = [PSCustomObject]@{
                    DisplayName = "Dynamische Gruppen haben keine festen Mitglieder."
                    PrimarySmtpAddress = ""
                    RecipientType = ""
                    HiddenFromAddressListsEnabled = ""
                }
                $displayList.Add($displayItem)
            } elseif ($displayList.Count -eq 0) {
                $displayItem = [PSCustomObject]@{
                    DisplayName = "Keine Mitglieder gefunden."
                    PrimarySmtpAddress = ""
                    RecipientType = ""
                    HiddenFromAddressListsEnabled = ""
                }
                $displayList.Add($displayItem)
            }
            
            # Setze die ItemsSource des DataGrids
            $script:lstGroupMembers.ItemsSource = $displayList
            # Speichere die Original-Mitgliederliste für Export
            $script:lstGroupMembers.Tag = $members
        }

        # UI aktualisieren - Gruppeneinstellungen (Checkboxes)
        try {
            $script:chkHiddenFromGAL.IsEnabled = $true
            $script:chkRequireSenderAuth.IsEnabled = $true
            $script:chkAllowExternalSenders.IsEnabled = $true
            
            $groupDetailsForSettings = $null
            if ($recipientType -eq "GroupMailbox") {
                $groupDetailsForSettings = Get-UnifiedGroup -Identity $effectiveIdentityForExo -ErrorAction Stop
                if ($groupDetailsForSettings) {
                    $script:chkHiddenFromGAL.IsChecked = $groupDetailsForSettings.HiddenFromAddressListsEnabled
                    $script:chkRequireSenderAuth.IsChecked = $groupDetailsForSettings.RequireSenderAuthenticationEnabled
                    $script:chkAllowExternalSenders.IsChecked = (-not $groupDetailsForSettings.RequireSenderAuthenticationEnabled)
                }
            } elseif ($recipientType -in ("MailUniversalDistributionGroup", "MailUniversalSecurityGroup", "MailNonUniversalGroup")) {
                $groupDetailsForSettings = Get-DistributionGroup -Identity $effectiveIdentityForExo -ErrorAction Stop
                if ($groupDetailsForSettings) {
                    $script:chkHiddenFromGAL.IsChecked = $groupDetailsForSettings.HiddenFromAddressListsEnabled
                    $script:chkRequireSenderAuth.IsChecked = $groupDetailsForSettings.RequireSenderAuthenticationEnabled
                    $script:chkAllowExternalSenders.IsChecked = (-not $groupDetailsForSettings.RequireSenderAuthenticationEnabled)
                }
            } elseif ($recipientType -eq "DynamicDistributionGroup") {
                $groupDetailsForSettings = Get-DynamicDistributionGroup -Identity $effectiveIdentityForExo -ErrorAction Stop
                if ($groupDetailsForSettings) {
                    $script:chkHiddenFromGAL.IsChecked = $groupDetailsForSettings.HiddenFromAddressListsEnabled
                    if ($groupDetailsForSettings.PSObject.Properties["RequireSenderAuthenticationEnabled"]) {
                        $script:chkRequireSenderAuth.IsChecked = $groupDetailsForSettings.RequireSenderAuthenticationEnabled
                        $script:chkAllowExternalSenders.IsChecked = (-not $groupDetailsForSettings.RequireSenderAuthenticationEnabled)
                    } else {
                        $script:chkRequireSenderAuth.IsEnabled = $false
                        $script:chkAllowExternalSenders.IsEnabled = $false
                    }
                }
            } else {
                Write-Log "Get-ExoGroupMembersAction: Gruppentyp '$recipientType' hat keine unterstützten Einstellungen für die UI." -Type Info
                $script:chkHiddenFromGAL.IsEnabled = $false
                $script:chkRequireSenderAuth.IsEnabled = $false
                $script:chkAllowExternalSenders.IsEnabled = $false
            }
            
            if ($null -ne $groupDetailsForSettings) {
                Write-Log "Get-ExoGroupMembersAction: Einstellungen für '$groupDisplayName' geladen und UI aktualisiert." -Type Info
            } else {
                Write-Log "Get-ExoGroupMembersAction: Keine Einstellungsdetails für '$groupDisplayName' (Typ '$recipientType') abrufbar oder Typ nicht unterstützt für Einstellungen." -Type Warning
                $script:chkHiddenFromGAL.IsEnabled = $false
                $script:chkRequireSenderAuth.IsEnabled = $false
                $script:chkAllowExternalSenders.IsEnabled = $false
            }

        } catch {
            $errorMsg = $_.Exception.Message
            Write-Log "Get-ExoGroupMembersAction: Fehler beim Laden der Einstellungen für '$groupDisplayName': $errorMsg" -Type Error
            Show-MessageBox -Message "Fehler beim Laden der Gruppeneinstellungen für '$groupDisplayName': $errorMsg" -Title "Fehler Einstellungen" -Type Error
            $script:chkHiddenFromGAL.IsChecked = $false; $script:chkHiddenFromGAL.IsEnabled = $false
            $script:chkRequireSenderAuth.IsChecked = $false; $script:chkRequireSenderAuth.IsEnabled = $false
            $script:chkAllowExternalSenders.IsChecked = $false; $script:chkAllowExternalSenders.IsEnabled = $false
        }

        Update-StatusBar -Message "Mitglieder und Einstellungen für '$groupDisplayName' geladen." -Type Success
        Write-Log "Get-ExoGroupMembersAction: Aktion erfolgreich abgeschlossen für '$groupDisplayName'." -Type Success

    } catch {
        $errorMsg = $_.Exception.Message
        $fullError = $_.ToString()
        Write-Log "Get-ExoGroupMembersAction: Schwerwiegender Fehler für Gruppe '$groupDisplayName': $errorMsg `n$fullError" -Type Error
        Show-MessageBox -Message "Ein schwerwiegender Fehler ist aufgetreten beim Laden der Gruppeninformationen für '$groupDisplayName': $errorMsg" -Title "Schwerer Fehler" -Type Error
        Update-StatusBar -Message "Fehler beim Laden der Gruppeninformationen für '$groupDisplayName'." -Type Error

        try {
            $script:chkHiddenFromGAL.IsChecked = $false; $script:chkHiddenFromGAL.IsEnabled = $false
            $script:chkRequireSenderAuth.IsChecked = $false; $script:chkRequireSenderAuth.IsEnabled = $false
            $script:chkAllowExternalSenders.IsChecked = $false; $script:chkAllowExternalSenders.IsEnabled = $false
            if ($null -ne $script:lstGroupMembers) {
                $errorItem = [PSCustomObject]@{
                    DisplayName = "Fehler beim Laden der Gruppeninformationen."
                    PrimarySmtpAddress = ""
                    RecipientType = ""
                    HiddenFromAddressListsEnabled = ""
                }
                $script:lstGroupMembers.ItemsSource = @($errorItem)
                $script:lstGroupMembers.Tag = $null
            }
        } catch {
            Write-Log "Get-ExoGroupMembersAction: Konnte UI nach schwerem Fehler nicht zurücksetzen." -Type Error
        }
    } finally {
        Stop-UIBusy
    }
}

#region Initialize-GroupsTab

function Initialize-GroupsTab {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Initialisiere Gruppen-Tab..." -Type "Info"

        $script:cmbGroupType = Get-XamlElement -ElementName "cmbGroupType"
        $script:txtGroupName = Get-XamlElement -ElementName "txtGroupName"
        $script:txtGroupEmail = Get-XamlElement -ElementName "txtGroupEmail"
        $script:txtGroupMembers = Get-XamlElement -ElementName "txtGroupMembers"
        $script:txtGroupDescription = Get-XamlElement -ElementName "txtGroupDescription"
        $script:btnCreateGroup = Get-XamlElement -ElementName "btnCreateGroup"
        $script:btnDeleteGroup = Get-XamlElement -ElementName "btnDeleteGroup"

        $script:cmbSelectExistingGroup = Get-XamlElement -ElementName "cmbSelectExistingGroup" 
        $script:btnRefreshExistingGroups = Get-XamlElement -ElementName "btnRefreshExistingGroups" 
        $script:txtGroupUser = Get-XamlElement -ElementName "txtGroupUser"
        $script:btnAddUserToGroup = Get-XamlElement -ElementName "btnAddUserToGroup"
        $script:btnRemoveUserFromGroup = Get-XamlElement -ElementName "btnRemoveUserFromGroup"
        $script:chkHiddenFromGAL = Get-XamlElement -ElementName "chkHiddenFromGAL"
        $script:chkRequireSenderAuth = Get-XamlElement -ElementName "chkRequireSenderAuth"
        $script:chkAllowExternalSenders = Get-XamlElement -ElementName "chkAllowExternalSenders"
        $script:btnShowGroupMembers = Get-XamlElement -ElementName "btnShowGroupMembers"
        $script:btnUpdateGroupSettings = Get-XamlElement -ElementName "btnUpdateGroupSettings"

        $script:lstGroupMembers = Get-XamlElement -ElementName "lstGroupMembers"
        $script:btnExportGroupMembers = Get-XamlElement -ElementName "btnExportGroupMembers" 

        $script:helpLinkGroups = Get-XamlElement -ElementName "helpLinkGroups"

        if ($null -ne $script:cmbGroupType) {
            # UI-Anzeigenamen. Die Umsetzung zu API-Werten erfolgt im Handler.
            $groupTypesForUI = @("Verteilergruppe", "E-Mail-aktivierte Sicherheitsgruppe", "Microsoft 365-Gruppe") 
            $script:cmbGroupType.Items.Clear()
            foreach ($type in $groupTypesForUI) {
                $item = New-Object System.Windows.Controls.ComboBoxItem
                $item.Content = $type
                [void]$script:cmbGroupType.Items.Add($item)
            }
            if ($script:cmbGroupType.Items.Count -gt 0) {
                $script:cmbGroupType.SelectedIndex = 0 
            }
        }

        # Beide Checkboxen bilden RequireSenderAuthenticationEnabled ab (invertiert) und werden bei
        # Benutzereingaben synchron gehalten. Click statt Checked/Unchecked, damit das programmatische
        # Setzen beim Laden/Zurücksetzen keine Rückkopplung auslöst.
        if ($null -ne $script:chkRequireSenderAuth -and $null -ne $script:chkAllowExternalSenders) {
            $null = Register-EventHandler -Control $script:chkRequireSenderAuth -ControlName "chkRequireSenderAuth" -Handler {
                $script:chkAllowExternalSenders.IsChecked = -not [bool]$script:chkRequireSenderAuth.IsChecked
            }
            $null = Register-EventHandler -Control $script:chkAllowExternalSenders -ControlName "chkAllowExternalSenders" -Handler {
                $script:chkRequireSenderAuth.IsChecked = -not [bool]$script:chkAllowExternalSenders.IsChecked
            }
        }

        if ($null -ne $script:btnRefreshExistingGroups) {
            Register-EventHandler -Control $script:btnRefreshExistingGroups -Handler {
                try {
                    Write-Log "Button 'Gruppenliste aktualisieren' (btnRefreshExistingGroups) geklickt." -Type "Info"
                    Refresh-ExistingGroupsDropdown
                }
                catch {
                    $errorMsg = $_.Exception.Message
                    $logErrorMsg = "Fehler beim Klick auf 'Gruppenliste aktualisieren': $errorMsg"
                    Write-Log $logErrorMsg -Type "Error"
                    Update-StatusBar -Message $logErrorMsg -Type "Error"
                }
            } -ControlName "btnRefreshExistingGroups"
        }

        if ($null -ne $script:cmbSelectExistingGroup) {
            $script:cmbSelectExistingGroup.Add_SelectionChanged({
            try {
                if ($null -ne $script:cmbSelectExistingGroup.SelectedItem) {
                $selectedGroupItem = $script:cmbSelectExistingGroup.SelectedItem
                $groupObject = $selectedGroupItem.Tag

                # Debug-Ausgabe für Fehlerbehebung
                Write-Log "SelectionChanged: SelectedItem Content: '$($selectedGroupItem.Content)'" -Type Debug
                if ($null -ne $selectedGroupItem.Tag) {
                    Write-Log "SelectionChanged: Tag Type: $($selectedGroupItem.Tag.GetType().Name)" -Type Debug
                    Write-Log "SelectionChanged: Tag Properties: $($selectedGroupItem.Tag.PSObject.Properties.Name -join ', ')" -Type Debug
                } else {
                    Write-Log "SelectionChanged: Tag ist null" -Type Debug
                }

                # Korrigierte Validierung: DistinguishedName statt Identity verwenden
                if ($null -eq $groupObject -or 
                    -not $groupObject.PSObject.Properties["DistinguishedName"] -or 
                    [string]::IsNullOrWhiteSpace($groupObject.DistinguishedName)) {
                    Write-Log "SelectionChanged: Ungültiges Gruppenobjekt oder fehlende DistinguishedName im Tag des ausgewählten Elements." -Type Warning
                    if ($null -ne $script:lstGroupMembers) { $script:lstGroupMembers.ItemsSource = $null; $script:lstGroupMembers.Tag = $null }
                    if ($null -ne $script:chkHiddenFromGAL) { $script:chkHiddenFromGAL.IsChecked = $false; $script:chkHiddenFromGAL.IsEnabled = $false }
                    if ($null -ne $script:chkRequireSenderAuth) { $script:chkRequireSenderAuth.IsChecked = $false; $script:chkRequireSenderAuth.IsEnabled = $false }
                    if ($null -ne $script:chkAllowExternalSenders) { $script:chkAllowExternalSenders.IsChecked = $false; $script:chkAllowExternalSenders.IsEnabled = $false }
                    if ($null -ne $script:txtGroupUser) { $script:txtGroupUser.Text = "" }
                    Update-StatusBar -Message "Ungültige Gruppenauswahl." -Type Warning
                    return
                }
                
                # DistinguishedName als Identity verwenden
                $effectiveIdentity = $groupObject.DistinguishedName
                Write-Log "Gruppe '$($selectedGroupItem.Content)' (DistinguishedName: $effectiveIdentity) in ComboBox ausgewählt. Lade Details..." -Type "Info"
                Get-ExoGroupMembersAction

                if ($null -ne $script:txtGroupUser) { $script:txtGroupUser.Text = "" } 
                } else {
                Write-Log "ComboBox-Auswahl gelöscht oder kein Element ausgewählt (cmbSelectExistingGroup)." -Type Info
                if ($null -ne $script:lstGroupMembers) { $script:lstGroupMembers.ItemsSource = $null; $script:lstGroupMembers.Tag = $null }
                if ($null -ne $script:chkHiddenFromGAL) { $script:chkHiddenFromGAL.IsChecked = $false; $script:chkHiddenFromGAL.IsEnabled = $false }
                if ($null -ne $script:chkRequireSenderAuth) { $script:chkRequireSenderAuth.IsChecked = $false; $script:chkRequireSenderAuth.IsEnabled = $false }
                if ($null -ne $script:chkAllowExternalSenders) { $script:chkAllowExternalSenders.IsChecked = $false; $script:chkAllowExternalSenders.IsEnabled = $false }
                if ($null -ne $script:txtGroupUser) { $script:txtGroupUser.Text = "" }
                Update-StatusBar -Message "Keine Gruppe ausgewählt." -Type Info
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler bei SelectionChanged für cmbSelectExistingGroup: $errorMsg" -Type "Error"
                Update-StatusBar -Message "Fehler bei Gruppenauswahl: $errorMsg" -Type "Error"
            }
            })
        }

        if ($null -ne $script:btnCreateGroup) {
            Register-EventHandler -Control $script:btnCreateGroup -Handler {
                try {
                    Write-Log "Button 'Gruppe erstellen' geklickt." -Type "Info"
                    if (-not $script:isConnected) {
                        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                        return
                    }

                    if ($null -eq $script:cmbGroupType.SelectedItem) {
                        Show-MessageBox -Message "Bitte wählen Sie einen Gruppentyp aus." -Title "Unvollständige Angaben" -Type Warning
                        return
                    }
                    if ([string]::IsNullOrWhiteSpace($script:txtGroupName.Text)) {
                        Show-MessageBox -Message "Bitte geben Sie einen Gruppennamen an." -Title "Unvollständige Angaben" -Type Warning
                        return
                    }
                     if ([string]::IsNullOrWhiteSpace($script:txtGroupEmail.Text)) {
                        Show-MessageBox -Message "Bitte geben Sie eine E-Mail-Adresse für die Gruppe an." -Title "Unvollständige Angaben" -Type Warning
                        return
                    }

                    $uiGroupType = $script:cmbGroupType.SelectedItem.Content
                    $apiGroupType = ""
                    switch ($uiGroupType) {
                        "Verteilergruppe" { $apiGroupType = "Distribution" }
                        "E-Mail-aktivierte Sicherheitsgruppe" { $apiGroupType = "Security" }
                        "Microsoft 365-Gruppe" { $apiGroupType = "Microsoft365" }
                        default {
                            Show-MessageBox -Message "Unbekannter oder nicht unterstützter Gruppentyp im UI: '$uiGroupType'." -Title "Fehler" -Type Error
                            return
                        }
                    }
                    
                    $membersInput = $script:txtGroupMembers.Text
                    $membersArray = @()
                    if (-not [string]::IsNullOrWhiteSpace($membersInput)) {
                        $membersArray = $membersInput -split '[;,\r\n]' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                    }

                    $createParams = @{
                        GroupName = $script:txtGroupName.Text
                        GroupEmail = $script:txtGroupEmail.Text
                        GroupType = $apiGroupType
                        Members = $membersArray
                        Description = $script:txtGroupDescription.Text
                        # Owner wird in New-ExoGroupAction behandelt (aktueller Benutzer als Fallback für M365)
                    }
                    
                    $createResult = New-ExoGroupAction @createParams 
                    
                    if ($createResult) { # New-ExoGroupAction gibt das Gruppenobjekt oder $null zurück
                        Update-StatusBar -Message "Gruppe '$($createResult.DisplayName)' erfolgreich erstellt." -Type Success
                        Write-Log "Gruppe '$($createResult.DisplayName)' erfolgreich erstellt." -Type "Success"
                        $script:txtGroupName.Text = ""
                        $script:txtGroupEmail.Text = ""
                        $script:txtGroupMembers.Text = ""
                        $script:txtGroupDescription.Text = ""
                        Refresh-ExistingGroupsDropdown 
                    } # Fehlerfall wird in New-ExoGroupAction behandelt (Statusbar, Log)

                } catch {
                    $errMsg = "Fehler beim Erstellen der Gruppe: $($_.Exception.Message)"
                    Write-Log $errMsg -Type "Error"
                    Update-StatusBar -Message $errMsg -Type "Error"
                }
            } -ControlName "btnCreateGroup"
        }

        if ($null -ne $script:btnDeleteGroup) {
            Register-EventHandler -Control $script:btnDeleteGroup -Handler {
                try {
                    Write-Log "Button 'Gruppe löschen' geklickt." -Type "Info"

                    if (-not $script:isConnected) {
                        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                        return
                    }

                    $groupToDeleteObject = $null
                    if ($null -ne $script:cmbSelectExistingGroup.SelectedItem) {
                        $groupToDeleteObject = $script:cmbSelectExistingGroup.SelectedItem.Tag 
                    }

                    if ($null -eq $groupToDeleteObject -and -not [string]::IsNullOrWhiteSpace($script:txtGroupName.Text) ) {
                         Write-Log "Versuche Gruppe zum Löschen über txtGroupName '$($script:txtGroupName.Text)' zu finden..." -Type Info
                         $groupToDeleteObject = Get-ExoGroupRecipientAction -Identity $script:txtGroupName.Text # Annahme: Get-ExoGroupRecipientAction kann das
                    }

                    if ($null -eq $groupToDeleteObject) {
                        Show-MessageBox -Message "Bitte wählen Sie eine zu löschende Gruppe aus der Liste 'Gruppe auswählen' aus oder geben Sie einen gültigen Gruppennamen im Feld 'Gruppenname' ein." -Title "Keine Gruppe ausgewählt/gefunden" -Type Warning
                        return
                    }
                    
                    $groupDisplayNameForDelete = $groupToDeleteObject.DisplayName
                    
                    # Bestimme die korrekte Identity für die Gruppe
                    $groupIdentityForDelete = $null
                    if ($groupToDeleteObject.PSObject.Properties["OriginalObject"] -and $groupToDeleteObject.OriginalObject.PSObject.Properties["Identity"]) {
                        $groupIdentityForDelete = $groupToDeleteObject.OriginalObject.Identity
                    } elseif ($groupToDeleteObject.PSObject.Properties["Identity"]) {
                        $groupIdentityForDelete = $groupToDeleteObject.Identity
                    } elseif ($groupToDeleteObject.PSObject.Properties["DistinguishedName"]) {
                        $groupIdentityForDelete = $groupToDeleteObject.DistinguishedName
                    } elseif ($groupToDeleteObject.PSObject.Properties["PrimarySmtpAddress"]) {
                        $groupIdentityForDelete = $groupToDeleteObject.PrimarySmtpAddress
                    } else {
                        Write-Log "Keine gültige Identity für zu löschende Gruppe gefunden" -Type "Error"
                        Show-MessageBox -Message "Keine gültige Gruppen-Identity gefunden." -Title "Fehler" -Type Error
                        return
                    }

                    $confirmResult = Show-MessageBox -Message "Sind Sie sicher, dass Sie die Gruppe '$groupDisplayNameForDelete' (Identity: $groupIdentityForDelete) löschen möchten? Diese Aktion kann nicht rückgängig gemacht werden." -Title "Gruppe löschen bestätigen" -Type Question
                    if ($confirmResult -ne "Yes") {
                        Write-Log "Löschen der Gruppe '$groupDisplayNameForDelete' abgebrochen." -Type "Info"
                        Update-StatusBar -Message "Löschen der Gruppe '$groupDisplayNameForDelete' abgebrochen." -Type Info
                        return
                    }
                    
                    $deleteResult = Remove-ExoGroupAction -Identity $groupIdentityForDelete 
                                        
                    if ($deleteResult) { # Remove-ExoGroupAction gibt $true/$false zurück
                        Update-StatusBar -Message "Gruppe '$groupDisplayNameForDelete' erfolgreich gelöscht." -Type Success
                        Write-Log "Gruppe '$groupDisplayNameForDelete' erfolgreich gelöscht." -Type "Success"
                        if ($script:txtGroupName.Text -eq $groupDisplayNameForDelete) { $script:txtGroupName.Text = "" }
                        Refresh-ExistingGroupsDropdown
                    } # Fehlerfall wird in Remove-ExoGroupAction behandelt

                } catch {
                    $errMsg = "Fehler beim Löschen der Gruppe: $($_.Exception.Message)"
                    Write-Log $errMsg -Type "Error"
                    Update-StatusBar -Message $errMsg -Type "Error"
                }
            } -ControlName "btnDeleteGroup"
        }

        if ($null -ne $script:btnAddUserToGroup) {
            Register-EventHandler -Control $script:btnAddUserToGroup -Handler {
                try {
                    Write-Log "Button 'Benutzer hinzufügen' geklickt." -Type "Info"

                    # Verbindungsprüfung
                    if (-not $script:isConnected) {
                        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                        return
                    }

                    # Gruppenauswahl prüfen
                    if ($null -eq $script:cmbSelectExistingGroup.SelectedItem) {
                        Show-MessageBox -Message "Bitte wählen Sie zuerst eine Gruppe aus der Liste aus." -Title "Keine Gruppe ausgewählt" -Type Warning
                        return
                    }

                    # Benutzereingabe prüfen
                    if ([string]::IsNullOrWhiteSpace($script:txtGroupUser.Text)) {
                        Show-MessageBox -Message "Bitte geben Sie den Benutzer (E-Mail-Adresse oder Alias) an, der hinzugefügt werden soll." -Title "Kein Benutzer angegeben" -Type Warning
                        return
                    }

                    $selectedGroupItem = $script:cmbSelectExistingGroup.SelectedItem
                    $groupObject = $selectedGroupItem.Tag
                    $userEmail = $script:txtGroupUser.Text.Trim()

                    # Bestimme die korrekte Identity für die Gruppe
                    $groupIdentity = $null
                    if ($groupObject.PSObject.Properties["OriginalObject"] -and $groupObject.OriginalObject.PSObject.Properties["Identity"]) {
                        $groupIdentity = $groupObject.OriginalObject.Identity
                    } elseif ($groupObject.PSObject.Properties["DistinguishedName"]) {
                        $groupIdentity = $groupObject.DistinguishedName
                    } elseif ($groupObject.PSObject.Properties["PrimarySmtpAddress"]) {
                        $groupIdentity = $groupObject.PrimarySmtpAddress
                    } else {
                        Write-Log "Keine gültige Identity für Gruppe gefunden" -Type "Error"
                        Show-MessageBox -Message "Keine gültige Gruppen-Identity gefunden." -Title "Fehler" -Type Error
                        return
                    }

                    # Bestätigung einholen
                    $confirmResult = Show-MessageBox -Message "Möchten Sie den Benutzer '$userEmail' zur Gruppe '$($groupObject.DisplayName)' hinzufügen?" -Title "Benutzer hinzufügen bestätigen" -Type Question
                    if ($confirmResult -ne "Yes") {
                        Write-Log "Hinzufügen des Benutzers '$userEmail' zu Gruppe '$($groupObject.DisplayName)' abgebrochen." -Type "Info"
                        Update-StatusBar -Message "Hinzufügen von '$userEmail' abgebrochen." -Type Info
                        return
                    }

                    # Benutzer zur Gruppe hinzufügen mit ErrorAction Stop
                    $addResult = Add-ExoGroupMemberAction -Identity $groupIdentity -MemberIdentity $userEmail -ErrorAction Stop

                    if ($addResult) {
                        $successMsg = "Benutzer '$userEmail' zu Gruppe '$($groupObject.DisplayName)' hinzugefügt."
                        Update-StatusBar -Message $successMsg -Type Success
                        Write-Log $successMsg -Type "Success"
                        $script:txtGroupUser.Text = ""

                        # Listen aktualisieren
                        Get-ExoGroupMembersAction
                    }
                } catch {
                    $errMsg = "Fehler beim Hinzufügen des Benutzers zur Gruppe: $($_.Exception.Message)"
                    Write-Log $errMsg -Type "Error"
                    Update-StatusBar -Message $errMsg -Type "Error"
                }
            } -ControlName "btnAddUserToGroup"
        }

        if ($null -ne $script:btnRemoveUserFromGroup) {
            Register-EventHandler -Control $script:btnRemoveUserFromGroup -Handler {
                try {
                    Write-Log "Button 'Benutzer entfernen' geklickt." -Type "Info"
                    
                    # Verbindungsprüfung
                    if (-not $script:isConnected) {
                        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                        return
                    }

                    # Gruppenauswahl prüfen
                    if ($null -eq $script:cmbSelectExistingGroup.SelectedItem) {
                        Show-MessageBox -Message "Bitte wählen Sie zuerst eine Gruppe aus der Liste aus." -Title "Keine Gruppe ausgewählt" -Type Warning
                        return
                    }

                    # Benutzereingabe prüfen
                    if ([string]::IsNullOrWhiteSpace($script:txtGroupUser.Text)) {
                        Show-MessageBox -Message "Bitte geben Sie den Benutzer (E-Mail-Adresse oder Alias) an, der entfernt werden soll." -Title "Kein Benutzer angegeben" -Type Warning
                        return
                    }

                    $selectedGroupItem = $script:cmbSelectExistingGroup.SelectedItem
                    $groupObject = $selectedGroupItem.Tag
                    $userEmail = $script:txtGroupUser.Text.Trim()
                    
                    # Bestimme die korrekte Identity für die Gruppe
                    $groupIdentity = $null
                    if ($groupObject.PSObject.Properties["OriginalObject"] -and $groupObject.OriginalObject.PSObject.Properties["Identity"]) {
                        $groupIdentity = $groupObject.OriginalObject.Identity
                    } elseif ($groupObject.PSObject.Properties["DistinguishedName"]) {
                        $groupIdentity = $groupObject.DistinguishedName
                    } elseif ($groupObject.PSObject.Properties["PrimarySmtpAddress"]) {
                        $groupIdentity = $groupObject.PrimarySmtpAddress
                    } else {
                        Write-Log "Keine gültige Identity für Gruppe gefunden" -Type "Error"
                        Show-MessageBox -Message "Keine gültige Gruppen-Identity gefunden." -Title "Fehler" -Type Error
                        return
                    }
                    
                    # Bestätigung einholen
                    $confirmResult = Show-MessageBox -Message "Sind Sie sicher, dass Sie den Benutzer '$userEmail' aus der Gruppe '$($groupObject.DisplayName)' entfernen möchten?" -Title "Benutzer entfernen bestätigen" -Type Question
                    if ($confirmResult -ne "Yes") {
                        Write-Log "Entfernen des Benutzers '$userEmail' aus Gruppe '$($groupObject.DisplayName)' abgebrochen." -Type "Info"
                        Update-StatusBar -Message "Entfernen von '$userEmail' abgebrochen." -Type Info
                        return
                    }

                    # Benutzer aus Gruppe entfernen mit ErrorAction Stop
                    $removeResult = Remove-ExoGroupMemberAction -GroupIdentity $groupIdentity -UserIdentity $userEmail -ErrorAction Stop

                    # $false ohne Exception: Gruppe nicht gefunden, dynamische/nicht unterstützte Gruppe oder abgebrochen.
                    # Statusleiste bzw. Meldung wurden bereits in Remove-ExoGroupMemberAction gesetzt.
                    if (-not $removeResult) {
                        Write-Log "Benutzer '$userEmail' wurde nicht aus Gruppe '$($groupObject.DisplayName)' entfernt." -Type "Warning"
                        return
                    }

                    $successMsg = "Benutzer '$userEmail' aus Gruppe '$($groupObject.DisplayName)' entfernt."
                    Update-StatusBar -Message $successMsg -Type Success
                    Write-Log $successMsg -Type "Success"
                    $script:txtGroupUser.Text = ""
                    
                    # Listen aktualisieren
                    Get-ExoGroupMembersAction
                } catch {
                    $errMsg = "Fehler beim Entfernen des Benutzers aus der Gruppe: $($_.Exception.Message)"
                    Write-Log $errMsg -Type "Error"
                    Update-StatusBar -Message $errMsg -Type "Error"
                    Show-MessageBox -Message $errMsg -Title "Fehler" -Type Error
                }
            } -ControlName "btnRemoveUserFromGroup"
        }

        if ($null -ne $script:btnUpdateGroupSettings) {
            Register-EventHandler -Control $script:btnUpdateGroupSettings -Handler {
                try {
                    Write-Log "Button 'Einstellungen aktualisieren' geklickt." -Type "Info"
                    if (-not $script:isConnected) {
                        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                        return
                    }
                    if ($null -eq $script:cmbSelectExistingGroup.SelectedItem) {
                        Show-MessageBox -Message "Bitte wählen Sie zuerst eine Gruppe aus der Liste aus." -Title "Keine Gruppe ausgewählt" -Type Warning
                        return
                    }
                    
                    $selectedGroupItem = $script:cmbSelectExistingGroup.SelectedItem
                    $groupObject = $selectedGroupItem.Tag

                    # Bestimme die korrekte Identity für die Gruppe
                    $groupIdentity = $null
                    if ($groupObject.PSObject.Properties["OriginalObject"] -and $groupObject.OriginalObject.PSObject.Properties["Identity"]) {
                        $groupIdentity = $groupObject.OriginalObject.Identity
                    } elseif ($groupObject.PSObject.Properties["DistinguishedName"]) {
                        $groupIdentity = $groupObject.DistinguishedName
                    } elseif ($groupObject.PSObject.Properties["PrimarySmtpAddress"]) {
                        $groupIdentity = $groupObject.PrimarySmtpAddress
                    } else {
                        Write-Log "Keine gültige Identity für Gruppe gefunden" -Type "Error"
                        Show-MessageBox -Message "Keine gültige Gruppen-Identity gefunden." -Title "Fehler" -Type Error
                        return
                    }

                    # Hashtable für die Gruppeneinstellungen erstellen
                    $settingsParams = @{
                        Identity = $groupIdentity
                    }

                    # Nur aktivierte und gesetzte Checkboxen in die Parameter aufnehmen
                    if ($script:chkHiddenFromGAL.IsEnabled -and $null -ne $script:chkHiddenFromGAL.IsChecked) {
                        $settingsParams.HiddenFromAddressListsEnabled = [bool]$script:chkHiddenFromGAL.IsChecked
                    }
                    # "Absender-Authentifizierung" und "Externe Absender zulassen" sind dieselbe Exchange-Einstellung
                    # (RequireSenderAuthenticationEnabled, invertiert). Die Checkboxen werden per Click-Handler
                    # synchron gehalten; übergeben wird nur ein Wert, damit keine Checkbox die andere überschreibt.
                    if ($script:chkRequireSenderAuth.IsEnabled -and $null -ne $script:chkRequireSenderAuth.IsChecked) {
                        $settingsParams.RequireSenderAuthenticationEnabled = [bool]$script:chkRequireSenderAuth.IsChecked
                    }
                    elseif ($script:chkAllowExternalSenders.IsEnabled -and $null -ne $script:chkAllowExternalSenders.IsChecked) {
                        $settingsParams.RequireSenderAuthenticationEnabled = -not [bool]$script:chkAllowExternalSenders.IsChecked
                    }

                    # Prüfen ob überhaupt Parameter zum Aktualisieren vorhanden sind
                    if ($settingsParams.Keys.Count -eq 1) {
                        Write-Log "Keine Einstellungen zum Aktualisieren ausgewählt." -Type "Warning"
                        Show-MessageBox -Message "Bitte wählen Sie mindestens eine Einstellung zum Aktualisieren aus." -Title "Keine Änderungen" -Type Warning
                        return
                    }

                    $updateResult = Update-ExoGroupSettingsAction @settingsParams

                    if ($updateResult) {
                        Write-Log "Gruppeneinstellungen für '$($groupObject.DisplayName)' erfolgreich aktualisiert." -Type "Success"
                        # Aktualisiere die Anzeige
                        Get-ExoGroupMembersAction
                    }

                } catch {
                    $errMsg = "Fehler beim Aktualisieren der Gruppeneinstellungen: $($_.Exception.Message)"
                    Write-Log $errMsg -Type "Error"
                    Update-StatusBar -Message $errMsg -Type "Error"
                    Show-MessageBox -Message $errMsg -Title "Fehler" -Type Error
                }
            } -ControlName "btnUpdateGroupSettings"
        }
        
        if ($null -ne $script:btnShowGroupMembers) {
            Register-EventHandler -Control $script:btnShowGroupMembers -Handler {
                try {
                    Write-Log "Button 'Mitglieder anzeigen' (btnShowGroupMembers) geklickt." -Type "Info"
                    if (-not $script:isConnected) {
                        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                        return
                    }
                    if ($null -eq $script:cmbSelectExistingGroup -or $null -eq $script:cmbSelectExistingGroup.SelectedItem) {
                        Show-MessageBox -Message "Bitte wählen Sie zuerst eine Gruppe aus der Liste 'Gruppe auswählen' aus." -Title "Keine Gruppe ausgewählt" -Type Info
                        return
                    }
                    Get-ExoGroupMembersAction
                }
                catch {
                    $errMsg = "Fehler beim Anzeigen der Gruppenmitglieder: $($_.Exception.Message)"
                    Write-Log $errMsg -Type "Error"
                    Update-StatusBar -Message $errMsg -Type "Error"
                }
            } -ControlName "btnShowGroupMembers"
        }

        if ($null -ne $script:btnExportGroupMembers) {
            Register-EventHandler -Control $script:btnExportGroupMembers -Handler {
                try {
                    Write-Log "Button 'Mitgliederliste exportieren' geklickt." -Type "Info"
                    if (-not $script:isConnected) {
                        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                        return
                    }
                    # Verwende $script:lstGroupMembers.Tag, da dort die rohen Mitgliederobjekte gespeichert werden
                    if ($null -eq $script:lstGroupMembers.Tag -or ($script:lstGroupMembers.Tag -is [array] -and $script:lstGroupMembers.Tag.Count -eq 0)) {
                         Show-MessageBox -Message "Es sind keine Mitglieder zum Exportieren vorhanden. Bitte laden Sie zuerst die Mitglieder einer Gruppe." -Title "Keine Daten für Export" -Type Info
                        return
                    }
                    
                    $groupNameForExport = "UnbekannteGruppe"
                    if ($null -ne $script:cmbSelectExistingGroup.SelectedItem) {
                         $groupNameForExport = $script:cmbSelectExistingGroup.SelectedItem.Content -replace '[^a-zA-Z0-9_.-]', '_' 
                    }

                    $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
                    $saveFileDialog.Filter = "CSV-Datei (*.csv)|*.csv|Textdatei (*.txt)|*.txt"
                    $saveFileDialog.FileName = "Mitglieder_$($groupNameForExport)_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                    $saveFileDialog.Title = "Mitgliederliste exportieren als"

                    if ($saveFileDialog.ShowDialog() -eq $true) {
                        $filePath = $saveFileDialog.FileName
                        $membersToExport = $script:lstGroupMembers.Tag # Dies ist das Array der Mitgliederobjekte
                        
                        # Wähle relevante Eigenschaften für den Export aus
                        $membersToExport | Select-Object DisplayName, PrimarySmtpAddress, RecipientType, Name, Alias | ConvertTo-SafeCsvObject | 
                            Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8 -Delimiter ";" 
                        
                        Update-StatusBar -Message "Mitgliederliste erfolgreich nach '$filePath' exportiert." -Type Success
                        Write-Log "Mitgliederliste erfolgreich nach '$filePath' exportiert." -Type "Success"
                        Show-MessageBox -Message "Die Mitgliederliste wurde erfolgreich exportiert nach:`n$filePath" -Title "Export erfolgreich" -Type Info
                    } else {
                        Write-Log "Export der Mitgliederliste vom Benutzer abgebrochen." -Type "Info"
                        Update-StatusBar -Message "Export abgebrochen." -Type Info
                    }

                } catch {
                    $errMsg = "Fehler beim Exportieren der Mitgliederliste: $($_.Exception.Message)"
                    Write-Log $errMsg -Type "Error"
                    Update-StatusBar -Message "Fehler beim Export: $errMsg" -Type "Error"
                    Show-MessageBox -Message "Fehler beim Exportieren der Mitgliederliste:`n$errMsg" -Title "Exportfehler" -Type Error
                }
            } -ControlName "btnExportGroupMembers"
        }

        if ($null -ne $script:helpLinkGroups) {
            $script:helpLinkGroups.Add_MouseLeftButtonDown({
                try {
                    if (Test-Path Function:\Show-HelpDialog) { Show-HelpDialog -Topic "Groups" }
                    else { Write-Log "Hilfefunktion Show-HelpDialog nicht gefunden." -Type Warning }
                } catch { Write-Log "Fehler beim Öffnen des Hilfe-Dialogs für Gruppen: $($_.Exception.Message)" -Type Error }
            })
            $script:helpLinkGroups.Add_MouseEnter({ try { $this.Cursor = [System.Windows.Input.Cursors]::Hand } catch {} })
            $script:helpLinkGroups.Add_MouseLeave({ try { $this.Cursor = [System.Windows.Input.Cursors]::Arrow } catch {} })
        }

        Write-Log "Initialize-GroupsTab erfolgreich abgeschlossen." -Type "Info"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "FATALER Fehler in Initialize-GroupsTab: $errorMsg `n$($_.ScriptStackTrace)" -Type "Error"
        Update-StatusBar -Message "Schwerer Fehler bei Initialisierung des Gruppen-Tabs: $errorMsg" -Type "Error"
        return $false
    }
}
