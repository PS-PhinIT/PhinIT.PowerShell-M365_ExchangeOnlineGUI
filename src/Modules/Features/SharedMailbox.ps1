# =====================================================================
# easyEXO - Modul: Freigegebene Postfächer
# Datei: src/Modules/Features/SharedMailbox.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

function RefreshSharedMailboxList {
    [CmdletBinding()]
    param()

    try {
        # Sicherstellen, dass das ComboBox-Element initialisiert ist
        if ($null -eq $script:cmbSharedMailboxSelect) {
            Write-Log "RefreshSharedMailboxList: Das Steuerelement 'cmbSharedMailboxSelect' ist nicht initialisiert." -Type "Warning"
            return $false
        }

        $script:cmbSharedMailboxSelect.Items.Clear()

        # Prüfen, ob eine Verbindung besteht
        if (-not $script:isConnected) {
            Write-Log "RefreshSharedMailboxList: Keine Verbindung zu Exchange Online. Aktualisierung abgebrochen." -Type "Warning"
            return $false
        }

        Write-Log "Beginne mit der Aktualisierung der Shared Mailbox-Liste." -Type "Info"
        
        # Abrufen aller Shared Mailboxen
        # Das -ErrorAction Stop ist wichtig, damit Fehler im Catch-Block landen
        $sharedMailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited -ErrorAction Stop | 
                            Select-Object -ExpandProperty PrimarySmtpAddress
        
        if ($null -eq $sharedMailboxes -or $sharedMailboxes.Count -eq 0) {
            Write-Log "Keine Shared Mailboxen gefunden oder Fehler beim Abrufen." -Type "Info"
        } else {
            foreach ($mailboxAddress in $sharedMailboxes) {
                [void]$script:cmbSharedMailboxSelect.Items.Add($mailboxAddress)
            }
            Write-Log "$($script:cmbSharedMailboxSelect.Items.Count) Shared Mailboxen zur Liste hinzugefügt." -Type "Info"
        }
        
        if ($script:cmbSharedMailboxSelect.Items.Count -gt 0) {
            $script:cmbSharedMailboxSelect.SelectedIndex = 0
        }
        
        Write-Log "Shared Mailbox-Liste erfolgreich aktualisiert." -Type "Success"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Aktualisieren der Shared Mailbox-Liste: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Aktualisieren der Shared Mailbox-Liste: $errorMsg" # Für detaillierteres Logging
        return $false
    }
}

function New-SharedMailboxAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [string]$EmailAddress
    )
    
    try {
        Write-Log  "Erstelle neue Shared Mailbox: $Name mit Adresse $EmailAddress" -Type "Info"
        New-Mailbox -Name $Name -PrimarySmtpAddress $EmailAddress -Shared -ErrorAction Stop
        Write-Log  "Shared Mailbox $Name erfolgreich erstellt" -Type "Success"
        Log-Action "Shared Mailbox $Name ($EmailAddress) erfolgreich erstellt"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Erstellen der Shared Mailbox: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Erstellen der Shared Mailbox $Name - $errorMsg"
        return $false
    }
}

function Convert-ToSharedMailboxAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity
    )
    
    try {
        Write-Log  "Konvertiere Postfach zu Shared Mailbox: $Identity" -Type "Info"
        Set-Mailbox -Identity $Identity -Type Shared -ErrorAction Stop
        Write-Log  "Postfach $Identity erfolgreich zu Shared Mailbox konvertiert" -Type "Success"
        Log-Action "Postfach $Identity erfolgreich zu Shared Mailbox konvertiert"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Konvertieren des Postfachs: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Konvertieren des Postfachs  - $errorMsg"
        return $false
    }
}

function Add-SharedMailboxPermissionAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Mailbox,
        
        [Parameter(Mandatory = $true)]
        [string]$User,
        
        [Parameter(Mandatory = $true)]
        [string]$PermissionType,
        
        [Parameter(Mandatory = $false)]
        [bool]$AutoMapping = $true
    )
    
    try {
        # Validiere Eingabeparameter
        if ([string]::IsNullOrEmpty($Mailbox) -or [string]::IsNullOrEmpty($User)) {
            throw "Mailbox und User dürfen nicht leer sein"
        }

        Write-Log "Füge Shared Mailbox Berechtigung hinzu: $PermissionType für $User auf $Mailbox" -Type "Info"
        
        # Prüfe ob Benutzer existiert
        try {
            $null = Get-Recipient -Identity $User -ErrorAction Stop
        }
        catch {
            throw "Der angegebene Benutzer $User wurde nicht gefunden"
        }

        # Prüfe ob Mailbox existiert
        try {
            $null = Get-Mailbox -Identity $Mailbox -ErrorAction Stop
        }
        catch {
            throw "Die angegebene Mailbox $Mailbox wurde nicht gefunden"
        }

        switch ($PermissionType) {
            "FullAccess" {
                Add-MailboxPermission -Identity $Mailbox -User $User -AccessRights FullAccess -AutoMapping $AutoMapping -ErrorAction Stop
            }
            "SendAs" {
                Add-RecipientPermission -Identity $Mailbox -Trustee $User -AccessRights SendAs -Confirm:$false -ErrorAction Stop
            }
            "SendOnBehalf" {
                # @{Add=...} ergänzt den Delegaten, ohne bestehende Einträge zu überschreiben
                Set-Mailbox -Identity $Mailbox -GrantSendOnBehalfTo @{Add = $User} -ErrorAction Stop
            }
            default {
                throw "Ungültiger PermissionType: $PermissionType"
            }
        }
        
        Write-Log "Shared Mailbox Berechtigung erfolgreich hinzugefügt" -Type "Success"
        Log-Action "Shared Mailbox Berechtigung $PermissionType für $User auf $Mailbox hinzugefügt"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Hinzufügen der Shared Mailbox Berechtigung: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Hinzufügen der Shared Mailbox Berechtigung: $errorMsg"
        return $false
    }
}

