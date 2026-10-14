# =====================================================================
# easyEXO - Modul: DLP, Compliance, eDiscovery & Legal Hold
# Datei: src/Modules/Features/Compliance.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
#
# DLP-, Aufbewahrungs-, Bezeichnungs- und eDiscovery-Cmdlets stehen nur in der
# Security & Compliance PowerShell zur Verfügung ("Compliance verbinden",
# Connect-IPPSSession). Legal Hold (Set-Mailbox -LitigationHoldEnabled)
# benötigt nur die Exchange-Online-Verbindung.
# =====================================================================

$script:DlpCurrentView = ""

# Prüft die Compliance-Verbindung und zeigt bei Bedarf einen Hinweis an
function Confirm-ComplianceReady {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (Test-ComplianceConnection) { return $true }
    $null = Show-MessageBox -Message "Für diese Funktion wird die Security & Compliance PowerShell benötigt. Bitte links zuerst auf 'Compliance verbinden' klicken." -Title "Compliance-Verbindung erforderlich" -Type "Warning"
    return $false
}

# Führt eine Compliance-Abfrage aus und zeigt das Ergebnis in der DLP-Ergebnisliste an
function Show-ComplianceQueryResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName,

        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$View,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Formatter
    )

    if (-not (Confirm-ComplianceReady)) { return }
    if (-not (Get-Command -Name $CommandName -ErrorAction SilentlyContinue)) {
        $null = Show-MessageBox -Message "Das Cmdlet '$CommandName' ist in der Compliance-Sitzung nicht verfügbar. Bitte Rollen/Lizenzen prüfen und die Compliance-Verbindung neu aufbauen." -Title "Nicht verfügbar" -Type "Warning"
        return
    }

    $rows = New-Object 'System.Collections.Generic.List[object]'
    $cancelled = $false
    Start-UIBusy -Message "Lade $Title..." -Title $Title -Cancelable
    try {
        & $CommandName -ErrorAction Stop | Step-UIProgress -Activity "Lade $Title" | ForEach-Object {
            $rows.Add((& $Formatter $_))
        }
    }
    catch {
        if ($script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException]) {
            $cancelled = $true
        }
        else {
            $errorMsg = $_.Exception.Message
            Write-Log "$CommandName fehlgeschlagen: $errorMsg" -Type "Error"
            $null = Show-MessageBox -Message "Fehler beim Laden ($Title): $errorMsg" -Title "Fehler" -Type "Error"
            return
        }
    }
    finally {
        Stop-UIBusy
    }

    $script:DlpCurrentView = $View
    $script:dgDlpResults.ItemsSource = $rows.ToArray()
    $info = "${Title}: $($rows.Count) Einträge"
    if ($cancelled) { $info += " (abgebrochen - Teilergebnis)" }
    $script:txtDlpResultInfo.Text = $info
    Update-StatusBar -Message $info -Type $(if ($cancelled) { "Warning" } else { "Success" })
}

function Get-DlpPoliciesAction {
    Show-ComplianceQueryResult -CommandName "Get-DlpCompliancePolicy" -Title "DLP-Richtlinien" -View "DlpPolicies" -Formatter {
        param($item)
        [PSCustomObject]@{
            Name        = [string]$item.Name
            Modus       = [string]$item.Mode
            Aktiviert   = $item.Enabled
            Workload    = [string]$item.Workload
            Prioritaet  = $item.Priority
            Geaendert   = $item.WhenChanged
        }
    }
}

function Get-DlpRulesAction {
    Show-ComplianceQueryResult -CommandName "Get-DlpComplianceRule" -Title "DLP-Regeln" -View "DlpRules" -Formatter {
        param($item)
        [PSCustomObject]@{
            Name          = [string]$item.Name
            Richtlinie    = [string]$item.ParentPolicyName
            Deaktiviert   = $item.Disabled
            Prioritaet    = $item.Priority
            Schweregrad   = [string]$item.ReportSeverityLevel
            ZugriffSperren = $item.BlockAccess
        }
    }
}

