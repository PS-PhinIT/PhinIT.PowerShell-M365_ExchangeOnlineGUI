# =====================================================================
# easyEXO - Modul: Troubleshooting (Diagnosen, Drosselungsrichtlinien)
# Datei: src/Modules/Features/Troubleshooting.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# -------------------------------------------------
# Abschnitt: Neue Hilfsfunktion für Throttling-Informationen
# -------------------------------------------------
function Get-ExchangeThrottlingInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$InfoType = "General"
    )
    
    try {
        Write-Log  "Rufe Exchange Throttling Informationen ab: $InfoType" -Type "Info"
        
        # Modern Exchange Online hat kein Get-ThrottlingPolicy, aber wir können alternative Informationen sammeln
        $result = @"
## Exchange Online Throttling Informationen

Hinweis: Der Befehl 'Get-ThrottlingPolicy' ist in modernen Exchange Online PowerShell-Verbindungen nicht mehr verfügbar.
Es wurden alternative Informationen zusammengestellt:

"@
        # Je nach gewünschtem Informationstyp unterschiedliche Alternativen anbieten
        switch ($InfoType) {
            "EWSPolicy" {
                $result += @"
### EWS Throttling Informationen

Die EWS-Throttling-Einstellungen können nicht direkt abgefragt werden, jedoch gelten folgende Standardlimits:
- EWSMaxConcurrency: 27 Anfragen/Benutzer
- EWSPercentTimeInAD: 75 (Prozentsatz der Zeit, die EWS in AD verbringen kann)
- EWSPercentTimeInCAS: 150 (Prozentsatz der Zeit, die EWS mit Client Access Services verbringen kann)
- EWSMaxSubscriptions: 20 Ereignisabonnements/Benutzer
- EWSFastSearchTimeoutInSeconds: 60 (Suchzeitlimit)

Weitere Informationen: https://learn.microsoft.com/de-de/exchange/clients-and-mobile-in-exchange-online/exchange-web-services/ews-throttling-in-exchange-online

Um die Werte für einen bestimmten Benutzer zu überprüfen, können Sie einen Test-Fall erstellen und das Verhalten analysieren.
"@
            }
            "PowerShell" {
                # Sammeln von verfügbaren Informationen über Remote PowerShell Limits
                try {
                    $orgConfig = Get-OrganizationConfig -ErrorAction SilentlyContinue
                    $result += @"
### PowerShell Throttling Informationen

PowerShell Verbindungslimits aus OrganizationConfig:
- PowerShellMaxConcurrency: $($orgConfig.PowerShellMaxConcurrency)
- PowerShellMaxCmdletQueueDepth: $($orgConfig.PowerShellMaxCmdletQueueDepth)
- PowerShellMaxCmdletsExecutionDuration: $($orgConfig.PowerShellMaxCmdletsExecutionDuration)

Standard Remote PowerShell Limits:
- 3 Remote PowerShell Verbindungen pro Benutzer
- 18 Remote PowerShell Verbindungen pro Mandant
- Timeoutzeit: 15 Minuten Leerlaufzeit

Weitere Informationen: https://learn.microsoft.com/de-de/powershell/exchange/exchange-online-powershell-v2?view=exchange-ps
"@
                }
                catch {
                    $result += "Fehler beim Abrufen von PowerShell-Konfigurationen: $($_.Exception.Message)`n`n"
                    $result += "Dies könnte auf fehlende Berechtigungen oder Verbindungsprobleme hindeuten."
                }
            }
            default {
                # Allgemeine Informationen zu Exchange Online Throttling
                $result += @"
### Allgemeine Throttling Informationen für Exchange Online

Exchange Online implementiert verschiedene Throttling-Mechanismen, um die Dienstverfügbarkeit für alle Benutzer sicherzustellen:

1. **EWS (Exchange Web Services)**
   - Begrenzte gleichzeitige Verbindungen und Anfragen pro Benutzer
   - Für Migrationstools empfohlene Werte: 
     * EWSMaxConcurrency: 20-50
     * EWSMaxConnections: 10-20
     * EWSMaxBatchSize: 500-1000

2. **Remote PowerShell**
   - Standardmäßig 3 Verbindungen pro Benutzer
   - 18 gleichzeitige Verbindungen pro Mandant
   - Timeout nach 15 Minuten Inaktivität

3. **REST APIs**
   - Verschiedene Limits je nach Endpunkt 
   - Microsoft Graph API hat eigene Throttling-Regeln

4. **SMTP**
   - Begrenzte ausgehende Nachrichten pro Tag
   - Begrenzte Empfänger pro Nachricht

Hinweis: Die genauen Throttling-Werte können sich ändern und werden nicht mehr über PowerShell-Cmdlets offengelegt. Bei anhaltenden Problemen mit Throttling wenden Sie sich an den Microsoft Support.

Weitere Informationen:
- https://learn.microsoft.com/de-de/exchange/clients-and-mobile-in-exchange-online/exchange-web-services/ews-throttling-in-exchange-online
- https://learn.microsoft.com/de-de/exchange/client-developer/exchange-web-services/how-to-maintain-affinity-between-group-of-subscriptions-and-mailbox-server
"@
            }
        }

        Write-Log  "Exchange Throttling Information erfolgreich erstellt" -Type "Success"
        return $result
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Abrufen der Exchange Throttling Informationen: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Abrufen der Exchange Throttling Informationen: $errorMsg"
        return "Fehler beim Abrufen der Exchange Throttling Informationen: $errorMsg"
    }
}

# -------------------------------------------------
# Abschnitt: Aktualisierte Throttling Policy Funktionen
# -------------------------------------------------
function Get-ThrottlingPolicyAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PolicyName = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowEWSOnly,
        
        [Parameter(Mandatory = $false)]
        [switch]$DetailedView
    )
    
    try {
        Write-Log  "Rufe alternative Throttling-Informationen ab" -Type "Info"
        
        if ($ShowEWSOnly) {
            return Get-ExchangeThrottlingInfo -InfoType "EWSPolicy"
        }
        elseif ($DetailedView) {
            return Get-ExchangeThrottlingInfo -InfoType "PowerShell"
        }
        else {
            return Get-ExchangeThrottlingInfo -InfoType "General"
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Abrufen der Throttling-Informationen: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Abrufen der Throttling-Informationen: $errorMsg"
        return "Fehler beim Abrufen der Throttling-Informationen: $errorMsg"
    }
}

