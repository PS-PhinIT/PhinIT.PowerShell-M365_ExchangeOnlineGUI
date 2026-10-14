# =====================================================================
# easyEXO - Modul: Berichte
# Datei: src/Modules/Features/Reports.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
#
# Die Berichte verwenden – sofern vorhanden – die REST-basierten EXO-V3-Cmdlets
# (Get-EXOMailbox, Get-EXOMailboxStatistics, Get-EXOMailboxPermission,
# Get-EXOMailboxFolderPermission). Statistiken werden per Pipeline im Block
# abgefragt statt einzeln pro Postfach. Alle Berichte zeigen Fortschritt an,
# lassen sich abbrechen und liefern bei Abbruch das bisherige Teilergebnis.
# =====================================================================

# Berichtskatalog: Name (Anzeige in cmbReportType), Kategorie (Tag in lstReportCategories),
# Key (interne Kennung) und ob der Benutzerfilter (txtReportUserFilter) berücksichtigt wird.
$script:ReportCatalog = @(
    [PSCustomObject]@{ Key = "MailboxSize";        Category = "mailbox";     UserFilter = $true;  Name = "Postfachgrößen" }
    [PSCustomObject]@{ Key = "LastLogon";          Category = "mailbox";     UserFilter = $true;  Name = "Letzte Anmeldung" }
    [PSCustomObject]@{ Key = "Forwarding";         Category = "mailbox";     UserFilter = $true;  Name = "Weiterleitungen (Postfach)" }
    [PSCustomObject]@{ Key = "ArchiveHold";        Category = "mailbox";     UserFilter = $true;  Name = "Archiv- und Aufbewahrungsstatus" }
    [PSCustomObject]@{ Key = "FullAccess";         Category = "permissions"; UserFilter = $true;  Name = "Postfachberechtigungen (Vollzugriff)" }
    [PSCustomObject]@{ Key = "SendAs";             Category = "permissions"; UserFilter = $true;  Name = "Senden als-Berechtigungen" }
    [PSCustomObject]@{ Key = "CalendarPermission"; Category = "permissions"; UserFilter = $true;  Name = "Kalenderberechtigungen" }
    [PSCustomObject]@{ Key = "SharedPermission";   Category = "permissions"; UserFilter = $true;  Name = "Shared Mailbox-Berechtigungen" }
    [PSCustomObject]@{ Key = "GroupMembers";       Category = "groups";      UserFilter = $false; Name = "Gruppenmitglieder (Verteilergruppen)" }
    [PSCustomObject]@{ Key = "UnifiedGroups";      Category = "groups";      UserFilter = $false; Name = "Microsoft 365-Gruppen" }
    [PSCustomObject]@{ Key = "GroupsWithoutOwner"; Category = "groups";      UserFilter = $false; Name = "Verteilergruppen ohne Besitzer" }
    [PSCustomObject]@{ Key = "Resources";          Category = "resources";   UserFilter = $true;  Name = "Raum- und Ressourcenpostfächer" }
    [PSCustomObject]@{ Key = "MailboxAudit";       Category = "audit";       UserFilter = $true;  Name = "Postfach-Überwachung (Audit-Status)" }
    [PSCustomObject]@{ Key = "ExternalForwarding"; Category = "audit";       UserFilter = $true;  Name = "Externe Weiterleitungen" }
)
$script:LastReportName = ""

function Test-ReportCommand {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

# Liefert eine eindeutige Identität eines Postfachs für Folgeabfragen
function Get-ReportMailboxIdentity {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        $Mailbox
    )

    foreach ($propertyName in @("ExchangeGuid", "UserPrincipalName", "PrimarySmtpAddress", "Identity")) {
        $value = [string]$Mailbox.$propertyName
        if (-not [string]::IsNullOrWhiteSpace($value) -and $value -ne "00000000-0000-0000-0000-000000000000") { return $value }
    }
    return [string]$Mailbox
}

# Wandelt TotalItemSize (ByteQuantifiedSize oder deserialisierte Zeichenfolge) in GB um
function ConvertTo-ReportSizeGB {
    [CmdletBinding()]
    param(
        $Size
    )

    if ($null -eq $Size) { return $null }
    try {
        if ($null -ne $Size.Value -and $null -ne $Size.Value.PSObject.Methods["ToBytes"]) {
            return [math]::Round($Size.Value.ToBytes() / 1GB, 2)
        }
    }
    catch {
        Write-Log "Postfachgröße konnte nicht direkt gelesen werden: $($_.Exception.Message)" -Type "Debug"
    }
    if ("$Size" -match '\(([\d\.,\s'']+) bytes\)') {
        $digits = $Matches[1] -replace '[^\d]', ''
        if (-not [string]::IsNullOrEmpty($digits)) { return [math]::Round([double]$digits / 1GB, 2) }
    }
    return $null
}