function Get-RetentionPoliciesAction {
    Show-ComplianceQueryResult -CommandName "Get-RetentionCompliancePolicy" -Title "Aufbewahrungsrichtlinien" -View "RetentionPolicies" -Formatter {
        param($item)
        [PSCustomObject]@{
            Name         = [string]$item.Name
            Aktiviert    = $item.Enabled
            Modus        = [string]$item.Mode
            Workload     = [string]$item.Workload
            Verteilung   = [string]$item.DistributionStatus
            Geaendert    = $item.WhenChanged
        }
    }
}

function Get-SensitivityLabelsAction {
    Show-ComplianceQueryResult -CommandName "Get-Label" -Title "Vertraulichkeitsbezeichnungen" -View "Labels" -Formatter {
        param($item)
        [PSCustomObject]@{
            Anzeigename = [string]$item.DisplayName
            Name        = [string]$item.Name
            Prioritaet  = $item.Priority
            Inhaltstyp  = [string]$item.ContentType
            Deaktiviert = $item.Disabled
        }
    }
}

function Set-DlpPolicyModeAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if (-not (Confirm-ComplianceReady)) { return }
    $selected = $script:dgDlpResults.SelectedItem
    if ($script:DlpCurrentView -ne "DlpPolicies" -or $null -eq $selected) {
        $null = Show-MessageBox -Message "Bitte zuerst 'DLP-Richtlinien laden' und eine Richtlinie in der Ergebnisliste auswählen." -Title "Keine Richtlinie ausgewählt" -Type "Info"
        return
    }

    $modeItem = $script:cmbDlpPolicyMode.SelectedItem
    $mode = if ($null -ne $modeItem) { [string]$modeItem.Tag } else { "" }
    if ([string]::IsNullOrWhiteSpace($mode)) {
        $null = Show-MessageBox -Message "Bitte einen Modus auswählen." -Title "Kein Modus" -Type "Info"
        return
    }

    $policyName = [string]$selected.Name
    $answer = Show-MessageBox -Message "Modus der DLP-Richtlinie '$policyName' auf '$($modeItem.Content)' setzen?" -Title "DLP-Modus ändern" -Type "YesNo"
    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }
    if (-not $PSCmdlet.ShouldProcess($policyName, "Set-DlpCompliancePolicy -Mode $mode")) { return }

    try {
        Start-UIBusy -Message "Setze Modus '$mode' für '$policyName'..." -Title "DLP-Modus ändern"
        Set-DlpCompliancePolicy -Identity $policyName -Mode $mode -ErrorAction Stop
        Write-Log "DLP-Richtlinie '$policyName': Modus auf '$mode' gesetzt." -Type "Success"
        Log-Action "DLP-Richtlinie '$policyName': Modus auf '$mode' gesetzt"
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "DLP-Modus konnte nicht gesetzt werden: $errorMsg" -Type "Error"
        $null = Show-MessageBox -Message "Der Modus konnte nicht gesetzt werden: $errorMsg" -Title "Fehler" -Type "Error"
        return
    }
    finally {
        Stop-UIBusy
    }
    Get-DlpPoliciesAction
}

function Initialize-DLPTab {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Initialisiere DLP-Tab..." -Type "Info"
        $script:dgDlpResults = Get-XamlElement -ElementName "dgDlpResults"
        $script:txtDlpResultInfo = Get-XamlElement -ElementName "txtDlpResultInfo"
        $script:cmbDlpPolicyMode = Get-XamlElement -ElementName "cmbDlpPolicyMode"

        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnGetDlpPolicies") -ControlName "btnGetDlpPolicies" -Handler { Get-DlpPoliciesAction }
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnGetDlpRules") -ControlName "btnGetDlpRules" -Handler { Get-DlpRulesAction }
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnGetRetentionPolicies") -ControlName "btnGetRetentionPolicies" -Handler { Get-RetentionPoliciesAction }
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnGetSensitivityLabels") -ControlName "btnGetSensitivityLabels" -Handler { Get-SensitivityLabelsAction }
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnSetDlpPolicyMode") -ControlName "btnSetDlpPolicyMode" -Handler { Set-DlpPolicyModeAction }
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnExportDlpResults") -ControlName "btnExportDlpResults" -Handler {
            $name = if ([string]::IsNullOrWhiteSpace($script:DlpCurrentView)) { "Compliance" } else { "Compliance_$($script:DlpCurrentView)" }
            Export-DataGridContent -DataGrid $script:dgDlpResults -DefaultFileName $name
        }
        $null = Register-HelpLink -ElementName "helpLinkDLP" -Topic "Compliance"

        Write-Log "DLP-Tab erfolgreich initialisiert." -Type "Success"
        return $true
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler bei der Initialisierung des DLP-Tabs."
        Write-Log $errorMsg -Type "Error"
        return $false
    }
}