# Funktion zur Unterstützung des Troubleshooting-Bereichs
function Get-ThrottlingPolicyForTroubleshooting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PolicyType
    )
    
    try {
        Write-Log  "Führe Throttling Policy Troubleshooting aus: $PolicyType" -Type "Info"
        
        switch ($PolicyType) {
            "EWSPolicy" {
                # Spezifisch für EWS Throttling (für Migrationstools)
                return Get-ExchangeThrottlingInfo -InfoType "EWSPolicy"
            }
            "PowerShell" {
                # Für Remote PowerShell Throttling
                return Get-ExchangeThrottlingInfo -InfoType "PowerShell"
            }
            "All" {
                # Zeige alle Policies in der Übersicht
                return Get-ExchangeThrottlingInfo -InfoType "General"
            }
            default {
                # Standard-Ansicht
                return Get-ExchangeThrottlingInfo -InfoType "General"
            }
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Throttling Policy Troubleshooting: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Throttling Policy Troubleshooting: $errorMsg"
        return "Fehler beim Abrufen der Throttling Policy Informationen: $errorMsg"
    }
}

# Erweitere die Diagnostics-Funktionen um einen speziellen Throttling-Test
function Test-EWSThrottlingPolicy {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log  "Prüfe EWS Throttling Policy für Migration" -Type "Info"
        
        # EWS Policy Informationen abrufen
        $ewsPolicy = Get-ExchangeThrottlingInfo -InfoType "EWSPolicy"
        
        # Ergebnis formatieren mit Empfehlungen
        $result = $ewsPolicy
        $result += "`n`nZusätzliche Empfehlungen für Migrationen:`n"
        $result += "- Verwenden Sie für große Migrationen mehrere Benutzerkonten, um die Throttling-Limits zu umgehen\n"
        $result += "- Planen Sie Migrationen zu Zeiten geringerer Exchange-Auslastung\n"
        $result += "- Implementieren Sie bei Throttling-Fehlern eine exponentielle Backoff-Strategie\n\n"
        
        $result += "Hinweis: Microsoft passt Throttling-Limits regelmäßig an, ohne dies zu dokumentieren.\n"
        $result += "Bei anhaltenden Problemen wenden Sie sich an den Microsoft Support."
        
        Write-Log  "EWS Throttling Policy Test abgeschlossen" -Type "Success"
        return $result
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Testen der EWS Throttling Policy: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Testen der EWS Throttling Policy: $errorMsg"
        return "Fehler beim Testen der EWS Throttling Policy: $errorMsg"
    }
}

# -------------------------------------------------
# Abschnitt: Exchange Online Troubleshooting Diagnostics
# -------------------------------------------------