function Remove-SharedMailboxPermissionAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Mailbox,
        
        [Parameter(Mandatory = $true)]
        [string]$User,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("FullAccess", "SendAs", "SendOnBehalf")]
        [string]$PermissionType
    )
    
    try {
        Write-Log "Entferne Shared Mailbox Berechtigung: $PermissionType für $User auf $Mailbox" -Type "Info"
        
        # Prüfe ob Benutzer existiert
        try {
            $null = Get-Recipient -Identity $User -ErrorAction Stop
        }
        catch {
            throw "Der angegebene Benutzer $User wurde nicht gefunden"
        }

        # Prüfe ob Mailbox existiert
        try {
            $null = Get-Mailbox -Identity $Mailbox -ErrorAction Stop
        }
        catch {
            throw "Die angegebene Mailbox $Mailbox wurde nicht gefunden"
        }

        # Bestätigungsdialog anzeigen
        $confirmResult = [System.Windows.MessageBox]::Show(
            "Möchten Sie wirklich die $PermissionType-Berechtigung für $User auf $Mailbox entfernen?",
            "Berechtigung entfernen",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )

        if ($confirmResult -eq [System.Windows.MessageBoxResult]::No) {
            Write-Log "Entfernen der Berechtigung durch Benutzer abgebrochen" -Type "Info"
            return $false
        }
        
        switch ($PermissionType) {
            "FullAccess" {
                Remove-MailboxPermission -Identity $Mailbox -User $User -AccessRights FullAccess -Confirm:$false -ErrorAction Stop
            }
            "SendAs" {
                Remove-RecipientPermission -Identity $Mailbox -Trustee $User -AccessRights SendAs -Confirm:$false -ErrorAction Stop
            }
            "SendOnBehalf" {
                # @{Remove=...} entfernt nur diesen Delegaten, übrige Einträge bleiben erhalten
                Set-Mailbox -Identity $Mailbox -GrantSendOnBehalfTo @{Remove = $User} -ErrorAction Stop
            }
            default {
                throw "Ungültiger PermissionType: $PermissionType"
            }
        }
        
        Write-Log "Shared Mailbox Berechtigung erfolgreich entfernt" -Type "Success"
        Log-Action "Shared Mailbox Berechtigung $PermissionType für $User auf $Mailbox entfernt"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Entfernen der Shared Mailbox Berechtigung: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Entfernen der Shared Mailbox Berechtigung: $errorMsg"
        return $false
    }
}

function Get-SharedMailboxPermissionsAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Mailbox
    )
    
    try {
        # Prüfe ob Mailbox existiert
        try {
            $null = Get-Mailbox -Identity $Mailbox -ErrorAction Stop
        }
        catch {
            throw "Die angegebene Mailbox $Mailbox wurde nicht gefunden"
        }

        Write-Log "Rufe Berechtigungen für Shared Mailbox ab: $Mailbox" -Type "Info"
        Update-StatusBar -Message "Rufe Berechtigungen für $Mailbox ab..." -Type Info
        
        $permissions = @()
        
        # FullAccess-Berechtigungen abrufen
        try {
            $fullAccessPerms = Get-MailboxPermission -Identity $Mailbox -ErrorAction Stop | Where-Object {
                $_.User -notlike "NT AUTHORITY\SELF" -and 
                $_.AccessRights -like "*FullAccess*" -and 
                $_.IsInherited -eq $false
            }
            
            foreach ($perm in $fullAccessPerms) {
                if ($null -ne $perm.User) {
                    $permissions += [PSCustomObject]@{
                        User = $perm.User.ToString()
                        AccessRights = "FullAccess"
                        PermissionType = "FullAccess"
                    }
                }
            }
        }
        catch {
            Write-Log "Fehler beim Abrufen der FullAccess-Berechtigungen: $($_.Exception.Message)" -Type "Warning"
        }
        
        # SendAs-Berechtigungen abrufen
        try {
            $sendAsPerms = Get-RecipientPermission -Identity $Mailbox -ErrorAction Stop | Where-Object {
                $_.Trustee -notlike "NT AUTHORITY\SELF" -and 
                $_.IsInherited -eq $false
            }
            
            foreach ($perm in $sendAsPerms) {
                if ($null -ne $perm.Trustee) {
                    $permissions += [PSCustomObject]@{
                        User = $perm.Trustee.ToString()
                        AccessRights = "SendAs"
                        PermissionType = "SendAs"
                    }
                }
            }
        }
        catch {
            Write-Log "Fehler beim Abrufen der SendAs-Berechtigungen: $($_.Exception.Message)" -Type "Warning"
        }
        
        # SendOnBehalf-Berechtigungen abrufen
        try {
            $mailboxObj = Get-Mailbox -Identity $Mailbox -ErrorAction Stop
            $sendOnBehalfPerms = $mailboxObj.GrantSendOnBehalfTo
            
            foreach ($perm in $sendOnBehalfPerms) {
                if ($null -ne $perm) {
                    $permissions += [PSCustomObject]@{
                        User = $perm.ToString()
                        AccessRights = "SendOnBehalf"
                        PermissionType = "SendOnBehalf"
                    }
                }
            }
        }
        catch {
            Write-Log "Fehler beim Abrufen der SendOnBehalf-Berechtigungen: $($_.Exception.Message)" -Type "Warning"
        }

        # GUI-Aktualisierung
        if ($null -ne $script:lstCurrentPermissions) {
            if ($permissions.Count -gt 0) {
                # DataGrid mit Berechtigungen füllen
                $permissionsCollection = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
                foreach ($perm in $permissions) {
                    $permissionsCollection.Add($perm)
                }
                $script:lstCurrentPermissions.ItemsSource = $permissionsCollection
                
                Write-Log "Shared Mailbox Berechtigungen erfolgreich abgerufen: $($permissions.Count) Einträge" -Type "Success"
                Update-StatusBar -Message "Berechtigungen erfolgreich abgerufen: $($permissions.Count) Einträge" -Type Success
                Log-Action "Shared Mailbox Berechtigungen für $Mailbox abgerufen: $($permissions.Count) Einträge"
            }
            else {
                # Leere DataGrid mit Hinweistext
                $noPermissionsCollection = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
                $noPermissionsCollection.Add([PSCustomObject]@{
                    User = "Keine Berechtigungen"
                    AccessRights = "---" 
                    PermissionType = "---"
                })
                $script:lstCurrentPermissions.ItemsSource = $noPermissionsCollection
                
                Write-Log "Keine Berechtigungen für Shared Mailbox $Mailbox gefunden" -Type "Info"
                Update-StatusBar -Message "Keine Berechtigungen hinterlegt" -Type Info
            }
        }
        
        return $permissions
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Abrufen der Shared Mailbox Berechtigungen: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Fehler beim Abrufen der Berechtigungen: $errorMsg" -Type Error
        Log-Action "Fehler beim Abrufen der Shared Mailbox Berechtigungen: $errorMsg"
        
        # Fehler in GUI anzeigen
        if ($null -ne $script:lstCurrentPermissions) {
            $errorCollection = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
            $errorCollection.Add([PSCustomObject]@{
                User = "Fehler beim Abrufen der Berechtigungen"
                AccessRights = "---"
                PermissionType = "---"  
            })
            $script:lstCurrentPermissions.ItemsSource = $errorCollection
        }
        
        return @()
    }
}

