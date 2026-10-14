# Audit-Bericht easyEXO

| | |
|---|---|
| **Version geprüft** | 0.1.1 (`easyEXO_V0.1.1.ps1`, ~28.500 Zeilen) |
| **Version nach Behebung** | 0.2.0, offene Punkte und Nachprüfung in 0.3.0, Funktionslücken (nicht angebundene Bereiche und Steuerelemente) in 0.4.0 (`src/easyEXO.ps1` + `src/Modules/**`, `src/GUI/*.xaml`) |
| **Datum** | 2026-10-14 |
| **Umfang** | Sicherheit, Befehle (Exchange-Cmdlets), Verweise (Funktionen/XAML-Elemente), GUI, Performance, Funktionen, Repository-Struktur und Dokumentation |
| **Methodik** | Manuelle Code-Review, PowerShell-Parser (`Parser::ParseFile`), PSScriptAnalyzer 1.25 (Error/Warning), Abgleich aller `FindName`/`Get-XamlElement`-Aufrufe mit dem XAML, Abgleich aller benannten XAML-Elemente mit dem Code (Steuerelemente ohne Funktion), Abgleich der Hilfethemen, Abgleich der verwendeten Cmdlets mit der aktuellen ExchangeOnlineManagement-Dokumentation |

Legende: ✅ behoben · ⚠️ offen / bekannte Einschränkung

## Zusammenfassung

| Kategorie | Befunde | Behoben | Offen |
|---|---:|---:|---:|
| Sicherheit | 11 | 11 | 0 |
| Befehle | 19 | 19 | 0 |
| Verweise / Funktionen | 25 | 25 | 0 |
| GUI | 20 | 20 | 0 |
| Performance | 7 | 7 | 0 |
| Code-Qualität (PSScriptAnalyzer) | 4 | 2 | 2 |
| Architektur / Modularisierung | 4 | 4 | 0 |
| Repository / Dokumentation | 6 | 6 | 0 |

Ergebnis nach Behebung: **0 Parser-Fehler** in allen 34 Skriptdateien; PSScriptAnalyzer meldet nur noch 3 Fehler der Regel
`PSAvoidUsingComputerNameHardcoded` (beabsichtigte Konnektivitätstests gegen `outlook.office365.com`, False Positive).
Alle Funktionsaufrufe lassen sich modulübergreifend auflösen; alle `StaticResource`-Verweise sind im Theme definiert.
Seit 0.4.0 ist jedes benannte Steuerelement des Hauptfensters im Code angebunden (Ausnahme: reine Layout-Container
`headerStatus`, `headerStatusContainer`, `gridOrgButtons`).

---

## 1. Sicherheit