# Erweiterte Diagnostics-Datenstruktur für umfassende Exchange Online Fehlerbehebung
$script:exchangeDiagnostics = @(
    @{
        Name = "Migrations-EWS-Drosselungsrichtlinie"
        Description = "Informationen über EWS-Drosselungseinstellungen für Postfachmigrationen (auch für Drittanbieter-Tools relevant)."
        PowerShellCheck = "Get-ExchangeThrottlingInfo -InfoType 'EWSPolicy'"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/settings/services"
        Tooltip = "Exchange Admin Center-Einstellungen öffnen"
    },
    @{
        Name = "Exchange Online Akzeptierte Domänen-Diagnose"
        Description = "Prüfen Sie, ob eine Domäne korrekt als akzeptierte Domäne in Exchange Online konfiguriert ist."
        PowerShellCheck = "Get-AcceptedDomain"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/accepted-domains"
        Tooltip = "Konfiguration akzeptierter Domänen überprüfen"
    },
    @{
        Name = "RBAC-Berechtigungsprüfung für Benutzer"
        Description = "Überprüfen Sie, ob ein Benutzer die erforderlichen RBAC-Rollen besitzt, um bestimmte Exchange Online-Cmdlets auszuführen."
        PowerShellCheck = "Get-ManagementRoleAssignment –RoleAssignee '[USER]'"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/permissions"
        Tooltip = "RBAC-Einstellungen zur Verwaltung von Benutzerberechtigungen öffnen"
        RequiresUser = $true
    },
    @{
        Name = "RBAC-Berechtigungsvergleich für zwei Benutzer"
        Description = "Vergleichen Sie die RBAC-Rollen zweier Benutzer, um Unterschiede zu identifizieren, wenn ein Benutzer Cmdlet-Fehler erhält."
        PowerShellCheck = "Compare-Object (Get-ManagementRoleAssignment –RoleAssignee '[USER1]') (Get-ManagementRoleAssignment –RoleAssignee '[USER2]')"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/permissions"
        Tooltip = "RBAC-Zuweisungen zur Fehlerbehebung überprüfen und vergleichen"
        RequiresTwoUsers = $true
    },
    @{
        Name = "Empfänger-Fehlerdiagnose"
        Description = "Überprüfen Sie den Status und die Konfiguration eines Exchange Online-Empfängers, um Bereitstellungs- oder Synchronisierungsprobleme zu beheben."
        PowerShellCheck = "Get-Recipient –Identity '[USER]'"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/recipients"
        Tooltip = "Empfängerkonfiguration und Bereitstellungsstatus überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Exchange-Organisationsobjekt-Prüfung"
        Description = "Diagnostizieren Sie Probleme mit dem Exchange Online-Organisationsobjekt, wie Mandantenbereitstellung oder RBAC-Fehlkonfigurationen."
        PowerShellCheck = "Get-OrganizationConfig | Format-List"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/organization"
        Tooltip = "Organisationskonfigurationseinstellungen überprüfen"
    },
    @{
        Name = "Postfach- und Nachrichtengröße"
        Description = "Überprüfen Sie die Postfachgröße und Nachrichtengröße (einschließlich Anhänge), um Speicherprobleme zu identifizieren."
        PowerShellCheck = "Get-MailboxStatistics –Identity '[USER]' | Select-Object DisplayName, TotalItemSize, ItemCount"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/mailboxes"
        Tooltip = "Postfachgröße und Speicherstatistiken überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Diagnose gelöschter Postfächer"
        Description = "Überprüfen Sie den Status kürzlich gelöschter (soft-deleted) Postfächer zur Wiederherstellung oder Bereinigung."
        PowerShellCheck = "Get-Mailbox –SoftDeletedMailbox"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/deletedmailboxes"
        Tooltip = "Gelöschte Postfächer verwalten"
    },
    @{
        Name = "Exchange Remote PowerShell Drosselungsinformationen"
        Description = "Bewerten Sie Remote PowerShell Drosselungseinstellungen, um Verbindungsprobleme zu minimieren. Hinweis: Remote PowerShell (RPS) wurde eingestellt - verwenden Sie die REST-basierten Cmdlets."
        PowerShellCheck = "Get-ExchangeThrottlingInfo -InfoType 'PowerShell'"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/settings"
        Tooltip = "Remote PowerShell Drosselungseinstellungen überprüfen"
    },
    @{
        Name = "E-Mail-Zustellungs-Problemlöser"
        Description = "Diagnostizieren Sie E-Mail-Zustellungsprobleme durch Nachverfolgung von Nachrichtenpfaden und Identifizierung von Fehlern."
        PowerShellCheck = "Get-MessageTraceV2 -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date)"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/mailflow"
        Tooltip = "Mail-Flow und Zustellungsprobleme überprüfen"
    },
    @{
        Name = "Archiv-Postfach-Diagnose"
        Description = "Überprüfen Sie die Konfiguration und den Status von Archiv-Postfächern, um sicherzustellen, dass die Archivierung aktiviert ist und funktioniert."
        PowerShellCheck = "Get-Mailbox –Identity '[USER]' | Select-Object DisplayName, ArchiveStatus"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/archivemailboxes"
        Tooltip = "Konfiguration des Archivpostfachs überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Aufbewahrungsrichtlinien-Diagnose für Benutzerpostfach"
        Description = "Überprüfen Sie die Aufbewahrungsrichtlinieneinstellungen (einschließlich Tags und Richtlinien) für ein Benutzerpostfach, um die Einhaltung der organisatorischen Richtlinien zu gewährleisten."
        PowerShellCheck = "Get-Mailbox –Identity '[USER]' | Select-Object DisplayName, RetentionPolicy; Get-RetentionPolicy"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/compliance"
        Tooltip = "Einstellungen der Aufbewahrungsrichtlinie überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "DKIM-Diagnose (DomainKeys Identified Mail)"
        Description = "Überprüfen Sie, ob die DKIM-Signierung korrekt konfiguriert ist und die richtigen DNS-Einträge veröffentlicht wurden."
        PowerShellCheck = "Get-DkimSigningConfig"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/dkim"
        Tooltip = "DKIM-Einstellungen verwalten und DNS-Konfiguration überprüfen"
    },
    @{
        Name = "Proxy-Adress-Konfliktdiagnose"
        Description = "Identifizieren Sie den Exchange-Empfänger, der eine bestimmte Proxy-Adresse (E-Mail-Adresse) verwendet, die Konflikte verursacht, z.B. Fehler bei der Postfacherstellung."
        PowerShellCheck = "Get-Recipient –Filter {EmailAddresses -like '[EMAIL]'}"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/recipients"
        Tooltip = "Proxy-Adresskonflikte identifizieren und beheben"
        RequiresEmail = $true
    },
    @{
        Name = "Diagnose für sichere/blockierte Absenderlisten"
        Description = "Überprüfen Sie sichere Absender und blockierte Absender/Domains in den Junk-E-Mail-Einstellungen eines Postfachs, um potenzielle Zustellungsprobleme zu beheben."
        PowerShellCheck = "Get-MailboxJunkEmailConfiguration –Identity '[USER]' | Select-Object SafeSenders, BlockedSenders"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/mailboxes"
        Tooltip = "Listen sicherer und blockierter Absender überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Gruppenpostfach-Diagnose"
        Description = "Überprüfen Sie die Konfiguration und Berechtigungen von Microsoft 365-Gruppen und deren Postfächern."
        PowerShellCheck = "Get-UnifiedGroup -Identity '[USER]' | Format-List"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/groups"
        Tooltip = "Gruppenpostfach-Konfiguration überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Verteilerlisten-Diagnose"
        Description = "Überprüfen Sie die Konfiguration, Mitgliedschaft und Zustellungseinstellungen von Verteilerlisten."
        PowerShellCheck = "Get-DistributionGroup -Identity '[USER]' | Format-List; Get-DistributionGroupMember -Identity '[USER]'"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/distributiongroups"
        Tooltip = "Verteilerlisten-Konfiguration überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Freigegebenes Postfach-Berechtigungsdiagnose"
        Description = "Überprüfen Sie die Berechtigungen und Zugriffseinstellungen für freigegebene Postfächer."
        PowerShellCheck = "Get-Mailbox -Identity '[USER]' -RecipientTypeDetails SharedMailbox | Format-List; Get-MailboxPermission -Identity '[USER]'"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/sharedmailboxes"
        Tooltip = "Berechtigungen für freigegebene Postfächer überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Transportregel-Diagnose"
        Description = "Überprüfen Sie die konfigurierten Transportregeln und deren Auswirkungen auf den E-Mail-Fluss."
        PowerShellCheck = "Get-TransportRule | Format-Table Name,State,Priority,Description -AutoSize"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/transportrules"
        Tooltip = "Transportregeln überprüfen"
    },
    @{
        Name = "Postfachberechtigungen-Übersicht"
        Description = "Zeigt eine Übersicht aller Berechtigungen für ein bestimmtes Postfach an."
        PowerShellCheck = "Get-MailboxPermission -Identity '[USER]'; Get-RecipientPermission -Identity '[USER]'; Get-MailboxFolderPermission -Identity '[USER]:\Kalender'"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/mailboxes"
        Tooltip = "Postfachberechtigungen überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Postfach-Audit-Konfiguration"
        Description = "Überprüfen Sie die Audit-Einstellungen für ein Postfach, um sicherzustellen, dass wichtige Aktionen protokolliert werden."
        PowerShellCheck = "Get-Mailbox -Identity '[USER]' | Select-Object DisplayName, AuditEnabled, AuditAdmin, AuditDelegate, AuditOwner, AuditLogAgeLimit"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/mailboxes"
        Tooltip = "Postfach-Audit-Einstellungen überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Postfach-Quota-Diagnose"
        Description = "Überprüfen Sie die Speicherquota-Einstellungen und -Nutzung für ein Postfach, um Speicherprobleme zu identifizieren."
        PowerShellCheck = "Get-Mailbox -Identity '[USER]' | Select-Object DisplayName, ProhibitSendQuota, ProhibitSendReceiveQuota, IssueWarningQuota; Get-MailboxStatistics -Identity '[USER]' | Select-Object TotalItemSize"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/mailboxes"
        Tooltip = "Postfach-Quota-Einstellungen überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Kalenderberechtigungen-Diagnose"
        Description = "Überprüfen Sie die Berechtigungen für den Kalender eines Benutzers, um Zugriffsprobleme zu beheben."
        PowerShellCheck = "Get-MailboxFolderPermission -Identity '[USER]:\Kalender'; Get-MailboxFolderPermission -Identity '[USER]:\Calendar'"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/mailboxes"
        Tooltip = "Kalenderberechtigungen überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Automatische Antworten-Diagnose"
        Description = "Überprüfen Sie die Konfiguration der automatischen Antworten (Out-of-Office) für einen Benutzer."
        PowerShellCheck = "Get-MailboxAutoReplyConfiguration -Identity '[USER]'"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/mailboxes"
        Tooltip = "Automatische Antworten-Einstellungen überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "E-Mail-Weiterleitung-Diagnose"
        Description = "Überprüfen Sie die E-Mail-Weiterleitungseinstellungen für ein Postfach, um unerwünschte Weiterleitungen zu identifizieren."
        PowerShellCheck = "Get-Mailbox -Identity '[USER]' | Select-Object DisplayName, ForwardingAddress, ForwardingSmtpAddress, DeliverToMailboxAndForward"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/mailboxes"
        Tooltip = "E-Mail-Weiterleitungseinstellungen überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Posteingangsregeln-Diagnose"
        Description = "Überprüfen Sie die Posteingangsregeln eines Benutzers, die E-Mail-Zustellungsprobleme verursachen könnten."
        PowerShellCheck = "Get-InboxRule -Mailbox '[USER]' | Format-Table Name, Enabled, Priority, Description -AutoSize"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/mailboxes"
        Tooltip = "Posteingangsregeln überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Mobile Geräte-Diagnose"
        Description = "Überprüfen Sie die mit einem Postfach verbundenen mobilen Geräte und deren Synchronisationsstatus."
        PowerShellCheck = "Get-MobileDevice -Mailbox '[USER]' | Format-Table DeviceId, DeviceType, LastSyncAttemptTime, DeviceAccessState -AutoSize"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/mobiledevices"
        Tooltip = "Mobile Geräte-Synchronisation überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Anti-Spam-Richtlinien-Diagnose"
        Description = "Überprüfen Sie die Anti-Spam-Richtlinien und deren Anwendung auf bestimmte Benutzer oder Domänen."
        PowerShellCheck = "Get-HostedContentFilterPolicy; Get-HostedContentFilterRule"
        AdminCenterLink = "https://security.microsoft.com/antispam"
        Tooltip = "Anti-Spam-Richtlinien im Security Center überprüfen"
    },
    @{
        Name = "Anti-Malware-Richtlinien-Diagnose"
        Description = "Überprüfen Sie die Anti-Malware-Richtlinien und deren Konfiguration für den Schutz vor schädlichen Anhängen."
        PowerShellCheck = "Get-MalwareFilterPolicy; Get-MalwareFilterRule"
        AdminCenterLink = "https://security.microsoft.com/antimalware"
        Tooltip = "Anti-Malware-Richtlinien im Security Center überprüfen"
    },
    @{
        Name = "Safe Attachments-Diagnose"
        Description = "Überprüfen Sie die Safe Attachments-Richtlinien für den Schutz vor schädlichen Anhängen."
        PowerShellCheck = "Get-SafeAttachmentPolicy; Get-SafeAttachmentRule"
        AdminCenterLink = "https://security.microsoft.com/safeattachmentv2"
        Tooltip = "Safe Attachments-Richtlinien im Security Center überprüfen"
    },
    @{
        Name = "Safe Links-Diagnose"
        Description = "Überprüfen Sie die Safe Links-Richtlinien für den Schutz vor schädlichen URLs in E-Mails."
        PowerShellCheck = "Get-SafeLinksPolicy; Get-SafeLinksRule"
        AdminCenterLink = "https://security.microsoft.com/safelinksv2"
        Tooltip = "Safe Links-Richtlinien im Security Center überprüfen"
    },
    @{
        Name = "Quarantäne-Diagnose"
        Description = "Überprüfen Sie die in Quarantäne befindlichen Nachrichten für einen bestimmten Benutzer oder die gesamte Organisation."
        PowerShellCheck = "Get-QuarantineMessage -RecipientAddress '[USER]' | Format-Table ReceivedTime, SenderAddress, Subject, QuarantineTypes -AutoSize"
        AdminCenterLink = "https://security.microsoft.com/quarantine"
        Tooltip = "Quarantäne-Nachrichten im Security Center überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Verbindungsfilter-Diagnose"
        Description = "Überprüfen Sie die Verbindungsfilter-Richtlinien, die IP-Adressen und Domänen blockieren oder zulassen."
        PowerShellCheck = "Get-HostedConnectionFilterPolicy"
        AdminCenterLink = "https://security.microsoft.com/connectionfilter"
        Tooltip = "Verbindungsfilter-Richtlinien im Security Center überprüfen"
    },
    @{
        Name = "Tenant Allow/Block List-Diagnose"
        Description = "Überprüfen Sie die mandantenweiten Zulassungs- und Blockierungslisten für URLs, Dateien und Absender."
        PowerShellCheck = "foreach (`$listType in 'Sender','Url','FileHash') { '=== ' + `$listType + ' ==='; Get-TenantAllowBlockListItems -ListType `$listType | Format-Table Value, Action, ExpirationDate, Notes -AutoSize }"
        AdminCenterLink = "https://security.microsoft.com/tenantAllowBlockList"
        Tooltip = "Tenant Allow/Block List im Security Center überprüfen"
    },
    @{
        Name = "Nachrichtenfluss-Regeln-Diagnose"
        Description = "Detaillierte Analyse der Nachrichtenfluss-Regeln (Transportregeln) und deren Auswirkungen auf E-Mails."
        PowerShellCheck = "Get-TransportRule | Format-List Name, State, Priority, Conditions, Actions, Exceptions"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/transportrules"
        Tooltip = "Nachrichtenfluss-Regeln detailliert überprüfen"
    },
    @{
        Name = "Connector-Diagnose"
        Description = "Überprüfen Sie die eingehenden und ausgehenden Connectors für den E-Mail-Fluss mit externen Systemen."
        PowerShellCheck = "Get-InboundConnector | Format-List Name, Enabled, ConnectorType, SenderDomains; Get-OutboundConnector | Format-List Name, Enabled, ConnectorType, RecipientDomains"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/connectors"
        Tooltip = "E-Mail-Connectors überprüfen"
    },
    @{
        Name = "Ressourcenpostfach-Diagnose"
        Description = "Überprüfen Sie die Konfiguration von Ressourcenpostfächern (Räume und Ausstattung) und deren Buchungsrichtlinien."
        PowerShellCheck = "Get-Mailbox -Identity '[USER]' -RecipientTypeDetails RoomMailbox,EquipmentMailbox | Format-List; Get-CalendarProcessing -Identity '[USER]'"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/resources"
        Tooltip = "Ressourcenpostfach-Konfiguration überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Öffentliche Ordner-Diagnose"
        Description = "Überprüfen Sie die Konfiguration und Berechtigungen von öffentlichen Ordnern in Exchange Online."
        PowerShellCheck = "Get-PublicFolder -Recurse | Format-Table Name, FolderPath, FolderSize -AutoSize"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/publicfolders"
        Tooltip = "Öffentliche Ordner-Konfiguration überprüfen"
    },
    @{
        Name = "Litigation Hold-Diagnose"
        Description = "Überprüfen Sie den Litigation Hold-Status für Postfächer zur Compliance und rechtlichen Aufbewahrung."
        PowerShellCheck = "Get-Mailbox -Identity '[USER]' | Select-Object DisplayName, LitigationHoldEnabled, LitigationHoldDate, LitigationHoldOwner, LitigationHoldDuration"
        AdminCenterLink = "https://compliance.microsoft.com/informationgovernance"
        Tooltip = "Litigation Hold-Einstellungen im Compliance Center überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "In-Place Hold-Diagnose"
        Description = "Zeigt organisationsweite Aufbewahrungs-Holds (InPlaceHolds der Organisationskonfiguration). Hinweis: Das klassische In-Place-eDiscovery (Get-MailboxSearch) wurde von Microsoft eingestellt."
        PowerShellCheck = "Get-OrganizationConfig | Select-Object -ExpandProperty InPlaceHolds"
        AdminCenterLink = "https://compliance.microsoft.com/informationgovernance"
        Tooltip = "In-Place Hold-Richtlinien im Compliance Center überprüfen"
    },
    @{
        Name = "Journaling-Diagnose"
        Description = "Überprüfen Sie die Journaling-Konfiguration für die Compliance-Archivierung von E-Mails."
        PowerShellCheck = "Get-JournalRule | Format-Table Name, Enabled, JournalEmailAddress, Scope -AutoSize"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/journaling"
        Tooltip = "Journaling-Regeln überprüfen"
    },
    @{
        Name = "Data Loss Prevention (DLP)-Diagnose"
        Description = "Überprüfen Sie DLP-Richtlinien und deren Anwendung zum Schutz sensibler Daten."
        PowerShellCheck = "if (Get-Command Get-DlpCompliancePolicy -ErrorAction SilentlyContinue) { Get-DlpCompliancePolicy | Format-Table Name, Mode, Enabled -AutoSize } else { 'Hinweis: DLP-Richtlinien werden über Security & Compliance PowerShell verwaltet. Bitte zuerst links auf ''Compliance verbinden'' klicken (Connect-IPPSSession) oder das Purview-Portal verwenden.' }"
        AdminCenterLink = "https://compliance.microsoft.com/datalossprevention"
        Tooltip = "DLP-Richtlinien im Compliance Center überprüfen"
    },
    @{
        Name = "Sensitivity Labels-Diagnose"
        Description = "Überprüfen Sie die Konfiguration von Vertraulichkeitsbezeichnungen für E-Mails und Dokumente."
        PowerShellCheck = "if (Get-Command Get-Label -ErrorAction SilentlyContinue) { Get-Label | Format-Table Name, DisplayName, Priority -AutoSize } else { 'Hinweis: Vertraulichkeitsbezeichnungen werden über Security & Compliance PowerShell verwaltet. Bitte zuerst links auf ''Compliance verbinden'' klicken (Connect-IPPSSession) oder das Purview-Portal verwenden.' }"
        AdminCenterLink = "https://compliance.microsoft.com/informationprotection"
        Tooltip = "Vertraulichkeitsbezeichnungen im Compliance Center überprüfen"
    },
    @{
        Name = "Exchange Online PowerShell-Modul-Diagnose"
        Description = "Überprüfen Sie die installierte Version des Exchange Online PowerShell-Moduls und prüfen Sie auf Updates. Remote PowerShell (RPS) wurde eingestellt - es werden nur REST-basierte Verbindungen (Modul ab Version 3) unterstützt."
        PowerShellCheck = "Get-InstalledModule ExchangeOnlineManagement | Select-Object Name, Version; Get-Module ExchangeOnlineManagement -ListAvailable | Select-Object Name, Version"
        AdminCenterLink = "https://learn.microsoft.com/powershell/exchange/exchange-online-powershell-v2"
        Tooltip = "Exchange Online PowerShell-Dokumentation öffnen"
    },
    @{
        Name = "Hybrid-Konfiguration-Diagnose"
        Description = "Überprüfen Sie die Hybrid-Konfiguration zwischen lokaler Exchange-Umgebung und Exchange Online."
        PowerShellCheck = "Get-OrganizationRelationship | Format-List Name, DomainNames, Enabled, FreeBusyAccessEnabled; Get-OnPremisesOrganization | Format-List; Get-IntraOrganizationConnector | Format-List"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/hybrid"
        Tooltip = "Hybrid-Konfiguration überprüfen"
    },
    @{
        Name = "Migration-Batch-Diagnose"
        Description = "Überprüfen Sie den Status laufender oder abgeschlossener Postfach-Migrationen."
        PowerShellCheck = "Get-MigrationBatch | Format-Table Identity, Status, TotalCount, SyncedCount, FinalizedCount -AutoSize"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/migration"
        Tooltip = "Migration-Batches überprüfen"
    },
    @{
        Name = "Benutzer-Migration-Status-Diagnose"
        Description = "Überprüfen Sie den detaillierten Migrationsstatus für einen bestimmten Benutzer."
        PowerShellCheck = "Get-MigrationUser -Identity '[USER]' | Format-List"
        AdminCenterLink = "https://admin.exchange.microsoft.com/#/migration"
        Tooltip = "Benutzer-Migrationsstatus überprüfen"
        RequiresUser = $true
    },
    @{
        Name = "Exchange Online Service Health-Diagnose"
        Description = "Überprüfen Sie den aktuellen Service Health-Status von Exchange Online und bekannte Probleme."
        PowerShellCheck = "# Service Health wird über das Admin Center oder Microsoft 365 Service Health Dashboard abgerufen"
        AdminCenterLink = "https://admin.microsoft.com/adminportal/home#/servicehealth"
        Tooltip = "Service Health Dashboard öffnen"
    }
)

