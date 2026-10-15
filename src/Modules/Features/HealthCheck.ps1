# =====================================================================
# easyEXO - Modul: Health Check (Dienste, Konnektivität, Konfiguration)
# Datei: src/Modules/Features/HealthCheck.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# -------------------------------------------------
# Abschnitt: Exchange Health Check-Funktionen
# -------------------------------------------------
function Get-OwnRetentionCompliancePolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Identity,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.SwitchParameter]$DistributionDetail,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.SwitchParameter]$ErrorPolicyOnly,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.SwitchParameter]$ExcludeTeamsPolicy,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.SwitchParameter]$IncludeTestModeResults,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.SwitchParameter]$PriorityCleanup,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.SwitchParameter]$RetentionRuleTypes,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.SwitchParameter]$TeamsPolicyOnly
    )
    try {
        Write-Log "Rufe Aufbewahrungsrichtlinien (Retention Compliance Policies) ab..." -Type "Debug"

        # Überprüfen, ob das Cmdlet verfügbar ist
        $cmdletAvailable = Get-Command Get-RetentionCompliancePolicy -ErrorAction SilentlyContinue
        if (-not $cmdletAvailable) {
            throw "Das Cmdlet 'Get-RetentionCompliancePolicy' ist nicht verfügbar. Bitte zuerst über 'Compliance verbinden' (Connect-IPPSSession) eine Verbindung zu Security & Compliance herstellen."
        }

        # Parameter für das eigentliche Cmdlet vorbereiten
        $params = @{
            ErrorAction = 'Stop'
        }
        if ($PSBoundParameters.ContainsKey('Identity')) {
            $params.Identity = $Identity
        }
        if ($PSBoundParameters.ContainsKey('DistributionDetail')) {
            $params.DistributionDetail = $true
        }
        if ($PSBoundParameters.ContainsKey('ErrorPolicyOnly')) {
            $params.ErrorPolicyOnly = $true
        }
        if ($PSBoundParameters.ContainsKey('ExcludeTeamsPolicy')) {
            $params.ExcludeTeamsPolicy = $true
        }
        if ($PSBoundParameters.ContainsKey('IncludeTestModeResults')) {
            $params.IncludeTestModeResults = $true
        }
        if ($PSBoundParameters.ContainsKey('PriorityCleanup')) {
            $params.PriorityCleanup = $true
        }
        if ($PSBoundParameters.ContainsKey('RetentionRuleTypes')) {
            $params.RetentionRuleTypes = $true
        }
        if ($PSBoundParameters.ContainsKey('TeamsPolicyOnly')) {
            $params.TeamsPolicyOnly = $true
        }

        # Das eigentliche Exchange Online Cmdlet aufrufen
        $policies = Get-RetentionCompliancePolicy @params

        # Extrahieren und Anzeigen der spezifischen Eigenschaften für jede Richtlinie
        $results = foreach ($policy in $policies) {
            [PSCustomObject]@{
                Name    = $policy.Name
                Workload = "All" # Platzhalter, da die Beschreibung erwähnt, dass alle Workloads angezeigt werden
                Enabled = $policy.Enabled
                Mode    = $policy.Mode
            }
        }

        Write-Log "Aufbewahrungsrichtlinien erfolgreich abgerufen." -Type "Debug"
        return $results
    }
    catch {
        $errorMsg = $_.Exception.Message
        if ($errorMsg -match "access denied|permissions") {
            $permissionLink = "https://learn.microsoft.com/en-us/purview/purview-permissions"
            $details = "Fehler: Berechtigungsproblem. Stellen Sie sicher, dass Sie die erforderlichen Berechtigungen haben. Weitere Informationen finden Sie hier: $permissionLink"
        } else {
            $details = "Fehler beim Abrufen der Aufbewahrungsrichtlinien: $errorMsg"
        }
        Write-Log $details -Type "Error"
        Log-Action $details
        throw $details
    }
}

