# Audit-Bericht easyEXO

| | |
|---|---|
| **Version geprüft** | 0.1.1 (`easyEXO_V0.1.1.ps1`, ~28.500 Zeilen) |
| **Version nach Behebung** | 0.2.0, offene Punkte und Nachprüfung in 0.3.0, Funktionslücken (nicht angebundene Bereiche und Steuerelemente) in 0.4.0, vollständige Nachprüfung aller Module in 0.5.0 (`src/easyEXO.ps1` + `src/Modules/**`, `src/GUI/*.xaml`) |
| **Datum** | 2026-10-14 |
| **Umfang** | Sicherheit, Befehle (Exchange-Cmdlets), Verweise (Funktionen/XAML-Elemente), GUI, Performance, Funktionen, Repository-Struktur und Dokumentation |
| **Methodik** | Manuelle Code-Review, PowerShell-Parser (`Parser::ParseFile`), PSScriptAnalyzer 1.25 (Error/Warning), Abgleich aller `FindName`/`Get-XamlElement`-Aufrufe mit dem XAML, Abgleich aller benannten XAML-Elemente mit dem Code (Steuerelemente ohne Funktion), Abgleich der Hilfethemen, Abgleich der verwendeten Cmdlets und Parameter mit der aktuellen ExchangeOnlineManagement-Dokumentation, Abgleich der DataGrid-Spaltenbindungen mit den Cmdlet-Eigenschaften, Prüfung aller Inline-XAML-Dialoge (Wohlgeformtheit, eingesetzte Daten, Farben) |

Legende: ✅ behoben · ⚠️ offen / bekannte Einschränkung. Befunde ab S12, B20, V26, G21, P8 und R7 stammen aus der Nachprüfung zu 0.5.0.

## Zusammenfassung

| Kategorie | Befunde | Behoben | Offen |
|---|---:|---:|---:|
| Sicherheit | 19 | 19 | 0 |
| Befehle | 33 | 33 | 0 |
| Verweise / Funktionen | 39 | 39 | 0 |
| GUI | 29 | 29 | 0 |
| Performance | 12 | 12 | 0 |
| Code-Qualität (PSScriptAnalyzer) | 5 | 4 | 1 |
| Architektur / Modularisierung | 4 | 4 | 0 |
| Repository / Dokumentation | 9 | 9 | 0 |

Ergebnis nach Behebung (0.5.0): **0 Parser-Fehler** in allen 34 Skriptdateien; PSScriptAnalyzer meldet **keine Fehler**
mehr, nur noch Warnungen (überwiegend Namens-/Stilregeln, siehe Abschnitt 6). Alle Funktionsaufrufe lassen sich
modulübergreifend auflösen, alle `Get-XamlElement`/`FindName`-Verweise existieren im XAML, alle `StaticResource`-,
`DynamicResource`- und `TryFindResource`-Schlüssel sind im Theme definiert. Jedes benannte Steuerelement des
Hauptfensters ist im Code angebunden (Ausnahme: reine Layout-Container `tabOrgSettings`, `gridOrgButtons`).
`MainWindow.xaml` und alle Inline-Dialoge enthalten keine fest kodierten Farben mehr.

---

## 1. Sicherheit

