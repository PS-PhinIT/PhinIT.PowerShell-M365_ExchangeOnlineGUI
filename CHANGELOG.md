# Changelog

Alle wesentlichen Änderungen an **easyEXO** werden in dieser Datei dokumentiert.

Das Format orientiert sich an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
die Versionierung folgt [Semantic Versioning](https://semver.org/lang/de/).
Jede Änderung wird direkt unter einer **konkreten Versionsnummer mit Datum** eingetragen.

Die Einträge bis einschließlich 0.1.1 wurden nachträglich aus der Git-Historie
(Commits und Pull Requests) rekonstruiert.

## [0.3.0] - 2026-10-14

Folge-Release zum Audit: Die in 0.2.0 offenen Punkte (blockierende Oberfläche, fehlende Compliance-Verbindung,
langsame Berichte, fehlende Felder der Organisationseinstellungen, funktionsloser Button „Gruppenmitglieder anzeigen“)
wurden behoben; dazu weitere Fehler aus einer erneuten Prüfung. Details: [docs/AUDIT.md](docs/AUDIT.md).

### Hinzugefügt
- **Arbeitsanzeige mit Abbrechen** (`src/Modules/UI/Busy.ps1`): Lange Abfragen zeigen ein Overlay mit Meldung,
  Fortschritt und Schaltfläche „Abbrechen“. Das Fenster wird währenddessen weiter gezeichnet und bleibt reaktionsfähig
  (`Start-UIBusy`, `Update-UIBusy`, `Stop-UIBusy`, `Step-UIProgress`).
- **Zentraler Click-Verteiler:** Alle über `Register-EventHandler` registrierten Buttons ignorieren Klicks, solange ein
  Vorgang läuft (keine Doppelausführung), zeigen den Warte-Cursor und fangen unbehandelte Fehler ab.
- **Schutz beim Schließen:** Wird das Fenster während eines Vorgangs geschlossen, wird stattdessen der Vorgang abgebrochen.
- **Schaltfläche „Compliance verbinden“** (`Connect-IPPSSession`, Security & Compliance PowerShell) für DLP-,
  Aufbewahrungs- und Bezeichnungsfunktionen; aktiv nach der Exchange-Online-Verbindung, lädt nur die benötigten Cmdlets.
- **„Gruppenmitglieder anzeigen“** lädt die Mitglieder der ausgewählten Gruppe (neben „Mitglieder exportieren“).
- **Organisationseinstellungen:** Feld `HierarchicalAddressBookRoot` ergänzt; 26 bereits im Layout vorhandene, aber nicht
  angebundene Steuerelemente (u. a. Bookings-Namensrichtlinie, MailTips für alle, Schwellwert großes Publikum, EWS, OAuth,
  öffentliche Ordner, IP-Sperrliste) werden jetzt geladen und gespeichert.
- **Berichte:** Auswahlliste der Berichtstypen (Postfachgrößen, letzte Anmeldung, Postfach- und Kalenderberechtigungen,
  Gruppenmitglieder u. a.), Laufzeit- und Ergebnisanzeige, Teilergebnisse bei Abbruch.

### Geändert
- **Berichte schneller:** Postfachstatistiken werden über die REST-Cmdlets per Pipeline gebündelt abgefragt
  (`Get-EXOMailbox | Get-EXOMailboxStatistics`) statt einzeln pro Postfach; Berechtigungsberichte nutzen
  `Get-EXOMailboxPermission`/`Get-EXOMailboxFolderPermission` mit Fallback auf die klassischen Cmdlets.
- **Organisationseinstellungen speichern nur Änderungen:** Vergleich mit dem Stand beim Laden, Vorschau „alt → neu“ mit
  Bestätigung, ungültige Parameter werden nicht mehr an `Set-OrganizationConfig` übergeben.
- **Verbindungsprüfung:** `Confirm-ExchangeConnection` prüft lokal über `Get-ConnectionInformation` und speichert ein
  positives Ergebnis 120 Sekunden zwischen (vorher ein Server-Aufruf vor jeder Aktion).
- **Dashboard:** Empfängerzählung per Streaming mit Fortschritt und Abbruchmöglichkeit.
- **Gruppen:** Mitgliederlisten mit `List`/`HashSet` statt Array-Verkettung und `Where-Object` je Mitglied.
- HealthCheck und Troubleshooting verweisen bei fehlenden Compliance-Cmdlets auf „Compliance verbinden“.

### Behoben
- Berichte waren nicht nutzbar: Die Auswahlliste `cmbReportType` wurde nie befüllt.
- Gruppen: Trennung mehrerer Mitglieder per Regex fehlerhaft; `Get-DistributionGroup`/`Get-UnifiedGroup` lieferten nur
  die ersten 1000 Einträge; `Items.Clear()` bei gebundener Liste löste eine Ausnahme aus; nach dem Erstellen einer Gruppe
  wurde fälschlich `Get-SharedMailboxPermissionsAction` aufgerufen.
- Ressourcen (Raum-/Gerätepostfächer) und Mobilgeräte in Quarantäne: fehlendes `-ResultSize Unlimited` (nur 1000 Einträge).
- Organisationseinstellungen: Zuordnungen zu nicht existierenden Steuerelementen und Parametern
  (`InformationBarrierMode`, `OfficeFeatures`, `txtHierAddressBookRoot`) entfernt.
- Verbindungsstatus: Farben der Statusanzeige werden aus den Theme-Brushes gesetzt; unerreichbarer Code in
  `Confirm-ExchangeConnection` entfernt; Trennen setzt auch den Compliance-Status zurück.
- PSScriptAnalyzer: Zuweisungen an automatische Variablen (`$sender`, `$event`) im neuen Code vermieden.

## [0.2.0] - 2026-10-14

Audit- und Modularisierungs-Release: Sicherheit, Befehle, Verweise, GUI, Performance, Repository-Struktur,
Aufteilung in Module und neues, modernes Design. Details zu allen Befunden: [docs/AUDIT.md](docs/AUDIT.md).

### Architektur
- **Modularisierung:** Das bisher monolithische Skript (~28.400 Zeilen) wurde aufgeteilt in
  - `src/easyEXO.ps1` – schlanker Launcher (Umgebungsprüfung, Modul-Laden, Fenster, zentrale Event-Handler),
  - `src/Modules/Core/` – Logging, Konfiguration (Registry), Umgebungsprüfung, Hilfsfunktionen,
  - `src/Modules/UI/` – Fenster/XAML-Laden, Steuerelemente, Dialoge, Navigation,
  - `src/Modules/Exchange/` – Verbindungsaufbau/-abbau,
  - `src/Modules/Features/` – 20 Fachmodule (Postfächer, Kalender, Gruppen, Ressourcen, Kontakte,
    Transportregeln, Posteingangsregeln, Nachrichtenverfolgung, Abwesenheit, Sicherheit, Mobilgeräte,
    Organisations- und Regionaleinstellungen, HealthCheck, Audit, Berichte, Troubleshooting u. a.).
- Module werden per Dot-Sourcing in einer festen Reihenfolge (`$script:ModuleFiles`) geladen; fehlende Dateien führen
  zu einer klaren Fehlermeldung statt zu Folgefehlern.
- **GUI ausgelagert:** `src/GUI/MainWindow.xaml` (Layout) und `src/GUI/Theme.xaml` (Farben/Styles); das Theme wird beim
  Start in die Fenster-Ressourcen eingefügt (`Get-MainWindowXaml`).

### Sicherheit
- **Code-Injection in der Exchange-Diagnose behoben:** Benutzereingaben werden nicht mehr per Textersetzung in
  `[ScriptBlock]::Create()` eingefügt, sondern als Single-Quoted-String maskiert.
- **CSV-/Formel-Injection verhindert:** Alle CSV-Exporte laufen über die neue Funktion `ConvertTo-SafeCsvObject`
  (Werte, die mit `=`, `+`, `-`, `@`, Tab oder CR beginnen, werden entschärft).
- **Log-Injection verhindert:** Steuerzeichen werden aus Log-Einträgen entfernt; Logs werden in UTF-8 geschrieben.
- **OPATH-Filter-Injection verhindert:** Neue Hilfsfunktion `ConvertTo-OPathValue` für Benutzereingaben in `-Filter`
  (z. B. Kontaktsuche).
- **PowerShell-7-Installation gehärtet:** winget mit `--id Microsoft.PowerShell --exact --source winget`; MSI-Download
  nur über HTTPS (TLS 1.2) in ein eindeutiges Temp-Verzeichnis mit Prüfung der Authenticode-Signatur
  (gültig, Herausgeber Microsoft Corporation); keine zusätzlichen Features (PSRemoting, Kontextmenü) mehr aktiviert.
- **Keine Administratorrechte mehr erforderlich:** Neustart unter PowerShell 7 ohne `RunAs`, mit `-NoProfile -STA`.
- Bestätigungsdialoge vor destruktiven Aktionen ergänzt (FullAccess/SendAs entfernen, Weiterleitung entfernen,
  Kalenderberechtigung entfernen); bei Fehlern im Bestätigungsdialog wird die Aktion abgebrochen.
- Ungültig gewordener Authenticode-Signaturblock entfernt (Releases werden vom Maintainer neu signiert,
  siehe [SECURITY.md](SECURITY.md)).

### Behoben
- Nicht existierende bzw. fehlerhafte Befehle korrigiert: `Get-ExoUnifiedGroup-Identity`/`Get-ExoUnifiedGroup@params`
  → `Get-UnifiedGroup`, `Convert- ToSharedMailboxAction`, `Set-AllCalendarPermissions`
  → `Set-DefaultCalendarPermissionForAll`, `Get-ExoContacts` → `Search-ExoContacts`.
- Veraltete Azure-AD-/MSOnline-Aufrufe (`Get-AzureADUser`, `Get-MsolUser`) durch `Get-User` ersetzt.
- Nachrichtenverfolgung: Nutzung von `Get-MessageTraceV2`/`Get-MessageTraceDetailV2` (inkl. Betreff-Filter und
  10-Tage-Prüfung) mit Fallback auf die alten Cmdlets; fehlerhafter `Get-HistoricalSearch`-Block entfernt.
- Postfach-Audit: Fallback von `Search-MailboxAuditLog` auf `Search-UnifiedAuditLog`.
- Diagnose-Vorlagen aktualisiert (`Get-TenantAllowBlockListItems` mit `-ListType`, In-Place-Holds statt
  `Get-MailboxSearch`, Hybrid-Prüfung über Organisationsbeziehungen, DLP/Labels nur mit IPPS-Sitzung).
- Vergleich `Items.Count > 0` (Umleitung in Datei „0“) durch `-gt 0` ersetzt (3×).
- `Show-MessageBox` unterstützt jetzt `YesNo`/`Question` korrekt – 7 Bestätigungsabfragen funktionierten vorher nicht.
- Freigegebene Postfächer: „Aus GAL ausblenden“ war invertiert; Berechtigungsquelle nutzt das ausgewählte Postfach;
  doppelte Aktualisierungslogik entfernt.
- Kalenderberechtigung entfernen: Erfolgsprüfung war immer falsch; nicht vorhandene Lokalisierungsfunktion entfernt.
- Organisationseinstellungen: `ActivityBasedAuthenticationTimeoutInterval` wird aus dem richtigen Textfeld gelesen.
- Quarantäne: Switch-Parameter mit Standardwert `$true` durch `-NoDefaultFilter` ersetzt.
- E-Mail-Validierung akzeptiert gültige Zeichen wie `+`, `'` und `%`.
- Erkennung des ExchangeOnlineManagement-Moduls (Banner) korrigiert.
- Hilfe-Links: Themen werden je Link korrekt zugeordnet (kein doppelter bzw. leerer Klick-Handler mehr).
- Umlaute in Log-Dateien und Statusanzeigen werden nicht mehr durch `?` ersetzt.
- Gruppenmitglieder werden vollständig geladen (`-ResultSize Unlimited` bei `Get-DistributionGroupMember`/
  `Get-UnifiedGroupLinks`).
- Exchange-Verbindung wird auch bei unerwarteten Fehlern im `finally`-Block getrennt.
- Fehlgeschlagene oder abgebrochene Anmeldung wurde als „verbunden“ gewertet (Rückgabewerte von Dialogen) – behoben.
- Mobilgeräte zulassen/blockieren: das nicht existierende Cmdlet `Set-MobileDevice` wurde durch
  `Set-CASMailbox -ActiveSyncAllowedDeviceIDs/-ActiveSyncBlockedDeviceIDs` ersetzt (`Set-MobileDeviceAccessState`).
- Editierbare ComboBoxen (z. B. Zeitzonen-/Formatauswahl) ließen keine Texteingabe zu – Vorlage korrigiert.
- `CornerRadius`-Attribute wurden beim XAML-Laden pauschal entfernt – nicht mehr nötig und entfernt.
- Unausgeglichene `#region`/`#endregion`-Marker bereinigt.

### Design (GUI)
- Neues, modernes Theme im Fluent-Stil: einheitliche Farbpalette, abgerundete Buttons mit Hover-/Pressed-Zuständen,
  Karten-Optik für GroupBoxen, modernisierte Eingabefelder, ComboBoxen, DataGrids und Tabs.
- Button-Varianten statt fest kodierter Einzelfarben (`SecondaryButton`, `SuccessButton`, `DangerButton`,
  `WarningButton`); vorher verhinderten lokale Farben bei 141 Buttons jeden Hover-Effekt.
- Navigation: dunkle Seitenleiste, aufklappbare Bereiche mit eigenem Stil, aktiver Bereich wird hervorgehoben
  (über `Tag="Active"` statt fest gesetzter Farben).
- Verbinden-Button wechselt im verbundenen Zustand automatisch in den „Trennen“-Stil.
- Versionsanzeige in der Kopfzeile (`txtVersion` war im Code referenziert, fehlte aber im XAML).
- Fenstergröße wird beim Start an den verfügbaren Bildschirmbereich angepasst (kleine Displays/Skalierung).

### Hinzugefügt
- Verbinden-Button trennt eine bestehende Verbindung (mit Bestätigung) und setzt die Dashboard-Statistiken zurück.
- Postfachberechtigungen: getrennte Buttons für „FullAccess anzeigen“, „SendAs anzeigen“, „SendOnBehalf anzeigen“.
- Freigegebene Postfächer: Buttons „Postfach entfernen“, „In GAL anzeigen“, „Berechtigungen exportieren“ sowie
  Funktion zum Entfernen der Weiterleitung.
- Posteingangsregeln: Button „Regeln exportieren“.
- Zentrale Versionsvariable `$script:AppVersion` (Fenstertitel, Kopfzeile, Info-Dialog, Registry).
- Automatischer Neustart im STA-Modus, falls das Skript in einem MTA-Thread gestartet wird.
- Repository-Dokumentation: `CHANGELOG.md`, `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`,
  `docs/AUDIT.md`, Pull-Request-Vorlage.

### Performance
- Dashboard-Statistiken mit **einer** Abfrage (`Get-EXORecipient -RecipientTypeDetails … -PropertySets Minimum`,
  Fallback `Get-Recipient`) statt mehrerer vollständiger Abfragen je Empfängertyp.
- WPF-Assemblies werden nur noch einmal zu Beginn geladen.

### Geändert
- Neue Ordnerstruktur: Skript unter `src/easyEXO.ps1` (ohne Versionsnummer im Dateinamen), Dokumentation unter `docs/`,
  Screenshots unter `docs/screenshots/`.
- Umgebungsprüfung beim Verbinden läuft nur einmal pro Sitzung und blockiert die Verbindung nicht mehr.
- Doppelte Click-Handler für Navigation und Schließen-Button entfernt (zentrale Registrierung).
- Tab-Wechsel werden mit dem Tab-Namen protokolliert.
- `.gitignore` erweitert (Logs, temporäre Dateien, Editor-Dateien).
- README aktualisiert (Voraussetzungen, Aufruf, Projektstruktur, Links).

### Entfernt
- Alte Skriptversionen (`# Versions/`, V0.0.1–V0.0.13 inkl. alter XAML-/Log-Dateien) – weiterhin über die Git-Historie verfügbar.
- Veraltete Screenshots (`# Screenshots/`).

## [0.1.1] - 2025-07-12

### Geändert
- Umfangreiche Code-Optimierungen.
- GUI (XAML) vollständig in das Skript eingebettet – keine externen Dateien (`assets/EXOGUI.xaml`,
  `assets/SettingsWindow.xaml`) mehr erforderlich.
- README neu geschrieben (Funktionsübersicht, Voraussetzungen, Anwendung).

### Sicherheit
- Skript mit Code-Signing-Zertifikat signiert (2025-07-14).

### Infrastruktur
- GitHub-Actions-Workflows für PSScriptAnalyzer und Codacy hinzugefügt (2025-07-26).
- Pull Request #1 „Fix incorrect logging call“ (2025-06-05) wurde geschlossen und nicht übernommen.

> Hinweis: Eine Version 0.1.0 wurde nicht veröffentlicht.

## [0.0.13] - 2025-07-12

### Hinzugefügt
- Erweitertes Dashboard mit zusätzlichen Statistiken.
- Bereiche ATP (Microsoft Defender), MDM und Cross-Premises/Mail-Routing in der GUI aktiviert.
- Separates Einstellungsfenster (`SettingsWindow.xaml`).
- Dashboard-Screenshot.

## [0.0.12] - 2025-07-11

### Geändert
- Erweiterte Funktionalität in mehreren Bereichen (neue Skriptversion mit überarbeiteter GUI).

### Infrastruktur
- Codacy-Workflow testweise hinzugefügt und wieder entfernt.

## [0.0.11] - 2025-07-06

### Hinzugefügt
- Neue Tabs und Funktionen.
- Neue Signatur des Skripts.
- README-Dokumentation.

### Geändert
- Kontakte-Tab überarbeitet (2025-07-08).

### Entfernt
- Alte Module, Assets und Konfigurationsdateien aus dem Versionsordner.

## [0.0.10] - 2025-05-25

### Geändert
- Neue Versionsnummerierung, Skript `easyEXO_V0.0.10.ps1`.
- Ordner `#OLD` in `# Versions` umbenannt (2025-07-02).
- GUI-Überarbeitung und Bereinigung der Konfiguration (`config.ini`/`settings.ini` entfernt,
  Admin-Hinweise nach `docs/` verschoben) (2025-07-04).

## [0.0.1] – [0.0.9] - 2025-05-23

### Hinzugefügt
- Erstveröffentlichung des Repositorys (MIT-Lizenz).
- Import der frühen Skriptversionen V0.0.1 bis V0.0.9 inklusive Funktionsmodulen, externer XAML-Oberfläche
  (`assets/EXOGUI.xaml`), Grafiken und Konfigurationsdateien (INI/JSON).

[0.3.0]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/compare/cda8c87...main
[0.2.0]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/compare/dffe553...cda8c87
[0.1.1]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/commit/dc4d8de
[0.0.13]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/commit/8425e6f
[0.0.12]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/commit/b16bfc8
[0.0.11]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/commit/0986ea6
[0.0.10]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/commit/67b5a5d