# Verbesserte Start-ExchangeDiagnostic Funktion mit noch robusterer Fehlerbehandlung und RPS-Kompatibilität
function Start-ExchangeDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$DiagnosticIndex,
        
        [Parameter(Mandatory = $false)]
        [string]$User = "",
        
        [Parameter(Mandatory = $false)]
        [string]$User2 = "",

        [Parameter(Mandatory = $false)]
        [string]$Email = ""
    )
    
    try {
        if (-not $script:isConnected) {
            throw "Sie müssen zuerst mit Exchange Online verbunden sein."
        }
        
        $diagnostic = $script:exchangeDiagnostics[$DiagnosticIndex]
        Write-Log  "Führe Diagnose aus: $($diagnostic.Name)" -Type "Info"
        
        # Status aktualisieren
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "Diagnose wird ausgeführt: $($diagnostic.Name)..."
        }
        
        # Befehl vorbereiten
        $command = $diagnostic.PowerShellCheck
        
        # Platzhalter ersetzen
        # Benutzereingaben für die Verwendung in einfachen Anführungszeichen maskieren (Schutz vor Code-Injection)
        $safeUser  = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($User.Trim())
        $safeUser2 = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($User2.Trim())
        $safeEmail = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($Email.Trim())

        if ($diagnostic.RequiresUser -and -not [string]::IsNullOrEmpty($User)) {
            $command = $command.Replace('[USER]', $safeUser)
        } elseif ($diagnostic.RequiresUser -and [string]::IsNullOrEmpty($User)) {
            throw "Diese Diagnose erfordert einen Benutzernamen."
        }
        
        if ($diagnostic.RequiresTwoUsers) {
            if ([string]::IsNullOrEmpty($User) -or [string]::IsNullOrEmpty($User2)) {
                throw "Diese Diagnose erfordert zwei Benutzernamen."
            }
            $command = $command.Replace('[USER1]', $safeUser).Replace('[USER2]', $safeUser2)
        }
        
        if ($diagnostic.RequiresEmail) {
            if ([string]::IsNullOrEmpty($Email)) {
                throw "Diese Diagnose erfordert eine E-Mail-Adresse."
            }
            $command = $command.Replace('[EMAIL]', $safeEmail)
        }
        
        # Spezielle Behandlung für Service Health
        if ($command -like "*Service Health*") {
            $result = "Service Health-Informationen sind über das Microsoft 365 Admin Center verfügbar.`n"
            $result += "Öffnen Sie das Service Health Dashboard über den bereitgestellten Link.`n"
            $result += "Dort finden Sie aktuelle Informationen über:`n"
            $result += "- Service-Unterbrechungen`n"
            $result += "- Geplante Wartungsarbeiten`n"
            $result += "- Service-Advisories`n"
            $result += "- Incident-Historie`n"
            return $result
        }
        
        # Befehl ausführen
        Write-Log  "Führe PowerShell-Befehl aus: $command" -Type "Info"
        
        # Create ScriptBlock from command string and execute
        try {
            $scriptBlock = [Scriptblock]::Create($command)
            $result = & $scriptBlock | Out-String
            
            # Behandlung für leere Ergebnisse
            if ([string]::IsNullOrWhiteSpace($result)) {
                $result = "Die Abfrage wurde erfolgreich ausgeführt, lieferte aber keine Ergebnisse. Dies kann bedeuten, dass keine Daten vorhanden sind oder dass ein Filter keine Übereinstimmungen fand."
            }
        }
        catch {
            # Spezielle Behandlung für bekannte Fehler
            if ($_.Exception.Message -like "*Get-ThrottlingPolicy*") {
                Write-Log  "Get-ThrottlingPolicy ist nicht verfügbar, verwende alternative Informationsquellen" -Type "Warning"
                $result = Get-ExchangeThrottlingInfo -InfoType $(if ($command -like "*EWS*") { "EWSPolicy" } elseif ($command -like "*PowerShell*") { "PowerShell" } else { "General" })
            }
            elseif ($_.Exception.Message -like "*not recognized as the name of a cmdlet*") {
                Write-Log  "Cmdlet wird nicht erkannt: $($_.Exception.Message)" -Type "Warning"
                
                # Spezifische Behandlung für bekannte alte Cmdlets und deren Ersatz
                if ($command -like "*Get-EXORecipient*") {
                    Write-Log  "Versuche Get-Recipient als Alternative zu Get-EXORecipient" -Type "Info"
                    $alternativeCommand = $command -replace "Get-EXORecipient", "Get-Recipient"
                    try {
                        $scriptBlock = [Scriptblock]::Create($alternativeCommand)
                        $result = & $scriptBlock | Out-String
                    } catch {
                        throw "Fehler beim Ausführen des alternativen Befehls: $($_.Exception.Message)"
                    }
                }
                elseif ($command -like "*Get-EXOMailboxStatistics*") {
                    Write-Log  "Versuche Get-MailboxStatistics als Alternative zu Get-EXOMailboxStatistics" -Type "Info"
                    $alternativeCommand = $command -replace "Get-EXOMailboxStatistics", "Get-MailboxStatistics"
                    try {
                        $scriptBlock = [Scriptblock]::Create($alternativeCommand)
                        $result = & $scriptBlock | Out-String
                    } catch {
                        throw "Fehler beim Ausführen des alternativen Befehls: $($_.Exception.Message)"
                    }
                }
                elseif ($command -like "*Get-EXOMailbox*") {
                    Write-Log  "Versuche Get-Mailbox als Alternative zu Get-EXOMailbox" -Type "Info"
                    $alternativeCommand = $command -replace "Get-EXOMailbox", "Get-Mailbox"
                    try {
                        $scriptBlock = [Scriptblock]::Create($alternativeCommand)
                        $result = & $scriptBlock | Out-String
                    } catch {
                        throw "Fehler beim Ausführen des alternativen Befehls: $($_.Exception.Message)"
                    }
                }
                else {
                    throw
                }
            }
            else {
                throw
            }
        }
        
        Log-Action "Exchange-Diagnose ausgeführt: $($diagnostic.Name)"
        Write-Log  "Diagnose abgeschlossen: $($diagnostic.Name)" -Type "Success"
        
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "Diagnose abgeschlossen: $($diagnostic.Name)" -Color $script:connectedBrush
        }
        
        # Format und Filter Ausgabe für bessere Lesbarkeit
        if ($result.Length -gt 30000) {
            $result = $result.Substring(0, 30000) + "`n`n... (Output gekürzt - zu viele Daten)`n"
        }
        
        # Zusätzliche Hinweise für RPS-bezogene Diagnosen
        if ($diagnostic.Name -like "*PowerShell*" -or $diagnostic.Name -like "*Remote*") {
            $result += "`n`n=== WICHTIGER HINWEIS ===`n"
            $result += "Remote PowerShell (RPS) wurde bereits im Juli 2023 in Exchange Online eingestellt.`n"
            $result += "Stellen Sie sicher, dass Sie das neueste Exchange Online PowerShell V3-Modul verwenden.`n"
            $result += "Weitere Informationen: https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell-v2?view=exchange-ps`n"
            $result += "Verwenden Sie Connect-ExchangeOnline ohne den -UseRPSSession Parameter.`n"
        }
        
        return $result
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler bei der Diagnose: $errorMsg" -Type "Error"
        Log-Action "Fehler bei der Exchange-Diagnose '$($diagnostic.Name)': $errorMsg"
        
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "Fehler bei der Diagnose: $errorMsg"
        }
        
        # Hilfreiche Fehlermeldung für häufige Probleme
        $result = "Fehler bei der Ausführung der Diagnose: $errorMsg`n`n"
        
        if ($errorMsg -like "*is not recognized as the name of a cmdlet*") {
            $result += "Dies könnte folgende Gründe haben:`n"
            $result += "1. Das verwendete Cmdlet ist in modernen Exchange Online PowerShell-Verbindungen nicht mehr verfügbar.`n"
            $result += "2. Sie benötigen möglicherweise zusätzliche Berechtigungen.`n"
            $result += "3. Die Exchange Online Verbindung wurde getrennt oder ist eingeschränkt.`n"
            $result += "4. Remote PowerShell (RPS) wurde eingestellt - verwenden Sie die REST-basierten Cmdlets.`n`n"
            $result += "Empfehlung: Aktualisieren Sie auf Exchange Online PowerShell V3 und verwenden Sie Connect-ExchangeOnline ohne -UseRPSSession.`n"
            $result += "Weitere Informationen: https://learn.microsoft.com/powershell/exchange/exchange-online-powershell-v2"
        }
        elseif ($errorMsg -like "*Benutzer nicht gefunden*" -or $errorMsg -like "*user not found*") {
            $result += "Der angegebene Benutzer konnte nicht gefunden werden. Mögliche Ursachen:`n"
            $result += "1. Der Benutzername oder die E-Mail-Adresse wurde falsch eingegeben.`n"
            $result += "2. Der Benutzer existiert nicht in der Exchange Online-Umgebung.`n"
            $result += "3. Es kann bis zu 24 Stunden dauern, bis ein neuer Benutzer in allen Exchange-Systemen sichtbar ist.`n`n"
            $result += "Empfehlung: Überprüfen Sie die Schreibweise oder verwenden Sie den vollständigen UPN (user@domain.com)."
        }
        elseif ($errorMsg -like "*insufficient*" -or $errorMsg -like "*not authorized*" -or $errorMsg -like "*access*denied*") {
            $result += "Sie haben nicht die erforderlichen Berechtigungen für diesen Vorgang. Mögliche Lösungen:`n"
            $result += "1. Versuchen Sie, sich mit einem Exchange Admin-Konto anzumelden.`n"
            $result += "2. Lassen Sie sich die erforderlichen RBAC-Rollen zuweisen.`n"
            $result += "3. Verwenden Sie das Exchange Admin Center für diese Aufgabe.`n"
        }
        elseif ($errorMsg -like "*timeout*" -or $errorMsg -like "*Zeitüberschreitung*") {
            $result += "Die Verbindung wurde durch ein Timeout unterbrochen. Mögliche Lösungen:`n"
            $result += "1. Stellen Sie die Verbindung zu Exchange Online neu her.`n"
            $result += "2. Die Abfrage könnte zu umfangreich sein, versuchen Sie einen spezifischeren Filter.`n"
            $result += "3. Exchange Online kann bei hoher Last gedrosselt werden, versuchen Sie es später erneut.`n"
        }
        elseif ($errorMsg -like "*throttling*" -or $errorMsg -like "*Drosselung*") {
            $result += "Die Anfrage wurde aufgrund von Throttling-Limits abgelehnt. Lösungsansätze:`n"
            $result += "1. Warten Sie einige Minuten und versuchen Sie es erneut.`n"
            $result += "2. Reduzieren Sie die Anzahl gleichzeitiger PowerShell-Verbindungen.`n"
            $result += "3. Verwenden Sie REST-API-basierte Cmdlets anstelle von RPS.`n"
            $result += "4. Implementieren Sie eine Backoff-Strategie in Ihren Skripten.`n"
        }
        
        return $result
    }
}