# Liefert die Postfächer für einen Bericht. Ist im Feld "Benutzer" etwas eingetragen,
# wird die Liste per -Anr (Name, Alias, Adresse - auch teilweise) eingeschränkt.
function Get-ReportMailboxes {
    [CmdletBinding()]
    param(
        [string[]]$RecipientTypeDetails,

        # Zusätzliche Eigenschaften für Get-EXOMailbox (Get-Mailbox liefert alle Eigenschaften)
        [string[]]$Properties,

        # Serverseitiger OPATH-Filter (nur ohne Benutzerfilter verwendet)
        [string]$Filter
    )

    $params = @{ ResultSize = "Unlimited"; ErrorAction = "Stop" }
    if ($RecipientTypeDetails.Count -gt 0) { $params["RecipientTypeDetails"] = $RecipientTypeDetails }
    if (-not [string]::IsNullOrWhiteSpace($script:ReportUserFilter)) {
        $params["Anr"] = $script:ReportUserFilter
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Filter)) {
        $params["Filter"] = $Filter
    }

    Update-UIBusy -Message "Lade Postfachliste..."
    if (Test-ReportCommand -Name "Get-EXOMailbox") {
        if ($Properties.Count -gt 0) { $params["Properties"] = $Properties }
        return @(Get-EXOMailbox @params | Step-UIProgress -Activity "Lade Postfachliste")
    }
    return @(Get-Mailbox @params | Step-UIProgress -Activity "Lade Postfachliste")
}

# Wandelt mehrwertige Eigenschaften in eine lesbare, CSV-taugliche Zeichenfolge um
function Join-ReportValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        $Value
    )

    if ($null -eq $Value) { return "" }
    return (@($Value) | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ", "
}

# Postfachgrößen / letzte Anmeldung: Statistiken werden per Pipeline (gebündelt) abgefragt
function Add-ReportMailboxStatistics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Mailboxes,

        [ValidateSet("Size", "Logon")]
        [string]$Mode = "Size",

        [Nullable[datetime]]$StartDate,

        [Nullable[datetime]]$EndDate
    )

    $mailboxLookup = @{}
    foreach ($mbx in $Mailboxes) {
        if ($null -ne $mbx.ExchangeGuid) { $mailboxLookup[[string]$mbx.ExchangeGuid] = $mbx }
    }
    $total = $Mailboxes.Count

    $addRow = {
        param($stat)
        $mailbox = $null
        if ($null -ne $stat.MailboxGuid) { $mailbox = $mailboxLookup[[string]$stat.MailboxGuid] }
        $address = if ($null -ne $mailbox) { [string]$mailbox.PrimarySmtpAddress } else { "" }
        $lastLogon = $stat.LastLogonTime

        if ($Mode -eq "Logon") {
            if ($null -ne $StartDate -or $null -ne $EndDate) {
                if ($null -eq $lastLogon) { return }
                $logonDate = [datetime]$lastLogon
                if ($null -ne $StartDate -and $logonDate -lt $StartDate.Date) { return }
                if ($null -ne $EndDate -and $logonDate -ge $EndDate.Date.AddDays(1)) { return }
            }
            $Results.Add([PSCustomObject]@{
                DisplayName        = $stat.DisplayName
                PrimarySmtpAddress = $address
                LastLogonTime      = $lastLogon
                ItemCount          = $stat.ItemCount
            })
        }
        else {
            $Results.Add([PSCustomObject]@{
                DisplayName        = $stat.DisplayName
                PrimarySmtpAddress = $address
                TotalItemSize      = [string]$stat.TotalItemSize
                TotalSizeGB        = ConvertTo-ReportSizeGB -Size $stat.TotalItemSize
                ItemCount          = $stat.ItemCount
                LastLogonTime      = $lastLogon
            })
        }
    }

    if ($total -eq 0) { return }

    if (Test-ReportCommand -Name "Get-EXOMailboxStatistics") {
        $Mailboxes |
            Get-EXOMailboxStatistics -Properties LastLogonTime -ErrorAction SilentlyContinue |
            Step-UIProgress -Activity "Lese Postfachstatistiken" -Total $total |
            ForEach-Object { & $addRow $_ }
    }
    else {
        $Mailboxes |
            ForEach-Object { Get-MailboxStatistics -Identity (Get-ReportMailboxIdentity -Mailbox $_) -ErrorAction SilentlyContinue } |
            Step-UIProgress -Activity "Lese Postfachstatistiken" -Total $total |
            ForEach-Object { & $addRow $_ }
    }
}

# Vollzugriffs-Berechtigungen (nicht geerbt, ohne Systemkonten)
function Add-ReportMailboxPermissions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Mailboxes
    )

    $useRest = Test-ReportCommand -Name "Get-EXOMailboxPermission"
    $total = $Mailboxes.Count
    $index = 0
    foreach ($mailbox in $Mailboxes) {
        $index++
        Update-UIBusy -Message "Lese Postfachberechtigungen" -Current $index -Total $total
        Assert-UINotCancelled

        $identity = Get-ReportMailboxIdentity -Mailbox $mailbox
        try {
            $permissions = if ($useRest) {
                Get-EXOMailboxPermission -Identity $identity -ErrorAction Stop
            }
            else {
                Get-MailboxPermission -Identity $identity -ErrorAction Stop
            }
        }
        catch {
            Write-Log "Berechtigungen für '$($mailbox.DisplayName)' konnten nicht gelesen werden: $($_.Exception.Message)" -Type "Warning"
            continue
        }

        foreach ($perm in $permissions) {
            $user = [string]$perm.User
            if ($perm.IsInherited -eq $true -or $user -like "NT AUTHORITY\*" -or $user -like "S-1-5-*") { continue }
            $Results.Add([PSCustomObject]@{
                Mailbox      = $mailbox.DisplayName
                MailboxEmail = [string]$mailbox.PrimarySmtpAddress
                User         = $user
                AccessRights = ($perm.AccessRights -join ", ")
            })
        }
    }
}

