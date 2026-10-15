# =====================================================================
# easyEXO - Modul: Raum- und Gerätepostfächer
# Datei: src/Modules/Features/Resources.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

function New-ResourceAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        
        [Parameter(Mandatory = $true)]
        [string]$ResourceType,
        
        [Parameter(Mandatory = $false)]
        [string]$Capacity,
        
        [Parameter(Mandatory = $false)]
        [string]$Location
    )
    
    try {
        Write-Log  "Erstelle neue Ressource: $Name (Typ: $ResourceType)" -Type "Info"
        
        # Parameter für die Ressourcenerstellung vorbereiten
        $params = @{
            Name = $Name
            DisplayName = $DisplayName
        }
        if (-not [string]::IsNullOrEmpty($Capacity)) {
            $params.Add("ResourceCapacity", [int]$Capacity)
        }
        
        # Ressource basierend auf Typ erstellen
        if ($ResourceType -eq "Room") {
            $result = New-Mailbox -Room @params -ErrorAction Stop
            $resourceTypeName = "Raumressource"
        } 
        elseif ($ResourceType -eq "Equipment") {
            $result = New-Mailbox -Equipment @params -ErrorAction Stop
            $resourceTypeName = "Ausstattungsressource"
        }
        else {
            throw "Ungültiger Ressourcentyp: $ResourceType. Erlaubte Werte sind 'Room' oder 'Equipment'."
        }
        
        Write-Log  "$resourceTypeName erfolgreich erstellt: $Name" -Type "Success"
        Log-Action "$resourceTypeName erstellt: $Name"
        
        # Standort: New-Mailbox kennt keinen Parameter -Location (-Office nur für Räume),
        # daher nachträglich per Set-Mailbox -Office setzen.
        if (-not [string]::IsNullOrWhiteSpace($Location) -and $null -ne $result) {
            try {
                Set-Mailbox -Identity $result.Identity -Office $Location -ErrorAction Stop
                Write-Log  "Standort für $Name gesetzt: $Location" -Type "Info"
            }
            catch {
                Write-Log  "$resourceTypeName '$Name' wurde erstellt, der Standort konnte aber nicht gesetzt werden: $($_.Exception.Message)" -Type "Warning"
            }
        }
        
        return $result
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Erstellen der Ressource: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Erstellen der Ressource: $errorMsg"
        throw $_
    }
}

function Get-RoomResourcesAction {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log  "Rufe alle Raumressourcen ab" -Type "Info"
        
        $rooms = Get-Mailbox -RecipientTypeDetails RoomMailbox -ResultSize Unlimited |
                 Select-Object DisplayName, Name, PrimarySmtpAddress, ResourceCapacity, Office
        
        Write-Log  "Erfolgreich $($rooms.Count) Raumressourcen abgerufen" -Type "Success"
        Log-Action "Raumressourcen abgerufen: $($rooms.Count) gefunden"
        
        return $rooms
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Abrufen der Raumressourcen: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Abrufen der Raumressourcen: $errorMsg"
        throw $_
    }
}

function Get-EquipmentResourcesAction {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log  "Rufe alle Ausstattungsressourcen ab" -Type "Info"
        
        $equipment = Get-Mailbox -RecipientTypeDetails EquipmentMailbox -ResultSize Unlimited | 
                     Select-Object DisplayName, Name, PrimarySmtpAddress, ResourceCapacity, Office
        
        Write-Log  "Erfolgreich $($equipment.Count) Ausstattungsressourcen abgerufen" -Type "Success"
        Log-Action "Ausstattungsressourcen abgerufen: $($equipment.Count) gefunden"
        
        return $equipment
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Abrufen der Ausstattungsressourcen: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Abrufen der Ausstattungsressourcen: $errorMsg"
        throw $_
    }
}

function Search-ResourcesAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchTerm
    )
    
    try {
        Write-Log  "Suche nach Ressourcen mit Suchbegriff: $SearchTerm" -Type "Info"
        
        # Alle Ressourcen abrufen und filtern
        $resources = Get-Mailbox -RecipientTypeDetails RoomMailbox,EquipmentMailbox -ResultSize Unlimited | 
                     Where-Object { 
                         $_.DisplayName -like "*$SearchTerm*" -or 
                         $_.Name -like "*$SearchTerm*" -or 
                         $_.PrimarySmtpAddress -like "*$SearchTerm*" -or
                         $_.Office -like "*$SearchTerm*"
                     } | 
                     Select-Object DisplayName, Name, PrimarySmtpAddress, RecipientTypeDetails, ResourceCapacity, Office
        
        Write-Log  "Suchergebnis: $($resources.Count) Ressourcen gefunden" -Type "Success"
        Log-Action "Ressourcensuche für '$SearchTerm': $($resources.Count) Ergebnisse"
        
        return $resources
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler bei der Ressourcensuche: $errorMsg" -Type "Error"
        Log-Action "Fehler bei der Ressourcensuche: $errorMsg"
        throw $_
    }
}

function Get-AllResourcesAction {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log  "Rufe alle Ressourcen (Räume und Ausstattung) ab" -Type "Info"
        
        # Array-Syntax für mehrere RecipientTypeDetails verwenden
        $recipientTypes = @("RoomMailbox", "EquipmentMailbox")
        $resources = Get-Mailbox -RecipientTypeDetails $recipientTypes -ResultSize Unlimited
        
        Write-Log  "Erfolgreich $($resources.Count) Ressourcen abgerufen" -Type "Success"
        Log-Action "Alle Ressourcen abgerufen: $($resources.Count) gefunden"
        
        return $resources
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Abrufen aller Ressourcen: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Abrufen aller Ressourcen: $errorMsg"
        throw $_
    }
}

function Remove-ResourceAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity
    )
    
    try {
        Write-Log  "Lösche Ressource: $Identity" -Type "Info"
        
        # Ressource abrufen, um den Typ zu bestimmen
        $resource = Get-Mailbox -Identity $Identity -ErrorAction Stop
        $resourceType = if ($resource.RecipientTypeDetails -eq "RoomMailbox") { "Raumressource" } else { "Ausstattungsressource" }
        
        # Ressource löschen
        Remove-Mailbox -Identity $Identity -Confirm:$false -ErrorAction Stop
        
        Write-Log  "$resourceType erfolgreich gelöscht: $Identity" -Type "Success"
        Log-Action "$resourceType gelöscht: $Identity"
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Löschen der Ressource: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Löschen der Ressource: $errorMsg"
        throw $_
    }
}

function Export-ResourcesAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Resources,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        Write-Log  "Exportiere $($Resources.Count) Ressourcen nach: $FilePath" -Type "Info"
        
        # Ressourcen in CSV-Datei exportieren
        $Resources | ConvertTo-SafeCsvObject | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8 -Delimiter ";"
        
        Write-Log  "Ressourcen erfolgreich exportiert" -Type "Success"
        Log-Action "Ressourcen exportiert nach: $FilePath"
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Exportieren der Ressourcen: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Exportieren der Ressourcen: $errorMsg"
        throw $_
    }
}