| # | Befund | Schwere | Status |
|---|---|---|---|
| S1 | **Code-Injection** in der Exchange-Diagnose: Benutzereingaben wurden per `-replace` in Befehlsvorlagen eingesetzt und mit `[ScriptBlock]::Create()` ausgeführt. Eine Eingabe wie `x'; Remove-Mailbox …` hätte beliebige Befehle ausgeführt. | Hoch | ✅ Eingaben werden mit `CodeGeneration::EscapeSingleQuotedStringContent` maskiert und literal ersetzt. |
| S2 | **PowerShell-7-Installer**: MSI-Download ohne Signaturprüfung in vorhersagbaren Temp-Pfad, Installation mit `ENABLE_PSREMOTING=1` und Kontextmenü; winget ohne exakte ID/Quelle. | Hoch | ✅ TLS 1.2, eindeutiges Temp-Verzeichnis, Authenticode-Prüfung (Valid + Microsoft Corporation), keine Zusatzfeatures, `winget --id Microsoft.PowerShell --exact --source winget`. Das Explorer-Kontextmenü wurde erst in 0.5.0 entfernt (S17). |
| S3 | Skript erzwang **Administratorrechte** (Neustart mit `RunAs`), obwohl für Exchange Online nicht erforderlich. | Mittel | ✅ Keine Adminrechte mehr nötig; Neustart mit `-NoProfile -STA -File`. |
| S4 | **CSV-/Formel-Injection** bei allen Exporten (Werte wie `=HYPERLINK(...)` aus Exchange-Attributen). | Mittel | ✅ `ConvertTo-SafeCsvObject` in allen `Export-Csv`-Pfaden. |
| S5 | **OPATH-Filter-Injection** in der Kontaktsuche (`-Filter "... -like '*$input*'"`). | Mittel | ✅ `ConvertTo-OPathValue` (verdoppelt einfache Anführungszeichen). |
| S6 | **Log-Injection**: Zeilenumbrüche in Benutzereingaben erzeugten gefälschte Log-Zeilen. | Niedrig | ✅ Steuerzeichen werden entfernt. |
| S7 | **Fehlende Bestätigungen** vor destruktiven Aktionen (FullAccess/SendAs/Weiterleitung/Kalenderberechtigung entfernen); 7 Bestätigungsdialoge waren durch `Show-MessageBox -Type YesNo` funktionslos (Aktion lief ohne Rückfrage). | Mittel | ✅ Bestätigungen ergänzt; `Show-MessageBox` gibt bei Fehlern `No` zurück (fail-safe). |
| S8 | Authenticode-Signatur nach Änderungen ungültig. | Info | ✅ Signaturblock entfernt; Neusignierung durch Maintainer dokumentiert ([SECURITY.md](../SECURITY.md)). |
| S9 | Logs enthalten personenbezogene Daten (UPNs, E-Mail-Adressen). | Info | ✅ Dokumentiert (README, SECURITY.md); `Logs/` per `.gitignore` ausgeschlossen. |
| S10 | Organisationseinstellungen: „Speichern“ übertrug **alle** Felder (auch unveränderte und nicht geladene) an `Set-OrganizationConfig` – Gefahr, Tenant-Einstellungen ungewollt zu überschreiben. | Mittel | ✅ 0.3.0: nur geänderte Werte, Vorschau „alt → neu“ mit Bestätigung, ungültige Parameter werden verworfen. |
| S11 | Neue Funktionen öffnen externe Seiten (Hybrid Configuration Wizard) und speichern Berichte automatisch. | Info | ✅ 0.4.0: `Open-ExternalUrl` öffnet nur `https`-Adressen bekannter Microsoft-Hosts (Allowlist); automatisch gespeicherte Berichte (personenbezogene Daten) liegen in `Reports/` und sind per `.gitignore` ausgeschlossen; Exporte laufen weiterhin über `ConvertTo-SafeCsvObject`, Filter über `ConvertTo-OPathValue`. |
| S12 | **XAML-Injection** in Dialogen: Betreff (Detailansicht der Nachrichtenverfolgung) und Anzeigename (Ressourcen-Einstellungen) wurden in das Inline-XAML eingesetzt – präparierte Exchange-Daten konnten Elemente einschleusen oder das Laden des Dialogs verhindern. | Hoch | ✅ 0.5.0: Werte werden nach dem Laden über Eigenschaften gesetzt; kein Inline-XAML enthält mehr Variablen. |
| S13 | Transportregel-Import (XML) übergab beliebige Eigenschaften der Datei als Parameter an `New-TransportRule`. | Mittel | ✅ 0.5.0: nur erlaubte Eigenschaften und einfache Datentypen (string/bool/int/String-Listen). |
| S14 | Audit: Abgleich „interne Domäne“ per Teilzeichenkette – `contoso.com.evil.net` galt als intern (externe Weiterleitungen unentdeckt). | Mittel | ✅ 0.5.0: exakter Abgleich auf Domäne bzw. Subdomäne. |
| S15 | Transportregeln ohne gültige Bedingung (gelten für **alle** Nachrichten) möglich; wirksame Aktionen (Erzwingen, Löschen, Umleiten, Quarantäne, Ablehnen), Deaktivieren, „Senden im Auftrag“ entfernen, AutoMapping ändern und Regionaleinstellungen einzelner Postfächer ohne Rückfrage. | Mittel | ✅ 0.5.0: Validierung und Bestätigungen. |
| S16 | Externe Links (Admin-Center, Hilfe Defender/Organisationseinstellungen) per `Start-Process` an der URL-Allowlist vorbei geöffnet. | Niedrig | ✅ 0.5.0: `Open-ExternalUrl`. |
| S17 | PowerShell-7-MSI registrierte weiterhin das Explorer-Kontextmenü (S2 nur teilweise umgesetzt). | Niedrig | ✅ 0.5.0: nur `REGISTER_MANIFEST=1`. |
| S18 | Verbindungsstatus zusätzlich in globaler Variable `$Global:IsConnectedToExo` (außerhalb des Skripts änderbar). | Niedrig | ✅ 0.5.0: nur Script-Scope. |
| S19 | Export der Regionaleinstellungen als CSV ohne Schutz vor Formel-Injection. | Niedrig | ✅ 0.5.0: Textdatei (`Export-TextContent`). |

## 2. Befehle (Exchange-Cmdlets)