| # | Befund | Schwere | Status |
|---|---|---|---|
| S1 | **Code-Injection** in der Exchange-Diagnose: Benutzereingaben wurden per `-replace` in Befehlsvorlagen eingesetzt und mit `[ScriptBlock]::Create()` ausgeführt. Eine Eingabe wie `x'; Remove-Mailbox …` hätte beliebige Befehle ausgeführt. | Hoch | ✅ Eingaben werden mit `CodeGeneration::EscapeSingleQuotedStringContent` maskiert und literal ersetzt. |
| S2 | **PowerShell-7-Installer**: MSI-Download ohne Signaturprüfung in vorhersagbaren Temp-Pfad, Installation mit `ENABLE_PSREMOTING=1` und Kontextmenü; winget ohne exakte ID/Quelle. | Hoch | ✅ TLS 1.2, eindeutiges Temp-Verzeichnis, Authenticode-Prüfung (Valid + Microsoft Corporation), keine Zusatzfeatures, `winget --id Microsoft.PowerShell --exact --source winget`. |
| S3 | Skript erzwang **Administratorrechte** (Neustart mit `RunAs`), obwohl für Exchange Online nicht erforderlich. | Mittel | ✅ Keine Adminrechte mehr nötig; Neustart mit `-NoProfile -STA -File`. |
| S4 | **CSV-/Formel-Injection** bei allen Exporten (Werte wie `=HYPERLINK(...)` aus Exchange-Attributen). | Mittel | ✅ `ConvertTo-SafeCsvObject` in allen `Export-Csv`-Pfaden. |
| S5 | **OPATH-Filter-Injection** in der Kontaktsuche (`-Filter "... -like '*$input*'"`). | Mittel | ✅ `ConvertTo-OPathValue` (verdoppelt einfache Anführungszeichen). |
| S6 | **Log-Injection**: Zeilenumbrüche in Benutzereingaben erzeugten gefälschte Log-Zeilen. | Niedrig | ✅ Steuerzeichen werden entfernt. |
| S7 | **Fehlende Bestätigungen** vor destruktiven Aktionen (FullAccess/SendAs/Weiterleitung/Kalenderberechtigung entfernen); 7 Bestätigungsdialoge waren durch `Show-MessageBox -Type YesNo` funktionslos (Aktion lief ohne Rückfrage). | Mittel | ✅ Bestätigungen ergänzt; `Show-MessageBox` gibt bei Fehlern `No` zurück (fail-safe). |
| S8 | Authenticode-Signatur nach Änderungen ungültig. | Info | ✅ Signaturblock entfernt; Neusignierung durch Maintainer dokumentiert ([SECURITY.md](../SECURITY.md)). |
| S9 | Logs enthalten personenbezogene Daten (UPNs, E-Mail-Adressen). | Info | ✅ Dokumentiert (README, SECURITY.md); `Logs/` per `.gitignore` ausgeschlossen. |
| S10 | Organisationseinstellungen: „Speichern“ übertrug **alle** Felder (auch unveränderte und nicht geladene) an `Set-OrganizationConfig` – Gefahr, Tenant-Einstellungen ungewollt zu überschreiben. | Mittel | ✅ 0.3.0: nur geänderte Werte, Vorschau „alt → neu“ mit Bestätigung, ungültige Parameter werden verworfen. |
| S11 | Neue Funktionen öffnen externe Seiten (Hybrid Configuration Wizard) und speichern Berichte automatisch. | Info | ✅ 0.4.0: `Open-ExternalUrl` öffnet nur `https`-Adressen bekannter Microsoft-Hosts (Allowlist); automatisch gespeicherte Berichte (personenbezogene Daten) liegen in `Reports/` und sind per `.gitignore` ausgeschlossen; Exporte laufen weiterhin über `ConvertTo-SafeCsvObject`, Filter über `ConvertTo-OPathValue`. |

## 2. Befehle (Exchange-Cmdlets)

| # | Befund | Status |
|---|---|---|
| B1 | `Get-ExoUnifiedGroup-Identity` (5×) und `Get-ExoUnifiedGroup@params` – existieren nicht (Tippfehler) | ✅ `Get-UnifiedGroup -Identity` / `Get-UnifiedGroup @params` |
| B2 | `Convert- ToSharedMailboxAction` (Leerzeichen im Funktionsnamen) | ✅ |
| B3 | `Set-AllCalendarPermissions` – Funktion nicht vorhanden | ✅ `Set-DefaultCalendarPermissionForAll -AccessRights` |
| B4 | `Get-ExoContacts` – Funktion nicht vorhanden | ✅ `Search-ExoContacts` |
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

## 6. Code-Qualität (PSScriptAnalyzer)

| Regel | Vorher | Nachher | Status |
|---|---:|---:|---|
| `PSPossibleIncorrectUsageOfRedirectionOperator` (`Count > 0`) | 3 | 0 | ✅ |
| `PSAvoidDefaultValueSwitchParameter` | 1 | 0 | ✅ |
| `PSUseShouldProcessForStateChangingFunctions`, `PSUseApprovedVerbs`, `PSUseSingularNouns` | 80 | 104 | ⚠️ Stil – Umbenennung würde alle Aufrufe betreffen; Anstieg durch neue UI-Hilfsfunktionen (`Start-/Update-/Stop-UIBusy`, Berichts-, Hybrid-, Multi-Forest- und Compliance-Helfer), die nur GUI-Zustand ändern. Funktionen, die Exchange/Entra Connect ändern, unterstützen `-WhatIf` (`SupportsShouldProcess`). |
| `PSAvoidUsingComputerNameHardcoded` | 3 | 3 | ⚠️ False Positive (Konnektivitätstest gegen Microsoft-Endpunkte) |

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

## Empfehlungen für Folgeversionen

Die Empfehlungen aus 0.2.0 (Compliance-Verbindung, bedienbare Oberfläche bei langen Abfragen, Berichte ohne N+1,
Organisationseinstellungen) sind in 0.3.0 umgesetzt; die nicht angebundenen Bereiche und Steuerelemente in 0.4.0.
Weiterhin gilt:

1. Launcher und alle Moduldateien nach jedem Release neu signieren.
2. Weitere direkt per `Add_Click` registrierte Handler schrittweise auf `Register-EventHandler` umstellen.
3. Funktionstest der Oberfläche unter Windows mit einem Test-Tenant vor jedem Release (WPF ist in der CI nicht testbar).