function Get-ResourceSettingsAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity
    )
    
    try {
        Write-Log  "Rufe Ressourceneinstellungen ab für: $Identity" -Type "Info"
        
        # Ressource abrufen
        $resource = Get-Mailbox -Identity $Identity -ErrorAction Stop
        
        # Kalenderverarbeitungseinstellungen abrufen
        $calendarProcessing = Get-CalendarProcessing -Identity $Identity -ErrorAction Stop
        
        # Ressourceneinstellungen zusammenstellen
        $resourceSettings = [PSCustomObject]@{
            Name = $resource.Name
            DisplayName = $resource.DisplayName
            PrimarySmtpAddress = $resource.PrimarySmtpAddress
            ResourceType = $resource.RecipientTypeDetails
            Capacity = $resource.ResourceCapacity
            Location = $resource.Office
            AutoAccept = $calendarProcessing.AutomateProcessing -eq "AutoAccept"
            AllowConflicts = $calendarProcessing.AllowConflicts
            BookingWindowInDays = $calendarProcessing.BookingWindowInDays
            MaximumDurationInMinutes = $calendarProcessing.MaximumDurationInMinutes
            AllowRecurringMeetings = $calendarProcessing.AllowRecurringMeetings
            EnforceSchedulingHorizon = $calendarProcessing.EnforceSchedulingHorizon
            ScheduleOnlyDuringWorkHours = $calendarProcessing.ScheduleOnlyDuringWorkHours
            DeleteComments = $calendarProcessing.DeleteComments
            DeleteSubject = $calendarProcessing.DeleteSubject
            RemovePrivateProperty = $calendarProcessing.RemovePrivateProperty
            AddOrganizerToSubject = $calendarProcessing.AddOrganizerToSubject
            ProcessExternalMeetingMessages = $calendarProcessing.ProcessExternalMeetingMessages
            RemoveOldMeetingMessages = $calendarProcessing.RemoveOldMeetingMessages
            AddAdditionalResponse = $calendarProcessing.AddAdditionalResponse
            AdditionalResponse = $calendarProcessing.AdditionalResponse
            DeleteNonCalendarItems = $calendarProcessing.DeleteNonCalendarItems
            ForwardRequestsToDelegates = $calendarProcessing.ForwardRequestsToDelegates
            TentativePendingApproval = $calendarProcessing.TentativePendingApproval
            EnableResponseDetails = $calendarProcessing.EnableResponseDetails
            OrganizerInfo = $calendarProcessing.OrganizerInfo
            RequestOutOfPolicy = $calendarProcessing.RequestOutOfPolicy
            AllRequestOutOfPolicy = $calendarProcessing.AllRequestOutOfPolicy
            BookInPolicy = $calendarProcessing.BookInPolicy
            AllBookInPolicy = $calendarProcessing.AllBookInPolicy
            RequestInPolicy = $calendarProcessing.RequestInPolicy
            AllRequestInPolicy = $calendarProcessing.AllRequestInPolicy
            ResourceDelegates = $calendarProcessing.ResourceDelegates
            ConflictPercentageAllowed = $calendarProcessing.ConflictPercentageAllowed
            MaximumConflictInstances = $calendarProcessing.MaximumConflictInstances
            MinimumDurationInMinutes = $calendarProcessing.MinimumDurationInMinutes
            PostReservationMaxClaimTimeInMinutes = $calendarProcessing.PostReservationMaxClaimTimeInMinutes
        }
        
        Write-Log  "Ressourceneinstellungen erfolgreich abgerufen" -Type "Success"
        Log-Action "Ressourceneinstellungen abgerufen für: $Identity"
        
        return $resourceSettings
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Abrufen der Ressourceneinstellungen: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Abrufen der Ressourceneinstellungen: $errorMsg"
        throw $_
    }
}

function Get-ResourcePermissionsAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity
    )
    
    try {
        Write-Log  "Rufe Ressourcenberechtigungen ab für: $Identity" -Type "Info"
        
        # Mailbox-Berechtigungen abrufen
        $mailboxPermissions = Get-MailboxPermission -Identity $Identity | Where-Object { 
            $_.User -notlike "NT AUTHORITY\*" -and 
            $_.User -notlike "S-1-*" -and 
            $_.User -ne "SELF" 
        }
        
        # Kalender-Berechtigungen abrufen
        # Kalender-Berechtigungen für verschiedene Sprachen abrufen
        $calendarPermissions = @()
        $calendarFolders = @("Calendar", "Kalender", "Calendrier", "Calendario", "Kalendarz")
        
        foreach ($folderName in $calendarFolders) {
            try {
                $permissions = Get-MailboxFolderPermission -Identity "${Identity}:\$folderName" -ErrorAction SilentlyContinue
                if ($permissions) {
                    $calendarPermissions += $permissions
                    break  # Erfolgreich gefunden, keine weiteren Versuche nötig
                }
            }
            catch {
                # Ordner existiert nicht in dieser Sprache, weiter versuchen
                continue
            }
        }
        
        # Berechtigungen zusammenstellen
        $permissions = @()
        
        # Mailbox-Berechtigungen hinzufügen
        foreach ($permission in $mailboxPermissions) {
            $permissions += [PSCustomObject]@{
                Resource = $Identity
                User = $permission.User
                PermissionType = "Mailbox"
                AccessRights = ($permission.AccessRights -join ", ")
                IsInherited = $permission.IsInherited
                Deny = $permission.Deny
            }
        }
        
        # Kalender-Berechtigungen hinzufügen
        foreach ($permission in $calendarPermissions) {
            if ($permission.User -ne "Default" -and $permission.User -ne "Anonymous") {
                $permissions += [PSCustomObject]@{
                    Resource = $Identity
                    User = $permission.User
                    PermissionType = "Kalender"
                    AccessRights = ($permission.AccessRights -join ", ")
                    IsInherited = $false
                    Deny = $false
                }
            }
        }
        
        Write-Log  "Erfolgreich $($permissions.Count) Berechtigungen für Ressource abgerufen" -Type "Success"
        Log-Action "Ressourcenberechtigungen abgerufen für: $Identity ($($permissions.Count) Berechtigungen)"
        
        return $permissions
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Abrufen der Ressourcenberechtigungen: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Abrufen der Ressourcenberechtigungen: $errorMsg"
        throw $_
    }
}