function Get-OwnDlpCompliancePolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Identity,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.SwitchParameter]$DistributionDetail,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.SwitchParameter]$ErrorPolicyOnly
    )
    try {
        Write-Log "Rufe DLP-Richtlinien (DLP Compliance Policies) ab..." -Type "Debug"

        # Überprüfen, ob das Cmdlet verfügbar ist
        $cmdletAvailable = Get-Command Get-DlpCompliancePolicy -ErrorAction SilentlyContinue
        if (-not $cmdletAvailable) {
            throw "Das Cmdlet 'Get-DlpCompliancePolicy' ist nicht verfügbar. Bitte zuerst über 'Compliance verbinden' (Connect-IPPSSession) eine Verbindung zu Security & Compliance herstellen. Ist die Verbindung aktiv, fehlen ggf. Lizenzen (z.B. Microsoft 365 E3/E5) oder Berechtigungen."
        }

        # Parameter für das eigentliche Cmdlet vorbereiten
        $params = @{
            ErrorAction = 'Stop'
        }
        if ($PSBoundParameters.ContainsKey('Identity')) {
            $params.Identity = $Identity
        }
        if ($PSBoundParameters.ContainsKey('DistributionDetail')) {
            $params.DistributionDetail = $true
        }
        if ($PSBoundParameters.ContainsKey('ErrorPolicyOnly')) {
            $params.ErrorPolicyOnly = $true
        }

        # Das eigentliche Exchange Online Cmdlet aufrufen
        $policies = Get-DlpCompliancePolicy @params

        # Extrahieren und Anzeigen der spezifischen Eigenschaften für jede Richtlinie
        $results = foreach ($policy in $policies) {
            [PSCustomObject]@{
                Name    = $policy.Name
                Workload = "All" # Platzhalter
                Enabled = $policy.Enabled
                Mode    = $policy.Mode
            }
        }

        Write-Log "DLP-Richtlinien erfolgreich abgerufen." -Type "Debug"
        return $results
    }
    catch {
        $errorMsg = $_.Exception.Message
        if ($errorMsg -match "access denied|permissions|nicht verfügbar") {
            $permissionLink = "https://learn.microsoft.com/en-us/purview/purview-permissions"
            $details = "Fehler: Berechtigungsproblem oder fehlende Lizenz. Stellen Sie sicher, dass Sie die erforderlichen Berechtigungen und Lizenzen (z.B. M365 E3/E5) haben. Weitere Informationen finden Sie hier: $permissionLink"
        } else {
            $details = "Fehler beim Abrufen der DLP-Richtlinien: $errorMsg"
        }
        Write-Log $details -Type "Error"
        Log-Action $details
        throw $details
    }
}

function Start-ExchangeHealthCheck {
    [CmdletBinding()]
    param()

    Start-UIBusy -Message "Starte Exchange Health Check..." -Title "Health Check"
    try {
        # GUI-Updates vor dem Start
        Update-StatusBar -Message "Starte Exchange Health Check..." -Type "Info"
        $script:pbHealthCheck.IsIndeterminate = $true
        $script:pbHealthCheck.Visibility = [System.Windows.Visibility]::Visible
        $script:lvHealthCheckResults.Items.Clear()

        # Erzwinge ein Neuzeichnen der GUI, damit die Änderungen sichtbar werden
        $script:lvHealthCheckResults.Dispatcher.Invoke([Action]{}, "Background") | Out-Null

        # Definition der auszuführenden Checks
        $checks = @(
            { Test-ExchangeConnection },
            { Test-MailboxService },
            { Test-TransportService },
            { Test-ComplianceService },
            { Test-SecurityServices },
            { Test-LicenseStatus },
            { Test-TenantConfiguration }
        )

        $allResults = [System.Collections.Generic.List[object]]::new()

        # Führe jeden Check nacheinander aus
        $checkIndex = 0
        foreach ($check in $checks) {
            $checkName = ($check.ToString() -split ' ')[1].TrimEnd('}') # Extrahiert den Funktionsnamen
            Update-UIBusy -Message "Prüfe: $checkName" -Current $checkIndex -Total $checks.Count
            $checkIndex++
            Update-StatusBar -Message "Prüfe: $checkName..." -Type "Info"
            Write-Log "Prüfe: $checkName..." -Type "Info"
            
            # Führe den Check aus und füge das Ergebnis der Liste hinzu
            $result = & $check
            if ($null -ne $result) {
                $script:lvHealthCheckResults.Items.Add($result)
                $allResults.Add($result)
                # Erzwinge ein Neuzeichnen der GUI, um das neue Element anzuzeigen
                $script:lvHealthCheckResults.Dispatcher.Invoke([Action]{}, "Background") | Out-Null
            }
        }

        # GUI-Updates nach Abschluss aller Checks
        $script:pbHealthCheck.IsIndeterminate = $false
        $script:pbHealthCheck.Visibility = [System.Windows.Visibility]::Hidden

        # Ergebnisse zusammenfassen
        $okCount = ($allResults | Where-Object { $_.Status -eq "OK" }).Count
        $warningCount = ($allResults | Where-Object { $_.Status -eq "Warnung" }).Count
        $errorCount = ($allResults | Where-Object { $_.Status -eq "Fehler" }).Count

        $summaryMessage = "Health Check abgeschlossen: $okCount OK, $warningCount Warnungen, $errorCount Fehler"
        Update-StatusBar -Message $summaryMessage -Type "Success"

        Write-Log $summaryMessage -Type "Info"
        Log-Action $summaryMessage
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Health Check: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Health Check: $errorMsg"
        
        # GUI im Fehlerfall zurücksetzen
        $script:pbHealthCheck.IsIndeterminate = $false
        $script:pbHealthCheck.Visibility = [System.Windows.Visibility]::Hidden
        Update-StatusBar -Message "Fehler beim Health Check: $errorMsg" -Type "Error"
    }
    finally {
        Stop-UIBusy
    }
}