# Kalenderberechtigungen; der lokalisierte Ordnername (Kalender/Calendar/...) wird gemerkt,
# damit nicht für jedes Postfach zuerst ein Fehlversuch nötig ist.
function Add-ReportCalendarPermissions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Mailboxes
    )

    $useRest = Test-ReportCommand -Name "Get-EXOMailboxFolderPermission"
    $folderNames = New-Object 'System.Collections.Generic.List[string]'
    foreach ($name in @("Kalender", "Calendar", "Calendrier", "Calendario", "Agenda")) { $folderNames.Add($name) }

    $total = $Mailboxes.Count
    $index = 0
    foreach ($mailbox in $Mailboxes) {
        $index++
        Update-UIBusy -Message "Lese Kalenderberechtigungen" -Current $index -Total $total
        Assert-UINotCancelled

        $address = [string]$mailbox.PrimarySmtpAddress
        if ([string]::IsNullOrWhiteSpace($address)) { $address = Get-ReportMailboxIdentity -Mailbox $mailbox }

        $permissions = $null
        foreach ($folderName in @($folderNames)) {
            try {
                $folderIdentity = "${address}:\$folderName"
                $permissions = if ($useRest) {
                    Get-EXOMailboxFolderPermission -Identity $folderIdentity -ErrorAction Stop
                }
                else {
                    Get-MailboxFolderPermission -Identity $folderIdentity -ErrorAction Stop
                }
                if ($folderNames[0] -ne $folderName) {
                    [void]$folderNames.Remove($folderName)
                    $folderNames.Insert(0, $folderName)
                }
                break
            }
            catch {
                $permissions = $null
            }
        }

        if ($null -eq $permissions) {
            Write-Log "Kalenderordner von '$($mailbox.DisplayName)' nicht gefunden oder nicht lesbar." -Type "Debug"
            continue
        }

        foreach ($perm in $permissions) {
            $user = [string]$perm.User
            if ($user -eq "Anonymous" -or $user -eq "Default" -or $user -eq "Standard" -or $user -eq "Anonym") { continue }
            $Results.Add([PSCustomObject]@{
                Mailbox      = $mailbox.DisplayName
                MailboxEmail = [string]$mailbox.PrimarySmtpAddress
                User         = $user
                AccessRights = ($perm.AccessRights -join ", ")
            })
        }
    }
}

function Add-ReportGroupMembers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results
    )

    Update-UIBusy -Message "Lade Verteilergruppen..."
    $groups = @(Get-DistributionGroup -ResultSize Unlimited -ErrorAction Stop | Step-UIProgress -Activity "Lade Verteilergruppen")
    $total = $groups.Count
    $index = 0
    foreach ($group in $groups) {
        $index++
        Update-UIBusy -Message "Lese Gruppenmitglieder" -Current $index -Total $total
        Assert-UINotCancelled

        $groupIdentity = if (-not [string]::IsNullOrWhiteSpace([string]$group.DistinguishedName)) { [string]$group.DistinguishedName } else { [string]$group.Identity }
        try {
            $members = Get-DistributionGroupMember -Identity $groupIdentity -ResultSize Unlimited -ErrorAction Stop
        }
        catch {
            Write-Log "Mitglieder von '$($group.DisplayName)' konnten nicht gelesen werden: $($_.Exception.Message)" -Type "Warning"
            continue
        }

        foreach ($member in $members) {
            $Results.Add([PSCustomObject]@{
                Gruppe        = $group.DisplayName
                GruppenEmail  = [string]$group.PrimarySmtpAddress
                Mitglied      = $member.DisplayName
                MitgliedEmail = [string]$member.PrimarySmtpAddress
                MitgliedTyp   = [string]$member.RecipientType
            })
        }
    }
}

