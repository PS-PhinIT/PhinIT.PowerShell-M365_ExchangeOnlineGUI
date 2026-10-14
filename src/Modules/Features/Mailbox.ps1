# =====================================================================
# easyEXO - Modul: Postfachberechtigungen (FullAccess, SendAs, SendOnBehalf)
# Datei: src/Modules/Features/Mailbox.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# -------------------------------------------------
# Abschnitt: Postfachberechtigungen
# -------------------------------------------------
function Add-MailboxPermissionAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceUser,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetUser
    )
    
    try {
        # Eingabevalidierung
        if (-not (Validate-Email -Email $SourceUser)) {
            throw "Ungültige E-Mail-Adresse für Quellpostfach."
        }
        if (-not (Validate-Email -Email $TargetUser)) {
            throw "Ungültige E-Mail-Adresse für Zielbenutzer."
        }
        
        Write-Log  "Füge Postfachberechtigung hinzu: $SourceUser -> $TargetUser (FullAccess)" -Type "Info"
        
        # Prüfen, ob die Berechtigung bereits existiert
        $existingPermissions = Get-MailboxPermission -Identity $SourceUser -User $TargetUser -ErrorAction SilentlyContinue
        $fullAccessExists = $existingPermissions | Where-Object { $_.AccessRights -like "*FullAccess*" }
        
        if ($fullAccessExists) {
            Write-Log  "Berechtigung existiert bereits, keine Änderung notwendig" -Type "Warning"
            if ($null -ne $txtStatus) {
                Update-GuiText -TextElement $txtStatus -Message "Postfachberechtigung bereits vorhanden." -Color $script:connectedBrush
            }
            Log-Action "Postfachberechtigung bereits vorhanden: $SourceUser -> $TargetUser"
            return $true
        }
        
        # Berechtigung hinzufügen
        Add-MailboxPermission -Identity $SourceUser -User $TargetUser -AccessRights FullAccess -InheritanceType All -AutoMapping $true -ErrorAction Stop
        
        Write-Log  "Postfachberechtigung erfolgreich hinzugefügt" -Type "Success"
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "Postfachberechtigung hinzugefügt." -Color $script:connectedBrush
        }
        Log-Action "Postfachberechtigung hinzugefügt: $SourceUser -> $TargetUser (FullAccess)"
        return $true
    } 
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Hinzufügen der Postfachberechtigung: $errorMsg" -Type "Error"
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "Fehler: $errorMsg"
        }
        Log-Action "Fehler beim Hinzufügen der Postfachberechtigung: $errorMsg"
        return $false
    }
}

function Remove-MailboxPermissionAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceUser,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetUser
    )
    
    try {
        # Eingabevalidierung
        if (-not (Validate-Email -Email $SourceUser)) {
            throw "Ungültige E-Mail-Adresse für Quellpostfach."
        }
        if (-not (Validate-Email -Email $TargetUser)) {
            throw "Ungültige E-Mail-Adresse für Zielbenutzer."
        }
        
        Write-Log  "Entferne Postfachberechtigung: $SourceUser -> $TargetUser" -Type "Info"
        
        # Prüfen, ob die Berechtigung existiert
        $existingPermissions = Get-MailboxPermission -Identity $SourceUser -User $TargetUser -ErrorAction SilentlyContinue
        if (-not $existingPermissions) {
            Write-Log  "Keine Berechtigung zum Entfernen gefunden" -Type "Warning"
            if ($null -ne $txtStatus) {
                Update-GuiText -TextElement $txtStatus -Message "Keine Postfachberechtigung zum Entfernen gefunden."
            }
            Log-Action "Keine Postfachberechtigung zum Entfernen gefunden: $SourceUser -> $TargetUser"
            return $false
        }
        
        # Berechtigung entfernen
        Remove-MailboxPermission -Identity $SourceUser -User $TargetUser -AccessRights FullAccess -Confirm:$false -ErrorAction Stop
        
        Write-Log  "Postfachberechtigung erfolgreich entfernt" -Type "Success"
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "Postfachberechtigung entfernt."
        }
        Log-Action "Postfachberechtigung entfernt: $SourceUser -> $TargetUser"
        return $true
    } 
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Entfernen der Postfachberechtigung: $errorMsg" -Type "Error"
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "Fehler: $errorMsg"
        }
        Log-Action "Fehler beim Entfernen der Postfachberechtigung: $errorMsg"
        return $false
    }
}