function Update-ResourceSettingsAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity,
        
        [Parameter(Mandatory = $false)]
        [string]$DisplayName,
        
        [Parameter(Mandatory = $false)]
        [int]$Capacity,
        
        [Parameter(Mandatory = $false)]
        [string]$Location,
        
        [Parameter(Mandatory = $false)]
        [bool]$AutoAccept,
        
        [Parameter(Mandatory = $false)]
        [bool]$AllowConflicts,
        
        [Parameter(Mandatory = $false)]
        [int]$BookingWindowInDays,
        
        [Parameter(Mandatory = $false)]
        [int]$MaximumDurationInMinutes,
        
        [Parameter(Mandatory = $false)]
        [int]$MinimumDurationInMinutes,
        
        [Parameter(Mandatory = $false)]
        [bool]$AllowRecurringMeetings,
        
        [Parameter(Mandatory = $false)]
        [bool]$ScheduleOnlyDuringWorkHours,
        
        [Parameter(Mandatory = $false)]
        [bool]$DeleteComments,
        
        [Parameter(Mandatory = $false)]
        [bool]$DeleteSubject,
        
        [Parameter(Mandatory = $false)]
        [bool]$RemovePrivateProperty,
        
        [Parameter(Mandatory = $false)]
        [bool]$AddOrganizerToSubject,
        
        [Parameter(Mandatory = $false)]
        [bool]$ProcessExternalMeetingMessages,
        
        [Parameter(Mandatory = $false)]
        [bool]$RemoveOldMeetingMessages,
        
        [Parameter(Mandatory = $false)]
        [bool]$AddAdditionalResponse,
        
        [Parameter(Mandatory = $false)]
        [string]$AdditionalResponse,
        
        [Parameter(Mandatory = $false)]
        [bool]$DeleteNonCalendarItems,
        
        [Parameter(Mandatory = $false)]
        [bool]$ForwardRequestsToDelegates,
        
        [Parameter(Mandatory = $false)]
        [bool]$TentativePendingApproval,
        
        [Parameter(Mandatory = $false)]
        [bool]$EnableResponseDetails,
        
        [Parameter(Mandatory = $false)]
        [bool]$OrganizerInfo,
        
        [Parameter(Mandatory = $false)]
        [string[]]$ResourceDelegates,
        
        [Parameter(Mandatory = $false)]
        [int]$ConflictPercentageAllowed,
        
        [Parameter(Mandatory = $false)]
        [int]$MaximumConflictInstances,
        
        [Parameter(Mandatory = $false)]
        [int]$PostReservationMaxClaimTimeInMinutes
    )
    
    try {
        Write-Log  "Aktualisiere Ressourceneinstellungen für: $Identity" -Type "Info"
        
        # Ressource abrufen, um den Typ zu bestimmen
        $resource = Get-Mailbox -Identity $Identity -ErrorAction Stop
        $resourceType = if ($resource.RecipientTypeDetails -eq "RoomMailbox") { "Raumressource" } else { "Ausstattungsressource" }
        
        # Mailbox-Eigenschaften aktualisieren
        $mailboxParams = @{
            Identity = $Identity
            ErrorAction = "Stop"
        }
        
        if ($PSBoundParameters.ContainsKey('DisplayName') -and ![string]::IsNullOrWhiteSpace($DisplayName)) {
            $mailboxParams.Add("DisplayName", $DisplayName)
        }
        
        if ($PSBoundParameters.ContainsKey('Capacity') -and $Capacity -gt 0) {
            $mailboxParams.Add("ResourceCapacity", $Capacity)
        }
        
        # Standort wird im Attribut "Office" gespeichert (ResourceCustom akzeptiert nur per Set-ResourceConfig definierte Eigenschaften)
        if ($PSBoundParameters.ContainsKey('Location') -and ![string]::IsNullOrWhiteSpace($Location)) {
            $mailboxParams.Add("Office", $Location)
        }
        
        if ($mailboxParams.Count -gt 2) {
            Set-Mailbox @mailboxParams
            Write-Log  "Mailbox-Eigenschaften aktualisiert" -Type "Info"
        }
        
        # Kalenderverarbeitungseinstellungen aktualisieren
        $calendarParams = @{
            Identity = $Identity
            ErrorAction = "Stop"
        }
        
        if ($PSBoundParameters.ContainsKey('AutoAccept')) {
            $calendarParams.Add("AutomateProcessing", $(if ($AutoAccept) { "AutoAccept" } else { "AutoUpdate" }))
        }
        
        if ($PSBoundParameters.ContainsKey('AllowConflicts')) {
            $calendarParams.Add("AllowConflicts", $AllowConflicts)
        }
        
        if ($PSBoundParameters.ContainsKey('BookingWindowInDays') -and $BookingWindowInDays -gt 0) {
            $calendarParams.Add("BookingWindowInDays", $BookingWindowInDays)
        }
        
        if ($PSBoundParameters.ContainsKey('MaximumDurationInMinutes') -and $MaximumDurationInMinutes -gt 0) {
            $calendarParams.Add("MaximumDurationInMinutes", $MaximumDurationInMinutes)
        }
        
        if ($PSBoundParameters.ContainsKey('MinimumDurationInMinutes') -and $MinimumDurationInMinutes -ge 0) {
            $calendarParams.Add("MinimumDurationInMinutes", $MinimumDurationInMinutes)
        }
        
        if ($PSBoundParameters.ContainsKey('AllowRecurringMeetings')) {
            $calendarParams.Add("AllowRecurringMeetings", $AllowRecurringMeetings)
        }
        
        if ($PSBoundParameters.ContainsKey('ScheduleOnlyDuringWorkHours')) {
            $calendarParams.Add("ScheduleOnlyDuringWorkHours", $ScheduleOnlyDuringWorkHours)
        }
        
        if ($PSBoundParameters.ContainsKey('DeleteComments')) {
            $calendarParams.Add("DeleteComments", $DeleteComments)
        }
        
        if ($PSBoundParameters.ContainsKey('DeleteSubject')) {
            $calendarParams.Add("DeleteSubject", $DeleteSubject)
        }
        
        if ($PSBoundParameters.ContainsKey('RemovePrivateProperty')) {
            $calendarParams.Add("RemovePrivateProperty", $RemovePrivateProperty)
        }
        
        if ($PSBoundParameters.ContainsKey('AddOrganizerToSubject')) {
            $calendarParams.Add("AddOrganizerToSubject", $AddOrganizerToSubject)
        }
        
        if ($PSBoundParameters.ContainsKey('ProcessExternalMeetingMessages')) {
            $calendarParams.Add("ProcessExternalMeetingMessages", $ProcessExternalMeetingMessages)
        }
        
        if ($PSBoundParameters.ContainsKey('RemoveOldMeetingMessages')) {
            $calendarParams.Add("RemoveOldMeetingMessages", $RemoveOldMeetingMessages)
        }
        
        if ($PSBoundParameters.ContainsKey('AddAdditionalResponse')) {
            $calendarParams.Add("AddAdditionalResponse", $AddAdditionalResponse)
        }
        
        if ($PSBoundParameters.ContainsKey('AdditionalResponse') -and ![string]::IsNullOrWhiteSpace($AdditionalResponse)) {
            $calendarParams.Add("AdditionalResponse", $AdditionalResponse)
        }
        
        if ($PSBoundParameters.ContainsKey('DeleteNonCalendarItems')) {
            $calendarParams.Add("DeleteNonCalendarItems", $DeleteNonCalendarItems)
        }
        
        if ($PSBoundParameters.ContainsKey('ForwardRequestsToDelegates')) {
            $calendarParams.Add("ForwardRequestsToDelegates", $ForwardRequestsToDelegates)
        }
        
        if ($PSBoundParameters.ContainsKey('TentativePendingApproval')) {
            $calendarParams.Add("TentativePendingApproval", $TentativePendingApproval)
        }
        
        if ($PSBoundParameters.ContainsKey('EnableResponseDetails')) {
            $calendarParams.Add("EnableResponseDetails", $EnableResponseDetails)
        }
        
        if ($PSBoundParameters.ContainsKey('OrganizerInfo')) {
            $calendarParams.Add("OrganizerInfo", $OrganizerInfo)
        }
        
        if ($PSBoundParameters.ContainsKey('ResourceDelegates')) {
            $calendarParams.Add("ResourceDelegates", $(if (@($ResourceDelegates).Count -gt 0) { $ResourceDelegates } else { $null }))
        }
        
        if ($PSBoundParameters.ContainsKey('ConflictPercentageAllowed') -and $ConflictPercentageAllowed -ge 0) {
            $calendarParams.Add("ConflictPercentageAllowed", $ConflictPercentageAllowed)
        }
        
        if ($PSBoundParameters.ContainsKey('MaximumConflictInstances') -and $MaximumConflictInstances -ge 0) {
            $calendarParams.Add("MaximumConflictInstances", $MaximumConflictInstances)
        }
        
        if ($PSBoundParameters.ContainsKey('PostReservationMaxClaimTimeInMinutes') -and $PostReservationMaxClaimTimeInMinutes -gt 0) {
            $calendarParams.Add("PostReservationMaxClaimTimeInMinutes", $PostReservationMaxClaimTimeInMinutes)
        }
        
        if ($calendarParams.Count -gt 2) {
            Set-CalendarProcessing @calendarParams
            Write-Log  "Kalenderverarbeitungseinstellungen aktualisiert" -Type "Info"
        }
        
        Write-Log  "$resourceType-Einstellungen erfolgreich aktualisiert: $Identity" -Type "Success"
        Log-Action "$resourceType-Einstellungen aktualisiert: $Identity"
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Aktualisieren der Ressourceneinstellungen: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Aktualisieren der Ressourceneinstellungen: $errorMsg"
        throw $_
    }
}