# Weiterleitungen auf Postfachebene (ForwardingSmtpAddress / ForwardingAddress)
function Add-ReportForwarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results,

        [switch]$ExternalOnly
    )

    $mailboxes = Get-ReportMailboxes -Properties ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward -Filter "ForwardingSmtpAddress -ne `$null -or ForwardingAddress -ne `$null"
    $acceptedDomains = @()
    if ($ExternalOnly) {
        Update-UIBusy -Message "Lese akzeptierte Domänen..."
        $acceptedDomains = @(Get-AcceptedDomain -ErrorAction Stop | ForEach-Object { ([string]$_.DomainName).ToLowerInvariant() })
    }

    $total = $mailboxes.Count
    $index = 0
    foreach ($mailbox in $mailboxes) {
        $index++
        Update-UIBusy -Message "Prüfe Weiterleitungen" -Current $index -Total $total
        Assert-UINotCancelled

        $smtpTarget = ([string]$mailbox.ForwardingSmtpAddress) -replace '^(?i)smtp:', ''
        $recipientTarget = [string]$mailbox.ForwardingAddress
        if ([string]::IsNullOrWhiteSpace($smtpTarget) -and [string]::IsNullOrWhiteSpace($recipientTarget)) { continue }

        $targetAddress = $smtpTarget
        if ([string]::IsNullOrWhiteSpace($targetAddress) -and -not [string]::IsNullOrWhiteSpace($recipientTarget)) {
            # ForwardingAddress verweist auf ein Empfängerobjekt (z. B. einen E-Mail-Kontakt)
            try {
                $recipient = Get-Recipient -Identity $recipientTarget -ErrorAction Stop
                $targetAddress = if (-not [string]::IsNullOrWhiteSpace([string]$recipient.ExternalEmailAddress)) {
                    ([string]$recipient.ExternalEmailAddress) -replace '^(?i)smtp:', ''
                }
                else {
                    [string]$recipient.PrimarySmtpAddress
                }
            }
            catch {
                $targetAddress = $recipientTarget
            }
        }

        $targetDomain = if ($targetAddress -match '@([^@\s]+)$') { $Matches[1].ToLowerInvariant() } else { "" }
        $isExternal = (-not [string]::IsNullOrWhiteSpace($targetDomain)) -and ($acceptedDomains.Count -gt 0) -and ($acceptedDomains -notcontains $targetDomain)
        if ($ExternalOnly -and -not $isExternal) { continue }

        $Results.Add([PSCustomObject]@{
            DisplayName                = $mailbox.DisplayName
            PrimarySmtpAddress         = [string]$mailbox.PrimarySmtpAddress
            Weiterleitungsziel         = $targetAddress
            ZielDomaene                = $targetDomain
            KopieImPostfach            = $mailbox.DeliverToMailboxAndForward
            Quelle                     = if (-not [string]::IsNullOrWhiteSpace($smtpTarget)) { "ForwardingSmtpAddress" } else { "ForwardingAddress" }
        })
    }
}

function Add-ReportArchiveHold {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results
    )

    $mailboxes = Get-ReportMailboxes -Properties ArchiveStatus, ArchiveName, LitigationHoldEnabled, RetentionHoldEnabled, RetentionPolicy, InPlaceHolds
    foreach ($mailbox in $mailboxes) {
        $Results.Add([PSCustomObject]@{
            DisplayName           = $mailbox.DisplayName
            PrimarySmtpAddress    = [string]$mailbox.PrimarySmtpAddress
            Postfachtyp           = [string]$mailbox.RecipientTypeDetails
            ArchivStatus          = [string]$mailbox.ArchiveStatus
            LitigationHold        = $mailbox.LitigationHoldEnabled
            RetentionHold         = $mailbox.RetentionHoldEnabled
            Aufbewahrungsrichtlinie = [string]$mailbox.RetentionPolicy
            InPlaceHolds          = @($mailbox.InPlaceHolds).Where({ $null -ne $_ }).Count
        })
    }
}

# "Senden als"-Berechtigungen; ohne Benutzerfilter genügt eine einzige Abfrage für den ganzen Tenant
function Add-ReportSendAs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results
    )

    $command = if (Test-ReportCommand -Name "Get-EXORecipientPermission") { "Get-EXORecipientPermission" } else { "Get-RecipientPermission" }
    $addRows = {
        param($perm)
        $trustee = [string]$perm.Trustee
        if ($perm.IsInherited -eq $true -or $trustee -like "NT AUTHORITY\*" -or $trustee -like "S-1-5-*") { return }
        if ((Join-ReportValue -Value $perm.AccessRights) -notmatch 'SendAs') { return }
        $Results.Add([PSCustomObject]@{
            Objekt       = [string]$perm.Identity
            Berechtigter = $trustee
            Rechte       = Join-ReportValue -Value $perm.AccessRights
        })
    }

    if ([string]::IsNullOrWhiteSpace($script:ReportUserFilter)) {
        Update-UIBusy -Message "Lese 'Senden als'-Berechtigungen..."
        & $command -ResultSize Unlimited -ErrorAction Stop |
            Step-UIProgress -Activity "Lese 'Senden als'-Berechtigungen" |
            ForEach-Object { & $addRows $_ }
        return
    }

    $mailboxes = Get-ReportMailboxes
    $total = $mailboxes.Count
    $index = 0
    foreach ($mailbox in $mailboxes) {
        $index++
        Update-UIBusy -Message "Lese 'Senden als'-Berechtigungen" -Current $index -Total $total
        Assert-UINotCancelled
        try {
            & $command -Identity (Get-ReportMailboxIdentity -Mailbox $mailbox) -ErrorAction Stop | ForEach-Object { & $addRows $_ }
        }
        catch {
            Write-Log "'Senden als' für '$($mailbox.DisplayName)' konnte nicht gelesen werden: $($_.Exception.Message)" -Type "Warning"
        }
    }
}