function Get-MailboxPermissions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Mailbox
    )
    
    try {
        Write-Log  "Postfachberechtigungen abrufen: Validiere Benutzereingabe" -Type "Info"
        
        # E-Mail-Format überprüfen
        if (-not ($Mailbox -match "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")) {
            if (-not ($Mailbox -match "^[a-zA-Z0-9\s.-]+$")) {
                throw "Ungültige E-Mail-Adresse oder Benutzername: $Mailbox"
            }
        }
        
        Write-Log  "Postfachberechtigungen abrufen für: $Mailbox" -Type "Info"
        
        # Postfachberechtigungen abrufen
        Write-Log  "Rufe Postfachberechtigungen ab für: $Mailbox" -Type "Info"
        $permissions = Get-MailboxPermission -Identity $Mailbox | Where-Object { 
            $_.User -notlike "NT AUTHORITY\SELF" -and 
            $_.User -notlike "S-1-5*" -and 
            $_.User -notlike "NT AUTHORITY\SYSTEM" -and
            $_.IsInherited -eq $false 
        }
        
        # SendAs-Berechtigungen abrufen
        $sendAsPermissions = Get-RecipientPermission -Identity $Mailbox | Where-Object { 
            $_.Trustee -notlike "NT AUTHORITY\SELF" -and 
            $_.Trustee -notlike "S-1-5*" -and
            $_.Trustee -notlike "NT AUTHORITY\SYSTEM" 
        }
        
        # Ergebnissammlung vorbereiten
        $resultCollection = @()
        
        # Postfachberechtigungen verarbeiten
        foreach ($perm in $permissions) {
            $entry = [PSCustomObject]@{
                Identity = $Mailbox
                User = $perm.User.ToString()
                AccessType = "Postfach"
                AccessRights = $perm.AccessRights -join ", "
            }
            
            Write-Log  "Postfachberechtigung verarbeitet: $($perm.User) -> $($perm.AccessRights -join ', ')" -Type "Info"
            $resultCollection += $entry
        }
        
        # SendAs-Berechtigungen: bei vorhandenem Eintrag des Benutzers zusammenführen, sonst als eigenen Eintrag hinzufügen
        foreach ($sendPerm in $sendAsPermissions) {
            $trustee = $sendPerm.Trustee.ToString()
            $existingEntry = $resultCollection | Where-Object { $_.User -eq $trustee } | Select-Object -First 1
            
            if ($null -ne $existingEntry) {
                if ($existingEntry.AccessRights -notmatch '\bSendAs\b') {
                    $existingEntry.AccessRights = "$($existingEntry.AccessRights), SendAs"
                }
                $existingEntry.AccessType = "Postfach + SendAs"
                Write-Log  "SendAs-Berechtigung mit Postfachberechtigung zusammengeführt: $trustee" -Type "Info"
            }
            else {
                $entry = [PSCustomObject]@{
                    Identity = $Mailbox
                    User = $trustee
                    AccessType = "SendAs"
                    AccessRights = "SendAs"
                }
                $resultCollection += $entry
                Write-Log  "Separate SendAs-Berechtigung verarbeitet: $trustee" -Type "Info"
            }
        }
        
        # Wenn keine Berechtigungen gefunden wurden
        if ($resultCollection.Count -eq 0) {
            # Füge "NT AUTHORITY\SELF" hinzu, der normalerweise vorhanden ist
            $selfPerm = Get-MailboxPermission -Identity $Mailbox | Where-Object { $_.User -like "NT AUTHORITY\SELF" } | Select-Object -First 1
            
            if ($null -ne $selfPerm) {
                $entry = [PSCustomObject]@{
                    Identity = $Mailbox
                    User = "Keine benutzerdefinierten Berechtigungen"
                    AccessType = "Standard"
                    AccessRights = "Nur Standardberechtigungen"
                }
                $resultCollection += $entry
                Write-Log  "Keine benutzerdefinierten Berechtigungen gefunden, nur Standardzugriff" -Type "Info"
            }
            else {
                $entry = [PSCustomObject]@{
                    Identity = $Mailbox
                    User = "Keine Berechtigungen gefunden"
                    AccessType = "-"
                    AccessRights = "Unbekannt"
                }
                $resultCollection += $entry
                Write-Log  "Keine Berechtigungen gefunden" -Type "Warning"
            }
        }
        
        Write-Log  "Postfachberechtigungen abgerufen und verarbeitet: $($resultCollection.Count) Einträge gefunden" -Type "Success"
        
        # Wichtig: Rückgabe als Array für die GUI-Darstellung
        return ,$resultCollection
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Abrufen der Postfachberechtigungen: $errorMsg" -Type "Error"
        return @()
    }
}

