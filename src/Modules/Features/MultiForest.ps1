# =====================================================================
# easyEXO - Modul: Multi-Forest-Verwaltung
# Datei: src/Modules/Features/MultiForest.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
#
# Exchange Online sieht lokale Forests nur über die synchronisierten Objekte
# und deren Domänen. Dieses Modul listet Empfänger je Domäne und Herkunft
# (AD-synchronisiert / Cloud) und steuert – sofern easyEXO auf dem
# Entra-Connect-Server läuft – die Synchronisation über das Modul ADSync.
# =====================================================================

$script:ForestAllDomainsLabel = "(Alle Domänen)"
$script:ForestObjectTypeMap = [ordered]@{
    "Alle Objekte" = @()
    "Benutzer"     = @("UserMailbox", "MailUser", "GuestMailUser")
    "Gruppen"      = @("MailUniversalDistributionGroup", "MailUniversalSecurityGroup", "MailNonUniversalGroup", "GroupMailbox", "DynamicDistributionGroup", "RoomList")
    "Postfächer"   = @("UserMailbox", "SharedMailbox", "RoomMailbox", "EquipmentMailbox")
}
$script:LastForestSearch = $null

function Get-ForestDomainsAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) {
        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type "Warning"
        return
    }

    try {
        Start-UIBusy -Message "Lese akzeptierte Domänen..." -Title "Domänen laden"
        $domains = @(Get-AcceptedDomain -ErrorAction Stop | Sort-Object -Property @{ Expression = { -not $_.Default } }, DomainName)
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Laden der Domänen: $errorMsg" -Type "Error"
        Show-MessageBox -Message "Die Domänen konnten nicht geladen werden: $errorMsg" -Title "Fehler" -Type "Error"
        return
    }
    finally {
        Stop-UIBusy
    }

    $script:cmbForests.Items.Clear()
    [void]$script:cmbForests.Items.Add($script:ForestAllDomainsLabel)
    foreach ($domain in $domains) {
        [void]$script:cmbForests.Items.Add([string]$domain.DomainName)
    }
    $script:cmbForests.SelectedIndex = 0
    Update-StatusBar -Message "$($domains.Count) Domänen geladen." -Type Success
}