function Test-ExchangeConnection {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Teste Exchange Online Verbindung (erweiterte Prüfung)..." -Type "Debug"
        
        $details = [System.Collections.Generic.List[string]]::new()
        $overallStatus = "OK" # Start with OK, downgrade on any failure
        $networkProblem = $false
        $exoEndpoint = "outlook.office365.com"

        # 1. DNS-Auflösung für M365-Endpunkte prüfen
        Write-Log "Prüfe DNS-Auflösung für M365-Endpunkte..." -Type "Debug"
        $dnsTest = Resolve-DnsName -Name $exoEndpoint -ErrorAction SilentlyContinue
        if ($dnsTest) {
            $details.Add("✅ DNS-Auflösung für '$exoEndpoint' erfolgreich.")
        } else {
            $details.Add("⚠️ WARNUNG: DNS-Auflösung für '$exoEndpoint' fehlgeschlagen. Prüfen Sie Ihre DNS-Einstellungen.")
            $networkProblem = $true
        }

        # 2. Port-Konnektivität prüfen (HTTPS/443)
        Write-Log "Prüfe Port-Konnektivität (TCP 443)..." -Type "Debug"
        $portTest = Test-NetConnection -ComputerName $exoEndpoint -Port 443 -InformationLevel Quiet -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        if ($portTest) {
            $details.Add("✅ Verbindung zu '$exoEndpoint' auf Port 443 (HTTPS) erfolgreich.")
        } else {
            $details.Add("⚠️ WARNUNG: Direkte Verbindung zu '$exoEndpoint' auf Port 443 (HTTPS) fehlgeschlagen. Prüfen Sie Ihre Firewall-Regeln (bei Verwendung eines Proxys kann dieser Test fehlschlagen, obwohl die Verbindung funktioniert).")
            $networkProblem = $true
        }

        # 3. Test der PowerShell-Verbindung mit einem EXO-Befehl (wird immer ausgeführt,
        # da die Netzwerktests z.B. hinter einem Proxy fehlschlagen können)
        Write-Log "Prüfe PowerShell-Befehlsausführung (Get-OrganizationConfig)..." -Type "Debug"
        $testResult = Get-OrganizationConfig -ErrorAction SilentlyContinue
        
        if ($null -ne $testResult) {
            $details.Add("✅ PowerShell-Befehl (Get-OrganizationConfig) erfolgreich ausgeführt.")
            if ($networkProblem) { $overallStatus = "Warnung" }
        } else {
            $details.Add("❌ FEHLER: PowerShell-Befehl konnte nicht ausgeführt werden. Mögliche Ursachen: Netzwerkprobleme, Berechtigungen, abgelaufene Sitzung oder ein temporäres Microsoft-Dienstproblem.")
            $details.Add("➡️ Service Health Dashboard: https://admin.microsoft.com/Adminportal/Home#/servicehealth")
            $overallStatus = "Fehler"
        }

        return [PSCustomObject]@{
            CheckName = "Exchange Online Verbindung"
            Status    = $overallStatus
            Details   = $details -join "`n"
        }
    }
    catch {
        return [PSCustomObject]@{
            CheckName = "Exchange Online Verbindung"
            Status    = "Fehler"
            Details   = "Unerwarteter Fehler bei der Verbindungsprüfung: $($_.Exception.Message)"
        }
    }
}