# ---------------------------------------------------------------------
# eDiscovery-Fälle
# ---------------------------------------------------------------------

function Get-eDiscoveryCasesAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ComplianceReady)) { return }
    if (-not (Get-Command -Name Get-ComplianceCase -ErrorAction SilentlyContinue)) {
        $null = Show-MessageBox -Message "Get-ComplianceCase ist nicht verfügbar. Es wird die Rolle 'eDiscovery-Manager' benötigt; danach die Compliance-Verbindung neu aufbauen." -Title "Nicht verfügbar" -Type "Warning"
        return
    }

    try {
        Start-UIBusy -Message "Lade eDiscovery-Fälle..." -Title "eDiscovery"
        $cases = @(Get-ComplianceCase -ErrorAction Stop | Sort-Object -Property Name | ForEach-Object {
            [PSCustomObject]@{
                Name        = [string]$_.Name
                CreatedBy   = [string]$_.CreatedBy
                Status      = [string]$_.Status
                Created     = $_.CreatedDateTime
                Description = [string]$_.Description
                Identity    = [string]$_.Identity
            }
        })
        $script:dgeDiscoveryCases.ItemsSource = $cases
        $script:txtSelectedCaseDetails.Text = "Bitte wählen Sie einen Fall aus, um Details anzuzeigen."
        Update-StatusBar -Message "$($cases.Count) eDiscovery-Fälle geladen." -Type Success
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "eDiscovery-Fälle konnten nicht geladen werden: $errorMsg" -Type "Error"
        $null = Show-MessageBox -Message "Die eDiscovery-Fälle konnten nicht geladen werden: $errorMsg" -Title "Fehler" -Type "Error"
    }
    finally {
        Stop-UIBusy
    }
}

function New-eDiscoveryCaseAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if (-not (Confirm-ComplianceReady)) { return }
    if (-not (Get-Command -Name New-ComplianceCase -ErrorAction SilentlyContinue)) {
        $null = Show-MessageBox -Message "New-ComplianceCase ist nicht verfügbar. Es wird die Rolle 'eDiscovery-Manager' benötigt." -Title "Nicht verfügbar" -Type "Warning"
        return
    }

    $caseName = Show-InputDialog -Title "Neuer eDiscovery-Fall" -Prompt "Name des neuen Falls:"
    if ([string]::IsNullOrWhiteSpace($caseName)) { return }
    $description = Show-InputDialog -Title "Neuer eDiscovery-Fall" -Prompt "Beschreibung (optional):" -Multiline -AllowEmpty
    if ($null -eq $description) { return }
    if (-not $PSCmdlet.ShouldProcess($caseName, "New-ComplianceCase")) { return }

    try {
        Start-UIBusy -Message "Lege Fall '$caseName' an..." -Title "eDiscovery"
        $params = @{ Name = $caseName; ErrorAction = "Stop" }
        if (-not [string]::IsNullOrWhiteSpace($description)) { $params["Description"] = $description }
        $null = New-ComplianceCase @params
        Write-Log "eDiscovery-Fall '$caseName' angelegt." -Type "Success"
        Log-Action "eDiscovery-Fall '$caseName' angelegt"
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "eDiscovery-Fall konnte nicht angelegt werden: $errorMsg" -Type "Error"
        $null = Show-MessageBox -Message "Der Fall konnte nicht angelegt werden: $errorMsg" -Title "Fehler" -Type "Error"
        return
    }
    finally {
        Stop-UIBusy
    }
    Get-eDiscoveryCasesAction
}