| # | Befund | Status |
|---|---|---|
| B1 | `Get-ExoUnifiedGroup-Identity` (5×) und `Get-ExoUnifiedGroup@params` – existieren nicht (Tippfehler) | ✅ `Get-UnifiedGroup -Identity` / `Get-UnifiedGroup @params` |
| B2 | `Convert- ToSharedMailboxAction` (Leerzeichen im Funktionsnamen) | ✅ |
| B3 | `Set-AllCalendarPermissions` – Funktion nicht vorhanden | ✅ `Set-DefaultCalendarPermissionForAll -AccessRights` |
| B4 | `Get-ExoContacts` – Funktion nicht vorhanden | ✅ `Search-ExoContacts` (in 0.5.0 als ungenutzt entfernt, siehe V38) |
| B5 | `Get-AzureADUser` / `Get-MsolUser` (abgekündigte Module) für Anzeige des angemeldeten Benutzers | ✅ `Get-User` |
| B6 | `Get-MessageTrace` / `Get-MessageTraceDetail` abgekündigt; `-Subject` existiert dort nicht | ✅ `Get-MessageTraceV2` / `Get-MessageTraceDetailV2` mit Fallback |
| B7 | `Get-HistoricalSearch` mit ungültigen Parametern in der Nachrichtenverfolgung | ✅ entfernt |
| B8 | `Search-MailboxAuditLog` abgekündigt | ✅ Fallback auf `Search-UnifiedAuditLog` |
| B9 | Diagnose-Vorlagen mit veralteten Cmdlets (`Get-MailboxSearch`, `Get-HybridConfiguration`, `Get-TenantAllowBlockListItems` ohne `-ListType`) | ✅ aktualisiert |
| B10 | DLP-/Label-Cmdlets ohne IPPS-Sitzung nicht verfügbar | ✅ Prüfung per `Get-Command` mit Hinweis auf `Connect-IPPSSession` |
| B11 | `Get-DistributionGroupMember` / `Get-UnifiedGroupLinks` ohne `-ResultSize Unlimited` (nur 1000 Einträge) | ✅ |
| B13 | Mobilgeräte zulassen/blockieren nutzte `Set-MobileDevice` – dieses Cmdlet existiert in Exchange Online nicht | ✅ `Set-CASMailbox -ActiveSyncAllowedDeviceIDs/-ActiveSyncBlockedDeviceIDs @{Add=…}` (`Set-MobileDeviceAccessState`) |
| B12 | Compliance-Funktionen (`Get-OwnRetentionCompliancePolicy`, `Get-OwnDlpCompliancePolicy`) benötigen `Connect-IPPSSession`, die GUI baut nur eine EXO-Verbindung auf | ✅ 0.3.0: Schaltfläche „Compliance verbinden“ (`Connect-OwnComplianceSession`, `-CommandName` begrenzt); HealthCheck/Troubleshooting weisen darauf hin |
| B14 | `Get-Mailbox` (Raum/Gerät) und `Get-MobileDevice` (Quarantäne) ohne `-ResultSize Unlimited` (nur 1000 Einträge) | ✅ 0.3.0 |
| B15 | Gruppenübersicht: `Get-DistributionGroup`/`Get-UnifiedGroup` ohne `-ResultSize Unlimited` | ✅ 0.3.0 |
| B16 | `Set-OrganizationConfig` wurde mit nicht existierenden Parametern (`InformationBarrierMode`, `OfficeFeatures`, `PowerShellMax*`) aufgerufen | ✅ 0.3.0: Parameter-Whitelist, nicht unterstützte Felder werden übersprungen und protokolliert |
| B17 | Abwesenheitsnotiz: Platzhalter `{StartDate}`/`{EndDate}` der Vorlage wurden nie ersetzt, Zeilenumbrüche gingen verloren (Anzeige als HTML), leere Datumsfelder führten zu einem Parameterfehler, die Notiz endete bereits um 00:00 Uhr des Endtags | ✅ 0.4.0: Platzhalter ersetzt, Umbrüche als `<br>`, Datumsprüfung (Start ≤ Ende, nicht in der Vergangenheit), Ende = Ende des gewählten Tags |
| B18 | Abwesenheitsstatus-Export ohne `-Delimiter ";"` (abweichend von allen anderen Exporten) | ✅ 0.4.0 |
| B19 | Compliance-Sitzung importierte nur Lese-Cmdlets für DLP/Aufbewahrung – `Set-DlpCompliancePolicy`, `Get-/New-ComplianceCase`, `Get-CaseHoldPolicy` fehlten | ✅ 0.4.0: `$script:ComplianceCommandNames` erweitert (weiterhin nur benötigte Cmdlets) |
| B20 | Microsoft Defender: Anti-Phishing-, Safe-Attachments- und Safe-Links-Dialoge nutzten nicht existierende Parameter (`Description`, `ImpersonationProtectionEnabled`, `SpoofProtectionEnabled`, `MailboxIntelligenceProtectionEnabled`, `EnableRedirect`, `Enabled` bei Safe Links) – Anlegen/Bearbeiten schlug fehl. | ✅ 0.5.0: dokumentierte Parameter (`AdminDisplayName`, `EnableTargetedUserProtection`, `EnableSpoofIntelligence`, `Enable`, `Redirect`, `DeliverMessageAfterScan` …); Aktionen Allow/Block/DynamicDelivery; fehlende Regeln werden angelegt. |
| B21 | `New-UnifiedGroup` mit ungültigen Parametern für Beschreibung und Besitzer | ✅ 0.5.0: `-Notes`, `-Owner` |
| B22 | Ressourcen: `New-Mailbox -Location` (Parameter existiert nicht), Standort in `ResourceCustom`, Kapazität immer `$null` | ✅ 0.5.0: `Set-Mailbox -Office`, Kapazität nur wenn angegeben |
| B23 | Transportregeln: Import mit `-State`/`-Description` (nicht vorhanden), Standardmodus „Test“ (ungültig) | ✅ 0.5.0: `-Enabled`/`-Comments`, Modus `Audit` |
| B24 | Posteingangsregeln: Identität aus Postfach und Regel doppelt mit `-Mailbox` kombiniert; Zielordner im falschen Format | ✅ 0.5.0: `-Mailbox` + Regel-ID, Ordner `user:\Inbox\…` |
| B25 | `New-MobileDeviceMailboxPolicy`: `AllowBluetooth` als Boolean (erwartet `Allow`/`Disable`/`HandsfreeOnly`), Parameter `Description` existiert nicht, Mindest-Kennwortlänge ohne `PasswordEnabled` | ✅ 0.5.0 |
| B26 | Kontakte: MailUser wurden mit `Set-MailContact` bearbeitet | ✅ 0.5.0: `Set-MailUser` |
| B27 | Health Check: SMTP AUTH aus falscher Quelle, `ModernAuthEnabled` (existiert nicht), `Get-RemoteDomain -Identity "*"` | ✅ 0.5.0: `Get-TransportConfig`, `OAuth2ClientProfileEnabled`, Remote-Domäne `Default` |
| B28 | Diagnosen: `PowerShellMax*` (existiert nicht), typografische Gedankenstriche als Parameterpräfix, fehlendes `-ResultSize Unlimited` | ✅ 0.5.0 |
| B29 | Berichte: ungültige Eigenschaft `AuditBypassEnabled` in `-Properties` | ✅ 0.5.0 |
| B30 | Quarantäne: nur die erste Ergebnisseite geladen, ungültige Typwerte | ✅ 0.5.0: Paging (max. 10 Seiten mit Hinweis), dokumentierte Typen |
| B31 | Cross-Premises: Smart Hosts ohne `UseMXRecord $false`, `TlsDomain` ohne `DomainValidation`, Inbound-Connector ohne `SenderDomains`, kein `-ErrorAction Stop` | ✅ 0.5.0 |
| B32 | „Senden im Auftrag“: Abgleich vorhandener Stellvertreter schlug fehl (Anzeigenamen vs. Adressen), ganze Liste neu geschrieben; Kalender: vorhandene Berechtigung mit `Add-MailboxFolderPermission` erneut angelegt (Fehler) | ✅ 0.5.0: `@{Add=…}`/`@{Remove=…}`, `Set-MailboxFolderPermission` |
| B33 | Regionaleinstellungen: `DefaultFolderNameMatchingUserLanguage` ohne `-VerifyDefaultFolderNameLanguage` gelesen | ✅ 0.5.0 |