function Test-MailboxService {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Teste Mailbox-Service..." -Type "Debug"
        $details = [System.Collections.Generic.List[string]]::new()
        $overallStatus = "OK"

        # 1. Test: Abrufen von Postfach-Objekten (Directory-Teil)
        Write-Log "Prüfe Abruf von Postfach-Objekten (Get-Mailbox)..." -Type "Debug"
        $testMailboxes = Get-Mailbox -ResultSize 5 -ErrorAction SilentlyContinue
        
        if ($null -ne $testMailboxes -and $testMailboxes.Count -gt 0) {
            $details.Add("✅ Postfach-Objekte können abgerufen werden (Get-Mailbox erfolgreich).")
            
            # 2. Test: Abrufen von Postfach-Statistiken (Store-Teil)
            $firstMailbox = $testMailboxes[0]
            Write-Log "Prüfe Abruf von Postfach-Statistiken für '$($firstMailbox.PrimarySmtpAddress)'..." -Type "Debug"
            $stats = Get-MailboxStatistics -Identity $firstMailbox.PrimarySmtpAddress -ErrorAction SilentlyContinue
            
            if ($null -ne $stats) {
                $details.Add("✅ Postfach-Statistiken können abgerufen werden (Get-MailboxStatistics erfolgreich).")
                $details.Add("➡️ Der Postfach-Speicher (Store) scheint erreichbar zu sein.")
            } else {
                $details.Add("⚠️ WARNUNG: Postfach-Statistiken konnten nicht abgerufen werden. Der Postfach-Speicher ist möglicherweise langsam oder nicht erreichbar.")
                if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
            }
        } else {
            $details.Add("❌ FEHLER: Postfach-Objekte konnten nicht abgerufen werden. Der Verzeichnisdienst für Postfächer antwortet nicht.")
            $overallStatus = "Fehler"
        }

        return [PSCustomObject]@{
            CheckName = "Mailbox-Service"
            Status    = $overallStatus
            Details   = $details -join "`n"
        }
    }
    catch {
        return [PSCustomObject]@{
            CheckName = "Mailbox-Service"
            Status    = "Fehler"
            Details   = "Unerwarteter Fehler beim Test des Mailbox-Service: $($_.Exception.Message)"
        }
    }
}

function Test-TransportService {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Teste Transport-Service..." -Type "Debug"
        $details = [System.Collections.Generic.List[string]]::new()
        $overallStatus = "OK"

        # 1. Test: Abrufen der Transport-Konfiguration
        Write-Log "Prüfe Abruf der Transport-Konfiguration (Get-TransportConfig)..." -Type "Debug"
        $transportConfig = Get-TransportConfig -ErrorAction SilentlyContinue
        if ($null -ne $transportConfig) {
            $details.Add("✅ Transport-Konfiguration kann abgerufen werden.")
        } else {
            $details.Add("❌ FEHLER: Transport-Konfiguration konnte nicht abgerufen werden. Dies deutet auf ein grundlegendes Problem hin.")
            $overallStatus = "Fehler"
        }

        # 2. Test: Abrufen von Transport-Regeln
        Write-Log "Prüfe Abruf von Transport-Regeln (Get-TransportRule)..." -Type "Debug"
        $transportRuleErrors = $null
        $transportRules = Get-TransportRule -ResultSize 1 -ErrorAction SilentlyContinue -ErrorVariable transportRuleErrors
        if ($null -ne $transportRules) {
            $details.Add("✅ Transport-Regeln können abgerufen werden.")
        } else {
            # Wenn keine Regeln vorhanden sind, ist das kein Fehler, aber das Cmdlet sollte nicht fehlschlagen.
            if (@($transportRuleErrors).Count -eq 0) {
                 $details.Add("✅ Transport-Regeln-Dienst ist erreichbar (keine Regeln gefunden).")
            } else {
                $details.Add("⚠️ WARNUNG: Transport-Regeln konnten nicht abgerufen werden. Der Regel-Dienst ist möglicherweise beeinträchtigt. Details: $($transportRuleErrors[0].Exception.Message)")
                if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
            }
        }

        # 3. Test: Nachrichtenverfolgungs-Dienst (Message Trace)
        Write-Log "Prüfe Nachrichtenverfolgungs-Dienst (Get-MessageTrace)..." -Type "Debug"
        # Wir führen eine sehr kurze Abfrage durch, nur um die Dienstverfügbarkeit zu testen.
        $traceErrors = $null
        if (Get-Command -Name Get-MessageTraceV2 -ErrorAction SilentlyContinue) {
            $traceTest = Get-MessageTraceV2 -StartDate (Get-Date).AddMinutes(-5) -EndDate (Get-Date) -ResultSize 1 -ErrorAction SilentlyContinue -ErrorVariable traceErrors
        } else {
            $traceTest = Get-MessageTrace -StartDate (Get-Date).AddMinutes(-1) -EndDate (Get-Date) -PageSize 1 -ErrorAction SilentlyContinue -ErrorVariable traceErrors
        }
        if ($null -ne $traceTest -or @($traceErrors).Count -eq 0) {
            $details.Add("✅ Nachrichtenverfolgungs-Dienst ist erreichbar.")
        } else {
            $details.Add("❌ FEHLER: Der Nachrichtenverfolgungs-Dienst antwortet nicht. Die Analyse des E-Mail-Flusses ist beeinträchtigt. Details: $($traceErrors[0].Exception.Message)")
            $overallStatus = "Fehler"
        }

        return [PSCustomObject]@{
            CheckName = "Transport-Service"
            Status    = $overallStatus
            Details   = $details -join "`n"
        }
    }
    catch {
        return [PSCustomObject]@{
            CheckName = "Transport-Service"
            Status    = "Fehler"
            Details   = "Unerwarteter Fehler beim Test des Transport-Service: $($_.Exception.Message)"
        }
    }
}