function Get-ForwardingMailboxesAction {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Rufe alle Postfächer mit Weiterleitung ab" -Type "Info"
        Update-StatusBar -Message "Rufe Postfächer mit Weiterleitung ab..." -Type Info

        # Nur Postfächer mit Weiterleitung abrufen (serverseitiger Filter statt Abruf aller Postfächer)
        $mailboxes = @(Get-Mailbox -ResultSize Unlimited -Filter "ForwardingSmtpAddress -ne `$null -or ForwardingAddress -ne `$null" -ErrorAction Stop |
            Step-UIProgress -Activity "Lade Postfächer mit Weiterleitung" |
            Select-Object DisplayName, PrimarySmtpAddress, ForwardingAddress, ForwardingSmtpAddress, DeliverToMailboxAndForward)

        if ($mailboxes.Count -gt 0) {
            Write-Log "$($mailboxes.Count) Postfächer mit Weiterleitung gefunden" -Type "Info"
            Update-StatusBar -Message "$($mailboxes.Count) Postfächer mit Weiterleitung gefunden" -Type Info
        } else {
            Write-Log "Keine Postfächer mit Weiterleitung gefunden" -Type "Info"
            Update-StatusBar -Message "Keine Postfächer mit Weiterleitung gefunden" -Type Info
        }

        return $mailboxes
    }
    catch {
        if ($script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException]) {
            Write-Log "Abruf der Postfächer mit Weiterleitung durch Benutzer abgebrochen" -Type "Info"
        }
        else {
            $errorMsg = $_.Exception.Message
            Write-Log "Fehler beim Abrufen der Postfächer mit Weiterleitung: $errorMsg" -Type "Error"
            Update-StatusBar -Message "Fehler beim Abrufen der Postfächer mit Weiterleitung: $errorMsg" -Type Error
        }
        # Fehler (inkl. Abbruch) an den Aufrufer weitergeben, damit nicht "keine Weiterleitungen" gemeldet wird
        throw
    }
}

function Update-SharedMailboxAutoMappingAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Mailbox,
        
        [Parameter(Mandatory = $true)]
        [bool]$AutoMapping
    )
    
    try {
        Write-Log  "Aktualisiere AutoMapping für Shared Mailbox $Mailbox auf $AutoMapping" -Type "Info"
        
        # Bestehende FullAccess-Berechtigungen abrufen und neu setzen mit AutoMapping-Parameter
        $fullAccessPerms = @(Get-MailboxPermission -Identity $Mailbox -ErrorAction Stop | Where-Object {
            $_.User -notlike "NT AUTHORITY\SELF" -and 
            $_.AccessRights -like "*FullAccess*" -and 
            $_.IsInherited -eq $false
        })
        
        $failedUsers = New-Object 'System.Collections.Generic.List[string]'
        $index = 0
        Start-UIBusy -Message "Aktualisiere AutoMapping..." -Title "AutoMapping"
        try {
            foreach ($perm in $fullAccessPerms) {
                $index++
                $user = $perm.User.ToString()
                Update-UIBusy -Message "Aktualisiere AutoMapping" -Current $index -Total $fullAccessPerms.Count

                try {
                    Remove-MailboxPermission -Identity $Mailbox -User $user -AccessRights FullAccess -Confirm:$false -ErrorAction Stop
                }
                catch {
                    Write-Log  "AutoMapping für $user auf $Mailbox nicht geändert (Entfernen fehlgeschlagen): $($_.Exception.Message)" -Type "Error"
                    $failedUsers.Add($user)
                    continue
                }

                try {
                    Add-MailboxPermission -Identity $Mailbox -User $user -AccessRights FullAccess -AutoMapping $AutoMapping -ErrorAction Stop
                    Write-Log  "AutoMapping für $user auf $Mailbox aktualisiert" -Type "Info"
                }
                catch {
                    $addError = $_.Exception.Message
                    $failedUsers.Add($user)
                    Write-Log  "Erneutes Hinzufügen der FullAccess-Berechtigung für $user auf $Mailbox fehlgeschlagen: $addError - versuche Wiederherstellung" -Type "Error"
                    try {
                        # Wiederherstellung ohne AutoMapping-Angabe (Exchange-Standard), damit der Zugriff erhalten bleibt
                        Add-MailboxPermission -Identity $Mailbox -User $user -AccessRights FullAccess -ErrorAction Stop
                        Write-Log  "FullAccess-Berechtigung für $user auf $Mailbox wiederhergestellt" -Type "Warning"
                        Log-Action "FullAccess-Berechtigung für $user auf $Mailbox nach Fehler beim AutoMapping-Update wiederhergestellt"
                    }
                    catch {
                        Write-Log  "Wiederherstellung der FullAccess-Berechtigung für $user auf $Mailbox fehlgeschlagen: $($_.Exception.Message)" -Type "Error"
                        Log-Action "ACHTUNG: FullAccess-Berechtigung für $user auf $Mailbox wurde entfernt und konnte nicht wiederhergestellt werden: $($_.Exception.Message)"
                    }
                }
            }
        }
        finally {
            Stop-UIBusy
        }
        
        if ($failedUsers.Count -gt 0) {
            throw "AutoMapping konnte für $($failedUsers.Count) von $($fullAccessPerms.Count) Benutzer(n) nicht aktualisiert werden: $($failedUsers -join ', ')"
        }
        
        Write-Log  "AutoMapping für Shared Mailbox erfolgreich aktualisiert" -Type "Success"
        Log-Action "AutoMapping für Shared Mailbox $Mailbox auf $AutoMapping gesetzt"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Aktualisieren des AutoMapping: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Aktualisieren des AutoMapping: $errorMsg"
        return $false
    }
}