function Get-ForestObjectsAction {
    [CmdletBinding()]
    param(
        # Letzte Suche mit denselben Kriterien wiederholen
        [switch]$Repeat
    )

    if (-not (Confirm-ExchangeConnection)) {
        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type "Warning"
        return
    }

    if ($Repeat -and $null -ne $script:LastForestSearch) {
        $search = $script:LastForestSearch
    }
    else {
        $typeName = "Alle Objekte"
        if ($null -ne $script:cmbObjectType.SelectedItem) {
            $selected = $script:cmbObjectType.SelectedItem
            $typeName = if ($selected -is [System.Windows.Controls.ComboBoxItem]) { [string]$selected.Content } else { [string]$selected }
        }
        $domain = [string]$script:cmbForests.SelectedItem
        if ($domain -eq $script:ForestAllDomainsLabel) { $domain = "" }
        $search = @{
            TypeName = $typeName
            Domain   = $domain
            Filter   = ([string]$script:txtForestFilter.Text).Trim()
        }
        $script:LastForestSearch = $search
    }

    if ([string]::IsNullOrWhiteSpace($search.Filter) -and [string]::IsNullOrWhiteSpace($search.Domain) -and $search.TypeName -eq "Alle Objekte") {
        $answer = Show-MessageBox -Message "Ohne Domäne, Objekttyp oder Suchfilter werden alle Empfänger des Tenants geladen. Fortfahren?" -Title "Alle Objekte laden" -Type "YesNo"
        if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }
    }

    $params = @{ ResultSize = "Unlimited"; ErrorAction = "Stop" }
    $recipientTypes = @($script:ForestObjectTypeMap[$search.TypeName])
    if ($recipientTypes.Count -gt 0) { $params["RecipientTypeDetails"] = $recipientTypes }
    if (-not [string]::IsNullOrWhiteSpace($search.Filter)) {
        $params["Anr"] = $search.Filter
    }
    elseif (-not [string]::IsNullOrWhiteSpace($search.Domain)) {
        $params["Filter"] = "PrimarySmtpAddress -like '*@$(ConvertTo-OPathValue -Value $search.Domain)'"
    }

    $domainSuffix = if ([string]::IsNullOrWhiteSpace($search.Domain)) { $null } else { "@" + $search.Domain.ToLowerInvariant() }
    $rows = New-Object 'System.Collections.Generic.List[object]'
    $cancelled = $false
    Start-UIBusy -Message "Suche Objekte..." -Title "Multi-Forest" -Cancelable
    try {
        # Abfrage als Scriptblock, damit die Ergebnisse direkt (gestreamt) verarbeitet werden
        $recipientQuery = if (Get-Command -Name Get-EXORecipient -ErrorAction SilentlyContinue) {
            { Get-EXORecipient @params -Properties IsDirSynced }
        }
        else {
            { Get-Recipient @params }
        }
        & $recipientQuery | Step-UIProgress -Activity "Lade Empfänger" | ForEach-Object {
            $address = [string]$_.PrimarySmtpAddress
            if ($null -ne $domainSuffix -and -not $address.ToLowerInvariant().EndsWith($domainSuffix)) { return }
            $addressDomain = if ($address -match '@(.+)$') { $Matches[1] } else { "-" }
            $origin = if ($_.IsDirSynced -eq $true) { "AD-synchronisiert" } else { "Cloud" }
            $rows.Add([PSCustomObject]@{
                DisplayName = $_.DisplayName
                ObjectType  = [string]$_.RecipientTypeDetails
                Forest      = "$addressDomain ($origin)"
                Email       = $address
            })
        }
    }
    catch {
        if ($script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException]) {
            $cancelled = $true
        }
        else {
            $errorMsg = $_.Exception.Message
            Write-Log "Fehler bei der Objektsuche: $errorMsg" -Type "Error"
            Show-MessageBox -Message "Fehler bei der Objektsuche: $errorMsg" -Title "Fehler" -Type "Error"
        }
    }
    finally {
        Stop-UIBusy
    }

    $script:dgCrossForestObjects.ItemsSource = $rows.ToArray()
    $syncedCount = @($rows | Where-Object { $_.Forest -like "*AD-synchronisiert*" }).Count
    $message = "$($rows.Count) Objekte gefunden ($syncedCount AD-synchronisiert)."
    if ($cancelled) { $message = "Suche abgebrochen - Teilergebnis: $message" }
    Update-StatusBar -Message $message -Type $(if ($cancelled) { "Warning" } else { "Success" })
}

# Lädt das Modul ADSync (nur auf dem Microsoft-Entra-Connect-Server vorhanden)
function Test-ADSyncAvailable {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (Get-Command -Name Start-ADSyncSyncCycle -ErrorAction SilentlyContinue) { return $true }
    if (-not (Get-Module -ListAvailable -Name ADSync)) { return $false }
    try {
        Import-Module -Name ADSync -ErrorAction Stop
        return [bool](Get-Command -Name Start-ADSyncSyncCycle -ErrorAction SilentlyContinue)
    }
    catch {
        Write-Log "Modul ADSync konnte nicht geladen werden: $($_.Exception.Message)" -Type "Warning"
        return $false
    }
}

function Update-ADSyncStatus {
    [CmdletBinding()]
    param()

    if ($null -eq $script:txtSyncStatus) { return }
    if (-not (Test-ADSyncAvailable)) {
        $script:txtSyncStatus.Text = "Status: Modul ADSync nicht gefunden (kein Entra-Connect-Server)."
        return
    }
    try {
        $scheduler = Get-ADSyncScheduler -ErrorAction Stop
        $script:txtSyncStatus.Text = "Status: Zeitplan aktiv: $($scheduler.SyncCycleEnabled); Synchronisation läuft: $($scheduler.SyncCycleInProgress); nächster Lauf: $($scheduler.NextSyncCycleStartTimeInUTC) (UTC)"
    }
    catch {
        $script:txtSyncStatus.Text = "Status: konnte nicht gelesen werden ($($_.Exception.Message))"
    }
}