function Test-ComplianceService {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Teste Compliance-Service..." -Type "Debug"
        $details = [System.Collections.Generic.List[string]]::new()
        $overallStatus = "OK"

        # 1. Test: Audit-Status der Organisation prüfen
        Write-Log "Prüfe Audit-Status der Organisation (Get-OrganizationConfig)..." -Type "Debug"
        $orgConfig = Get-OrganizationConfig -ErrorAction SilentlyContinue
        if ($null -ne $orgConfig) {
            if ($orgConfig.AuditDisabled -eq $false) {
                $details.Add("✅ Audit-Protokollierung ist auf Organisationsebene aktiviert.")
            } else {
                $details.Add("⚠️ WARNUNG: Die Audit-Protokollierung ist auf Organisationsebene deaktiviert. Dies ist eine Sicherheitslücke.")
                if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
            }
        } else {
            $details.Add("❌ FEHLER: Die Organisationskonfiguration konnte nicht abgerufen werden. Grundlegende Compliance-Prüfungen sind nicht möglich.")
            $overallStatus = "Fehler"
        }

        # Ohne Compliance-Sitzung (Connect-IPPSSession) sind die folgenden Cmdlets nicht vorhanden
        if (-not (Test-ComplianceConnection)) {
            $details.Add("ℹ️ HINWEIS: Keine Verbindung zu Security & Compliance. DLP- und Aufbewahrungsrichtlinien werden erst nach 'Compliance verbinden' (Connect-IPPSSession) geprüft.")
            if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
            return [PSCustomObject]@{
                CheckName = "Compliance-Service"
                Status    = $overallStatus
                Details   = $details -join "`n"
            }
        }

        # 2. Test: Abrufen von Aufbewahrungsrichtlinien (Retention Policies)
        # Dieses Cmdlet ist Teil des Security & Compliance PowerShell und erfordert entsprechende Berechtigungen.
        Write-Log "Prüfe Abruf von Aufbewahrungsrichtlinien (Get-RetentionCompliancePolicy)..." -Type "Debug"
        try {
            # Der Abruf dient nur dem Test der Dienstverfügbarkeit; das Ergebnis wird nicht ausgewertet.
            $null = Get-OwnRetentionCompliancePolicy -ErrorAction Stop
            $details.Add("✅ Dienst für Aufbewahrungsrichtlinien ist erreichbar.")
        }
        catch {
            $errorMsg = Get-FormattedError -ErrorRecord $_
            $details.Add("⚠️ WARNUNG: Der Dienst für Aufbewahrungsrichtlinien antwortet nicht oder es fehlen Berechtigungen. Details: $errorMsg")
            if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
        }

        # 3. Test: Abrufen von DLP-Richtlinien (Data Loss Prevention)
        # Dieses Cmdlet ist ebenfalls Teil des Security & Compliance PowerShell.
        Write-Log "Prüfe Abruf von DLP-Richtlinien (Get-DlpCompliancePolicy)..." -Type "Debug"
        try {
            # Der Abruf dient nur dem Test der Dienstverfügbarkeit; das Ergebnis wird nicht ausgewertet.
            $null = Get-OwnDlpCompliancePolicy -ErrorAction Stop
            $details.Add("✅ Dienst für DLP-Richtlinien ist erreichbar.")
        }
        catch {
            $errorMsg = Get-FormattedError -ErrorRecord $_
            $details.Add("⚠️ WARNUNG: Der Dienst für DLP-Richtlinien antwortet nicht oder es fehlen Berechtigungen. Details: $errorMsg")
            if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
        }

        # Wenn grundlegende Checks fehlschlagen, hier abbrechen
        if ($overallStatus -eq "Fehler") {
            return [PSCustomObject]@{
                CheckName = "Compliance-Service"
                Status    = "Fehler"
                Details   = $details -join "`n"
            }
        }

        return [PSCustomObject]@{
            CheckName = "Compliance-Service"
            Status    = $overallStatus
            Details   = $details -join "`n"
        }
    }
    catch {
        return [PSCustomObject]@{
            CheckName = "Compliance-Service"
            Status    = "Fehler"
            Details   = "Unerwarteter Fehler beim Test des Compliance-Service: $($_.Exception.Message)"
        }
    }
}