function Add-ReportUnifiedGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results
    )

    Update-UIBusy -Message "Lade Microsoft 365-Gruppen..."
    Get-UnifiedGroup -ResultSize Unlimited -ErrorAction Stop |
        Step-UIProgress -Activity "Lade Microsoft 365-Gruppen" |
        ForEach-Object {
            $Results.Add([PSCustomObject]@{
                Gruppe          = $_.DisplayName
                Email           = [string]$_.PrimarySmtpAddress
                Zugriff         = [string]$_.AccessType
                Mitglieder      = $_.GroupMemberCount
                ExterneMitglieder = $_.GroupExternalMemberCount
                Besitzer        = Join-ReportValue -Value $_.ManagedBy
                Erstellt        = $_.WhenCreated
            })
        }
}

function Add-ReportGroupsWithoutOwner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results
    )

    Update-UIBusy -Message "Lade Verteilergruppen..."
    Get-DistributionGroup -ResultSize Unlimited -ErrorAction Stop |
        Step-UIProgress -Activity "Lade Verteilergruppen" |
        Where-Object { @($_.ManagedBy | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count -eq 0 } |
        ForEach-Object {
            $Results.Add([PSCustomObject]@{
                Gruppe      = $_.DisplayName
                Email       = [string]$_.PrimarySmtpAddress
                Gruppentyp  = [string]$_.RecipientTypeDetails
                Synchronisiert = $_.IsDirSynced
                Erstellt    = $_.WhenCreated
            })
        }
}

function Add-ReportResources {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results
    )

    $mailboxes = Get-ReportMailboxes -RecipientTypeDetails RoomMailbox, EquipmentMailbox -Properties ResourceCapacity, Office
    $total = $mailboxes.Count
    $index = 0
    foreach ($mailbox in $mailboxes) {
        $index++
        Update-UIBusy -Message "Lese Buchungsoptionen" -Current $index -Total $total
        Assert-UINotCancelled

        $processing = $null
        try {
            $processing = Get-CalendarProcessing -Identity (Get-ReportMailboxIdentity -Mailbox $mailbox) -ErrorAction Stop
        }
        catch {
            Write-Log "Buchungsoptionen von '$($mailbox.DisplayName)' konnten nicht gelesen werden: $($_.Exception.Message)" -Type "Debug"
        }

        $Results.Add([PSCustomObject]@{
            DisplayName         = $mailbox.DisplayName
            PrimarySmtpAddress  = [string]$mailbox.PrimarySmtpAddress
            Typ                 = [string]$mailbox.RecipientTypeDetails
            Kapazitaet          = $mailbox.ResourceCapacity
            Standort            = [string]$mailbox.Office
            AutomatischeAnnahme = if ($null -ne $processing) { [string]$processing.AutomateProcessing } else { "" }
            Buchungsfenster     = if ($null -ne $processing) { $processing.BookingWindowInDays } else { $null }
            KonflikteErlaubt    = if ($null -ne $processing) { $processing.AllowConflicts } else { $null }
        })
    }
}

function Add-ReportMailboxAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results
    )

    $orgAuditDisabled = $null
    try {
        $orgAuditDisabled = (Get-OrganizationConfig -ErrorAction Stop).AuditDisabled
    }
    catch {
        Write-Log "AuditDisabled der Organisation konnte nicht gelesen werden: $($_.Exception.Message)" -Type "Debug"
    }

    $mailboxes = Get-ReportMailboxes -Properties AuditEnabled, AuditLogAgeLimit, AuditBypassEnabled, DefaultAuditSet
    foreach ($mailbox in $mailboxes) {
        $Results.Add([PSCustomObject]@{
            DisplayName              = $mailbox.DisplayName
            PrimarySmtpAddress       = [string]$mailbox.PrimarySmtpAddress
            Postfachtyp              = [string]$mailbox.RecipientTypeDetails
            AuditAktiviert           = $mailbox.AuditEnabled
            Aufbewahrung             = [string]$mailbox.AuditLogAgeLimit
            StandardAuditSet         = Join-ReportValue -Value $mailbox.DefaultAuditSet
            OrganisationAuditDeaktiviert = $orgAuditDisabled
        })
    }
}