function Set-SharedMailboxForwardingAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Mailbox,
        
        [Parameter(Mandatory = $true)]
        [string]$ForwardingAddress,

        [Parameter(Mandatory = $false)]
        [bool]$DeliverToMailboxAndForward = $true
    )
    
    try {
        Write-Log  "Setze Weiterleitung für Shared Mailbox $Mailbox auf $ForwardingAddress (Kopie behalten: $DeliverToMailboxAndForward)" -Type "Info"
        
        if ([string]::IsNullOrEmpty($ForwardingAddress)) {
            # Weiterleitung entfernen
            Set-Mailbox -Identity $Mailbox -ForwardingAddress $null -ForwardingSmtpAddress $null -ErrorAction Stop
            Write-Log  "Weiterleitung für Shared Mailbox erfolgreich entfernt" -Type "Success"
        } else {
            # Weiterleitung setzen
            Set-Mailbox -Identity $Mailbox -ForwardingSmtpAddress $ForwardingAddress -DeliverToMailboxAndForward $DeliverToMailboxAndForward -ErrorAction Stop
            Write-Log  "Weiterleitung für Shared Mailbox erfolgreich gesetzt" -Type "Success"
        }
        
        Log-Action "Weiterleitung für Shared Mailbox $Mailbox auf $ForwardingAddress gesetzt (Kopie behalten: $DeliverToMailboxAndForward)"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Setzen der Weiterleitung: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Setzen der Weiterleitung: $errorMsg"
        return $false
    }
}

function Remove-SharedMailboxForwardingAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Mailbox
    )

    try {
        Write-Log  "Entferne Weiterleitung für Shared Mailbox $Mailbox" -Type "Info"
        Set-Mailbox -Identity $Mailbox -ForwardingAddress $null -ForwardingSmtpAddress $null -DeliverToMailboxAndForward $false -ErrorAction Stop
        Write-Log  "Weiterleitung für Shared Mailbox erfolgreich entfernt" -Type "Success"
        Log-Action "Weiterleitung für Shared Mailbox $Mailbox entfernt"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Entfernen der Weiterleitung: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Entfernen der Weiterleitung: $errorMsg"
        return $false
    }
}

function Set-SharedMailboxGALVisibilityAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Mailbox,
        
        [Parameter(Mandatory = $true)]
        [bool]$HideFromGAL
    )
    
    try {
        Write-Log  "Setze GAL-Sichtbarkeit für Shared Mailbox $Mailbox auf HideFromGAL=$HideFromGAL" -Type "Info"
        
        Set-Mailbox -Identity $Mailbox -HiddenFromAddressListsEnabled $HideFromGAL -ErrorAction Stop
        
        $visibilityStatus = if ($HideFromGAL) { "ausgeblendet" } else { "sichtbar" }
        Write-Log  "GAL-Sichtbarkeit für Shared Mailbox erfolgreich gesetzt - $visibilityStatus" -Type "Success"
        Log-Action "Shared Mailbox $Mailbox wurde in GAL $visibilityStatus gesetzt"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Setzen der GAL-Sichtbarkeit: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Setzen der GAL-Sichtbarkeit: $errorMsg"
        return $false
    }
}

function Remove-SharedMailboxAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Mailbox
    )
    
    try {
        Write-Log  "Lösche Shared Mailbox: $Mailbox" -Type "Info"
        
        Remove-Mailbox -Identity $Mailbox -Confirm:$false -ErrorAction Stop
        
        Write-Log  "Shared Mailbox erfolgreich gelöscht" -Type "Success"
        Log-Action "Shared Mailbox $Mailbox wurde gelöscht"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Löschen der Shared Mailbox: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Löschen der Shared Mailbox: $errorMsg"
        return $false
    }
}