function Test-SecurityServices {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Teste Security-Services..." -Type "Debug"
        $details = [System.Collections.Generic.List[string]]::new()
        $overallStatus = "OK"

        # 1. Anti-Spam-Richtlinien (Eingehend)
        Write-Log "Prüfe Anti-Spam-Richtlinien (eingehend)..." -Type "Debug"
        $spamPolicies = Get-HostedContentFilterPolicy -ErrorAction SilentlyContinue
        if ($null -ne $spamPolicies) {
            $details.Add("✅ Anti-Spam-Richtlinien (eingehend) sind konfiguriert.")
        } else {
            $details.Add("❌ FEHLER: Anti-Spam-Dienst (eingehend) nicht erreichbar oder keine Richtlinien gefunden.")
            $overallStatus = "Fehler"
        }

        # 2. Anti-Malware-Richtlinien
        Write-Log "Prüfe Anti-Malware-Richtlinien..." -Type "Debug"
        $malwarePolicies = Get-MalwareFilterPolicy -ErrorAction SilentlyContinue
        if ($null -ne $malwarePolicies) {
            $details.Add("✅ Anti-Malware-Richtlinien sind konfiguriert.")
        } else {
            $details.Add("❌ FEHLER: Anti-Malware-Dienst nicht erreichbar oder keine Richtlinien gefunden.")
            $overallStatus = "Fehler"
        }

        # 3. DKIM-Konfiguration
        Write-Log "Prüfe DKIM-Konfiguration..." -Type "Debug"
        $dkimConfigs = Get-DkimSigningConfig -ErrorAction SilentlyContinue
        if ($null -ne $dkimConfigs) {
            if ($dkimConfigs | Where-Object { $_.Enabled }) {
                $details.Add("✅ DKIM ist für mindestens eine Domain aktiviert.")
            } else {
                $details.Add("⚠️ WARNUNG: DKIM ist für keine Domain aktiviert. Dies wird für die E-Mail-Authentizität dringend empfohlen.")
                if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
            }
        } else {
            $details.Add("⚠️ WARNUNG: DKIM-Konfiguration konnte nicht abgerufen werden.")
            if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
        }

        # 4. Defender for Office 365-Richtlinien (optional, da lizenzabhängig)
        Write-Log "Prüfe Safe Links-Richtlinien (Defender for O365)..." -Type "Debug"
        $safeLinksPolicies = Get-SafeLinksPolicy -ErrorAction SilentlyContinue
        if ($null -ne $safeLinksPolicies) {
            $details.Add("ℹ️ Info: Safe Links-Richtlinien (Defender for O365) sind vorhanden.")
        } else {
            $details.Add("ℹ️ Info: Keine Safe Links-Richtlinien gefunden (möglicherweise nicht lizenziert).")
        }

        Write-Log "Prüfe Safe Attachment-Richtlinien (Defender for O365)..." -Type "Debug"
        $safeAttachmentPolicies = Get-SafeAttachmentPolicy -ErrorAction SilentlyContinue
        if ($null -ne $safeAttachmentPolicies) {
            $details.Add("ℹ️ Info: Safe Attachment-Richtlinien (Defender for O365) sind vorhanden.")
        } else {
            $details.Add("ℹ️ Info: Keine Safe Attachment-Richtlinien gefunden (möglicherweise nicht lizenziert).")
        }

        return [PSCustomObject]@{
            CheckName = "Security-Services"
            Status    = $overallStatus
            Details   = $details -join "`n"
        }
    }
    catch {
        return [PSCustomObject]@{
            CheckName = "Security-Services"
            Status    = "Fehler"
            Details   = "Unerwarteter Fehler beim Test der Security-Services: $($_.Exception.Message)"
        }
    }
}

