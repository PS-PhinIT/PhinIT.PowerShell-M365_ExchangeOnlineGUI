# =====================================================================
# easyEXO - Modul: Hybrid Exchange
# Datei: src/Modules/Features/Hybrid.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
#
# Liest die Hybrid-Konfiguration aus Exchange Online (nur lesend). Die
# Einrichtung erfolgt über den Hybrid Configuration Wizard (HCW) lokal.
# =====================================================================

$script:HybridWizardUrl = "https://aka.ms/HybridWizard"

# Führt ein Exchange-Cmdlet aus, falls vorhanden, und liefert die Ergebnisse oder eine Hinweiszeile
function Invoke-HybridQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Area,

        [Parameter(Mandatory = $true)]
        [string]$CommandName,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Formatter,

        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results
    )

    Update-UIBusy -Message "Lese $Area ($CommandName)..."
    Assert-UINotCancelled

    if (-not (Get-Command -Name $CommandName -ErrorAction SilentlyContinue)) {
        $Results.Add([PSCustomObject]@{
            Bereich   = $Area
            Name      = "-"
            Aktiviert = $null
            Details   = "Cmdlet '$CommandName' ist in dieser Sitzung nicht verfügbar (fehlende Rolle oder Berechtigung)."
        })
        return
    }

    try {
        $items = @(& $CommandName -ErrorAction Stop)
    }
    catch {
        Write-Log "$CommandName fehlgeschlagen: $($_.Exception.Message)" -Type "Warning"
        $Results.Add([PSCustomObject]@{
            Bereich   = $Area
            Name      = "-"
            Aktiviert = $null
            Details   = "Fehler: $($_.Exception.Message)"
        })
        return
    }

    if ($items.Count -eq 0) {
        $Results.Add([PSCustomObject]@{
            Bereich   = $Area
            Name      = "-"
            Aktiviert = $null
            Details   = "Nicht konfiguriert"
        })
        return
    }

    foreach ($item in $items) {
        $row = & $Formatter $item
        $Results.Add([PSCustomObject]@{
            Bereich   = $Area
            Name      = [string]$row.Name
            Aktiviert = $row.Enabled
            Details   = [string]$row.Details
        })
    }
}

function Get-HybridStatusAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) {
        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type "Warning"
        return
    }

    $results = New-Object 'System.Collections.Generic.List[object]'
    Start-UIBusy -Message "Lese Hybrid-Konfiguration..." -Title "Hybrid-Status" -Cancelable
    try {
        Invoke-HybridQuery -Results $results -Area "Lokale Organisation" -CommandName "Get-OnPremisesOrganization" -Formatter {
            param($o)
            @{ Name = $o.Name; Enabled = $null; Details = "Hybrid-Domänen: $(@($o.HybridDomains) -join ', '); Inbound: $($o.InboundConnector); Outbound: $($o.OutboundConnector); Beziehung: $($o.OrganizationRelationship)" }
        }
        Invoke-HybridQuery -Results $results -Area "Organisationsbeziehung" -CommandName "Get-OrganizationRelationship" -Formatter {
            param($o)
            @{ Name = $o.Name; Enabled = $o.Enabled; Details = "Domänen: $(@($o.DomainNames) -join ', '); Frei/Gebucht: $($o.FreeBusyAccessEnabled) ($($o.FreeBusyAccessLevel)); Postfachverschiebung: $($o.MailboxMoveEnabled); Autodiscover: $($o.TargetAutodiscoverEpr)" }
        }
        Invoke-HybridQuery -Results $results -Area "IntraOrganization-Connector (OAuth)" -CommandName "Get-IntraOrganizationConnector" -Formatter {
            param($o)
            @{ Name = $o.Name; Enabled = $o.Enabled; Details = "Zieldomänen: $(@($o.TargetAddressDomains) -join ', '); Discovery: $($o.DiscoveryEndpoint)" }
        }
        Invoke-HybridQuery -Results $results -Area "Eingehender Connector" -CommandName "Get-InboundConnector" -Formatter {
            param($o)
            @{ Name = $o.Name; Enabled = $o.Enabled; Details = "Typ: $($o.ConnectorType); TLS-Zertifikat: $($o.TlsSenderCertificateName); Absenderdomänen: $(@($o.SenderDomains) -join ', ')" }
        }
        Invoke-HybridQuery -Results $results -Area "Ausgehender Connector" -CommandName "Get-OutboundConnector" -Formatter {
            param($o)
            @{ Name = $o.Name; Enabled = $o.Enabled; Details = "Typ: $($o.ConnectorType); Smarthosts: $(@($o.SmartHosts) -join ', '); TLS: $($o.TlsSettings)" }
        }
        Invoke-HybridQuery -Results $results -Area "Migrationsendpunkt" -CommandName "Get-MigrationEndpoint" -Formatter {
            param($o)
            @{ Name = [string]$o.Identity; Enabled = $null; Details = "Typ: $($o.EndpointType); Server: $($o.RemoteServer); Max. gleichzeitige Migrationen: $($o.MaxConcurrentMigrations)" }
        }
    }
    catch {
        if (-not ($script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException])) {
            $errorMsg = $_.Exception.Message
            Write-Log "Fehler beim Lesen des Hybrid-Status: $errorMsg" -Type "Error"
            Show-MessageBox -Message "Fehler beim Lesen des Hybrid-Status: $errorMsg" -Title "Fehler" -Type "Error"
        }
    }
    finally {
        Stop-UIBusy
    }

    $script:dgHybridStatus.ItemsSource = $results.ToArray()
    $configured = @($results | Where-Object { $_.Name -ne "-" }).Count
    Update-StatusBar -Message "Hybrid-Status gelesen: $configured konfigurierte Einträge." -Type Success
    Write-Log "Hybrid-Status gelesen ($configured Einträge)." -Type "Info"
}