function Initialize-SharedMailboxTab {
    [CmdletBinding()]
    param()
    
    try {
        
        # UI-Elemente referenzieren
        $txtSharedMailboxName = Get-XamlElement -ElementName "txtSharedMailboxName"
        $txtSharedMailboxEmail = Get-XamlElement -ElementName "txtSharedMailboxEmail"
        $cmbSharedMailboxDomain = Get-XamlElement -ElementName "cmbSharedMailboxDomain"
        $btnCreateSharedMailbox = Get-XamlElement -ElementName "btnCreateSharedMailbox"
        $btnConvertToShared = Get-XamlElement -ElementName "btnConvertToShared"
        
        # Quell-Postfach für Berechtigungen wird aus cmbSharedMailboxSelect übernommen (kein separates Eingabefeld im XAML)
        $txtSharedMailboxPermSource = $null
        $txtSharedMailboxPermUser = Get-XamlElement -ElementName "txtSharedMailboxPermUser"
        $cmbSharedMailboxPermType = Get-XamlElement -ElementName "cmbSharedMailboxPermType"
        $btnAddSharedMailboxPermission = Get-XamlElement -ElementName "btnAddSharedMailboxPermission"
        $btnRemoveSharedMailboxPermission = Get-XamlElement -ElementName "btnRemoveSharedMailboxPermission"
        
        $cmbSharedMailboxSelect = Get-XamlElement -ElementName "cmbSharedMailboxSelect"
        $btnShowSharedMailboxes = Get-XamlElement -ElementName "btnShowSharedMailboxes"
        $btnShowSharedMailboxPerms = Get-XamlElement -ElementName "btnShowSharedMailboxPerms"
        $chkAutoMapping = Get-XamlElement -ElementName "chkAutoMapping"
        $btnUpdateAutoMapping = Get-XamlElement -ElementName "btnUpdateAutoMapping"
        $txtForwardingAddress = Get-XamlElement -ElementName "txtForwardingAddress"
        $chkKeepCopy = Get-XamlElement -ElementName "chkKeepCopy"
        $btnSetForwarding = Get-XamlElement -ElementName "btnSetForwarding"
        $btnRemoveForwarding = Get-XamlElement -ElementName "btnRemoveForwarding"
        $btnGetForwardingMailboxes = Get-XamlElement -ElementName "btnGetForwardingMailboxes"
        $btnHideFromGAL = Get-XamlElement -ElementName "btnHideFromGAL"
        $btnShowInGAL = Get-XamlElement -ElementName "btnShowInGAL"
        $btnRemoveSharedMailbox = Get-XamlElement -ElementName "btnRemoveSharedMailbox"
        $helpLinkShared = Get-XamlElement -ElementName "helpLinkShared"
        $lstCurrentPermissions = Get-XamlElement -ElementName "lstCurrentPermissions"
        $btnExportSharedPermissions = Get-XamlElement -ElementName "btnExportSharedPermissions"
        
        # Globale Variablen setzen
        $script:txtSharedMailboxName = $txtSharedMailboxName
        $script:txtSharedMailboxEmail = $txtSharedMailboxEmail
        $script:cmbSharedMailboxDomain = $cmbSharedMailboxDomain
        $script:txtSharedMailboxPermSource = $txtSharedMailboxPermSource
        $script:txtSharedMailboxPermUser = $txtSharedMailboxPermUser
        $script:cmbSharedMailboxPermType = $cmbSharedMailboxPermType
        $script:cmbSharedMailboxSelect = $cmbSharedMailboxSelect
        $script:chkAutoMapping = $chkAutoMapping
        $script:chkKeepCopy = $chkKeepCopy
        $script:txtForwardingAddress = $txtForwardingAddress
        $script:lstCurrentPermissions = $lstCurrentPermissions
        
        # Hilfsfunktion zum Aktualisieren der Shared Mailbox-Liste
        # Hinweis: RefreshSharedMailboxList ist global definiert (doppelte lokale Definition entfernt)

        # Berechtigungstypen für die ComboBox initialisieren
        if ($null -ne $cmbSharedMailboxPermType) {
            $permissionTypes = @("FullAccess", "SendAs", "SendOnBehalf")
            $cmbSharedMailboxPermType.Items.Clear()
            foreach ($perm in $permissionTypes) {
                $item = New-Object System.Windows.Controls.ComboBoxItem
                $item.Content = $perm
                [void]$cmbSharedMailboxPermType.Items.Add($item)
            }
            if ($cmbSharedMailboxPermType.Items.Count -gt 0) {
                $cmbSharedMailboxPermType.SelectedIndex = 0
            }
        }
        
        # Domains für ComboBox laden
        if ($null -ne $cmbSharedMailboxDomain) {
            try {
                # Sichere Ausführung der Domain-Abfrage
                if ($script:isConnected) {
                    $domains = Get-AcceptedDomain | Select-Object -ExpandProperty DomainName
                    $cmbSharedMailboxDomain.Items.Clear()
                    foreach ($domain in $domains) {
                        [void]$cmbSharedMailboxDomain.Items.Add($domain)
                    }
                    if ($cmbSharedMailboxDomain.Items.Count -gt 0) {
                        $cmbSharedMailboxDomain.SelectedIndex = 0
                    }
                }
    }
    catch {
                Write-Log  "Fehler beim Laden der Domains: $($_.Exception.Message)" -Type "Warning"
            }
        }
        
        # Event-Handler registrieren
        Register-EventHandler -Control $btnCreateSharedMailbox -Handler {
            try {
                # Verbindungsprüfung
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Keine Verbindung", 
                        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
        
                # Eingabeprüfung
                if ([string]::IsNullOrWhiteSpace($script:txtSharedMailboxName.Text)) {
                    [System.Windows.MessageBox]::Show("Bitte geben Sie einen Namen für die Shared Mailbox an.", 
                        "Unvollständige Angaben", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
        
                # E-Mail-Adresse zusammensetzen, falls nicht angegeben
                $mailboxEmail = $script:txtSharedMailboxEmail.Text
                if ([string]::IsNullOrWhiteSpace($mailboxEmail) -and $null -ne $script:cmbSharedMailboxDomain.SelectedItem) {
                    # Einfache Normalisierung des Namens für die E-Mail-Adresse
                    $mailboxName = $script:txtSharedMailboxName.Text.ToLower() -replace '[^\w\d]', '.'
                    $domain = $script:cmbSharedMailboxDomain.SelectedItem.ToString()
                    $mailboxEmail = "$mailboxName@$domain"
                }
                
                # Funktion zur Erstellung der Shared Mailbox aufrufen
                $result = New-SharedMailboxAction -Name $script:txtSharedMailboxName.Text -EmailAddress $mailboxEmail
                
                if ($result) {
                    $script:txtStatus.Text = "Shared Mailbox wurde erfolgreich erstellt."
                    
                    # Felder zurücksetzen
                    $script:txtSharedMailboxName.Text = ""
                    $script:txtSharedMailboxEmail.Text = ""
                    
                    # Shared Mailbox Liste aktualisieren, falls geöffnet
                    if ($null -ne $script:cmbSharedMailboxSelect -and $script:cmbSharedMailboxSelect.Items.Count -gt 0) {
                        RefreshSharedMailboxList
                    }
                }
    }
    catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnCreateSharedMailbox"
        
        Register-EventHandler -Control $btnConvertToShared -Handler {
            try {
                # Verbindungsprüfung
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Keine Verbindung", 
                        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Eingabeprüfung
                if ([string]::IsNullOrWhiteSpace($script:txtSharedMailboxEmail.Text)) {
                    [System.Windows.MessageBox]::Show("Bitte geben Sie die E-Mail-Adresse des zu konvertierenden Postfachs an.", 
                        "Unvollständige Angaben", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Sicherheitsabfrage
                $result = [System.Windows.MessageBox]::Show(
                    "Sind Sie sicher, dass Sie das Postfach '$($script:txtSharedMailboxEmail.Text)' in eine Shared Mailbox umwandeln möchten? " +
                    "Der Benutzer kann sich danach nicht mehr direkt an diesem Postfach anmelden.",
                    "Postfach konvertieren",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Warning)
                
                if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                    # Funktion zum Konvertieren des Postfachs aufrufen
                    $result = Convert-ToSharedMailboxAction -Identity $script:txtSharedMailboxEmail.Text
                    
                    if ($result) {
                        $script:txtStatus.Text = "Postfach wurde erfolgreich in eine Shared Mailbox umgewandelt."
                        
                        # Shared Mailbox Liste aktualisieren, falls geöffnet
                        if ($null -ne $script:cmbSharedMailboxSelect -and $script:cmbSharedMailboxSelect.Items.Count -gt 0) {
                            RefreshSharedMailboxList
                        }
                    }
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnConvertToShared"
        
        Register-EventHandler -Control $btnAddSharedMailboxPermission -Handler {
            try {
                # Verbindungsprüfung
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Keine Verbindung", 
                        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
        
                # Eingabeprüfung
                if ([string]::IsNullOrWhiteSpace("$($script:cmbSharedMailboxSelect.SelectedItem)")) {
                    [System.Windows.MessageBox]::Show("Bitte wählen Sie oben eine Shared Mailbox aus.", 
                        "Fehlende Shared Mailbox", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }

                if ([string]::IsNullOrWhiteSpace($script:txtSharedMailboxPermUser.Text)) {
                    [System.Windows.MessageBox]::Show("Bitte geben Sie einen Benutzer an.", 
                        "Fehlender Benutzer", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }

                if ($null -eq $script:cmbSharedMailboxPermType.SelectedItem) {
                    [System.Windows.MessageBox]::Show("Bitte wählen Sie einen Berechtigungstyp aus.", 
                        "Fehlender Berechtigungstyp", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
        
                # Parameter sammeln und validieren
                $mailbox = "$($script:cmbSharedMailboxSelect.SelectedItem)".Trim()
                $user = $script:txtSharedMailboxPermUser.Text.Trim()
                $permType = $script:cmbSharedMailboxPermType.SelectedItem.Content.ToString()
                $autoMapping = $script:chkAutoMapping.IsChecked

                if ([string]::IsNullOrEmpty($mailbox) -or [string]::IsNullOrEmpty($user)) {
                    [System.Windows.MessageBox]::Show("Die Shared Mailbox und der Benutzer dürfen nicht leer sein.", 
                        "Ungültige Eingabe", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Funktion zum Hinzufügen der Berechtigung aufrufen
                $result = Add-SharedMailboxPermissionAction -Mailbox $mailbox -User $user -PermissionType $permType -AutoMapping $autoMapping
                
                if ($result) {
                    $script:txtStatus.Text = "Berechtigung wurde erfolgreich hinzugefügt."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Hinzufügen der Berechtigung: $errorMsg" -Type Error
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnAddSharedMailboxPermission"
        
        Register-EventHandler -Control $btnRemoveSharedMailboxPermission -Handler {
            try {
                # Verbindungsprüfung
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Keine Verbindung", 
                        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Eingabeprüfung
                if ([string]::IsNullOrWhiteSpace("$($script:cmbSharedMailboxSelect.SelectedItem)") -or 
                    [string]::IsNullOrWhiteSpace($script:txtSharedMailboxPermUser.Text) -or 
                    $null -eq $script:cmbSharedMailboxPermType.SelectedItem) {
                    [System.Windows.MessageBox]::Show("Bitte geben Sie Shared Mailbox, Benutzer und Berechtigungstyp an.", 
                        "Unvollständige Angaben", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Parameter sammeln
                $mailbox = "$($script:cmbSharedMailboxSelect.SelectedItem)"
                $user = $script:txtSharedMailboxPermUser.Text
                $permType = $script:cmbSharedMailboxPermType.SelectedItem.Content.ToString()
                
                # Funktion zum Entfernen der Berechtigung aufrufen
                $result = Remove-SharedMailboxPermissionAction -Mailbox $mailbox -User $user -PermissionType $permType
                
                if ($result) {
                    $script:txtStatus.Text = "Berechtigung wurde erfolgreich entfernt."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnRemoveSharedMailboxPermission"
        
        Register-EventHandler -Control $btnShowSharedMailboxes -Handler {
            try {
                # Verbindungsprüfung
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Keine Verbindung", 
                        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Funktion zum Anzeigen der Shared Mailboxes aufrufen
                RefreshSharedMailboxList
                
                if ($script:cmbSharedMailboxSelect.Items.Count -gt 0) {
                    $script:txtStatus.Text = "$($script:cmbSharedMailboxSelect.Items.Count) Shared Mailboxes gefunden."
                } else {
                    $script:txtStatus.Text = "Keine Shared Mailboxes gefunden."
        }
    }
    catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        }
        
        Register-EventHandler -Control $btnShowSharedMailboxPerms -Handler {
            try {
                # Verbindungsprüfung
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Keine Verbindung", 
                        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
        
                # Eingabeprüfung
                if ($null -eq $script:cmbSharedMailboxSelect.SelectedItem) {
                    [System.Windows.MessageBox]::Show("Bitte wählen Sie eine Shared Mailbox aus.", 
                        "Keine Auswahl", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
        
                # Parameter sammeln
                $mailbox = $script:cmbSharedMailboxSelect.SelectedItem.ToString()
                
                # Übernehme die ausgewählte Mailbox ins Eingabefeld für besseren Workflow
                if ($null -ne $script:txtSharedMailboxPermSource) {
                    $script:txtSharedMailboxPermSource.Text = $mailbox
                }
                
                # Funktion zum Anzeigen der Berechtigungen aufrufen
                $permissions = @(Get-SharedMailboxPermissionsAction -Mailbox $mailbox)
                
                # Berechtigungen in der Benutzeroberfläche anzeigen
                if ($permissions.Count -gt 0) {
                    # DataGrid für die Anzeige der Berechtigungen verwenden
                    if ($null -ne $script:lstCurrentPermissions) {
                        # DataGrid leeren und mit den Berechtigungsdaten füllen
                        $permissionsCollection = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
                        
                        foreach ($perm in $permissions) {
                            $permObject = [PSCustomObject]@{
                                Mailbox = $mailbox
                                User = $perm.User
                                PermissionType = $perm.PermissionType
                                AccessRights = $perm.AccessRights
                                AutoMapping = "N/A"
                                AddedDate = (Get-Date).ToString("yyyy-MM-dd")
                            }
                            $permissionsCollection.Add($permObject)
                        }
                        
                        $script:lstCurrentPermissions.ItemsSource = $permissionsCollection
                        
                        $script:txtStatus.Text = "$($permissions.Count) Berechtigungen gefunden für $mailbox."
                    } else {
                        
                        # Fallback: MessageBox anzeigen
                        $permText = "Berechtigungen für Shared Mailbox '$mailbox':`n`n"
                        foreach ($perm in $permissions) {
                            $permText += "- $($perm.User): $($perm.AccessRights) ($($perm.PermissionType))`n"
                        }
                        
                    [System.Windows.MessageBox]::Show(
                            $permText,
                            "Shared Mailbox Berechtigungen",
                        [System.Windows.MessageBoxButton]::OK,
                            [System.Windows.MessageBoxImage]::Information)
                        
                        $script:txtStatus.Text = "$($permissions.Count) Berechtigungen gefunden für $mailbox."
                    }
                } else {
                    # Berechtigungsliste leeren
                    if ($null -ne $script:lstCurrentPermissions) {
                        $script:lstCurrentPermissions.ItemsSource = $null
                    }
                    
                    $script:txtStatus.Text = "Keine Berechtigungen gefunden für $mailbox."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnShowSharedMailboxPerms"
        
        Register-EventHandler -Control $btnGetForwardingMailboxes -Handler {
            try {
                # Verbindungsprüfung
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Keine Verbindung", 
                        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Funktion zum Anzeigen aller Weiterleitungen aufrufen
                Start-UIBusy -Message "Rufe Postfächer mit Weiterleitung ab..." -Title "Weiterleitungen" -Cancelable
                try {
                    $forwardingMailboxes = @(Get-ForwardingMailboxesAction)
                }
                finally {
                    Stop-UIBusy
                }
                
                if ($forwardingMailboxes.Count -gt 0) {
                    # Anzeige der Weiterleitungen in einem neuen Fenster oder Dialog
                    $forwardingText = "Aktive Weiterleitungen:`n`n"
                    foreach ($fwd in $forwardingMailboxes) {
                        # ForwardingSmtpAddress (z. B. "smtp:user@extern.de") hat Vorrang vor ForwardingAddress (Empfängerobjekt)
                        $forwardingTarget = if (-not [string]::IsNullOrWhiteSpace("$($fwd.ForwardingSmtpAddress)")) {
                            "$($fwd.ForwardingSmtpAddress)" -replace '^smtp:', ''
                        } else {
                            "$($fwd.ForwardingAddress)"
                        }
                        $keepCopyText = if ($fwd.DeliverToMailboxAndForward) { "Ja" } else { "Nein" }
                        $forwardingText += "- $($fwd.DisplayName) <$($fwd.PrimarySmtpAddress)> → $forwardingTarget (Kopie behalten: $keepCopyText)`n"
                    }
                    
                    [System.Windows.MessageBox]::Show(
                        $forwardingText,
                        "Mailbox-Weiterleitungen",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Information)
                    
                    $script:txtStatus.Text = "$($forwardingMailboxes.Count) Weiterleitungen gefunden."
                } else {
                    [System.Windows.MessageBox]::Show(
                        "Es wurden keine aktiven Weiterleitungen gefunden.",
                        "Mailbox-Weiterleitungen",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Information)
                    
                    $script:txtStatus.Text = "Keine Weiterleitungen gefunden."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                if ($script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException]) {
                    $script:txtStatus.Text = "Abruf der Weiterleitungen abgebrochen."
                }
                else {
                    $script:txtStatus.Text = "Fehler: $errorMsg"
                }
            }
        } -ControlName "btnGetForwardingMailboxes"

        Register-EventHandler -Control $btnUpdateAutoMapping -Handler {
            try {
                # Verbindungsprüfung
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Keine Verbindung", 
                        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Eingabeprüfung
                if ($null -eq $script:cmbSharedMailboxSelect.SelectedItem) {
                    [System.Windows.MessageBox]::Show("Bitte wählen Sie eine Shared Mailbox aus.", 
                        "Keine Auswahl", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Parameter sammeln
                $mailbox = $script:cmbSharedMailboxSelect.SelectedItem.ToString()
                $autoMapping = [bool]$script:chkAutoMapping.IsChecked
                
                # Sicherheitsabfrage: Für das Ändern des AutoMappings werden alle FullAccess-Berechtigungen entfernt und neu gesetzt
                $autoMappingText = if ($autoMapping) { "aktiviert" } else { "deaktiviert" }
                $confirmResult = Show-MessageBox -Message "Zum Ändern des AutoMappings werden alle FullAccess-Berechtigungen der Shared Mailbox '$mailbox' entfernt und mit AutoMapping $autoMappingText neu gesetzt. Möchten Sie fortfahren?" -Title "AutoMapping aktualisieren" -Type "Question"
                if ($confirmResult -ne "Yes") {
                    $script:txtStatus.Text = "Aktualisierung des AutoMappings abgebrochen."
                    return
                }
                
                # Funktion zum Aktualisieren des Auto-Mappings aufrufen
                $result = Update-SharedMailboxAutoMappingAction -Mailbox $mailbox -AutoMapping $autoMapping
                
                if ($result) {
                    $script:txtStatus.Text = "Auto-Mapping wurde erfolgreich aktualisiert."
                }
                else {
                    $script:txtStatus.Text = "Auto-Mapping konnte nicht (vollständig) aktualisiert werden. Details siehe Protokoll."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnUpdateAutoMapping"
        
        Register-EventHandler -Control $btnSetForwarding -Handler {
            try {
                # Verbindungsprüfung
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Keine Verbindung", 
                        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Eingabeprüfung
                if ($null -eq $script:cmbSharedMailboxSelect.SelectedItem -or 
                    [string]::IsNullOrWhiteSpace($script:txtForwardingAddress.Text)) {
                    [System.Windows.MessageBox]::Show("Bitte wählen Sie eine Shared Mailbox aus und geben Sie eine Weiterleitungsadresse an.", 
                        "Unvollständige Angaben", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Parameter sammeln
                $mailbox = $script:cmbSharedMailboxSelect.SelectedItem.ToString()
                $forwardingAddress = $script:txtForwardingAddress.Text
                $keepCopy = [bool]$script:chkKeepCopy.IsChecked
                
                # Funktion zum Einrichten der Weiterleitung aufrufen
                $result = Set-SharedMailboxForwardingAction -Mailbox $mailbox -ForwardingAddress $forwardingAddress -DeliverToMailboxAndForward $keepCopy
                
                if ($result) {
                    $script:txtStatus.Text = "Weiterleitung wurde erfolgreich eingerichtet."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnSetForwarding"
        
        Register-EventHandler -Control $btnRemoveForwarding -Handler {
            try {
                # Verbindungsprüfung
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Keine Verbindung", 
                        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Eingabeprüfung
                if ($null -eq $script:cmbSharedMailboxSelect.SelectedItem) {
                    [System.Windows.MessageBox]::Show("Bitte wählen Sie eine Shared Mailbox aus.", 
                        "Keine Auswahl", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Parameter sammeln
                $mailbox = $script:cmbSharedMailboxSelect.SelectedItem.ToString()
                
                $confirmResult = Show-MessageBox -Message "Möchten Sie die Weiterleitung für '$mailbox' wirklich entfernen?" -Title "Entfernen bestätigen" -Type "Question"
                if ($confirmResult -ne "Yes") {
                    $script:txtStatus.Text = "Entfernen der Weiterleitung abgebrochen."
                    return
                }

                # Funktion zum Entfernen der Weiterleitung aufrufen
                $result = Remove-SharedMailboxForwardingAction -Mailbox $mailbox
                
                if ($result) {
                    $script:txtStatus.Text = "Weiterleitung wurde erfolgreich entfernt."
                    $script:txtForwardingAddress.Text = ""
                    $script:chkKeepCopy.IsChecked = $false
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnRemoveForwarding"
        
        Register-EventHandler -Control $btnHideFromGAL -Handler {
            try {
                # Verbindungsprüfung
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Keine Verbindung", 
                        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Eingabeprüfung
                if ($null -eq $script:cmbSharedMailboxSelect.SelectedItem) {
                    [System.Windows.MessageBox]::Show("Bitte wählen Sie eine Shared Mailbox aus.", 
                        "Keine Auswahl", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Parameter sammeln
                $mailbox = $script:cmbSharedMailboxSelect.SelectedItem.ToString()
                
                # Funktion zum Ausblenden aus der GAL aufrufen
                $result = Set-SharedMailboxGALVisibilityAction -Mailbox $mailbox -HideFromGAL $true
                
                if ($result) {
                    $script:txtStatus.Text = "Shared Mailbox wurde aus der GAL ausgeblendet."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnHideFromGAL"
        
        Register-EventHandler -Control $btnShowInGAL -Handler {
            try {
                # Verbindungsprüfung
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Keine Verbindung", 
                        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Eingabeprüfung
                if ($null -eq $script:cmbSharedMailboxSelect.SelectedItem) {
                    [System.Windows.MessageBox]::Show("Bitte wählen Sie eine Shared Mailbox aus.", 
                        "Keine Auswahl", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Parameter sammeln
                $mailbox = $script:cmbSharedMailboxSelect.SelectedItem.ToString()
                
                # Funktion zum Einblenden in GAL aufrufen
                $result = Set-SharedMailboxGALVisibilityAction -Mailbox $mailbox -HideFromGAL $false
                
                if ($result) {
                    $script:txtStatus.Text = "Shared Mailbox wurde in der GAL sichtbar gemacht."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnShowInGAL"
        
        # Event-Handler für den Export der Shared-Mailbox-Berechtigungen
        Register-EventHandler -Control $btnExportSharedPermissions -Handler {
            if ($null -ne $script:lstCurrentPermissions) {
                Export-DataGridContent -DataGrid $script:lstCurrentPermissions -DefaultFileName "SharedMailboxPermissions"
            }
        } -ControlName "btnExportSharedPermissions"

        # Event-Handler für Löschen einer Shared Mailbox
        Register-EventHandler -Control $btnRemoveSharedMailbox -Handler {
            try {
                # Verbindungsprüfung
                if (-not $script:isConnected) {
                    [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Keine Verbindung", 
                        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Eingabeprüfung
                if ($null -eq $script:cmbSharedMailboxSelect.SelectedItem) {
                    [System.Windows.MessageBox]::Show("Bitte wählen Sie eine Shared Mailbox aus.", 
                        "Keine Auswahl", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }
                
                # Sicherheitsabfrage
                $mailbox = $script:cmbSharedMailboxSelect.SelectedItem.ToString()
                $result = [System.Windows.MessageBox]::Show(
                    "Sind Sie sicher, dass Sie die Shared Mailbox '$mailbox' löschen möchten? Diese Aktion kann nicht rückgängig gemacht werden.",
                    "Shared Mailbox löschen",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Warning)
                
                if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                    # Funktion zum Löschen der Shared Mailbox aufrufen
                    $result = Remove-SharedMailboxAction -Mailbox $mailbox
                    
                    if ($result) {
                        $script:txtStatus.Text = "Shared Mailbox wurde erfolgreich gelöscht."
                        RefreshSharedMailboxList
                    }
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnRemoveSharedMailbox"
        
        # Hilfe-Link initialisieren
        if ($null -ne $helpLinkShared) {
            $helpLinkShared.Add_MouseLeftButtonDown({
                Show-HelpDialog -Topic "SharedMailbox"
            })
            
            $helpLinkShared.Add_MouseEnter({
                $this.TextDecorations = [System.Windows.TextDecorations]::Underline
                $this.Cursor = [System.Windows.Input.Cursors]::Hand
            })
            
            $helpLinkShared.Add_MouseLeave({
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