# Erstellt den in cmbReportType gewählten Bericht und zeigt ihn in lstReportResults an
function Invoke-ReportGeneration {
    [CmdletBinding()]
    param()

    if (-not $script:isConnected) {
        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type "Warning"
        return
    }

    $reportType = $script:cmbReportType.SelectedItem
    if ($null -eq $reportType) {
        Show-MessageBox -Message "Bitte wählen Sie einen Berichtstyp aus." -Title "Keine Auswahl" -Type "Warning"
        return
    }
    $reportName = if ($reportType -is [System.Windows.Controls.ComboBoxItem]) { [string]$reportType.Content } else { [string]$reportType }
    $report = $script:ReportCatalog | Where-Object { $_.Name -eq $reportName } | Select-Object -First 1
    if ($null -eq $report) {
        Show-MessageBox -Message "Der gewählte Berichtstyp wird derzeit nicht unterstützt." -Title "Nicht unterstützt" -Type "Warning"
        return
    }
    $script:ReportUserFilter = ""
    if ($report.UserFilter -and $null -ne $script:txtReportUserFilter) {
        $script:ReportUserFilter = ([string]$script:txtReportUserFilter.Text).Trim()
    }

    $startDate = $null
    $endDate = $null
    if ($null -ne $script:dpReportStartDate -and $null -ne $script:dpReportStartDate.SelectedDate) { $startDate = $script:dpReportStartDate.SelectedDate }
    if ($null -ne $script:dpReportEndDate -and $null -ne $script:dpReportEndDate.SelectedDate) { $endDate = $script:dpReportEndDate.SelectedDate }
    if ($null -ne $startDate -and $null -ne $endDate -and $startDate -gt $endDate) {
        Show-MessageBox -Message "Das Startdatum liegt nach dem Enddatum." -Title "Ungültiger Zeitraum" -Type "Warning"
        return
    }

    $results = New-Object 'System.Collections.Generic.List[object]'
    $cancelled = $false
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Update-StatusBar -Message "Generiere Bericht: $reportName..." -Type Info
    Write-Log "Generiere Bericht '$reportName'" -Type "Info"

    try {
        Start-UIBusy -Message "Generiere Bericht '$reportName'..." -Title "Bericht wird erstellt" -Cancelable
        try {
            switch ($report.Key) {
                "MailboxSize" {
                    $mailboxes = Get-ReportMailboxes
                    Add-ReportMailboxStatistics -Results $results -Mailboxes $mailboxes -Mode Size
                }
                "LastLogon" {
                    $mailboxes = Get-ReportMailboxes
                    Add-ReportMailboxStatistics -Results $results -Mailboxes $mailboxes -Mode Logon -StartDate $startDate -EndDate $endDate
                }
                "Forwarding" { Add-ReportForwarding -Results $results }
                "ArchiveHold" { Add-ReportArchiveHold -Results $results }
                "FullAccess" {
                    $mailboxes = Get-ReportMailboxes
                    Add-ReportMailboxPermissions -Results $results -Mailboxes $mailboxes
                }
                "SendAs" { Add-ReportSendAs -Results $results }
                "CalendarPermission" {
                    $mailboxes = Get-ReportMailboxes
                    Add-ReportCalendarPermissions -Results $results -Mailboxes $mailboxes
                }
                "SharedPermission" {
                    $mailboxes = Get-ReportMailboxes -RecipientTypeDetails "SharedMailbox"
                    Add-ReportMailboxPermissions -Results $results -Mailboxes $mailboxes
                }
                "GroupMembers" { Add-ReportGroupMembers -Results $results }
                "UnifiedGroups" { Add-ReportUnifiedGroups -Results $results }
                "GroupsWithoutOwner" { Add-ReportGroupsWithoutOwner -Results $results }
                "Resources" { Add-ReportResources -Results $results }
                "MailboxAudit" { Add-ReportMailboxAudit -Results $results }
                "ExternalForwarding" { Add-ReportForwarding -Results $results -ExternalOnly }
            }
        }
        catch {
            # Abbruch durch den Benutzer: Teilergebnis anzeigen (EXO-Cmdlets verpacken die Ausnahme ggf.)
            if ($script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException]) {
                $cancelled = $true
            }
            else {
                throw
            }
        }
        finally {
            Stop-UIBusy
        }

        $displayData = $results.ToArray()
        if ($report.Key -eq "MailboxSize") {
            $displayData = @($displayData | Sort-Object -Property TotalSizeGB -Descending)
        }
        $script:lstReportResults.ItemsSource = $displayData

        $duration = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
        if ($cancelled) {
            $statusMessage = "Bericht '$reportName' abgebrochen - Teilergebnis: $($results.Count) Datensätze ($duration s)."
            Write-Log $statusMessage -Type "Warning"
            Update-StatusBar -Message $statusMessage -Type Warning
        }
        else {
            $statusMessage = "Bericht '$reportName' generiert: $($results.Count) Datensätze ($duration s)."
            Write-Log $statusMessage -Type "Success"
            Update-StatusBar -Message $statusMessage -Type Success
        }
        $script:LastReportName = $reportName

        if ($script:chkAutoExport.IsChecked -eq $true -and $displayData.Count -gt 0) {
            Save-ReportAutoExport -Data $displayData -ReportName $reportName
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Generieren des Berichts: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Fehler: $errorMsg" -Type Error
        Show-MessageBox -Message "Fehler beim Generieren des Berichts: $errorMsg" -Title "Fehler" -Type "Error"
    }
}

# Erzeugt einen gültigen Dateinamen aus dem Berichtsnamen
function Get-ReportFileBaseName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$ReportName
    )

    $baseName = if ([string]::IsNullOrWhiteSpace($ReportName)) { "Exchange_Bericht" } else { $ReportName }
    $invalid = [System.IO.Path]::GetInvalidFileNameChars() + @(' ', '(', ')')
    foreach ($char in $invalid) { $baseName = $baseName.Replace([string]$char, "_") }
    $baseName = ($baseName -replace '_+', '_').Trim('_')
    return "${baseName}_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
}

