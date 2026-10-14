# Audit-Bericht easyEXO

| | |
|---|---|
| **Version geprüft** | 0.1.1 (`easyEXO_V0.1.1.ps1`, ~28.500 Zeilen) |
| **Version nach Behebung** | 0.2.0 (`src/easyEXO.ps1` + `src/Modules/**`, `src/GUI/*.xaml`) |
| **Datum** | 2026-10-14 |
| **Umfang** | Sicherheit, Befehle (Exchange-Cmdlets), Verweise (Funktionen/XAML-Elemente), GUI, Performance, Funktionen, Repository-Struktur und Dokumentation |
| **Methodik** | Manuelle Code-Review, PowerShell-Parser (`Parser::ParseFile`), PSScriptAnalyzer 1.25 (Error/Warning), Abgleich aller `FindName`/`Get-XamlElement`-Aufrufe mit dem XAML, Abgleich der verwendeten Cmdlets mit der aktuellen ExchangeOnlineManagement-Dokumentation |

Legende: ✅ behoben · ⚠️ offen / bekannte Einschränkung

## Zusammenfassung

| Kategorie | Befunde | Behoben | Offen |
|---|---:|---:|---:|
| Sicherheit | 9 | 9 | 0 |
| Befehle | 13 | 12 | 1 |
| Verweise / Funktionen | 13 | 11 | 2 |
| GUI | 15 | 14 | 1 |
| Performance | 4 | 3 | 1 |
| Code-Qualität (PSScriptAnalyzer) | 4 | 2 | 2 |
| Architektur / Modularisierung | 4 | 4 | 0 |
| Repository / Dokumentation | 6 | 6 | 0 |

Ergebnis nach Behebung: **0 Parser-Fehler** in allen 30 Skriptdateien; PSScriptAnalyzer meldet nur noch 3 Fehler der Regel
`PSAvoidUsingComputerNameHardcoded` (beabsichtigte Konnektivitätstests gegen `outlook.office365.com`, False Positive).
Alle Funktionsaufrufe lassen sich modulübergreifend auflösen; alle `StaticResource`-Verweise sind im Theme definiert.

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
| B12 | Compliance-Funktionen (`Get-OwnRetentionCompliancePolicy`, `Get-OwnDlpCompliancePolicy`) benötigen `Connect-IPPSSession`, die GUI baut nur eine EXO-Verbindung auf | ⚠️ offen – Fehlermeldung erscheint; IPPS-Verbindung wäre ein neues Feature |

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
| V11 | Organisationseinstellungen: Steuerelemente `cmbInformationBarrierMode`, `cmbOfficeFeatures`, `txtHierAddressBookRoot` werden gesucht, existieren aber nicht im XAML (werden stillschweigend übersprungen) | ⚠️ offen – kein Fehler, aber Einstellungen nicht bearbeitbar |
| V13 | Fehlgeschlagene/abgebrochene Anmeldung wurde als „verbunden“ gewertet (Dialog-Rückgabewerte im Pipeline-Output) | ✅ Status über `$script:isConnected`, Dialog-Rückgaben verworfen |
| V12 | `btnShowGroupMembers` wird gesucht, aber ohne Click-Handler | ⚠️ offen – Mitglieder werden über die Gruppenauswahl geladen |

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
| G9 | Alle Exchange-Abfragen laufen im UI-Thread – das Fenster reagiert bei großen Tenants während Abfragen nicht | ⚠️ bekannte Einschränkung (Umstellung auf Runspaces wäre ein größeres Refactoring) |
| G10 | Feste Fenstergröße 1700×1000 – auf kleinen Bildschirmen abgeschnitten | ✅ Größe wird beim Start auf den Arbeitsbereich des Bildschirms begrenzt |
| G11 | 141 von 161 Buttons mit lokal gesetzten Farben – Hover-/Pressed-Effekte der Styles wirkungslos, uneinheitliche Farben | ✅ Button-Varianten im Theme (`SecondaryButton`, `SuccessButton`, `DangerButton`, `WarningButton`) |
| G12 | Editierbare ComboBoxen ließen keine Texteingabe zu (Vorlage ohne `IsEditable`-Zweig) | ✅ |
| G13 | Navigation markierte den aktiven Bereich über fest gesetzte Farben im Code | ✅ `Tag="Active"` + Style-Trigger |
| G14 | `CornerRadius`-Attribute wurden beim Laden per Regex aus dem XAML entfernt | ✅ entfernt (nur an `Border` verwendet) |
| G15 | Veraltetes, uneinheitliches Design | ✅ neues Theme `src/GUI/Theme.xaml` (Fluent-Stil) |

## 5. Performance

| # | Befund | Status |
|---|---|---|
| P1 | `Get-DistributionGroupMember` lud nur 1000 Mitglieder (Funktion, nicht Performance) | ✅ |
| P2 | Dashboard lädt mehrere Empfängertypen jeweils mit `-ResultSize Unlimited` (bei großen Tenants langsam) | ✅ ein `Get-EXORecipient -PropertySets Minimum`-Aufruf mit Gruppierung |
| P3 | Berichte iterieren pro Objekt mit Einzelabfragen (N+1, z. B. Postfachstatistiken) | ⚠️ offen |
| P4 | Mehrfache `Add-Type`-Aufrufe für WPF-Assemblies | ✅ einmalig im Launcher |

## 6. Code-Qualität (PSScriptAnalyzer)

| Regel | Vorher | Nachher | Status |
|---|---:|---:|---|
| `PSPossibleIncorrectUsageOfRedirectionOperator` (`Count > 0`) | 3 | 0 | ✅ |
| `PSAvoidDefaultValueSwitchParameter` | 1 | 0 | ✅ |
| `PSUseShouldProcessForStateChangingFunctions`, `PSUseApprovedVerbs`, `PSUseSingularNouns` | 80 | 81 | ⚠️ Stil – Umbenennung würde alle Aufrufe betreffen |
| `PSAvoidUsingComputerNameHardcoded` | 3 | 3 | ⚠️ False Positive (Konnektivitätstest gegen Microsoft-Endpunkte) |

## 7. Architektur / Modularisierung

| # | Befund | Status |
|---|---|---|
| A1 | Monolithisches Skript mit ~28.400 Zeilen (210 Funktionen, XAML eingebettet) – schwer wartbar und reviewbar | ✅ Launcher + 29 Moduldateien (`src/Modules/Core`, `UI`, `Exchange`, `Features`) |
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

1. Optionale Verbindung zu Security & Compliance (`Connect-IPPSSession`) für DLP-/Aufbewahrungsfunktionen.
2. Langlaufende Abfragen in Runspaces auslagern (GUI bleibt bedienbar).
3. Berichte ohne N+1-Abfragen (Batch-Abfragen, `-PropertySets`).
4. Fehlende Steuerelemente der Organisationseinstellungen ergänzen oder den Code entfernen.
5. Launcher und alle Moduldateien nach jedem Release neu signieren.