function Show-eDiscoveryCaseDetails {
    [CmdletBinding()]
    param()

    $case = $script:dgeDiscoveryCases.SelectedItem
    if ($null -eq $case) { return }

    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add("Name: $($case.Name)")
    $lines.Add("Status: $($case.Status)")
    $lines.Add("Erstellt von: $($case.CreatedBy)")
    if ($null -ne $case.Created) { $lines.Add("Erstellt am: $($case.Created)") }
    if (-not [string]::IsNullOrWhiteSpace($case.Description)) { $lines.Add("Beschreibung: $($case.Description)") }

    if (Get-Command -Name Get-CaseHoldPolicy -ErrorAction SilentlyContinue) {
        try {
            Start-UIBusy -Message "Lese Aufbewahrungen des Falls..." -Title "eDiscovery"
            $holds = @(Get-CaseHoldPolicy -Case $case.Identity -ErrorAction Stop)
            if ($holds.Count -eq 0) {
                $lines.Add("Aufbewahrungen (Holds): keine")
            }
            else {
                $lines.Add("Aufbewahrungen (Holds):")
                foreach ($hold in $holds) {
                    $lines.Add("  - $($hold.Name) (aktiviert: $($hold.Enabled); Verteilung: $($hold.DistributionStatus))")
                }
            }
        }
        catch {
            $lines.Add("Aufbewahrungen konnten nicht gelesen werden: $($_.Exception.Message)")
        }
        finally {
            Stop-UIBusy
        }
    }

    $script:txtSelectedCaseDetails.Text = $lines -join [Environment]::NewLine
}

# ---------------------------------------------------------------------
# Legal Hold (Beweissicherung) - benötigt nur die Exchange-Online-Verbindung
# ---------------------------------------------------------------------

function Get-LegalHoldMailboxesAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) {
        $null = Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type "Warning"
        return
    }

    $searchText = ([string]$script:txtSearchLegalHoldMailbox.Text).Trim()
    $params = @{ ResultSize = "Unlimited"; ErrorAction = "Stop" }
    if ([string]::IsNullOrWhiteSpace($searchText)) {
        $params["Filter"] = "LitigationHoldEnabled -eq `$true"
    }
    else {
        $params["Anr"] = $searchText
    }

    $rows = New-Object 'System.Collections.Generic.List[object]'
    $cancelled = $false
    Start-UIBusy -Message "Suche Postfächer..." -Title "Legal Hold" -Cancelable
    try {
        Get-Mailbox @params | Step-UIProgress -Activity "Lade Postfächer" | ForEach-Object {
            $rows.Add([PSCustomObject]@{
                DisplayName           = $_.DisplayName
                UserPrincipalName     = $_.UserPrincipalName
                LitigationHoldEnabled = [bool]$_.LitigationHoldEnabled
                LitigationHoldDate    = $_.LitigationHoldDate
                LitigationHoldOwner   = $_.LitigationHoldOwner
                LitigationHoldDuration = [string]$_.LitigationHoldDuration
            })
        }
    }
    catch {
        if ($script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException]) {
            $cancelled = $true
        }
        else {
            $errorMsg = $_.Exception.Message
            Write-Log "Legal-Hold-Suche fehlgeschlagen: $errorMsg" -Type "Error"
            $null = Show-MessageBox -Message "Fehler bei der Suche: $errorMsg" -Title "Fehler" -Type "Error"
        }
    }
    finally {
        Stop-UIBusy
    }

    $script:dgLegalHoldMailboxes.ItemsSource = $rows.ToArray()
    $message = "$($rows.Count) Postfächer gefunden."
    if ($cancelled) { $message = "Suche abgebrochen - Teilergebnis: $message" }
    Update-StatusBar -Message $message -Type $(if ($cancelled) { "Warning" } else { "Success" })
}