# -------------------------------------------------
# Abschnitt: SendAs Berechtigungen
# -------------------------------------------------
function Add-SendAsPermissionAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceUser,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetUser
    )
    
    try {
        # Eingabevalidierung
        if (-not (Validate-Email -Email $SourceUser)) {
            throw "Ungültige E-Mail-Adresse für Quellpostfach."
        }
        if (-not (Validate-Email -Email $TargetUser)) {
            throw "Ungültige E-Mail-Adresse für Zielbenutzer."
        }
        
        Write-Log  "SendAs-Berechtigung hinzufügen: $SourceUser -> $TargetUser" -Type "Info"
        
        # Prüfen, ob die Berechtigung bereits existiert
        $existingPermissions = Get-RecipientPermission -Identity $SourceUser -Trustee $TargetUser -ErrorAction SilentlyContinue
        
        if ($existingPermissions) {
            Write-Log  "SendAs-Berechtigung existiert bereits, keine Änderung notwendig" -Type "Warning"
            if ($null -ne $txtStatus) {
                Update-GuiText -TextElement $txtStatus -Message "SendAs-Berechtigung bereits vorhanden." -Color $script:connectedBrush
            }
            Log-Action "SendAs-Berechtigung bereits vorhanden: $SourceUser -> $TargetUser"
            return $true
        }
        
        # Berechtigung hinzufügen
        Add-RecipientPermission -Identity $SourceUser -Trustee $TargetUser -AccessRights SendAs -Confirm:$false -ErrorAction Stop
        
        Write-Log  "SendAs-Berechtigung erfolgreich hinzugefügt" -Type "Success"
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "SendAs-Berechtigung hinzugefügt." -Color $script:connectedBrush
        }
        Log-Action "SendAs-Berechtigung hinzugefügt: $SourceUser -> $TargetUser"
        return $true
    } 
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Hinzufügen der SendAs-Berechtigung: $errorMsg" -Type "Error"
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "Fehler: $errorMsg"
        }
        Log-Action "Fehler beim Hinzufügen der SendAs-Berechtigung: $errorMsg"
            return $false
    }
}

function Remove-SendAsPermissionAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceUser,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetUser
    )
    
    try {
        # Eingabevalidierung
        if (-not (Validate-Email -Email $SourceUser)) {
            throw "Ungültige E-Mail-Adresse für Quellpostfach."
        }
        if (-not (Validate-Email -Email $TargetUser)) {
            throw "Ungültige E-Mail-Adresse für Zielbenutzer."
        }
        
        Write-Log  "Entferne SendAs-Berechtigung: $SourceUser -> $TargetUser" -Type "Info"
        
        # Prüfen, ob die Berechtigung existiert
        $existingPermissions = Get-RecipientPermission -Identity $SourceUser -Trustee $TargetUser -ErrorAction SilentlyContinue
        if (-not $existingPermissions) {
            Write-Log  "Keine SendAs-Berechtigung zum Entfernen gefunden" -Type "Warning"
            if ($null -ne $txtStatus) {
                Update-GuiText -TextElement $txtStatus -Message "Keine SendAs-Berechtigung zum Entfernen gefunden."
            }
            Log-Action "Keine SendAs-Berechtigung zum Entfernen gefunden: $SourceUser -> $TargetUser"
            return $false
        }
        
        # Berechtigung entfernen
        Remove-RecipientPermission -Identity $SourceUser -Trustee $TargetUser -AccessRights SendAs -Confirm:$false -ErrorAction Stop
        
        Write-Log  "SendAs-Berechtigung erfolgreich entfernt" -Type "Success"
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "SendAs-Berechtigung entfernt." -Color $script:connectedBrush
        }
        Log-Action "SendAs-Berechtigung entfernt: $SourceUser -> $TargetUser"
        return $true
    } 
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Entfernen der SendAs-Berechtigung: $errorMsg" -Type "Error"
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "Fehler: $errorMsg"
        }
        Log-Action "Fehler beim Entfernen der SendAs-Berechtigung: $errorMsg"
        return $false
    }
}