function Test-LicenseStatus {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Teste Lizenz-Status..." -Type "Debug"
        $details = [System.Collections.Generic.List[string]]::new()
        $overallStatus = "OK"

        # Abrufen der Organisationskonfiguration, um den Servicetyp zu ermitteln
        $orgConfig = Get-OrganizationConfig -ErrorAction SilentlyContinue
        
        if ($null -ne $orgConfig) {
            $details.Add("✅ Organisationskonfiguration erfolgreich abgerufen.")
            $details.Add("➡️ Organisationstyp: $($orgConfig.OrganizationType)")
            
            # Überprüfen, ob es sich um einen dedizierten oder einen Standard-Mandanten handelt
            if ($orgConfig.IsDehydrated) {
                $details.Add("ℹ️ Info: Dies ist ein 'dehydrierter' Mandant (typisch für Hybrid-Szenarien). Lizenzdetails sind hier oft eingeschränkt.")
            }

            # Überprüfen der Lizenz-SKUs (erfordert MSOnline oder Microsoft.Graph Modul, was hier nicht vorausgesetzt wird)
            # Daher beschränken wir uns auf EXO-interne Checks.
            # Ein guter Indikator ist, ob Postfächer erstellt werden können.
            $testMailbox = Get-Mailbox -ResultSize 1 -ErrorAction SilentlyContinue
            if ($null -ne $testMailbox) {
                $details.Add("✅ Mindestens ein Postfach gefunden. Exchange Online-Lizenzen scheinen zugewiesen zu sein.")
            } else {
                $details.Add("⚠️ WARNUNG: Es konnten keine Postfächer gefunden werden. Überprüfen Sie, ob Lizenzen zugewiesen sind und die Synchronisierung korrekt ist.")
                if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
            }

            # Prüfung auf Premium-Features als Indikator für höhere Lizenzen
            $litigationHoldMailboxes = Get-Mailbox -Filter "LitigationHoldEnabled -eq `$true" -ResultSize 1 -ErrorAction SilentlyContinue
            if ($null -ne $litigationHoldMailboxes) {
                $details.Add("ℹ️ Info: Mindestens ein Postfach mit 'Litigation Hold' gefunden. Dies deutet auf Lizenzen wie E3/E5 oder Add-ons hin.")
            }

            $archiveMailboxes = Get-Mailbox -Filter "ArchiveStatus -ne 'None'" -ResultSize 1 -ErrorAction SilentlyContinue
            if ($null -ne $archiveMailboxes) {
                $details.Add("ℹ️ Info: Mindestens ein Postfach mit aktivem Archiv gefunden. Dies deutet auf Lizenzen wie Exchange Online Plan 2 oder höher hin.")
            }

        }
        else {
            $details.Add("❌ FEHLER: Die Organisationskonfiguration konnte nicht abgerufen werden. Eine grundlegende Lizenzprüfung ist nicht möglich.")
            $overallStatus = "Fehler"
        }

        return [PSCustomObject]@{
            CheckName = "Lizenz-Status"
            Status    = $overallStatus
            Details   = $details -join "`n"
        }
    }
    catch {
        return [PSCustomObject]@{
            CheckName = "Lizenz-Status"
            Status    = "Fehler"
            Details   = "Unerwarteter Fehler beim Test des Lizenz-Status: $($_.Exception.Message)"
        }
    }
}