## 3. Verweise / Funktionen

| # | Befund | Status |
|---|---|---|
| V1 | Postfach-Tab suchte `txtMailboxUser` (nicht im XAML) – Anzeige von Berechtigungen nicht möglich | ✅ `txtMailboxShowPermissions` + neue Buttons FullAccess/SendAs/SendOnBehalf |
| V2 | `btnExportInboxRules`, `btnRemoveSharedMailbox` im Code, aber nicht im XAML | ✅ Buttons ergänzt |
| V3 | Handler für `btnShowInGAL`, `btnExportSharedPermissions` fehlten | ✅ ergänzt |
| V4 | Freigegebene Postfächer: `btnHideFromGAL` setzte `HiddenFromAddressListsEnabled $false` (invertiert) | ✅ |
| V5 | Berechtigungsquelle `txtSharedMailboxPermSource` existiert nicht | ✅ Auswahl aus `cmbSharedMailboxSelect` |
| V6 | Verschachtelte doppelte Funktion `RefreshSharedMailboxList` | ✅ entfernt |
| V7 | Kalender: `Get-LocalizedString` nicht vorhanden; Erfolgsprüfung immer `false` | ✅ |
| V8 | Organisationseinstellungen: `ActivityBasedAuthenticationTimeoutInterval` aus falschem Steuerelement gelesen | ✅ |
| V9 | `Show-MessageBox` kannte `YesNo` nicht | ✅ |
| V10 | Versionsnummer `0.1.XX` als Platzhalter in Registry/Info-Dialog | ✅ `$script:AppVersion` (aktuell 0.2.0) |
| V11 | Organisationseinstellungen: Steuerelemente `cmbInformationBarrierMode`, `cmbOfficeFeatures`, `txtHierAddressBookRoot` werden gesucht, existieren aber nicht im XAML (werden stillschweigend übersprungen) | ✅ 0.3.0: Feld `txtHierarchicalAddressBookRoot` ergänzt; `InformationBarrierMode`/`OfficeFeatures` sind keine Parameter von `Set-OrganizationConfig` und wurden entfernt |
| V13 | Fehlgeschlagene/abgebrochene Anmeldung wurde als „verbunden“ gewertet (Dialog-Rückgabewerte im Pipeline-Output) | ✅ Status über `$script:isConnected`, Dialog-Rückgaben verworfen |
| V12 | `btnShowGroupMembers` wird gesucht, aber ohne Click-Handler | ✅ 0.3.0: Button im Layout, lädt die Mitglieder der ausgewählten Gruppe |
| V14 | Berichte: Auswahlliste `cmbReportType` wurde nie befüllt – kein Bericht ausführbar | ✅ 0.3.0 |
| V15 | Gruppen: Regex zum Trennen mehrerer Mitglieder fehlerhaft; nach dem Erstellen einer Gruppe Aufruf von `Get-SharedMailboxPermissionsAction` mit falschem Parameter | ✅ 0.3.0 |
| V16 | 26 Steuerelemente der Organisationseinstellungen im XAML ohne Anbindung im Code (Werte weder geladen noch gespeichert) | ✅ 0.3.0 |
| V17 | `Confirm-ExchangeConnection`: unerreichbarer Code nach `return`; Statusfarben über nicht definierte Brushes | ✅ 0.3.0 |
| V18 | Bereich **Hybrid Exchange**: 8 Steuerelemente (u. a. `btnRunHCW`, `btnGetHybridStatus`, `btnGetFederationTrust`, beide Ergebnislisten) ohne Code, Initialisierung auskommentiert | ✅ 0.4.0: `Features/Hybrid.ps1` |
| V19 | Bereich **Multi-Forest**: 13 Steuerelemente ohne Code; Synchronisations-Optionen ohne Entsprechung in Exchange Online | ✅ 0.4.0: `Features/MultiForest.ps1` (Domänen, Objektsuche mit Herkunft, Entra-Connect-Synchronisation über `ADSync`) |
| V20 | Bereich **eDiscovery & Legal Hold**: 9 Steuerelemente ohne Code | ✅ 0.4.0: `Features/Compliance.ps1` |
| V21 | Bereich **DLP** war nur ein Platzhalter („in Entwicklung“) | ✅ 0.4.0: DLP-Richtlinien/-Regeln, Aufbewahrungsrichtlinien, Vertraulichkeitsbezeichnungen, Moduswechsel, Export |
| V22 | Berichte: Kategorieliste, Benutzerfilter, „Automatisch als CSV speichern“, „Nach Export öffnen“ und „Nach Excel exportieren“ ohne Funktion | ✅ 0.4.0 |
| V23 | Export-Buttons für Postfachberechtigungen, Audit- und Diagnoseergebnis ohne Handler | ✅ 0.4.0 (Audit/Diagnose als Textdatei, da Freitext) |
| V24 | Hilfe: `Show-HelpDialog` wurde mit nicht vorhandenen Themen aufgerufen (Berichte, Freigegebene Postfächer, Troubleshooting, Regionaleinstellungen) – Anzeige „Unbekanntes Thema“; Hilfe-Link im Bereich Kontakte ohne Handler | ✅ 0.4.0: Themen ergänzt, zentrale Funktion `Register-HelpLink` |
| V25 | Liste der Tab-Initialisierungen doppelt gepflegt (`Initialize-RemainingTabs`, `Start-AsyncTabInitialization`) | ✅ 0.4.0: eine Liste `$script:TabInitializers`, Ausführung über `Invoke-TabInitializers` (Fehler eines Bereichs halten die übrigen nicht auf) |
| V26 | Fehlendes `@(…)` um Cmdlet-/Funktionsergebnisse in 12 Listen (Domänen, Gruppen, Ressourcen, Ressourcenberechtigungen, MailUser, Berechtigungen/Weiterleitungen freigegebener Postfächer, Posteingangsregeln, mobile Geräte, akzeptierte Domänen) – Absturz oder leere Liste bei genau einem Treffer | ✅ 0.5.0 |
| V27 | Erfolgsmeldung trotz Fehler: Gruppenmitglied entfernen, Kalender (Anzeigen, „Standardberechtigung für alle“), Diagnosen, Transportregel-Import, Connectors laden/ändern, Audit | ✅ 0.5.0: Meldung nach tatsächlichem Ergebnis, Fehlerzähler |
| V28 | Launcher: `$script:tabEXOSettings = $null` überschrieb den Verweis auf den Bereich; tote Verweise `tabOrgSettings`, `btnNavOrgSettings`, `btnCheckPrerequisites`; `$_` im Loaded-Handler | ✅ 0.5.0 |
| V29 | Einstellungen: Log-Verzeichnis aus falschem Schlüssel gelesen und vom Logging ignoriert; Debug-Einträge immer geschrieben; Debug-Wert mit falschem Typ gespeichert; Änderungen erst nach Neustart | ✅ 0.5.0: `Initialize-Logging`, sofort wirksam |
| V30 | Health Check: Warnungen und Details der Tenant-Prüfung wurden nie ausgegeben (`.ForEach` mit `+=`, wörtliches `"\n"`); Auswertung über globales `$Error` | ✅ 0.5.0 |
| V31 | Audit: Zeichenketten mit ```` ``` ```` verschluckten Code (Option „Vollständige Audit-Details“ unerreichbar); `${$rule.Name}`; `AuditLogAgeLimit` als Text verglichen; Ordner nach Text statt Größe sortiert | ✅ 0.5.0 |
| V32 | Ressourcen: Liste nach Erstellen/Bearbeiten/Löschen nicht aktualisiert (lokale Button-Variable); ungültige Zahlen still verworfen; Platzhalter-Handler mit `$sender` | ✅ 0.5.0 |
| V33 | Gruppen: „Aus GAL ausblenden“ (M365) aus nicht existierender Eigenschaft gelesen – Speichern blendete Gruppen ein; widersprüchliche Checkboxen zur Absender-Authentifizierung | ✅ 0.5.0 |
| V34 | Postfach: „Senden als“ bei Vollzugriff verworfen, Spalte „Berechtigungstyp“ leer; Freigegebene Postfächer: „Kopie behalten“ ignoriert, falscher `Write-Log -Level` | ✅ 0.5.0 |
| V35 | Nachrichtenverfolgung: End-Tag ausgeschlossen, „Lokale Zeit“ nicht umgerechnet, Zuweisung an automatische Variable `$event` | ✅ 0.5.0 |
| V36 | Organisationseinstellungen: „Speichern“/„Exportieren“ erst nach dem ersten Laden; Regionaleinstellungen: Absturz der Fortschrittsanzeige (`Dispatcher.Invoke`), Warnungen als Fehler gezählt | ✅ 0.5.0 |
| V37 | Mobile Geräte: Zulassen/Blockieren ließ die Geräte-ID in der Gegenliste; Dashboard: „Zurücksetzen“ ohne Wirkung; Abwesenheitsnotizen: Massen-Deaktivierung lud die Liste je Benutzer | ✅ 0.5.0 |
| V38 | Toter Code: über 30 nie aufgerufene Funktionen (u. a. zehn Altfunktionen in `Groups.ps1`, Kalender-/Kontakt-Altfunktionen, `Test-ModuleInstalled`, `Write-StatusMessage`), ungenutzte Variablen, wirkungslose Checkbox „Authentifizierung“ im Connector-Dialog | ✅ 0.5.0: entfernt (keine Verweise mehr) |
| V39 | Defender-Regeln: Einträge in „Gesendet an“ ohne `@` werden beim Bearbeiten als Domänen behandelt | ✅ vorhandene `SentTo`-Einträge und Einträge ohne Punkt (Alias/Name) bleiben Empfänger (`ConvertTo-SecurityRuleScope -KnownRecipients`) |

## 4. GUI

| # | Befund | Status |
|---|---|---|
| G1 | Navigations-Buttons hatten **zwei** Click-Handler (Einzelregistrierung + `Initialize-TabNavigation`) | ✅ zentrale Registrierung |
| G2 | `btnClose` hatte zwei Handler (einer ohne Trennen der Verbindung) | ✅ |
| G3 | Hilfe-Links: Closure-Variable lieferte immer das letzte Thema, Handler ohne Funktion | ✅ Thema im `Tag`, Handler in den Tabs |
| G4 | Umlaute wurden in Statusleiste und Log durch `?` ersetzt | ✅ nur Steuerzeichen werden entfernt |
| G5 | Tab-Wechsel-Log leer (Header ausgeblendet) und durch untergeordnete Selektoren ausgelöst | ✅ Tab-Name, nur TabControl-Ereignisse |
| G6 | Verbinden-Button konnte nicht trennen; Umgebungsprüfung bei jeder Verbindung blockierend | ✅ |
| G7 | Banner-Erkennung des EXO-Moduls fehlerhaft | ✅ |
| G8 | Version nicht sichtbar; `txtVersion` im Code referenziert, aber nicht im XAML | ✅ Fenstertitel, Kopfzeile, Info-Dialog |
| G9 | Alle Exchange-Abfragen laufen im UI-Thread – das Fenster reagiert bei großen Tenants während Abfragen nicht | ✅ 0.3.0: Arbeits-Overlay mit Fortschritt und „Abbrechen“; die Oberfläche wird während Abfragen weiter verarbeitet (Dispatcher). Echte Hintergrund-Runspaces sind nicht möglich, da die EXO-Sitzung an den GUI-Runspace gebunden ist. |
| G10 | Feste Fenstergröße 1700×1000 – auf kleinen Bildschirmen abgeschnitten | ✅ Größe wird beim Start auf den Arbeitsbereich des Bildschirms begrenzt |
| G11 | 141 von 161 Buttons mit lokal gesetzten Farben – Hover-/Pressed-Effekte der Styles wirkungslos, uneinheitliche Farben | ✅ Button-Varianten im Theme (`SecondaryButton`, `SuccessButton`, `DangerButton`, `WarningButton`) |
| G12 | Editierbare ComboBoxen ließen keine Texteingabe zu (Vorlage ohne `IsEditable`-Zweig) | ✅ |
| G13 | Navigation markierte den aktiven Bereich über fest gesetzte Farben im Code | ✅ `Tag="Active"` + Style-Trigger |
| G14 | `CornerRadius`-Attribute wurden beim Laden per Regex aus dem XAML entfernt | ✅ entfernt (nur an `Border` verwendet) |
| G15 | Veraltetes, uneinheitliches Design | ✅ neues Theme `src/GUI/Theme.xaml` (Fluent-Stil) |
| G16 | `Items.Clear()` auf Listen mit gebundener `ItemsSource` löste eine Ausnahme aus | ✅ 0.3.0: `ItemsSource = $null` |
| G17 | Mehrfachklicks starteten Abfragen parallel; Fenster ließ sich während einer Abfrage schließen | ✅ 0.3.0: Click-Verteiler sperrt während laufender Vorgänge; Schließen bricht den Vorgang ab |
| G18 | Unbehandelte Ausnahmen in Click-Handlern konnten die Anwendung beenden | ✅ 0.3.0: zentrale Fehlerbehandlung mit Log und Statusleiste |
| G19 | Abwesenheitsstatus aller Postfächer ohne Arbeitsanzeige (Fenster blockiert, kein Abbrechen) | ✅ 0.4.0: Fortschritt und „Abbrechen“ |
| G20 | „Masseneinrichtung“ der Abwesenheitsnotizen meldete „noch nicht implementiert“ | ✅ 0.4.0: für markierte Benutzer der Statusliste oder mehrere Adressen, mit Bestätigung und Fortschritt |
| G21 | Fest kodierte Farben in `MainWindow.xaml` (Kopfzeile, Navigation, Statusleiste, Hinweise, Dashboard-Kacheln), in Inline-Dialogen und im Code | ✅ 0.5.0: alle Farben in `Theme.xaml`; Dialoge über `Add-ThemeResource`, Statusfarben über `Get-StatusBrush` |
| G22 | 22 Schaltflächen ohne Theme-Style | ✅ 0.5.0 |
| G23 | Spaltenbindungen auf nicht existierende Eigenschaften (Safe Attachments „Aktiviert“, Safe Links, Geräte in Quarantäne, Connectors) – leere Spalten | ✅ 0.5.0 |
| G24 | Bereich Transportregeln englisch beschriftet, Auswahllisten mit ungültigen statischen Werten | ✅ 0.5.0: deutsch, Listen nur aus dem Code |
| G25 | Statusleiste dunkel, Statusfarben (Schwarz/Rot/Grün) schlecht lesbar | ✅ 0.5.0: `Status*Brush` im Theme |
| G26 | Defender-Richtlinien ließen sich nicht löschen | ✅ 0.5.0: „Ausgewählte löschen“ mit Bestätigung |
| G27 | Anmeldedialog als eigenes XAML ohne Theme; Abbrechen nicht sauber behandelt | ✅ 0.5.0: `Show-InputDialog` |
| G28 | Fenster blockiert ohne Fortschritt/Abbrechen bei Health Check, Audit, Diagnosen, Quarantäne, Regionaleinstellungen, Kalender „für alle“, Nachrichtenverfolgung, Transportregel-Import | ✅ 0.5.0: Arbeitsanzeige mit „Abbrechen“ |
| G29 | Berichte: Datumsfelder auch bei Berichten ohne Zeitraum aktiv | ✅ 0.5.0 |

## 5. Performance

| # | Befund | Status |
|---|---|---|
| P1 | `Get-DistributionGroupMember` lud nur 1000 Mitglieder (Funktion, nicht Performance) | ✅ |
| P2 | Dashboard lädt mehrere Empfängertypen jeweils mit `-ResultSize Unlimited` (bei großen Tenants langsam) | ✅ ein `Get-EXORecipient -PropertySets Minimum`-Aufruf mit Gruppierung |
| P3 | Berichte iterieren pro Objekt mit Einzelabfragen (N+1, z. B. Postfachstatistiken) | ✅ 0.3.0: `Get-EXOMailbox \| Get-EXOMailboxStatistics` per Pipeline (REST, gebündelt); Berechtigungsberichte bleiben je Postfach (von Exchange Online vorgegeben), sind aber abbrechbar |
| P4 | Mehrfache `Add-Type`-Aufrufe für WPF-Assemblies | ✅ einmalig im Launcher |
| P5 | Verbindungsprüfung führte vor jeder Aktion einen Server-Aufruf (`Get-OrganizationConfig`) aus | ✅ 0.3.0: lokale Prüfung über `Get-ConnectionInformation`, Ergebnis 120 s zwischengespeichert |
| P6 | Gruppenmitglieder: Array-Verkettung (`+=`) und `Where-Object` je Mitglied für den Besitzer-Abgleich | ✅ 0.3.0: `List`/`HashSet` |
| P7 | Neue Berichte ohne Einzelabfragen je Objekt, wo Exchange Online es zulässt | ✅ 0.4.0: „Senden als“ über **einen** mandantenweiten Aufruf `Get-EXORecipientPermission`; Weiterleitungsberichte mit serverseitigem OPATH-Filter; Postfachlisten mit gezielten `-Properties` |
| P8 | Weiterleitungen freigegebener Postfächer: alle Postfächer geladen und clientseitig gefiltert | ✅ 0.5.0: serverseitiger Filter |
| P9 | Transportregel-Import fragte vorhandene Regeln je Eintrag ab | ✅ 0.5.0: einmalige Abfrage |
| P10 | Audit: `Get-MailboxStatistics` immer ausgeführt | ✅ 0.5.0: nur bei Bedarf |
| P11 | Abwesenheitsnotizen: Liste nach jedem einzelnen Deaktivieren neu geladen | ✅ 0.5.0: einmal am Ende |
| P12 | Health Check: Ping an 8.8.8.8 (Zeitüberschreitung in Netzen ohne ICMP, brach den Test ab) | ✅ 0.5.0: entfernt; EXO-Test läuft immer |

## 6. Code-Qualität (PSScriptAnalyzer)

| Regel | Vorher | Nachher | Status |
|---|---:|---:|---|
| `PSPossibleIncorrectUsageOfRedirectionOperator` (`Count > 0`) | 3 | 0 | ✅ |
| `PSAvoidDefaultValueSwitchParameter` | 1 | 0 | ✅ |
| `PSUseShouldProcessForStateChangingFunctions`, `PSUseApprovedVerbs`, `PSUseSingularNouns` | 80 | 86 | ⚠️ Stil – Umbenennung würde alle Aufrufe betreffen; Anstieg durch neue UI-Hilfsfunktionen (`Start-/Update-/Stop-UIBusy`, Berichts-, Hybrid-, Multi-Forest- und Compliance-Helfer), die nur GUI-Zustand ändern. Funktionen, die Exchange/Entra Connect ändern, unterstützen `-WhatIf` (`SupportsShouldProcess`). |
| `PSAvoidUsingComputerNameHardcoded` | 3 | 0 | ✅ 0.5.0: Ping an 8.8.8.8 entfernt, Endpunkt als Variable |
| Weitere Warnungen (ungenutzte Parameter/Variablen, leere `catch`-Blöcke, `$null`-Vergleiche, automatische/globale Variablen, fehlender `process`-Block) | 93 | 17 | ✅ 0.5.0 (Rest: Parameter in Closures genutzt, bewusst leere `catch`-Blöcke im Fallback-Logging) |

## 7. Architektur / Modularisierung

| # | Befund | Status |
|---|---|---|
| A1 | Monolithisches Skript mit ~28.400 Zeilen (210 Funktionen, XAML eingebettet) – schwer wartbar und reviewbar | ✅ Launcher + Moduldateien (`src/Modules/Core`, `UI`, `Exchange`, `Features`; seit 0.4.0 33 Module) |
| A2 | XAML (~7.000 Zeilen) als Here-String im Skript | ✅ `src/GUI/MainWindow.xaml` + `src/GUI/Theme.xaml` |
| A3 | Pfade über `$PSScriptRoot`/`$PSCommandPath` (bei Dot-Sourcing aus Unterordnern falsch) | ✅ zentrale `$script:AppRoot`/`$script:AppScriptPath` |
| A4 | Unausgeglichene `#region`-Marker | ✅ bereinigt |