function Set-LegalHoldAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Enabled
    )

    if (-not (Confirm-ExchangeConnection)) {
        $null = Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type "Warning"
        return
    }

    $selection = @(Get-SelectedGridItems -DataGrid $script:dgLegalHoldMailboxes)
    if ($selection.Count -eq 0) {
        $null = Show-MessageBox -Message "Bitte mindestens ein Postfach in der Liste auswählen (vorher 'Suchen')." -Title "Keine Auswahl" -Type "Info"
        return
    }

    $actionText = if ($Enabled) { "aktivieren" } else { "entfernen" }
    $answer = Show-MessageBox -Message "Legal Hold für $($selection.Count) Postfach/Postfächer $actionText?" -Title "Legal Hold" -Type "YesNo"
    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $ok = 0
    $errors = New-Object 'System.Collections.Generic.List[string]'
    Start-UIBusy -Message "Legal Hold $actionText..." -Title "Legal Hold" -Cancelable
    try {
        $index = 0
        foreach ($item in $selection) {
            $index++
            Assert-UINotCancelled
            $identity = [string]$item.UserPrincipalName
            Update-UIBusy -Message "Legal Hold $actionText" -Current $index -Total $selection.Count
            if (-not $PSCmdlet.ShouldProcess($identity, "Set-Mailbox -LitigationHoldEnabled $Enabled")) { continue }
            try {
                Set-Mailbox -Identity $identity -LitigationHoldEnabled $Enabled -ErrorAction Stop
                $ok++
                Log-Action "Legal Hold für $identity auf $Enabled gesetzt"
            }
            catch {
                $errors.Add("${identity}: $($_.Exception.Message)")
            }
        }
    }
    catch {
        if (-not ($script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException])) {
            $errors.Add($_.Exception.Message)
        }
    }
    finally {
        Stop-UIBusy
    }

    Write-Log "Legal Hold $actionText`: $ok erfolgreich, $($errors.Count) Fehler." -Type $(if ($errors.Count -gt 0) { "Warning" } else { "Success" })
    if ($errors.Count -gt 0) {
        $null = Show-MessageBox -Message "Legal Hold: $ok erfolgreich, $($errors.Count) Fehler:`n`n$(($errors | Select-Object -First 10) -join "`n")" -Title "Legal Hold" -Type "Warning"
    }
    else {
        Update-StatusBar -Message "Legal Hold für $ok Postfach/Postfächer geändert." -Type Success
    }
    Get-LegalHoldMailboxesAction
}

function Initialize-eDiscoveryTab {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Initialisiere eDiscovery-Tab..." -Type "Info"
        $script:dgeDiscoveryCases = Get-XamlElement -ElementName "dgeDiscoveryCases"
        $script:txtSelectedCaseDetails = Get-XamlElement -ElementName "txtSelectedCaseDetails"
        $script:txtSearchLegalHoldMailbox = Get-XamlElement -ElementName "txtSearchLegalHoldMailbox"
        $script:dgLegalHoldMailboxes = Get-XamlElement -ElementName "dgLegalHoldMailboxes"

        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnGeteDiscoveryCases") -ControlName "btnGeteDiscoveryCases" -Handler { Get-eDiscoveryCasesAction }
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnNeweDiscoveryCase") -ControlName "btnNeweDiscoveryCase" -Handler { New-eDiscoveryCaseAction }
        if ($null -ne $script:dgeDiscoveryCases) {
            $script:dgeDiscoveryCases.Add_SelectionChanged({
                try { Show-eDiscoveryCaseDetails }
                catch { Write-Log "Falldetails konnten nicht angezeigt werden: $($_.Exception.Message)" -Type "Warning" }
            })
        }
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnSearchLegalHoldMailbox") -ControlName "btnSearchLegalHoldMailbox" -Handler { Get-LegalHoldMailboxesAction }
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnAddLegalHold") -ControlName "btnAddLegalHold" -Handler { Set-LegalHoldAction -Enabled $true }
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnRemoveLegalHold") -ControlName "btnRemoveLegalHold" -Handler { Set-LegalHoldAction -Enabled $false }
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnExportLegalHold") -ControlName "btnExportLegalHold" -Handler {
            Export-DataGridContent -DataGrid $script:dgLegalHoldMailboxes -DefaultFileName "LegalHold_Postfaecher"
        }
        if ($null -ne $script:txtSearchLegalHoldMailbox) {
            $script:txtSearchLegalHoldMailbox.Add_KeyDown({
                param($eventSource, $keyArgs)
                if ($keyArgs.Key -eq [System.Windows.Input.Key]::Return) { Get-LegalHoldMailboxesAction }
            })
        }
        $null = Register-HelpLink -ElementName "helpLinkeDiscovery" -Topic "eDiscovery"

        Write-Log "eDiscovery-Tab erfolgreich initialisiert." -Type "Success"
        return $true
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler bei der Initialisierung des eDiscovery-Tabs."
        Write-Log $errorMsg -Type "Error"
        return $false
    }
}