function Start-ForestSyncAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if (-not (Test-ADSyncAvailable)) {
        Show-MessageBox -Message "Das Modul ADSync wurde nicht gefunden. Die Synchronisation kann nur auf dem Microsoft-Entra-Connect-Server gestartet werden." -Title "Nicht verfügbar" -Type "Warning"
        Update-ADSyncStatus
        return
    }

    $policyType = if ($script:chkSyncFullCycle.IsChecked -eq $true) { "Initial" } else { "Delta" }
    $answer = Show-MessageBox -Message "Synchronisation ($policyType) jetzt starten?" -Title "Synchronisation starten" -Type "YesNo"
    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }
    if (-not $PSCmdlet.ShouldProcess("Microsoft Entra Connect", "Start-ADSyncSyncCycle -PolicyType $policyType")) { return }

    try {
        $null = Start-ADSyncSyncCycle -PolicyType $policyType -ErrorAction Stop
        Write-Log "Entra-Connect-Synchronisation gestartet ($policyType)." -Type "Info"
        Log-Action "Entra-Connect-Synchronisation gestartet ($policyType)"
        Update-StatusBar -Message "Synchronisation ($policyType) gestartet." -Type Success
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Synchronisation konnte nicht gestartet werden: $errorMsg" -Type "Error"
        Show-MessageBox -Message "Die Synchronisation konnte nicht gestartet werden: $errorMsg" -Title "Fehler" -Type "Error"
    }
    Update-ADSyncStatus
}

function Stop-ForestSyncAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if (-not (Test-ADSyncAvailable)) {
        Show-MessageBox -Message "Das Modul ADSync wurde nicht gefunden. Die Synchronisation kann nur auf dem Microsoft-Entra-Connect-Server gesteuert werden." -Title "Nicht verfügbar" -Type "Warning"
        Update-ADSyncStatus
        return
    }

    $answer = Show-MessageBox -Message "Die laufende Synchronisation abbrechen?" -Title "Synchronisation stoppen" -Type "YesNo"
    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }
    if (-not $PSCmdlet.ShouldProcess("Microsoft Entra Connect", "Stop-ADSyncSyncCycle")) { return }

    try {
        $null = Stop-ADSyncSyncCycle -ErrorAction Stop
        Write-Log "Entra-Connect-Synchronisation gestoppt." -Type "Info"
        Log-Action "Entra-Connect-Synchronisation gestoppt"
        Update-StatusBar -Message "Synchronisation gestoppt." -Type Success
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Synchronisation konnte nicht gestoppt werden: $errorMsg" -Type "Error"
        Show-MessageBox -Message "Die Synchronisation konnte nicht gestoppt werden: $errorMsg" -Title "Fehler" -Type "Error"
    }
    Update-ADSyncStatus
}

function Initialize-MultiForestTab {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Initialisiere Multi-Forest-Tab..." -Type "Info"

        $script:cmbForests = Get-XamlElement -ElementName "cmbForests"
        $script:cmbObjectType = Get-XamlElement -ElementName "cmbObjectType"
        $script:txtForestFilter = Get-XamlElement -ElementName "txtForestFilter"
        $script:dgCrossForestObjects = Get-XamlElement -ElementName "dgCrossForestObjects"
        $script:chkSyncFullCycle = Get-XamlElement -ElementName "chkSyncFullCycle"
        $script:txtSyncStatus = Get-XamlElement -ElementName "txtSyncStatus"

        if ($null -ne $script:cmbObjectType -and $script:cmbObjectType.SelectedIndex -lt 0) { $script:cmbObjectType.SelectedIndex = 0 }

        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnConnectForest") -ControlName "btnConnectForest" -Handler { Get-ForestDomainsAction }
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnSearchForestObjects") -ControlName "btnSearchForestObjects" -Handler { Get-ForestObjectsAction }
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnRefreshForestObjects") -ControlName "btnRefreshForestObjects" -Handler { Get-ForestObjectsAction -Repeat }
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnExportForestObjects") -ControlName "btnExportForestObjects" -Handler {
            Export-DataGridContent -DataGrid $script:dgCrossForestObjects -DefaultFileName "MultiForest_Objekte"
        }
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnStartSync") -ControlName "btnStartSync" -Handler { Start-ForestSyncAction }
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnStopSync") -ControlName "btnStopSync" -Handler { Stop-ForestSyncAction }
        $null = Register-HelpLink -ElementName "helpLinkMultiForest" -Topic "MultiForest"

        Write-Log "Multi-Forest-Tab erfolgreich initialisiert." -Type "Success"
        return $true
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler bei der Initialisierung des Multi-Forest-Tabs."
        Write-Log $errorMsg -Type "Error"
        return $false
    }
}