function Get-FederationTrustAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) {
        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type "Warning"
        return
    }

    $results = New-Object 'System.Collections.Generic.List[object]'
    Start-UIBusy -Message "Lese Verbundvertrauensstellungen..." -Title "Verbundvertrauensstellung" -Cancelable
    try {
        Invoke-HybridQuery -Results $results -Area "Verbundorganisationsbezeichner" -CommandName "Get-FederatedOrganizationIdentifier" -Formatter {
            param($o)
            @{ Name = [string]$o.AccountNamespace; Enabled = $o.Enabled; Details = "Domänen: $(@($o.Domains) -join ', '); Vertrauensstellung: $($o.DelegationTrustLink); Kontakt: $($o.OrganizationContact)" }
        }
        Invoke-HybridQuery -Results $results -Area "Organisationsbeziehung" -CommandName "Get-OrganizationRelationship" -Formatter {
            param($o)
            @{ Name = $o.Name; Enabled = $o.Enabled; Details = "Domänen: $(@($o.DomainNames) -join ', '); Anwendungs-URI: $($o.TargetApplicationUri); Frei/Gebucht: $($o.FreeBusyAccessLevel); Zustellung: $($o.DeliveryReportEnabled)" }
        }
        Invoke-HybridQuery -Results $results -Area "Freigaberichtlinie" -CommandName "Get-SharingPolicy" -Formatter {
            param($o)
            @{ Name = $o.Name; Enabled = $o.Enabled; Details = "Standard: $($o.Default); Domänen: $(@($o.Domains) -join ', ')" }
        }
    }
    catch {
        if (-not ($script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException])) {
            $errorMsg = $_.Exception.Message
            Write-Log "Fehler beim Lesen der Vertrauensstellungen: $errorMsg" -Type "Error"
            Show-MessageBox -Message "Fehler beim Lesen der Vertrauensstellungen: $errorMsg" -Title "Fehler" -Type "Error"
        }
    }
    finally {
        Stop-UIBusy
    }

    $script:dgFederationTrust.ItemsSource = $results.ToArray()
    Update-StatusBar -Message "Verbundvertrauensstellungen gelesen: $($results.Count) Einträge." -Type Success
}

function Initialize-HybridExchangeTab {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Initialisiere Hybrid-Exchange-Tab..." -Type "Info"

        $script:dgHybridStatus = Get-XamlElement -ElementName "dgHybridStatus"
        $script:dgFederationTrust = Get-XamlElement -ElementName "dgFederationTrust"
        $btnRunHCW = Get-XamlElement -ElementName "btnRunHCW"
        $btnGetHybridStatus = Get-XamlElement -ElementName "btnGetHybridStatus"
        $btnGetFederationTrust = Get-XamlElement -ElementName "btnGetFederationTrust"
        $btnExportHybridStatus = Get-XamlElement -ElementName "btnExportHybridStatus"
        $btnExportFederationTrust = Get-XamlElement -ElementName "btnExportFederationTrust"

        $null = Register-EventHandler -Control $btnRunHCW -ControlName "btnRunHCW" -Handler {
            if (Open-ExternalUrl -Url $script:HybridWizardUrl) {
                Update-StatusBar -Message "Download-Seite des Hybrid-Assistenten geöffnet. Der Assistent wird auf einem lokalen Exchange-Server ausgeführt." -Type Info
            }
        }
        $null = Register-EventHandler -Control $btnGetHybridStatus -ControlName "btnGetHybridStatus" -Handler { Get-HybridStatusAction }
        $null = Register-EventHandler -Control $btnGetFederationTrust -ControlName "btnGetFederationTrust" -Handler { Get-FederationTrustAction }
        $null = Register-EventHandler -Control $btnExportHybridStatus -ControlName "btnExportHybridStatus" -Handler {
            Export-DataGridContent -DataGrid $script:dgHybridStatus -DefaultFileName "HybridStatus"
        }
        $null = Register-EventHandler -Control $btnExportFederationTrust -ControlName "btnExportFederationTrust" -Handler {
            Export-DataGridContent -DataGrid $script:dgFederationTrust -DefaultFileName "Verbundvertrauensstellungen"
        }
        $null = Register-HelpLink -ElementName "helpLinkHybridExchange" -Topic "HybridExchange"

        Write-Log "Hybrid-Exchange-Tab erfolgreich initialisiert." -Type "Success"
        return $true
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler bei der Initialisierung des Hybrid-Exchange-Tabs."
        Write-Log $errorMsg -Type "Error"
        return $false
    }
}