Die Module werden per Dot-Sourcing in den Script-Scope des Launchers geladen. Dadurch bleiben gemeinsam genutzte
`$script:`-Variablen und WPF-Event-Handler unverändert funktionsfähig. Echte PowerShell-Module (`.psm1`) hätten einen
eigenen Scope und hätten den gemeinsamen Zustand der GUI aufgebrochen.

## 8. Repository / Dokumentation

| # | Befund | Status |
|---|---|---|
| R1 | Alte Versionen (`# Versions/`, V0.0.1–V0.0.13) im Repository | ✅ gelöscht (in Git-Historie erhalten) |
| R2 | Screenshots veraltet (V0.0.13) und in Ordner mit Sonderzeichen | ✅ gelöscht; neuer Ort `docs/screenshots/` |
| R3 | Versionsnummer im Dateinamen des Hauptskripts | ✅ `src/easyEXO.ps1` |
| R4 | Kein CHANGELOG | ✅ aus Git-Historie rekonstruiert |
| R5 | Keine SECURITY.md / CONTRIBUTING.md / CODE_OF_CONDUCT.md / PR-Vorlage | ✅ angelegt |
| R6 | README verwies auf gelöschte Dateien und verlangte Adminrechte | ✅ aktualisiert |
| R7 | Keine Issue-Vorlagen | ✅ 0.5.0: Fehlerbericht, Funktionswunsch, Verweis auf vertrauliche Sicherheitsmeldung |
| R8 | Screenshot-Konvention mit Versionsnummer im Dateinamen | ✅ 0.5.0: `<Nr>_<bereich>.png` ohne Version, Ersetzen statt Ergänzen |
| R9 | Doku veraltet (Konfiguration/Registry-Werte, unterstützte Version, „HTML-Exporte“), CHANGELOG ohne Verweis auf PR #2 | ✅ 0.5.0 |

## Empfehlungen für Folgeversionen

Die Empfehlungen aus 0.2.0 (Compliance-Verbindung, bedienbare Oberfläche bei langen Abfragen, Berichte ohne N+1,
Organisationseinstellungen) sind in 0.3.0 umgesetzt; die nicht angebundenen Bereiche und Steuerelemente in 0.4.0; die
Nachprüfung aller Module (Parameter, Erfolgsmeldungen, Einzelergebnisse, Design) in 0.5.0. Weiterhin gilt:

1. Launcher und alle Moduldateien nach jedem Release neu signieren.
2. Weitere direkt per `Add_Click` registrierte Handler (v. a. in modalen Dialogen) schrittweise auf
   `Register-EventHandler` umstellen.
3. Funktionstest der Oberfläche unter Windows mit einem Test-Tenant vor jedem Release (WPF und Exchange Online sind in
   der CI nicht testbar) – insbesondere die in 0.5.0 korrigierten Defender-, Mobilgeräte- und Connector-Dialoge.
4. Neue Cmdlet-Parameter und Spaltenbindungen immer gegen die aktuelle Dokumentation auf learn.microsoft.com prüfen.