function Show-ResourceSettingsDialog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity
    )
    
    try {
        Write-Log  "Öffne Ressourceneinstellungen-Dialog für: $Identity" -Type "Info"
        
        # Ressourceneinstellungen abrufen
        $resourceSettings = Get-ResourceSettingsAction -Identity $Identity
        
        # Ressourcenberechtigungen abrufen (@(): bei genau einem Eintrag liefert die Funktion ein Einzelobjekt)
        $resourcePermissions = @(Get-ResourcePermissionsAction -Identity $Identity)
        
        # XAML für den Dialog erstellen
        $xaml = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Ressourceneinstellungen bearbeiten" Height="800" Width="1200" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="600"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        
        <TextBlock Grid.Row="0" Grid.ColumnSpan="2" Name="txtResourceHeader" FontWeight="Bold" Margin="0,0,0,10"/>
        
        <!-- Linke Spalte - Einstellungen -->
        <ScrollViewer Grid.Row="1" Grid.Column="0" VerticalScrollBarVisibility="Auto" Margin="0,0,10,0">
            <StackPanel>
                <GroupBox Header="Allgemeine Einstellungen" Margin="0,5,0,10">
                    <Grid Margin="5">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        
                        <TextBlock Grid.Row="0" Grid.Column="0" Text="Anzeigename:" Margin="0,5,10,5" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="0" Grid.Column="1" Name="txtDisplayName" Margin="0,5,0,5"/>
                        
                        <TextBlock Grid.Row="1" Grid.Column="0" Text="Kapazität:" Margin="0,5,10,5" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="1" Grid.Column="1" Name="txtCapacity" Margin="0,5,0,5"/>
                        
                        <TextBlock Grid.Row="2" Grid.Column="0" Text="Standort:" Margin="0,5,10,5" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="2" Grid.Column="1" Name="txtLocation" Margin="0,5,0,5"/>
                    </Grid>
                </GroupBox>
                
                <GroupBox Header="Buchungseinstellungen" Margin="0,5,0,10">
                    <Grid Margin="5">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        
                        <CheckBox Grid.Row="0" Grid.Column="0" Grid.ColumnSpan="2" Name="chkAutoAccept" Content="Buchungen automatisch akzeptieren" Margin="0,5,0,5"/>
                        
                        <CheckBox Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="2" Name="chkAllowConflicts" Content="Terminüberschneidungen erlauben" Margin="0,5,0,5"/>
                        
                        <TextBlock Grid.Row="2" Grid.Column="0" Text="Buchungszeitraum (Tage):" Margin="0,5,10,5" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="2" Grid.Column="1" Name="txtBookingWindow" Margin="0,5,0,5"/>
                        
                        <TextBlock Grid.Row="3" Grid.Column="0" Text="Maximale Dauer (Minuten):" Margin="0,5,10,5" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="3" Grid.Column="1" Name="txtMaxDuration" Margin="0,5,0,5"/>
                        
                        <TextBlock Grid.Row="4" Grid.Column="0" Text="Minimale Dauer (Minuten):" Margin="0,5,10,5" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="4" Grid.Column="1" Name="txtMinDuration" Margin="0,5,0,5"/>
                        
                        <CheckBox Grid.Row="5" Grid.Column="0" Grid.ColumnSpan="2" Name="chkAllowRecurring" Content="Serientermine erlauben" Margin="0,5,0,5"/>
                        
                        <CheckBox Grid.Row="6" Grid.Column="0" Grid.ColumnSpan="2" Name="chkWorkHoursOnly" Content="Nur während Arbeitszeiten buchen" Margin="0,5,0,5"/>
                        
                        <TextBlock Grid.Row="7" Grid.Column="0" Text="Nachreservierungszeit (Min):" Margin="0,5,10,5" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="7" Grid.Column="1" Name="txtPostReservationTime" Margin="0,5,0,5"/>
                    </Grid>
                </GroupBox>
                
                <GroupBox Header="Konfliktbehandlung" Margin="0,5,0,10">
                    <Grid Margin="5">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        
                        <TextBlock Grid.Row="0" Grid.Column="0" Text="Erlaubter Konfliktprozentsatz:" Margin="0,5,10,5" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="0" Grid.Column="1" Name="txtConflictPercentage" Margin="0,5,0,5"/>
                        
                        <TextBlock Grid.Row="1" Grid.Column="0" Text="Maximale Konfliktinstanzen:" Margin="0,5,10,5" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="1" Grid.Column="1" Name="txtMaxConflictInstances" Margin="0,5,0,5"/>
                    </Grid>
                </GroupBox>
                
                <GroupBox Header="Terminverarbeitung" Margin="0,5,0,10">
                    <Grid Margin="5">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        
                        <CheckBox Grid.Row="0" Grid.Column="0" Name="chkDeleteComments" Content="Kommentare löschen" Margin="0,5,0,5"/>
                        <CheckBox Grid.Row="0" Grid.Column="1" Name="chkDeleteSubject" Content="Betreff löschen" Margin="0,5,0,5"/>
                        
                        <CheckBox Grid.Row="1" Grid.Column="0" Name="chkRemovePrivate" Content="Private Markierung entfernen" Margin="0,5,0,5"/>
                        <CheckBox Grid.Row="1" Grid.Column="1" Name="chkAddOrganizer" Content="Organisator zum Betreff hinzufügen" Margin="0,5,0,5"/>
                        
                        <CheckBox Grid.Row="2" Grid.Column="0" Name="chkProcessExternal" Content="Externe Termine verarbeiten" Margin="0,5,0,5"/>
                        <CheckBox Grid.Row="2" Grid.Column="1" Name="chkRemoveOldMessages" Content="Alte Nachrichten entfernen" Margin="0,5,0,5"/>
                        
                        <CheckBox Grid.Row="3" Grid.Column="0" Name="chkDeleteNonCalendar" Content="Nicht-Kalender-Elemente löschen" Margin="0,5,0,5"/>
                        <CheckBox Grid.Row="3" Grid.Column="1" Name="chkForwardToDelegates" Content="An Delegaten weiterleiten" Margin="0,5,0,5"/>
                        
                        <CheckBox Grid.Row="4" Grid.Column="0" Name="chkTentativePending" Content="Vorläufig bei Genehmigung" Margin="0,5,0,5"/>
                        <CheckBox Grid.Row="4" Grid.Column="1" Name="chkEnableResponseDetails" Content="Antwortdetails aktivieren" Margin="0,5,0,5"/>
                        
                        <CheckBox Grid.Row="5" Grid.Column="0" Name="chkOrganizerInfo" Content="Organisator-Informationen" Margin="0,5,0,5"/>
                        <CheckBox Grid.Row="5" Grid.Column="1" Name="chkAddAdditionalResponse" Content="Zusätzliche Antwort hinzufügen" Margin="0,5,0,5"/>
                    </Grid>
                </GroupBox>
                
                <GroupBox Header="Zusätzliche Antwort" Margin="0,5,0,10">
                    <Grid Margin="5">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        
                        <TextBox Grid.Row="0" Name="txtAdditionalResponse" Height="60" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" Margin="0,5,0,5"/>
                    </Grid>
                </GroupBox>
                
                <GroupBox Header="Ressourcen-Delegaten" Margin="0,5,0,10">
                    <Grid Margin="5">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        
                        <TextBox Grid.Row="0" Name="txtResourceDelegates" Margin="0,5,0,5"/>
                    </Grid>
                </GroupBox>
            </StackPanel>
        </ScrollViewer>
        
        <!-- Rechte Spalte - Berechtigungen -->
        <GroupBox Grid.Row="1" Grid.Column="1" Header="Ressourcenberechtigungen" Background="{DynamicResource SurfaceBrush}">
            <Grid Margin="10">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                
                <TextBlock Grid.Row="0" Text="Aktuelle Berechtigungen für diese Ressource:" Margin="0,0,0,10" FontWeight="SemiBold"/>
                
                <DataGrid
                    Grid.Row="1"
                    Name="dgResourcePermissions"
                    AutoGenerateColumns="False"
                    IsReadOnly="True"
                    GridLinesVisibility="Horizontal"
                    HeadersVisibility="Column"
                    CanUserResizeColumns="True"
                    CanUserSortColumns="True">
                    <DataGrid.Columns>
                        <DataGridTextColumn
                            Width="*"
                            Binding="{Binding User}"
                            Header="Benutzer" />
                        <DataGridTextColumn
                            Width="100"
                            Binding="{Binding PermissionType}"
                            Header="Typ" />
                        <DataGridTextColumn
                            Width="*"
                            Binding="{Binding AccessRights}"
                            Header="Zugriffsrechte" />
                        <DataGridCheckBoxColumn
                            Width="80"
                            Binding="{Binding IsInherited}"
                            Header="Vererbt" />
                        <DataGridCheckBoxColumn
                            Width="60"
                            Binding="{Binding Deny}"
                            Header="Verweigern" />
                    </DataGrid.Columns>
                </DataGrid>
                
                <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
                    <Button Name="btnRefreshPermissions" Content="Aktualisieren" Width="100" Margin="0,0,10,0"/>
                    <Button Name="btnExportPermissions" Content="Exportieren (CSV)" Width="120"/>
                </StackPanel>
            </Grid>
        </GroupBox>
        
        <StackPanel Grid.Row="2" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button Name="btnSave" Content="Speichern" Width="100" Margin="0,0,10,0"/>
            <Button Name="btnCancel" Content="Abbrechen" Width="100"/>
        </StackPanel>
    </Grid>
</Window>
"@
        
        # XAML laden und Fenster erstellen
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
        $null = Add-ThemeResource -Window $window
        
        # UI-Elemente referenzieren
        $txtResourceHeader = $window.FindName("txtResourceHeader")
        # Exchange-Daten erst nach dem Laden setzen (keine Interpolation in das XAML-Markup)
        $txtResourceHeader.Text = "Ressourceneinstellungen für: $($resourceSettings.DisplayName)"
        $txtDisplayName = $window.FindName("txtDisplayName")
        $txtCapacity = $window.FindName("txtCapacity")
        $txtLocation = $window.FindName("txtLocation")
        $chkAutoAccept = $window.FindName("chkAutoAccept")
        $chkAllowConflicts = $window.FindName("chkAllowConflicts")
        $txtBookingWindow = $window.FindName("txtBookingWindow")
        $txtMaxDuration = $window.FindName("txtMaxDuration")
        $txtMinDuration = $window.FindName("txtMinDuration")
        $chkAllowRecurring = $window.FindName("chkAllowRecurring")
        $chkWorkHoursOnly = $window.FindName("chkWorkHoursOnly")
        $txtPostReservationTime = $window.FindName("txtPostReservationTime")
        $txtConflictPercentage = $window.FindName("txtConflictPercentage")
        $txtMaxConflictInstances = $window.FindName("txtMaxConflictInstances")
        $chkDeleteComments = $window.FindName("chkDeleteComments")
        $chkDeleteSubject = $window.FindName("chkDeleteSubject")
        $chkRemovePrivate = $window.FindName("chkRemovePrivate")
        $chkAddOrganizer = $window.FindName("chkAddOrganizer")
        $chkProcessExternal = $window.FindName("chkProcessExternal")
        $chkRemoveOldMessages = $window.FindName("chkRemoveOldMessages")
        $chkDeleteNonCalendar = $window.FindName("chkDeleteNonCalendar")
        $chkForwardToDelegates = $window.FindName("chkForwardToDelegates")
        $chkTentativePending = $window.FindName("chkTentativePending")
        $chkEnableResponseDetails = $window.FindName("chkEnableResponseDetails")
        $chkOrganizerInfo = $window.FindName("chkOrganizerInfo")
        $chkAddAdditionalResponse = $window.FindName("chkAddAdditionalResponse")
        $txtAdditionalResponse = $window.FindName("txtAdditionalResponse")
        $txtResourceDelegates = $window.FindName("txtResourceDelegates")
        $dgResourcePermissions = $window.FindName("dgResourcePermissions")
        $btnRefreshPermissions = $window.FindName("btnRefreshPermissions")
        $btnExportPermissions = $window.FindName("btnExportPermissions")
        $btnSave = $window.FindName("btnSave")
        $btnCancel = $window.FindName("btnCancel")
        
        # Werte in die UI-Elemente laden oder Platzhalter setzen
        $txtDisplayName.Text = if ($resourceSettings.DisplayName) { $resourceSettings.DisplayName } else { "" }
        $txtDisplayName.Tag = "z.B. Konferenzraum Berlin"
        
        $txtCapacity.Text = if ($resourceSettings.Capacity) { $resourceSettings.Capacity.ToString() } else { "" }
        $txtCapacity.Tag = "z.B. 12"
        
        $txtLocation.Text = if ($resourceSettings.Location) { $resourceSettings.Location } else { "" }
        $txtLocation.Tag = "z.B. Gebäude A, 2. Stock"
        
        $chkAutoAccept.IsChecked = $resourceSettings.AutoAccept
        $chkAllowConflicts.IsChecked = $resourceSettings.AllowConflicts
        
        $txtBookingWindow.Text = if ($resourceSettings.BookingWindowInDays) { $resourceSettings.BookingWindowInDays.ToString() } else { "" }
        $txtBookingWindow.Tag = "z.B. 180"
        
        $txtMaxDuration.Text = if ($resourceSettings.MaximumDurationInMinutes) { $resourceSettings.MaximumDurationInMinutes.ToString() } else { "" }
        $txtMaxDuration.Tag = "z.B. 480"
        
        $txtMinDuration.Text = if ($null -ne $resourceSettings.MinimumDurationInMinutes) { $resourceSettings.MinimumDurationInMinutes.ToString() } else { "" }
        $txtMinDuration.Tag = "z.B. 15"
        
        $chkAllowRecurring.IsChecked = $resourceSettings.AllowRecurringMeetings
        $chkWorkHoursOnly.IsChecked = $resourceSettings.ScheduleOnlyDuringWorkHours
        
        $txtPostReservationTime.Text = if ($resourceSettings.PostReservationMaxClaimTimeInMinutes) { $resourceSettings.PostReservationMaxClaimTimeInMinutes.ToString() } else { "" }
        $txtPostReservationTime.Tag = "z.B. 10"
        
        $txtConflictPercentage.Text = if ($resourceSettings.ConflictPercentageAllowed) { $resourceSettings.ConflictPercentageAllowed.ToString() } else { "" }
        $txtConflictPercentage.Tag = "z.B. 0"
        
        $txtMaxConflictInstances.Text = if ($resourceSettings.MaximumConflictInstances) { $resourceSettings.MaximumConflictInstances.ToString() } else { "" }
        $txtMaxConflictInstances.Tag = "z.B. 0"
        
        $chkDeleteComments.IsChecked = $resourceSettings.DeleteComments
        $chkDeleteSubject.IsChecked = $resourceSettings.DeleteSubject
        $chkRemovePrivate.IsChecked = $resourceSettings.RemovePrivateProperty
        $chkAddOrganizer.IsChecked = $resourceSettings.AddOrganizerToSubject
        $chkProcessExternal.IsChecked = $resourceSettings.ProcessExternalMeetingMessages
        $chkRemoveOldMessages.IsChecked = $resourceSettings.RemoveOldMeetingMessages
        $chkDeleteNonCalendar.IsChecked = $resourceSettings.DeleteNonCalendarItems
        $chkForwardToDelegates.IsChecked = $resourceSettings.ForwardRequestsToDelegates
        $chkTentativePending.IsChecked = $resourceSettings.TentativePendingApproval
        $chkEnableResponseDetails.IsChecked = $resourceSettings.EnableResponseDetails
        $chkOrganizerInfo.IsChecked = $resourceSettings.OrganizerInfo
        $chkAddAdditionalResponse.IsChecked = $resourceSettings.AddAdditionalResponse
        
        $txtAdditionalResponse.Text = if ($resourceSettings.AdditionalResponse) { $resourceSettings.AdditionalResponse } else { "" }
        $txtAdditionalResponse.Tag = "z.B. Bitte beachten Sie die Hausordnung."
        
        $txtResourceDelegates.Text = if ($resourceSettings.ResourceDelegates) { ($resourceSettings.ResourceDelegates -join "; ") } else { "" }
        $txtResourceDelegates.Tag = "z.B. admin@firma.de; manager@firma.de"
        
        # Berechtigungen in DataGrid laden
        $dgResourcePermissions.ItemsSource = $resourcePermissions
        
        # Platzhalter-Funktionalität für TextBoxen
        $textBoxes = @($txtDisplayName, $txtCapacity, $txtLocation, $txtBookingWindow, $txtMaxDuration, $txtMinDuration, 
                      $txtPostReservationTime, $txtConflictPercentage, $txtMaxConflictInstances, $txtAdditionalResponse, $txtResourceDelegates)
        
        foreach ($textBox in $textBoxes) {
            # GotFocus Event - Platzhalter entfernen ($this = auslösende TextBox)
            $textBox.Add_GotFocus({
                if ($null -ne $this.Tag -and $this.Text -eq [string]$this.Tag) {
                    $this.Text = ""
                    $this.ClearValue([System.Windows.Controls.Control]::ForegroundProperty)
                }
            })
            
            # LostFocus Event - Platzhalter anzeigen wenn leer
            $textBox.Add_LostFocus({
                if ([string]::IsNullOrEmpty($this.Text) -and $null -ne $this.Tag) {
                    $this.Text = [string]$this.Tag
                    $this.SetResourceReference([System.Windows.Controls.Control]::ForegroundProperty, "TextSecondaryBrush")
                }
            })
            
            # Initialer Platzhalter wenn Feld leer ist
            if ($textBox.Text -eq "" -and $textBox.Tag) {
                $textBox.Text = $textBox.Tag
                $textBox.SetResourceReference([System.Windows.Controls.Control]::ForegroundProperty, "TextSecondaryBrush")
            }
        }
        
        # Event-Handler für Berechtigungen aktualisieren
        $btnRefreshPermissions.Add_Click({
            try {
                $updatedPermissions = @(Get-ResourcePermissionsAction -Identity $Identity)
                $dgResourcePermissions.ItemsSource = $updatedPermissions
                [System.Windows.MessageBox]::Show("Berechtigungen wurden erfolgreich aktualisiert.", 
                    "Aktualisiert", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            }
            catch {
                $errorMsg = $_.Exception.Message
                [System.Windows.MessageBox]::Show("Fehler beim Aktualisieren der Berechtigungen: $errorMsg", 
                    "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        })
        
        # Event-Handler für Berechtigungen exportieren
        $btnExportPermissions.Add_Click({
            try {
                $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
                $saveDialog.Filter = "CSV-Dateien (*.csv)|*.csv"
                $saveDialog.FileName = "Ressourcenberechtigungen_$($resourceSettings.Name)_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                
                if ($saveDialog.ShowDialog() -eq $true) {
                    $dgResourcePermissions.ItemsSource | ConvertTo-SafeCsvObject | Export-Csv -Path $saveDialog.FileName -NoTypeInformation -Encoding UTF8 -Delimiter ";"
                    [System.Windows.MessageBox]::Show("Berechtigungen wurden erfolgreich exportiert nach: $($saveDialog.FileName)", 
                        "Export erfolgreich", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                [System.Windows.MessageBox]::Show("Fehler beim Exportieren der Berechtigungen: $errorMsg", 
                    "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        })
        
        # Event-Handler für Speichern-Button
        $btnSave.Add_Click({
            try {
                # Parameter sammeln - nur wenn Werte nicht Platzhalter sind
                $params = @{
                    Identity = $Identity
                }
                
                # Ganzzahlfelder prüfen (ein angezeigter Platzhalter gilt als leer). Ungültige Eingaben werden
                # gemeldet, statt sie stillschweigend zu verwerfen.
                $intFields = @(
                    @{ Box = $txtCapacity; Param = "Capacity"; Label = "Kapazität"; Min = 1 }
                    @{ Box = $txtBookingWindow; Param = "BookingWindowInDays"; Label = "Buchungszeitraum (Tage)"; Min = 1 }
                    @{ Box = $txtMaxDuration; Param = "MaximumDurationInMinutes"; Label = "Maximale Dauer (Minuten)"; Min = 1 }
                    @{ Box = $txtMinDuration; Param = "MinimumDurationInMinutes"; Label = "Minimale Dauer (Minuten)"; Min = 0 }
                    @{ Box = $txtPostReservationTime; Param = "PostReservationMaxClaimTimeInMinutes"; Label = "Nachreservierungszeit (Min)"; Min = 1 }
                    @{ Box = $txtConflictPercentage; Param = "ConflictPercentageAllowed"; Label = "Erlaubter Konfliktprozentsatz"; Min = 0 }
                    @{ Box = $txtMaxConflictInstances; Param = "MaximumConflictInstances"; Label = "Maximale Konfliktinstanzen"; Min = 0 }
                )
                foreach ($intField in $intFields) {
                    $fieldText = [string]$intField.Box.Text
                    if ([string]::IsNullOrWhiteSpace($fieldText) -or $fieldText -eq [string]$intField.Box.Tag) { continue }
                    $fieldValue = 0
                    if (-not [int]::TryParse($fieldText, [ref]$fieldValue) -or $fieldValue -lt $intField.Min) {
                        Show-MessageBox -Message "Ungültiger Wert für '$($intField.Label)': '$fieldText'.`nBitte geben Sie eine ganze Zahl ab $($intField.Min) ein oder lassen Sie das Feld leer." -Title "Ungültige Eingabe" -Type Warning
                        [void]$intField.Box.Focus()
                        return
                    }
                    $params[$intField.Param] = $fieldValue
                }
                
                if ($txtDisplayName.Text -ne "" -and $txtDisplayName.Text -ne $txtDisplayName.Tag) {
                    $params.Add("DisplayName", $txtDisplayName.Text)
                }
                
                if ($txtLocation.Text -ne "" -and $txtLocation.Text -ne $txtLocation.Tag) {
                    $params.Add("Location", $txtLocation.Text)
                }
                
                if ([bool]$chkAutoAccept.IsChecked -ne [bool]$resourceSettings.AutoAccept) {
                    $params.Add("AutoAccept", [bool]$chkAutoAccept.IsChecked)
                }
                $params.Add("AllowConflicts", $chkAllowConflicts.IsChecked)
                
                $params.Add("AllowRecurringMeetings", $chkAllowRecurring.IsChecked)
                $params.Add("ScheduleOnlyDuringWorkHours", $chkWorkHoursOnly.IsChecked)
                
                $params.Add("DeleteComments", $chkDeleteComments.IsChecked)
                $params.Add("DeleteSubject", $chkDeleteSubject.IsChecked)
                $params.Add("RemovePrivateProperty", $chkRemovePrivate.IsChecked)
                $params.Add("AddOrganizerToSubject", $chkAddOrganizer.IsChecked)
                $params.Add("ProcessExternalMeetingMessages", $chkProcessExternal.IsChecked)
                $params.Add("RemoveOldMeetingMessages", $chkRemoveOldMessages.IsChecked)
                $params.Add("DeleteNonCalendarItems", $chkDeleteNonCalendar.IsChecked)
                $params.Add("ForwardRequestsToDelegates", $chkForwardToDelegates.IsChecked)
                $params.Add("TentativePendingApproval", $chkTentativePending.IsChecked)
                $params.Add("EnableResponseDetails", $chkEnableResponseDetails.IsChecked)
                $params.Add("OrganizerInfo", $chkOrganizerInfo.IsChecked)
                $params.Add("AddAdditionalResponse", $chkAddAdditionalResponse.IsChecked)
                
                if ($txtAdditionalResponse.Text -ne "" -and $txtAdditionalResponse.Text -ne $txtAdditionalResponse.Tag) {
                    $params.Add("AdditionalResponse", $txtAdditionalResponse.Text)
                }
                
                $delegatesText = if ($txtResourceDelegates.Text -eq [string]$txtResourceDelegates.Tag) { "" } else { $txtResourceDelegates.Text }
                $delegatesArray = @($delegatesText -split ";" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
                $params.Add("ResourceDelegates", $delegatesArray)
                
                # Ressourceneinstellungen aktualisieren
                $result = Update-ResourceSettingsAction @params
                
                if ($result) {
                    [System.Windows.MessageBox]::Show("Die Ressourceneinstellungen wurden erfolgreich aktualisiert.", 
                        "Erfolg", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                    $window.DialogResult = $true
                    $window.Close()
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                [System.Windows.MessageBox]::Show("Fehler beim Aktualisieren der Ressourceneinstellungen: $errorMsg", 
                    "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        })
        
        # Event-Handler für Abbrechen-Button
        $btnCancel.Add_Click({
            $window.DialogResult = $false
            $window.Close()
        })
        
        # Dialog anzeigen
        $result = $window.ShowDialog()
        
        return $result
    }
    catch {
        $errorMsg = $_.Exception.Message
        Log-Action "Fehler beim Öffnen des Ressourceneinstellungen-Dialogs: $errorMsg"
        throw $_
    }
}


function Initialize-ResourcesTab {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Initialisiere Ressourcen-Tab..." -Type "Info"

        # UI-Elemente für Ressourcen referenzieren basierend auf dem neuen XAML
        $helpLinkResources = Get-XamlElement -ElementName "helpLinkResources"
        $cmbResourceType = Get-XamlElement -ElementName "cmbResourceType"
        $txtResourceName = Get-XamlElement -ElementName "txtResourceName"
        $btnCreateResource = Get-XamlElement -ElementName "btnCreateResource"
        $txtResourceSearch = Get-XamlElement -ElementName "txtResourceSearch"
        $btnSearchResources = Get-XamlElement -ElementName "btnSearchResources"
        $btnRefreshResources = Get-XamlElement -ElementName "btnRefreshResources"
        $btnShowRoomResources = Get-XamlElement -ElementName "btnShowRoomResources"
        $btnShowEquipmentResources = Get-XamlElement -ElementName "btnShowEquipmentResources"
        $cmbResourceSelect = Get-XamlElement -ElementName "cmbResourceSelect"
        $btnRefreshResourceList = Get-XamlElement -ElementName "btnRefreshResourceList"
        $btnEditResourceSettings = Get-XamlElement -ElementName "btnEditResourceSettings"
        $btnRemoveResource = Get-XamlElement -ElementName "btnRemoveResource"
        $dgResources = Get-XamlElement -ElementName "dgResources"
        $btnExportResources = Get-XamlElement -ElementName "btnExportResources"

        # Globale Script-Variablen für die UI-Elemente setzen
        $script:cmbResourceType = $cmbResourceType
        $script:txtResourceName = $txtResourceName
        $script:txtResourceSearch = $txtResourceSearch
        $script:cmbResourceSelect = $cmbResourceSelect
        $script:dgResources = $dgResources
        # Wird in Click-Handlern (nach Ende dieser Funktion) für die Listenaktualisierung benötigt
        $script:btnRefreshResources = $btnRefreshResources

        # Event-Handler für "Alle anzeigen"
        Register-EventHandler -Control $btnRefreshResources -Handler {
            try {
            if (-not $script:isConnected) { 
                Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                Update-StatusBar -Message "Keine Verbindung zu Exchange Online." -Type Warning
                return
            }
            
            Update-StatusBar -Message "Lade alle Ressourcen..." -Type Info
            $allResources = @(Get-AllResourcesAction)
            
            # Thread-sichere UI-Aktualisierung
            $script:dgResources.Dispatcher.Invoke([Action]{
                $script:dgResources.ItemsSource = $allResources
            }, "Normal")
            
            $script:cmbResourceSelect.Dispatcher.Invoke([Action]{
                $script:cmbResourceSelect.Items.Clear()
                if ($allResources.Count -gt 0) {
                foreach ($resource in $allResources) {
                    if ($null -ne $resource.PrimarySmtpAddress) {
                    [void]$script:cmbResourceSelect.Items.Add($resource.PrimarySmtpAddress)
                    }
                }
                if ($script:cmbResourceSelect.Items.Count -gt 0) {
                    $script:cmbResourceSelect.SelectedIndex = 0
                }
                }
            }, "Normal")
            
            Update-StatusBar -Message "$($allResources.Count) Ressource(n) geladen." -Type Success
            Write-Log "Alle Ressourcen erfolgreich geladen: $($allResources.Count) Einträge" -Type Success
            
            } catch {
            $errorMsg = $_.Exception.Message
            Write-Log "Fehler beim Laden aller Ressourcen: $errorMsg" -Type Error
            Update-StatusBar -Message "Fehler beim Laden der Ressourcen: $errorMsg" -Type Error
            Show-MessageBox -Message "Fehler beim Laden der Ressourcen:`n$errorMsg" -Title "Fehler" -Type Error
            }
        } -ControlName "btnRefreshResources"

        # Event-Handler für "Nur Räume"
        Register-EventHandler -Control $btnShowRoomResources -Handler {
            try {
            if (-not $script:isConnected) { 
                Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                Update-StatusBar -Message "Keine Verbindung zu Exchange Online." -Type Warning
                return
            }
            
            Update-StatusBar -Message "Lade Raumressourcen..." -Type Info
            $rooms = @(Get-RoomResourcesAction)
            
            # Thread-sichere UI-Aktualisierung
            $script:dgResources.Dispatcher.Invoke([Action]{
                $script:dgResources.ItemsSource = $rooms
            }, "Normal")
            
            $script:cmbResourceSelect.Dispatcher.Invoke([Action]{
                $script:cmbResourceSelect.Items.Clear()
                if ($rooms.Count -gt 0) {
                foreach ($room in $rooms) {
                    if ($null -ne $room.PrimarySmtpAddress) {
                    [void]$script:cmbResourceSelect.Items.Add($room.PrimarySmtpAddress)
                    }
                }
                if ($script:cmbResourceSelect.Items.Count -gt 0) {
                    $script:cmbResourceSelect.SelectedIndex = 0
                }
                }
            }, "Normal")
            
            Update-StatusBar -Message "$($rooms.Count) Raumressource(n) geladen." -Type Success
            Write-Log "Raumressourcen erfolgreich geladen: $($rooms.Count) Einträge" -Type Success
            
            } catch {
            $errorMsg = $_.Exception.Message
            Write-Log "Fehler beim Laden der Raumressourcen: $errorMsg" -Type Error
            Update-StatusBar -Message "Fehler beim Laden der Raumressourcen: $errorMsg" -Type Error
            Show-MessageBox -Message "Fehler beim Laden der Raumressourcen:`n$errorMsg" -Title "Fehler" -Type Error
            }
        } -ControlName "btnShowRoomResources"

        # Event-Handler für "Nur Ausstattung"
        Register-EventHandler -Control $btnShowEquipmentResources -Handler {
            try {
            if (-not $script:isConnected) { 
                Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                Update-StatusBar -Message "Keine Verbindung zu Exchange Online." -Type Warning
                return
            }
            
            Update-StatusBar -Message "Lade Ausstattungsressourcen..." -Type Info
            $equipment = Get-EquipmentResourcesAction
            
            if ($null -eq $equipment) {
                Write-Log "Get-EquipmentResourcesAction gab null zurück." -Type Warning
                $equipment = @()
            }
            
            # Sicherstellen, dass $equipment immer ein Array ist
            if ($equipment -isnot [array]) {
                $equipment = @($equipment)
            }
            
            # Thread-sichere UI-Aktualisierung
            $script:dgResources.Dispatcher.Invoke([Action]{
                $script:dgResources.ItemsSource = $equipment
            }, "Normal")
            
            $script:cmbResourceSelect.Dispatcher.Invoke([Action]{
                $script:cmbResourceSelect.Items.Clear()
                if ($equipment.Count -gt 0) {
                foreach ($item in $equipment) {
                    if ($null -ne $item.PrimarySmtpAddress) {
                    [void]$script:cmbResourceSelect.Items.Add($item.PrimarySmtpAddress)
                    }
                }
                if ($script:cmbResourceSelect.Items.Count -gt 0) {
                    $script:cmbResourceSelect.SelectedIndex = 0
                }
                }
            }, "Normal")
            
            Update-StatusBar -Message "$($equipment.Count) Ausstattungsressource(n) geladen." -Type Success
            Write-Log "Ausstattungsressourcen erfolgreich geladen: $($equipment.Count) Einträge" -Type Success
            
            } catch {
            $errorMsg = $_.Exception.Message
            Write-Log "Fehler beim Laden der Ausstattungsressourcen: $errorMsg" -Type Error
            Update-StatusBar -Message "Fehler beim Laden der Ausstattungsressourcen: $errorMsg" -Type Error
            Show-MessageBox -Message "Fehler beim Laden der Ausstattungsressourcen:`n$errorMsg" -Title "Fehler" -Type Error
            }
        } -ControlName "btnShowEquipmentResources"

        # Event-Handler für "Suchen"
        Register-EventHandler -Control $btnSearchResources -Handler {
            try {
            if (-not $script:isConnected) { 
                Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                Update-StatusBar -Message "Keine Verbindung zu Exchange Online." -Type Warning
                return
            }
            
            $searchTerm = $script:txtResourceSearch.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($searchTerm)) { 
                Show-MessageBox -Message "Bitte geben Sie einen Suchbegriff ein." -Title "Suchbegriff fehlt" -Type Warning
                Update-StatusBar -Message "Kein Suchbegriff eingegeben." -Type Warning
                return
            }
            
            # Sicherheitsprüfung: Mindestlänge des Suchbegriffs
            if ($searchTerm.Length -lt 2) {
                Show-MessageBox -Message "Der Suchbegriff muss mindestens 2 Zeichen lang sein." -Title "Suchbegriff zu kurz" -Type Warning
                Update-StatusBar -Message "Suchbegriff zu kurz (mindestens 2 Zeichen)." -Type Warning
                return
            }
            
            Update-StatusBar -Message "Suche nach Ressourcen mit '$searchTerm'..." -Type Info
            $foundResources = Search-ResourcesAction -SearchTerm $searchTerm
            
            if ($null -eq $foundResources) {
                Write-Log "Search-ResourcesAction gab null zurück." -Type Warning
                $foundResources = @()
            }
            
            # Sicherstellen, dass $foundResources immer ein Array ist
            if ($foundResources -isnot [array]) {
                $foundResources = @($foundResources)
            }
            
            # Thread-sichere UI-Aktualisierung
            $script:dgResources.Dispatcher.Invoke([Action]{
                $script:dgResources.ItemsSource = $foundResources
            }, "Normal")
            
            $script:cmbResourceSelect.Dispatcher.Invoke([Action]{
                $script:cmbResourceSelect.Items.Clear()
                if ($foundResources.Count -gt 0) {
                foreach ($resource in $foundResources) {
                    if ($null -ne $resource.PrimarySmtpAddress) {
                    [void]$script:cmbResourceSelect.Items.Add($resource.PrimarySmtpAddress)
                    }
                }
                if ($script:cmbResourceSelect.Items.Count -gt 0) {
                    $script:cmbResourceSelect.SelectedIndex = 0
                }
                }
            }, "Normal")
            
            $resultMessage = if ($foundResources.Count -eq 0) {
                "Keine Ressourcen mit '$searchTerm' gefunden."
            } else {
                "$($foundResources.Count) Ressource(n) mit '$searchTerm' gefunden."
            }
            
            Update-StatusBar -Message $resultMessage -Type Success
            Write-Log "Ressourcensuche abgeschlossen: $resultMessage" -Type Success
            
            # Zusätzliche Information bei keinen Ergebnissen
            if ($foundResources.Count -eq 0) {
                Show-MessageBox -Message "Es wurden keine Ressourcen gefunden, die '$searchTerm' enthalten. Versuchen Sie einen anderen Suchbegriff." -Title "Keine Ergebnisse" -Type Info
            }
            
            } catch {
            $errorMsg = $_.Exception.Message
            Write-Log "Fehler bei der Ressourcensuche: $errorMsg" -Type Error
            Update-StatusBar -Message "Fehler bei der Ressourcensuche: $errorMsg" -Type Error
            Show-MessageBox -Message "Fehler bei der Ressourcensuche:`n$errorMsg" -Title "Suchfehler" -Type Error
            }
        } -ControlName "btnSearchResources"


        # Event-Handler für "Ressourcenliste aktualisieren" (ComboBox)
        Register-EventHandler -Control $btnRefreshResourceList -Handler {
            try {
                if (-not $script:isConnected) { Throw "Keine Verbindung zu Exchange Online." }
                Update-StatusBar -Message "Aktualisiere Ressourcenliste..." -Type Info
                $allResources = @(Get-AllResourcesAction)
                
                # Thread-sichere UI-Aktualisierung der ComboBox
                $script:cmbResourceSelect.Dispatcher.Invoke([Action]{
                    # Aktuell ausgewähltes Element merken
                    $currentSelection = $script:cmbResourceSelect.SelectedItem
                    
                    # ComboBox leeren und neu befüllen
                    $script:cmbResourceSelect.Items.Clear()
                    
                    if ($allResources.Count -gt 0) {
                        # Ressourcen nach PrimarySmtpAddress sortieren (A-Z)
                        $sortedResourceEmails = $allResources | ForEach-Object { $_.PrimarySmtpAddress } | Sort-Object
                        
                        foreach ($email in $sortedResourceEmails) {
                            if (-not [string]::IsNullOrWhiteSpace($email)) {
                                [void]$script:cmbResourceSelect.Items.Add($email)
                            }
                        }
                        
                        # Versuche die vorherige Auswahl wiederherzustellen
                        if ($null -ne $currentSelection -and $script:cmbResourceSelect.Items.Contains($currentSelection)) {
                            $script:cmbResourceSelect.SelectedItem = $currentSelection
                        } elseif ($script:cmbResourceSelect.Items.Count -gt 0) {
                            $script:cmbResourceSelect.SelectedIndex = 0
                        }
                        
                        # ComboBox explizit aktualisieren
                        $script:cmbResourceSelect.UpdateLayout()
                        $script:cmbResourceSelect.InvalidateVisual()
                    }
                }, "Normal")
                
                Update-StatusBar -Message "Ressourcenliste aktualisiert ($($allResources.Count) Einträge)." -Type Success
                Write-Log "Ressourcenliste erfolgreich aktualisiert: $($allResources.Count) Einträge" -Type Success
                
            } catch { 
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Aktualisieren der Ressourcenliste: $errorMsg" -Type Error
                Update-StatusBar -Message "Fehler beim Aktualisieren der Ressourcenliste: $errorMsg" -Type Error
            }
        } -ControlName "btnRefreshResourceList"

        # Event-Handler für "Ressource erstellen"
        Register-EventHandler -Control $btnCreateResource -Handler {
            try {
                if (-not $script:isConnected) { Throw "Keine Verbindung zu Exchange Online." }
                $name = $script:txtResourceName.Text
                $type = if ($script:cmbResourceType.SelectedItem.Content -eq "Raum") { "Room" } else { "Equipment" }

                if ([string]::IsNullOrWhiteSpace($name)) {
                    Throw "Name der Ressource darf nicht leer sein."
                }
                
                $result = New-ResourceAction -Name $name -DisplayName $name -ResourceType $type
                
                if ($result) { 
                    Update-StatusBar -Message "Ressource '$name' erfolgreich erstellt." -Type "Success"
                    $script:txtResourceName.Text = ""
                    # Optional: Ressourcenliste aktualisieren
                    if ($null -ne $script:btnRefreshResources) { $script:btnRefreshResources.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent)) }
                }
            } catch {
                Update-StatusBar -Message "Fehler: $($_.Exception.Message)" -Type "Error"
            }
        } -ControlName "btnCreateResource"

        # Event-Handler für "Einstellungen bearbeiten"
        Register-EventHandler -Control $btnEditResourceSettings -Handler {
            try {
                if (-not $script:isConnected) { Throw "Keine Verbindung zu Exchange Online." }
                $selectedResource = $script:cmbResourceSelect.SelectedItem
                if ($null -eq $selectedResource) { Throw "Bitte wählen Sie eine Ressource aus." }
                
                $result = Show-ResourceSettingsDialog -Identity $selectedResource
                
                if ($result) {
                    Update-StatusBar -Message "Einstellungen für '$selectedResource' aktualisiert." -Type "Success"
                    # Ressourcenliste aktualisieren
                    if ($null -ne $script:btnRefreshResources) { $script:btnRefreshResources.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent)) }
                } else {
                    Update-StatusBar -Message "Bearbeitung abgebrochen." -Type "Info"
                }
            } catch {
                Update-StatusBar -Message "Fehler: $($_.Exception.Message)" -Type "Error"
            }
        } -ControlName "btnEditResourceSettings"

        # Event-Handler für "Ressource löschen"
        Register-EventHandler -Control $btnRemoveResource -Handler {
            try {
                if (-not $script:isConnected) { Throw "Keine Verbindung zu Exchange Online." }
                $selectedResource = $script:cmbResourceSelect.SelectedItem
                if ($null -eq $selectedResource) { Throw "Bitte wählen Sie eine Ressource aus." }

                $confirm = [System.Windows.MessageBox]::Show("Möchten Sie die Ressource '$selectedResource' wirklich löschen?", "Bestätigung", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)

                if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
                    $result = Remove-ResourceAction -Identity $selectedResource
                    if ($result) { 
                        Update-StatusBar -Message "Ressource '$selectedResource' gelöscht." -Type "Success"
                        # Ressourcenliste aktualisieren
                        if ($null -ne $script:btnRefreshResources) { $script:btnRefreshResources.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent)) }
                    }
                }
            } catch {
                Update-StatusBar -Message "Fehler: $($_.Exception.Message)" -Type "Error"
            }
        } -ControlName "btnRemoveResource"

        # Event-Handler für "Ressourcenliste exportieren"
        Register-EventHandler -Control $btnExportResources -Handler {
            try {
                if ($null -eq $script:dgResources.ItemsSource -or $script:dgResources.Items.Count -eq 0) {
                    Throw "Keine Ressourcen zum Exportieren vorhanden."
                }
                
                $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
                $saveFileDialog.Filter = "CSV-Dateien (*.csv)|*.csv|Alle Dateien (*.*)|*.*"
                $saveFileDialog.Title = "Ressourcenliste exportieren"
                $saveFileDialog.FileName = "Ressourcenliste_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                
                if ($saveFileDialog.ShowDialog() -eq $true) {
                    Export-ResourcesAction -Resources $script:dgResources.ItemsSource -FilePath $saveFileDialog.FileName
                    Update-StatusBar -Message "Ressourcen erfolgreich exportiert." -Type "Success"
                }
            } catch {
                Update-StatusBar -Message "Fehler: $($_.Exception.Message)" -Type "Error"
            }
        } -ControlName "btnExportResources"

        # Event-Handler für Hilfe-Link
        if ($null -ne $helpLinkResources) {
            $helpLinkResources.Add_MouseLeftButtonDown({
                try { Show-HelpDialog -Topic "Resources" }
                catch { Write-Log "Fehler beim Öffnen des Hilfe-Dialogs für Ressourcen: $($_.Exception.Message)" -Type Error }
            })
        }

        Write-Log "Ressourcen-Tab erfolgreich initialisiert." -Type "Success"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Initialisieren des Ressourcen-Tabs: $errorMsg" -Type "Error"
        return $false
    }
}