function Get-SendAsPermissionAction {
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
        
        Write-Log  "Rufe SendAs-Berechtigungen ab für: $MailboxUser" -Type "Info"
        
        # Berechtigungen abrufen
        $permissions = Get-RecipientPermission -Identity $MailboxUser -ErrorAction Stop
        
        # Wichtig: Deserialisierungsproblem beheben, indem wir die Daten in ein neues Array umwandeln
        $processedPermissions = @()
        
        foreach ($permission in $permissions) {
            $permObj = [PSCustomObject]@{
                Identity = $permission.Identity
                User = $permission.Trustee.ToString()
                AccessType = "SendAs"
                AccessRights = "SendAs"
                IsInherited = $permission.IsInherited
                Deny = $false
            }
            $processedPermissions += $permObj
            Write-Log  "SendAs-Berechtigung verarbeitet: $($permission.Trustee)" -Type "Info"
        }
        
        Write-Log  "SendAs-Berechtigungen abgerufen und verarbeitet: $($processedPermissions.Count) Einträge gefunden" -Type "Success"
        Log-Action "SendAs-Berechtigungen für $MailboxUser abgerufen: $($processedPermissions.Count) Einträge gefunden"
        return $processedPermissions
    } 
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Abrufen der SendAs-Berechtigungen: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Abrufen der SendAs-Berechtigungen: $errorMsg"
        
        # Bei Fehler ein leeres Array zurückgeben, damit die GUI nicht abstürzt
        return @()
    }
}

# -------------------------------------------------
# Abschnitt: SendOnBehalf Berechtigungen
# -------------------------------------------------

# Prüft, ob ein Empfänger in GrantSendOnBehalfTo enthalten ist. Exchange liefert dort keine
# SMTP-Adressen, sondern Namen, kanonische Namen oder DNs - daher werden die Bezeichner des
# per Get-Recipient aufgelösten Empfängers verglichen.
function Test-SendOnBehalfDelegate {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        $Delegates,

        [Parameter(Mandatory = $true)]
        $Recipient
    )

    $candidates = @(
        $Recipient.Name,
        $Recipient.Alias,
        $Recipient.PrimarySmtpAddress,
        $Recipient.DistinguishedName,
        $Recipient.Identity,
        $Recipient.ExchangeObjectId,
        $Recipient.Guid
    ) | Where-Object { $null -ne $_ } | ForEach-Object { $_.ToString() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($delegate in @($Delegates)) {
        if ($null -eq $delegate) { continue }
        $delegateText = $delegate.ToString()
        foreach ($candidate in $candidates) {
            if ($delegateText -eq $candidate -or $delegateText.EndsWith("/$candidate", [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
    }
    return $false
}

function Add-SendOnBehalfPermissionAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceUser,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetUser
    )
    
    try {
        # Eingabevalidierung
        if (-not (Validate-Email -Email $SourceUser)) {
            throw "Ungültige E-Mail-Adresse für Quellpostfach."
        }
        if (-not (Validate-Email -Email $TargetUser)) {
            throw "Ungültige E-Mail-Adresse für Zielbenutzer."
        }
        
        Write-Log  "Füge SendOnBehalf-Berechtigung hinzu: $SourceUser -> $TargetUser" -Type "Info"
        
        # Prüfen, ob die Berechtigung bereits existiert (Zielbenutzer auflösen, da GrantSendOnBehalfTo keine SMTP-Adressen enthält)
        $mailbox = Get-Mailbox -Identity $SourceUser -ErrorAction Stop
        $targetRecipient = Get-Recipient -Identity $TargetUser -ErrorAction Stop
        $currentDelegates = $mailbox.GrantSendOnBehalfTo
        
        if (Test-SendOnBehalfDelegate -Delegates $currentDelegates -Recipient $targetRecipient) {
            Write-Log  "SendOnBehalf-Berechtigung existiert bereits, keine Änderung notwendig" -Type "Warning"
            if ($null -ne $txtStatus) {
                Update-GuiText -TextElement $txtStatus -Message "SendOnBehalf-Berechtigung bereits vorhanden." -Color $script:connectedBrush
            }
            Log-Action "SendOnBehalf-Berechtigung bereits vorhanden: $SourceUser -> $TargetUser"
            return $true
        }
        
        # Berechtigung hinzufügen (bestehende Berechtigungen bleiben durch @{Add=...} erhalten)
        Set-Mailbox -Identity $SourceUser -GrantSendOnBehalfTo @{Add = $TargetUser} -ErrorAction Stop
        
        Write-Log  "SendOnBehalf-Berechtigung erfolgreich hinzugefügt" -Type "Success"
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "SendOnBehalf-Berechtigung hinzugefügt." -Color $script:connectedBrush
        }
        Log-Action "SendOnBehalf-Berechtigung hinzugefügt: $SourceUser -> $TargetUser"
        return $true
    } 
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Hinzufügen der SendOnBehalf-Berechtigung: $errorMsg" -Type "Error"
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "Fehler: $errorMsg"
        }
        Log-Action "Fehler beim Hinzufügen der SendOnBehalf-Berechtigung: $errorMsg"
        return $false
    }
}

function Remove-SendOnBehalfPermissionAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceUser,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetUser
    )
    
    try {
        # Eingabevalidierung
        if (-not (Validate-Email -Email $SourceUser)) {
            throw "Ungültige E-Mail-Adresse für Quellpostfach."
        }
        if (-not (Validate-Email -Email $TargetUser)) {
            throw "Ungültige E-Mail-Adresse für Zielbenutzer."
        }
        
        Write-Log  "Entferne SendOnBehalf-Berechtigung: $SourceUser -> $TargetUser" -Type "Info"
        
        # Prüfen, ob die Berechtigung existiert (Zielbenutzer auflösen, da GrantSendOnBehalfTo keine SMTP-Adressen enthält)
        $mailbox = Get-Mailbox -Identity $SourceUser -ErrorAction Stop
        $targetRecipient = Get-Recipient -Identity $TargetUser -ErrorAction Stop
        $currentDelegates = $mailbox.GrantSendOnBehalfTo
        
        if (-not (Test-SendOnBehalfDelegate -Delegates $currentDelegates -Recipient $targetRecipient)) {
            Write-Log  "Keine SendOnBehalf-Berechtigung zum Entfernen gefunden" -Type "Warning"
            if ($null -ne $txtStatus) {
                Update-GuiText -TextElement $txtStatus -Message "Keine SendOnBehalf-Berechtigung zum Entfernen gefunden."
            }
            Log-Action "Keine SendOnBehalf-Berechtigung zum Entfernen gefunden: $SourceUser -> $TargetUser"
            return $false
        }
        
        # Berechtigung entfernen (übrige Berechtigungen bleiben durch @{Remove=...} erhalten)
        Set-Mailbox -Identity $SourceUser -GrantSendOnBehalfTo @{Remove = $TargetUser} -ErrorAction Stop
        
        Write-Log  "SendOnBehalf-Berechtigung erfolgreich entfernt" -Type "Success"
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "SendOnBehalf-Berechtigung entfernt." -Color $script:connectedBrush
        }
        Log-Action "SendOnBehalf-Berechtigung entfernt: $SourceUser -> $TargetUser"
        return $true
    } 
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Entfernen der SendOnBehalf-Berechtigung: $errorMsg" -Type "Error"
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "Fehler: $errorMsg"
        }
        Log-Action "Fehler beim Entfernen der SendOnBehalf-Berechtigung: $errorMsg"
        return $false
    }
}