function Test-TenantConfiguration {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Teste Tenant-Konfiguration..." -Type "Debug"
        $details = [System.Collections.Generic.List[string]]::new()
        $warnings = [System.Collections.Generic.List[string]]::new()
        $overallStatus = "OK"

        # 1. Test: Allgemeine Organisationskonfiguration abrufen
        Write-Log "Prüfe allgemeine Organisationskonfiguration (Get-OrganizationConfig)..." -Type "Debug"
        $orgConfig = Get-OrganizationConfig -ErrorAction SilentlyContinue
        if ($null -ne $orgConfig) {
            $details.Add("✅ Allgemeine Organisationskonfiguration erfolgreich abgerufen.")
            
            # Kritische Einstellungen prüfen
            if ($orgConfig.AuditDisabled -eq $true) {
                $warnings.Add("Die Audit-Protokollierung ist auf Organisationsebene deaktiviert. Dies ist eine Sicherheitslücke.")
                if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
            } else {
                $details.Add("✅ Audit-Protokollierung ist aktiviert.")
            }

            if ($orgConfig.OAuth2ClientProfileEnabled -eq $false) {
                $warnings.Add("Modern Authentication (OAuth2ClientProfileEnabled) ist deaktiviert. Dies ist veraltet und unsicher.")
                if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
            } else {
                $details.Add("✅ Modern Authentication ist aktiviert.")
            }

            $details.Add("➡️ Öffentliche Ordner: $($orgConfig.PublicFoldersEnabled)")

        } else {
            $warnings.Add("Die allgemeine Organisationskonfiguration konnte nicht abgerufen werden.")
            $overallStatus = "Fehler"
        }

        # SMTP AUTH (SmtpClientAuthenticationDisabled) ist Teil der Transport-Konfiguration
        Write-Log "Prüfe SMTP AUTH-Einstellung (Get-TransportConfig)..." -Type "Debug"
        $transportConfig = Get-TransportConfig -ErrorAction SilentlyContinue
        if ($null -ne $transportConfig) {
            if ($transportConfig.SmtpClientAuthenticationDisabled -ne $true) {
                $warnings.Add("SMTP AUTH ist mandantenweit aktiviert. Dies stellt ein erhebliches Sicherheitsrisiko dar und sollte deaktiviert werden, es sei denn, es wird explizit benötigt.")
                if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
            } else {
                $details.Add("✅ SMTP AUTH ist mandantenweit deaktiviert (Best Practice).")
            }
        } else {
            $warnings.Add("Die Transport-Konfiguration (SMTP AUTH) konnte nicht abgerufen werden.")
            if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
        }

        # 2. Test: Standard-Remote-Domain-Einstellungen prüfen
        Write-Log "Prüfe Standard-Remote-Domain-Einstellungen (Get-RemoteDomain)..." -Type "Debug"
        $remoteDomain = Get-RemoteDomain -Identity "Default" -ErrorAction SilentlyContinue
        if ($null -ne $remoteDomain) {
            $details.Add("✅ Standard-Remote-Domain-Einstellungen ('Default', '*') erfolgreich abgerufen.")
            if ($remoteDomain.AutoForwardEnabled -eq $true) {
                $warnings.Add("Automatische externe Weiterleitungen sind für die gesamte Organisation erlaubt. Dies stellt ein Sicherheitsrisiko dar.")
                if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
            } else {
                $details.Add("✅ Automatische externe Weiterleitungen sind standardmäßig blockiert (Best Practice).")
            }
            if ($remoteDomain.AutoReplyEnabled -eq $false) {
                $details.Add("ℹ️ Info: Automatische Abwesenheitsnotizen an externe Empfänger sind standardmäßig deaktiviert.")
            }
        } else {
            $warnings.Add("Die Standard-Remote-Domain-Einstellungen konnten nicht abgerufen werden.")
            if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
        }

        # 3. Test: Akzeptierte Domains prüfen
        Write-Log "Prüfe akzeptierte Domains (Get-AcceptedDomain)..." -Type "Debug"
        $acceptedDomains = Get-AcceptedDomain -ErrorAction SilentlyContinue
        if ($null -ne $acceptedDomains) {
            $details.Add("✅ Akzeptierte Domains erfolgreich abgerufen ($($acceptedDomains.Count) gefunden).")
            if (-not ($acceptedDomains | Where-Object { $_.IsDefault })) {
                $warnings.Add("Es ist keine Standard-Domain ('IsDefault' = $true) konfiguriert. Dies kann zu Problemen bei der E-Mail-Zustellung führen.")
                if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
            } else {
                $details.Add("✅ Eine Standard-Domain ist konfiguriert.")
            }
        } else {
            $warnings.Add("Die akzeptierten Domains konnten nicht abgerufen werden.")
            if ($overallStatus -ne "Fehler") { $overallStatus = "Warnung" }
        }

        # Ergebnis zusammenstellen
        $finalDetails = ""
        if ($warnings.Count -gt 0) {
            $finalDetails += "⚠️ Warnungen:`n"
            foreach ($warning in $warnings) {
                $finalDetails += "- $warning`n"
            }
            $finalDetails += "`n"
        }
        $finalDetails += "ℹ️ Details:`n"
        foreach ($detail in $details) {
            $finalDetails += "- $detail`n"
        }

        return [PSCustomObject]@{
            CheckName = "Tenant-Konfiguration"
            Status    = $overallStatus
            Details   = $finalDetails.Trim()
        }
    }
    catch {
        return [PSCustomObject]@{
            CheckName = "Tenant-Konfiguration"
            Status    = "Fehler"
            Details   = "Tenant-Konfiguration nicht abrufbar: $($_.Exception.Message)"
        }
    }
}

function Initialize-HealthCheckTab {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Initialisiere Health Check-Tab..." -Type "Info"
        
        # UI-Elemente referenzieren
        $btnRunHealthCheck = Get-XamlElement -ElementName "btnRunHealthCheck"
        $pbHealthCheck = Get-XamlElement -ElementName "pbHealthCheck"
        $lvHealthCheckResults = Get-XamlElement -ElementName "lvHealthCheckResults"
        
        # Globale Variablen setzen
        $script:btnRunHealthCheck = $btnRunHealthCheck
        $script:pbHealthCheck = $pbHealthCheck
        $script:lvHealthCheckResults = $lvHealthCheckResults
        
        # Event-Handler für Health Check Button registrieren
        Register-EventHandler -Control $btnRunHealthCheck -Handler {
            try {
                # Prüfen, ob eine Exchange-Verbindung besteht
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type "Warning"
                    return
                }
                
                Write-Log "Health Check wird gestartet..." -Type "Info"
                Update-StatusBar -Message "Health Check wird gestartet..." -Type "Info"
                Start-ExchangeHealthCheck
            }
            catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler bei der Ausführung des Health Checks."
                Write-Log "Fehler bei der Ausführung des Health Checks: $errorMsg" -Type "Error"
                Update-StatusBar -Message "Fehler beim Health Check: $($_.Exception.Message)" -Type "Error"
                Show-MessageBox -Message "Fehler beim Ausführen des Health Checks: `n$($_.Exception.Message)" -Title "Fehler" -Type "Error"
            }
        } -ControlName "btnRunHealthCheck"
        
        Write-Log "Health Check-Tab erfolgreich initialisiert" -Type "Success"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Initialisieren des Health Check-Tabs: $errorMsg" -Type "Error"
        return $false
    }
}