function Initialize-TroubleshootingTab {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log  "Initialisiere Troubleshooting-Tab" -Type "Info"
        
        # Referenzieren der UI-Elemente im Troubleshooting-Tab
        $lstDiagnostics = Get-XamlElement -ElementName "lstDiagnostics"
        $txtDiagnosticUser = Get-XamlElement -ElementName "txtDiagnosticUser"
        $txtDiagnosticUser2 = Get-XamlElement -ElementName "txtDiagnosticUser2"
        $txtDiagnosticEmail = Get-XamlElement -ElementName "txtDiagnosticEmail"
        $btnRunDiagnostic = Get-XamlElement -ElementName "btnRunDiagnostic"
        $btnAdminCenter = Get-XamlElement -ElementName "btnAdminCenter"
        $txtDiagnosticResult = Get-XamlElement -ElementName "txtDiagnosticResult"
        $helpLinkTroubleshooting = Get-XamlElement -ElementName "helpLinkTroubleshooting"
        
        # Globale Variablen für spätere Verwendung setzen
        $script:lstDiagnostics = $lstDiagnostics
        $script:txtDiagnosticUser = $txtDiagnosticUser
        $script:txtDiagnosticUser2 = $txtDiagnosticUser2
        $script:txtDiagnosticEmail = $txtDiagnosticEmail
        $script:txtDiagnosticResult = $txtDiagnosticResult
        
        # Diagnostics-Liste befüllen
        if ($null -ne $lstDiagnostics) {
            $lstDiagnostics.Items.Clear()
            for ($i = 0; $i -lt $script:exchangeDiagnostics.Count; $i++) {
                $diagnostic = $script:exchangeDiagnostics[$i]
                $item = New-Object PSObject -Property @{
                    Name = $diagnostic.Name
                    Description = $diagnostic.Description
                    Index = $i
                }
                [void]$lstDiagnostics.Items.Add($item)
            }
            
            # Set DisplayMemberPath to only show the Name property
            $lstDiagnostics.DisplayMemberPath = "Name"
        }
        
        # Event-Handler für Diagnose-Button registrieren
        Register-EventHandler -Control $btnRunDiagnostic -Handler {
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
                
                # Prüfen, ob ein Eintrag in der Liste ausgewählt wurde
                if ($null -eq $script:lstDiagnostics.SelectedItem) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte wählen Sie eine Diagnose aus der Liste.",
                        "Keine Diagnose ausgewählt",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $diagnosticIndex = $script:lstDiagnostics.SelectedItem.Index
                $user = $script:txtDiagnosticUser.Text
                $user2 = $script:txtDiagnosticUser2.Text
                $email = $script:txtDiagnosticEmail.Text
                
                Write-Log  "Führe Diagnose aus: Index=$diagnosticIndex, User=$user, User2=$user2, Email=$email" -Type "Info"
                
                $result = Start-ExchangeDiagnostic -DiagnosticIndex $diagnosticIndex -User $user -User2 $user2 -Email $email
                
                if ($null -ne $script:txtDiagnosticResult) {
                    $script:txtDiagnosticResult.Text = $result
                    $script:txtStatus.Text = "Diagnose erfolgreich ausgeführt."
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log  "Fehler bei der Diagnose: $errorMsg" -Type "Error"
                if ($null -ne $script:txtStatus) {
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
                
                if ($null -ne $script:txtDiagnosticResult) {
                    $script:txtDiagnosticResult.Text = "Fehler bei der Diagnose: $errorMsg"
                }
            }
        } -ControlName "btnRunDiagnostic"
        
        
        # Event-Handler für Admin-Center-Button
        Register-EventHandler -Control $btnAdminCenter -Handler {
            try {
                # Prüfen, ob ein Eintrag in der Liste ausgewählt wurde
                if ($null -eq $script:lstDiagnostics.SelectedItem) {
                    [System.Windows.MessageBox]::Show(
                        "Bitte wählen Sie eine Diagnose aus der Liste.",
                        "Keine Diagnose ausgewählt",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                    return
                }
                
                $diagnosticIndex = $script:lstDiagnostics.SelectedItem.Index
                
                Write-Log  "Öffne Admin-Center für Diagnose: Index=$diagnosticIndex" -Type "Info"
                $result = Open-AdminCenterLink -DiagnosticIndex $diagnosticIndex
                
                if (-not $result) {
                    [System.Windows.MessageBox]::Show(
                        "Kein Admin-Center-Link für diese Diagnose verfügbar.",
                        "Kein Link verfügbar",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Information
                    )
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log  "Fehler beim Öffnen des Admin-Centers: $errorMsg" -Type "Error"
                if ($null -ne $script:txtStatus) {
                    $script:txtStatus.Text = "Fehler: $errorMsg"
                }
            }
        } -ControlName "btnAdminCenter"
        
        # Event-Handler für Hilfe-Link
        if ($null -ne $helpLinkTroubleshooting) {
            $helpLinkTroubleshooting.Add_MouseLeftButtonDown({
                Show-HelpDialog -Topic "Troubleshooting"
            })
            
            $helpLinkTroubleshooting.Add_MouseEnter({
                $this.Cursor = [System.Windows.Input.Cursors]::Hand
                $this.TextDecorations = [System.Windows.TextDecorations]::Underline
            })
            
            $helpLinkTroubleshooting.Add_MouseLeave({
                $this.TextDecorations = $null
                $this.Cursor = [System.Windows.Input.Cursors]::Arrow
            })
        }
        
        $null = Register-EventHandler -Control (Get-XamlElement -ElementName "btnExportDiagnosticResult") -ControlName "btnExportDiagnosticResult" -Handler {
            $diagnosticText = if ($null -ne $script:txtDiagnosticResult) { [string]$script:txtDiagnosticResult.Text } else { "" }
            Export-TextContent -Text $diagnosticText -DefaultFileName "Diagnose_Ergebnis"
        }

        Write-Log  "Troubleshooting-Tab erfolgreich initialisiert" -Type "Success"
        return $true
            }
            catch {
                $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Initialisieren des Troubleshooting-Tabs: $errorMsg" -Type "Error"
        return $false
    }
}