function Get-SendOnBehalfPermissionAction {
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
        
        Write-Log  "Rufe SendOnBehalf-Berechtigungen ab für: $MailboxUser" -Type "Info"
        
        # Mailbox abrufen
        $mailbox = Get-Mailbox -Identity $MailboxUser -ErrorAction Stop
        
        # SendOnBehalf-Berechtigungen extrahieren
        $delegates = $mailbox.GrantSendOnBehalfTo
        
        # Ergebnisse in ein Array von Objekten umwandeln
        $processedDelegates = @()
        
        if ($delegates -and $delegates.Count -gt 0) {
            foreach ($delegate in $delegates) {
                # Versuche, den anzeigenamen des Delegated zu bekommen
                try {
                    $delegateUser = Get-User -Identity $delegate -ErrorAction SilentlyContinue
                    $displayName = if ($delegateUser) { $delegateUser.DisplayName } else { $delegate }
                }
                catch {
                    $displayName = $delegate
                }
                
                $permObj = [PSCustomObject]@{
                    Identity = $MailboxUser
                    User = $delegate
                    DisplayName = $displayName
                    AccessType = "SendOnBehalf"
                    AccessRights = "SendOnBehalf"
                    IsInherited = $false
                    Deny = $false
                }
                
                $processedDelegates += $permObj
                Write-Log  "SendOnBehalf-Berechtigung verarbeitet: $delegate" -Type "Info"
            }
        }
        
        Write-Log  "SendOnBehalf-Berechtigungen abgerufen: $($processedDelegates.Count) Einträge gefunden" -Type "Success"
        Log-Action "SendOnBehalf-Berechtigungen für $MailboxUser abgerufen: $($processedDelegates.Count) Einträge gefunden"
        
        return $processedDelegates
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Abrufen der SendOnBehalf-Berechtigungen: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Abrufen der SendOnBehalf-Berechtigungen: $errorMsg"
        
        # Bei Fehler ein leeres Array zurückgeben, damit die GUI nicht abstürzt
        return @()
    }
}