# Ordner für automatisch gespeicherte Berichte: "Reports" neben dem Programm,
# ersatzweise "Dokumente\easyEXO\Reports", falls dort keine Schreibrechte bestehen.
function Get-ReportOutputFolder {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $candidates = @(
        (Join-Path -Path $script:AppRoot -ChildPath "Reports"),
        (Join-Path -Path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath "easyEXO\Reports")
    )
    foreach ($folder in $candidates) {
        try {
            if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
                $null = New-Item -Path $folder -ItemType Directory -Force -ErrorAction Stop
            }
            $probe = Join-Path -Path $folder -ChildPath ".write_test"
            [System.IO.File]::WriteAllText($probe, "")
            Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
            return $folder
        }
        catch {
            Write-Log "Berichtsordner '$folder' ist nicht beschreibbar: $($_.Exception.Message)" -Type "Debug"
        }
    }
    throw "Es wurde kein beschreibbarer Ordner für Berichte gefunden."
}

# Speichert einen Bericht automatisch als CSV (Option "Automatisch als CSV speichern")
function Save-ReportAutoExport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Data,

        [string]$ReportName
    )

    try {
        $folder = Get-ReportOutputFolder
        $path = Join-Path -Path $folder -ChildPath ((Get-ReportFileBaseName -ReportName $ReportName) + ".csv")
        $Data | ConvertTo-SafeCsvObject | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8 -Delimiter ";"
        Write-Log "Bericht automatisch gespeichert: $path" -Type "Success"
        Update-StatusBar -Message "Bericht automatisch gespeichert: $path" -Type Success
        if ($script:chkOpenAfterExport.IsChecked -eq $true) {
            Start-Process -FilePath $path
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Automatisches Speichern des Berichts fehlgeschlagen: $errorMsg" -Type "Error"
        Show-MessageBox -Message "Der Bericht konnte nicht automatisch gespeichert werden: $errorMsg" -Title "Fehler" -Type "Error"
    }
}

# Export für Excel: XLSX über das Modul ImportExcel (falls installiert), sonst Excel-kompatible CSV
function Export-ReportResultsExcel {
    [CmdletBinding()]
    param()

    try {
        $data = @($script:lstReportResults.ItemsSource)
        if ($data.Count -eq 0) {
            Show-MessageBox -Message "Es sind keine Daten zum Exportieren vorhanden. Bitte generieren Sie zuerst einen Bericht." -Title "Keine Daten" -Type "Warning"
            return
        }

        $hasImportExcel = [bool](Get-Command -Name Export-Excel -ErrorAction SilentlyContinue)
        if (-not $hasImportExcel -and (Get-Module -ListAvailable -Name ImportExcel)) {
            try {
                Import-Module -Name ImportExcel -ErrorAction Stop
                $hasImportExcel = [bool](Get-Command -Name Export-Excel -ErrorAction SilentlyContinue)
            }
            catch {
                Write-Log "Modul ImportExcel konnte nicht geladen werden: $($_.Exception.Message)" -Type "Warning"
            }
        }

        $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveFileDialog.Title = "Bericht für Excel exportieren"
        $baseName = Get-ReportFileBaseName -ReportName $script:LastReportName
        if ($hasImportExcel) {
            $saveFileDialog.Filter = "Excel-Arbeitsmappe (*.xlsx)|*.xlsx"
            $saveFileDialog.FileName = "$baseName.xlsx"
        }
        else {
            $saveFileDialog.Filter = "CSV für Excel (*.csv)|*.csv"
            $saveFileDialog.FileName = "$baseName.csv"
        }
        if ($saveFileDialog.ShowDialog() -ne $true) { return }

        $path = $saveFileDialog.FileName
        $safeData = @($data | ConvertTo-SafeCsvObject)
        if ($hasImportExcel) {
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force -ErrorAction Stop }
            $safeData | Export-Excel -Path $path -WorksheetName "Bericht" -AutoSize -FreezeTopRow -BoldTopRow -AutoFilter
        }
        else {
            $safeData | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8 -Delimiter ";"
        }

        Update-StatusBar -Message "Bericht exportiert: $path" -Type Success
        $hint = if ($hasImportExcel) { "" } else { "`n`nHinweis: Das Modul 'ImportExcel' ist nicht installiert; es wurde eine Excel-kompatible CSV-Datei erstellt (Install-Module ImportExcel -Scope CurrentUser für XLSX)." }
        Show-MessageBox -Message "Der Bericht wurde exportiert: $path$hint" -Title "Export erfolgreich" -Type "Info"
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Excel-Export des Berichts: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Fehler: $errorMsg" -Type Error
        Show-MessageBox -Message "Fehler beim Exportieren des Berichts: $errorMsg" -Title "Fehler" -Type "Error"
    }
}