function Initialize-MailboxTab {
    [CmdletBinding()]
    param()
    
    try {
        
        # Referenzieren der UI-Elemente im Postfach-Tab
        $txtMailboxSource = Get-XamlElement -ElementName "txtMailboxSource"
        $txtMailboxTarget = Get-XamlElement -ElementName "txtMailboxTarget"
        $btnAddMailboxPermission = Get-XamlElement -ElementName "btnAddMailboxPermission"
        $btnRemoveMailboxPermission = Get-XamlElement -ElementName "btnRemoveMailboxPermission"
        $btnShowMailboxPermissions = Get-XamlElement -ElementName "btnShowMailboxPermissions"
        $btnAddSendAs = Get-XamlElement -ElementName "btnAddSendAs"
        $btnRemoveSendAs = Get-XamlElement -ElementName "btnRemoveSendAs"
        $btnShowSendAs = Get-XamlElement -ElementName "btnShowSendAs"
        $btnAddSendOnBehalf = Get-XamlElement -ElementName "btnAddSendOnBehalf"
        $btnRemoveSendOnBehalf = Get-XamlElement -ElementName "btnRemoveSendOnBehalf"
        $btnShowSendOnBehalf = Get-XamlElement -ElementName "btnShowSendOnBehalf"
        # Eingabefeld "Postfach" im Bereich "Berechtigungen anzeigen" (x:Name im XAML: txtMailboxShowPermissions)
        $txtMailboxUser = Get-XamlElement -ElementName "txtMailboxShowPermissions"
        $lstMailboxPermissions = Get-XamlElement -ElementName "lstMailboxPermissions"
        $helpLinkMailbox = Get-XamlElement -ElementName "helpLinkMailbox"
        
        # Globale Variablen für spätere Verwendung setzen
        $script:txtMailboxSource = $txtMailboxSource
        $script:txtMailboxTarget = $txtMailboxTarget
        $script:txtMailboxUser = $txtMailboxUser
        $script:lstMailboxPermissions = $lstMailboxPermissions
        
        # Event-Handler für Postfach-Buttons registrieren
        Register-EventHandler -Control $btnAddMailboxPermission -Handler {
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
                if ([string]::IsNullOrWhiteSpace($script:txtMailboxSource.Text) -or 
                    [string]::IsNullOrWhiteSpace($script:txtMailboxTarget.Text)) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte geben Sie Quell- und Zielbenutzer an.",
                        "Unvollständige Eingabe",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $sourceUser = $script:txtMailboxSource.Text
                $targetUser = $script:txtMailboxTarget.Text
                
                $result = Add-MailboxPermissionAction -SourceUser $sourceUser -TargetUser $targetUser
                
                if ($result) {
                    $script:txtStatus.Text = "Postfachberechtigung erfolgreich hinzugefügt."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnAddMailboxPermission"
        
        # Event-Handler für Entfernen von Postfachberechtigungen
        Register-EventHandler -Control $btnRemoveMailboxPermission -Handler {
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
                if ([string]::IsNullOrWhiteSpace($script:txtMailboxSource.Text) -or 
                    [string]::IsNullOrWhiteSpace($script:txtMailboxTarget.Text)) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte geben Sie Quell- und Zielbenutzer an.",
                        "Unvollständige Eingabe",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $sourceUser = $script:txtMailboxSource.Text
                $targetUser = $script:txtMailboxTarget.Text
                
                $confirmResult = Show-MessageBox -Message "Möchten Sie die FullAccess-Berechtigung von '$targetUser' auf das Postfach '$sourceUser' wirklich entfernen?" -Title "Entfernen bestätigen" -Type "Question"
                if ($confirmResult -ne "Yes") {
                    $script:txtStatus.Text = "Entfernen der Postfachberechtigung abgebrochen."
                    return
                }

                $result = Remove-MailboxPermissionAction -SourceUser $sourceUser -TargetUser $targetUser
                
                if ($result) {
                    $script:txtStatus.Text = "Postfachberechtigung erfolgreich entfernt."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnRemoveMailboxPermission"
        
        # Event-Handler für Anzeigen von Postfachberechtigungen
        Register-EventHandler -Control $btnShowMailboxPermissions -Handler {
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
                if ([string]::IsNullOrWhiteSpace($script:txtMailboxUser.Text)) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte geben Sie eine E-Mail-Adresse ein.",
                        "Unvollständige Eingabe",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $mailboxUser = $script:txtMailboxUser.Text
                
                $permissions = Get-MailboxPermissions -Mailbox $mailboxUser
                
                # ListView leeren und mit neuen Daten füllen
                if ($null -ne $script:lstMailboxPermissions) {
                    $script:lstMailboxPermissions.Items.Clear()
                    
                    foreach ($perm in $permissions) {
                        [void]$script:lstMailboxPermissions.Items.Add($perm)
                    }
                    
                    $script:txtStatus.Text = "Postfachberechtigungen erfolgreich abgerufen."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnShowMailboxPermissions"
        
        # Event-Handler für SendAs-Berechtigungen hinzufügen
        Register-EventHandler -Control $btnAddSendAs -Handler {
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
                if ([string]::IsNullOrWhiteSpace($script:txtMailboxSource.Text) -or 
                    [string]::IsNullOrWhiteSpace($script:txtMailboxTarget.Text)) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte geben Sie Quell- und Zielbenutzer an.",
                        "Unvollständige Eingabe",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $sourceUser = $script:txtMailboxSource.Text
                $targetUser = $script:txtMailboxTarget.Text
                
                $result = Add-SendAsPermissionAction -SourceUser $sourceUser -TargetUser $targetUser
                
                if ($result) {
                    $script:txtStatus.Text = "SendAs-Berechtigung erfolgreich hinzugefügt."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnAddSendAs"
        
        # Event-Handler für SendAs-Berechtigungen entfernen
        Register-EventHandler -Control $btnRemoveSendAs -Handler {
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
                if ([string]::IsNullOrWhiteSpace($script:txtMailboxSource.Text) -or 
                    [string]::IsNullOrWhiteSpace($script:txtMailboxTarget.Text)) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte geben Sie Quell- und Zielbenutzer an.",
                        "Unvollständige Eingabe",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $sourceUser = $script:txtMailboxSource.Text
                $targetUser = $script:txtMailboxTarget.Text
                
                $confirmResult = Show-MessageBox -Message "Möchten Sie die SendAs-Berechtigung von '$targetUser' auf das Postfach '$sourceUser' wirklich entfernen?" -Title "Entfernen bestätigen" -Type "Question"
                if ($confirmResult -ne "Yes") {
                    $script:txtStatus.Text = "Entfernen der SendAs-Berechtigung abgebrochen."
                    return
                }

                $result = Remove-SendAsPermissionAction -SourceUser $sourceUser -TargetUser $targetUser
                
                if ($result) {
                    $script:txtStatus.Text = "SendAs-Berechtigung erfolgreich entfernt."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnRemoveSendAs"
        
        # Event-Handler für Anzeigen von SendAs-Berechtigungen
        Register-EventHandler -Control $btnShowSendAs -Handler {
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
                if ([string]::IsNullOrWhiteSpace($script:txtMailboxUser.Text)) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte geben Sie eine E-Mail-Adresse ein.",
                        "Unvollständige Eingabe",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $mailboxUser = $script:txtMailboxUser.Text
                
                $permissions = Get-SendAsPermissionAction -MailboxUser $mailboxUser
                
                # ListView leeren und mit neuen Daten füllen
                if ($null -ne $script:lstMailboxPermissions) {
                    $script:lstMailboxPermissions.Items.Clear()
                    
                    foreach ($perm in $permissions) {
                        [void]$script:lstMailboxPermissions.Items.Add($perm)
                    }
                    
                    $script:txtStatus.Text = "SendAs-Berechtigungen erfolgreich abgerufen."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnShowSendAs"
        
        # Event-Handler für SendOnBehalf-Berechtigungen hinzufügen
        Register-EventHandler -Control $btnAddSendOnBehalf -Handler {
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
                if ([string]::IsNullOrWhiteSpace($script:txtMailboxSource.Text) -or 
                    [string]::IsNullOrWhiteSpace($script:txtMailboxTarget.Text)) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte geben Sie Quell- und Zielbenutzer an.",
                        "Unvollständige Eingabe",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $sourceUser = $script:txtMailboxSource.Text
                $targetUser = $script:txtMailboxTarget.Text
                
                $result = Add-SendOnBehalfPermissionAction -SourceUser $sourceUser -TargetUser $targetUser
                
                if ($result) {
                    $script:txtStatus.Text = "SendOnBehalf-Berechtigung erfolgreich hinzugefügt."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnAddSendOnBehalf"
        
        # Event-Handler für SendOnBehalf-Berechtigungen entfernen
        Register-EventHandler -Control $btnRemoveSendOnBehalf -Handler {
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
                if ([string]::IsNullOrWhiteSpace($script:txtMailboxSource.Text) -or 
                    [string]::IsNullOrWhiteSpace($script:txtMailboxTarget.Text)) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte geben Sie Quell- und Zielbenutzer an.",
                        "Unvollständige Eingabe",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $sourceUser = $script:txtMailboxSource.Text
                $targetUser = $script:txtMailboxTarget.Text
                
                $confirmResult = Show-MessageBox -Message "Möchten Sie die SendOnBehalf-Berechtigung von '$targetUser' auf das Postfach '$sourceUser' wirklich entfernen?" -Title "Entfernen bestätigen" -Type "Question"
                if ($confirmResult -ne "Yes") {
                    $script:txtStatus.Text = "Entfernen der SendOnBehalf-Berechtigung abgebrochen."
                    return
                }

                $result = Remove-SendOnBehalfPermissionAction -SourceUser $sourceUser -TargetUser $targetUser
                
                if ($result) {
                    $script:txtStatus.Text = "SendOnBehalf-Berechtigung erfolgreich entfernt."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnRemoveSendOnBehalf"
        
        # Event-Handler für Anzeigen von SendOnBehalf-Berechtigungen
        Register-EventHandler -Control $btnShowSendOnBehalf -Handler {
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
                if ([string]::IsNullOrWhiteSpace($script:txtMailboxUser.Text)) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte geben Sie eine E-Mail-Adresse ein.",
                        "Unvollständige Eingabe",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $mailboxUser = $script:txtMailboxUser.Text
                
                $permissions = Get-SendOnBehalfPermissionAction -MailboxUser $mailboxUser
                
                # ListView leeren und mit neuen Daten füllen
                if ($null -ne $script:lstMailboxPermissions) {
                    $script:lstMailboxPermissions.Items.Clear()
                    
                    foreach ($perm in $permissions) {
                        [void]$script:lstMailboxPermissions.Items.Add($perm)
                    }
                    
                    $script:txtStatus.Text = "SendOnBehalf-Berechtigungen erfolgreich abgerufen."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnShowSendOnBehalf"
        
        # Event-Handler für Hilfe-Link
        if ($null -ne $helpLinkMailbox) {
            $helpLinkMailbox.Add_MouseLeftButtonDown({
                Show-HelpDialog -Topic "Mailbox"
            })
            
            $helpLinkMailbox.Add_MouseEnter({
                $this.TextDecorations = [System.Windows.TextDecorations]::Underline
                $this.Cursor = [System.Windows.Input.Cursors]::Hand
            })
            
            $helpLinkMailbox.Add_MouseLeave({
                $this.TextDecorations = $null
                $this.Cursor = [System.Windows.Input.Cursors]::Arrow
            })
        }

        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnExportMailboxPermissions") -ControlName "btnExportMailboxPermissions" -Handler {
            Export-DataGridContent -DataGrid $script:lstMailboxPermissions -DefaultFileName "Postfachberechtigungen"
        }
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        return $false
    }
}