# Füllt cmbReportType mit den Berichten der gewählten Kategorie
function Update-ReportTypeList {
    [CmdletBinding()]
    param()

    if ($null -eq $script:cmbReportType) { return }
    $category = "all"
    if ($null -ne $script:lstReportCategories -and $null -ne $script:lstReportCategories.SelectedItem) {
        $category = [string]$script:lstReportCategories.SelectedItem.Tag
    }

    $script:cmbReportType.Items.Clear()
    foreach ($report in $script:ReportCatalog) {
        if ($category -eq "all" -or $report.Category -eq $category) {
            [void]$script:cmbReportType.Items.Add($report.Name)
        }
    }
    if ($script:cmbReportType.Items.Count -gt 0) { $script:cmbReportType.SelectedIndex = 0 }
}

function Export-ReportResults {
    [CmdletBinding()]
    param()

    try {
        $data = @($script:lstReportResults.ItemsSource)
        if ($data.Count -eq 0) {
            Show-MessageBox -Message "Es sind keine Daten zum Exportieren vorhanden. Bitte generieren Sie zuerst einen Bericht." -Title "Keine Daten" -Type "Warning"
            return
        }

        $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveFileDialog.Filter = "CSV-Dateien (*.csv)|*.csv"
        $saveFileDialog.Title = "Bericht exportieren"
        $saveFileDialog.FileName = "$(Get-ReportFileBaseName -ReportName $script:LastReportName).csv"

        if ($saveFileDialog.ShowDialog() -eq $true) {
            $data | ConvertTo-SafeCsvObject | Export-Csv -Path $saveFileDialog.FileName -NoTypeInformation -Encoding UTF8 -Delimiter ";"
            Update-StatusBar -Message "Bericht wurde erfolgreich exportiert: $($saveFileDialog.FileName)" -Type Success
            Show-MessageBox -Message "Der Bericht wurde erfolgreich exportiert: $($saveFileDialog.FileName)" -Title "Export erfolgreich" -Type "Info"
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Exportieren des Berichts: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Fehler: $errorMsg" -Type Error
        Show-MessageBox -Message "Fehler beim Exportieren des Berichts: $errorMsg" -Title "Fehler" -Type "Error"
    }
}

function Initialize-ReportsTab {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log  "Initialisiere Berichte-Tab" -Type "Info"
        
        # UI-Elemente referenzieren
        $script:cmbReportType = Get-XamlElement -ElementName "cmbReportType"
        $script:dpReportStartDate = Get-XamlElement -ElementName "dpReportStartDate"
        $script:dpReportEndDate = Get-XamlElement -ElementName "dpReportEndDate"
        $script:lstReportResults = Get-XamlElement -ElementName "lstReportResults"
        $btnGenerateReport = Get-XamlElement -ElementName "btnGenerateReport"
        $btnExportReport = Get-XamlElement -ElementName "btnExportReport"
        $helpLinkReports = Get-XamlElement -ElementName "helpLinkReports"
        $script:lstReportCategories = Get-XamlElement -ElementName "lstReportCategories"
        $script:txtReportUserFilter = Get-XamlElement -ElementName "txtReportUserFilter"
        $script:chkAutoExport = Get-XamlElement -ElementName "chkAutoExport"
        $script:chkOpenAfterExport = Get-XamlElement -ElementName "chkOpenAfterExport"

        # Berichtstypen gemäß gewählter Kategorie eintragen (die ComboBox ist in der XAML leer)
        Update-ReportTypeList
        if ($null -ne $script:lstReportCategories) {
            $script:lstReportCategories.Add_SelectionChanged({
                try { Update-ReportTypeList }
                catch { Write-Log "Berichtsliste konnte nicht aktualisiert werden: $($_.Exception.Message)" -Type "Warning" }
            })
        }
        if ($null -ne $script:lstReportResults) {
            $script:lstReportResults.IsReadOnly = $true
        }
        
        # Event-Handler registrieren
        Register-EventHandler -Control $btnGenerateReport -Handler { Invoke-ReportGeneration } -ControlName "btnGenerateReport"
        Register-EventHandler -Control $btnExportReport -Handler { Export-ReportResults } -ControlName "btnExportReport"
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnExportResultsExcel") -ControlName "btnExportResultsExcel" -Handler { Export-ReportResultsExcel }
        
        # Hilfe-Link initialisieren, falls vorhanden
        if ($null -ne $helpLinkReports) {
            $helpLinkReports.Add_MouseLeftButtonDown({
                Show-HelpDialog -Topic "Reports"
            })
            
            $helpLinkReports.Add_MouseEnter({
                $this.TextDecorations = [System.Windows.TextDecorations]::Underline
                $this.Cursor = [System.Windows.Input.Cursors]::Hand
            })
            
            $helpLinkReports.Add_MouseLeave({
                $this.TextDecorations = $null
                $this.Cursor = [System.Windows.Input.Cursors]::Arrow
            })
        }
        
        Write-Log  "Berichte-Tab erfolgreich initialisiert" -Type "Success"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Initialisieren des Berichte-Tabs: $errorMsg" -Type "Error"
        return $false
    }
}
