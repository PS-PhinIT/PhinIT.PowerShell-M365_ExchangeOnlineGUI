# Changelog

Alle wesentlichen Änderungen an **easyEXO** werden in dieser Datei dokumentiert.

Das Format orientiert sich an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
die Versionierung folgt [Semantic Versioning](https://semver.org/lang/de/).
Jede Änderung wird direkt unter einer **konkreten Versionsnummer mit Datum** eingetragen.

Die Einträge bis einschließlich 0.1.1 wurden nachträglich aus der Git-Historie
(Commits und Pull Requests) rekonstruiert. Die Versionen 0.2.0 bis 0.4.0 wurden gemeinsam mit
[Pull Request #2](https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/pull/2) in `main` übernommen.
Die Änderungen zu 0.5.0 wurden mit
[Pull Request #3](https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/pull/3)
am 2026-10-15 zusammengeführt; das bereits dokumentierte Versionsdatum bleibt erhalten.

## [0.5.1] - 2026-10-15

Erneutes Audit des aktuellen Quellstands nach Pull Request #3. Prüfumfang, Ergebnisse und
Grenzen der Prüfung stehen in [docs/AUDIT.md](docs/AUDIT.md#nachprüfung-051--2026-10-15).

### Behoben
- **Navigation:** Die Schaltflächen für Hybrid Exchange, Multi-Forest, DLP und eDiscovery waren im XAML
  auskommentiert. Sie sind wieder erreichbar und nutzen die bestehenden Tab-Zuordnungen und Handler.
- **Arbeitsanzeige:** Der Titelparameter wurde durch das gleichnamige TextBlock-Steuerelement überschrieben
  (PowerShell unterscheidet keine Groß-/Kleinschreibung). Das Overlay zeigt nun den übergebenen Titel.
- **Dashboard:** Fehler beim Laden von Empfängern oder Domänen werden nicht mehr als vollständiger Erfolg
  gemeldet. Nach einem Abbruch erfolgt keine weitere Domänenabfrage; die Arbeitsanzeige wird weiterhin
  im `finally` aufgeräumt.
- **Berichte:** Alle elf Berichtsfunktionen akzeptieren die initial leere Ergebnisliste; zuvor brachen die
  Aufrufe bereits bei der Parameterbindung ab.
- **Gruppen:** Fehlerdialoge und Mitgliedschaftsergebnisse verunreinigen die Gruppenrückgabe nicht mehr.
  Fehlgeschlagene Mitgliedschaften werden separat gemeldet statt eine vollständige Einrichtung vorzutäuschen.
- **Weiterleitungen:** Ein SMTP-Ziel ersetzt nun ein vorhandenes `ForwardingAddress`; Anzeige und Berichte
  berücksichtigen dessen tatsächlichen Vorrang vor `ForwardingSmtpAddress`.
- **Audit:** Der Unified-Audit-Fallback prüft das Zielpostfach über `MailboxOwnerUPN` statt den Akteur mit dem
  Postfach gleichzusetzen; Suchlimit wird ausdrücklich angezeigt.
- **Nachrichtenverfolgung:** Detailabfragen enthalten den Zeitraum der ausgewählten Nachricht, auch außerhalb
  des standardmäßigen 48-Stunden-Fensters.
- **Ressourcen:** Stellvertreterlisten lassen sich vollständig leeren; unverändertes Speichern aktiviert keine
  zuvor abgeschaltete Kalenderverarbeitung. Mindestdauer `0` wird angezeigt, akzeptiert und übertragen.
- **Abbruch / Multi-Forest:** Abbruch auch nach Verarbeitung des letzten Pipelineobjekts und am Pipelineende
  prüfen; Suchfehler nicht mehr als erfolgreiche leere Suche melden.
- **Kontakte:** Listenabfragen mit vorhandener Fortschritts-/Abbruchanzeige und ohne zusätzliche
  `Get-OrganizationConfig`-Abfrage; Cmdletfehler brechen zuverlässig ab.

### Sicherheit
- **Transportregelimport gesperrt:** Die bisherigen CSV-/CLIXML-Exporte verlieren Bedingungen, Ausnahmen und
  weitere Einstellungen. Die Wiederherstellung konnte dadurch wirksame Regeln ungewollt ausweiten.
  Importausführung entfernt, kompatible Fehlerrückgabe beibehalten und GUI-Schaltfläche deaktiviert.
  Exporte bleiben ausdrücklich **Berichte, keine Sicherungen**. Ein verlustfreier Import erfordert eine
  gesonderte Implementierung; vorhandene Berichte dürfen nicht zur Wiederherstellung verwendet werden.

### Entfernt
- Vollständige Screenshot-Ablage einschließlich ihrer README; Verweise in README und Mitwirkungsrichtlinien
  angepasst. Bilddateien und alte Skriptkopien waren im geprüften Ausgangsstand bereits nicht mehr enthalten.

### Dokumentation
- Bestehende Struktur mit `src/GUI`, `src/Modules/{Core,UI,Exchange,Features}` und `docs` beibehalten;
  wichtige Projektdokumente und Versionshistorie bleiben erhalten.
- Versionsangaben in Launcher, README und Sicherheitsrichtlinie auf 0.5.1 abgeglichen.
- Historische Einträge anhand der zusammengeführten Pull Requests #2 und #3 geprüft und Herkunft ergänzt.

## [0.5.0] - 2026-10-14

Zweites Audit-Release: vollständige Prüfung aller Module (Sicherheit, Performance, Funktionen, Verweise, GUI,
Exchange-Befehle) mit Abgleich der verwendeten Cmdlet-Parameter gegen die aktuelle Microsoft-Dokumentation.
Schwerpunkte: ungültige Exchange-Parameter, falsche Erfolgsmeldungen, Abstürze bei genau einem Ergebnis,
XAML-Injection in Dialogen, fehlende Bestätigungen und einheitliches Design. Details: [docs/AUDIT.md](docs/AUDIT.md)
(Abschnitt „Nachprüfung 0.5.0“).

### Hinzugefügt
- **Microsoft Defender (ATP):** Schaltflächen „Ausgewählte löschen“ für Anti-Phishing-, Safe-Attachments- und
  Safe-Links-Richtlinien (mit Bestätigung; zugehörige Regeln werden zuerst entfernt).
- **Einstellungen:** Standard-Benutzer, Debug-Modus und Log-Verzeichnis wirken sofort nach dem Speichern
  (`Initialize-Logging`).
- **Statusleiste:** Copyright mit aktuellem Jahr.
- **Theme für Dialoge:** `Add-ThemeResource` stellt Farben und Styles aus `Theme.xaml` auch in eigenen Fenstern
  bereit (Richtlinien-, Geräte-, Connector-, Ressourcen-, Nachrichtenverfolgungs- und Einstellungsdialog);
  `Get-StatusBrush` liefert die Statusfarben aus dem Theme.
- **Repository:** Issue-Vorlagen für Fehlerberichte und Funktionswünsche (`.github/ISSUE_TEMPLATE/`), Sicherheitslücken
  werden auf die vertrauliche Meldung verwiesen.
- Arbeitsanzeige mit Fortschritt und „Abbrechen“ zusätzlich für Health Check, Audit, Diagnosen, Quarantäne,
  Regionaleinstellungen, Weiterleitungen freigegebener Postfächer, „Standardberechtigung für alle“ (Kalender),
  Nachrichtenverfolgung, Import von Transportregeln und Deaktivieren mehrerer Abwesenheitsnotizen.

### Geändert
- **Design:** Alle fest kodierten Farben aus `MainWindow.xaml` und den Inline-Dialogen entfernt – Farben stehen nur
  noch in `Theme.xaml` (neue Brushes für Kopfzeile, Navigationsleiste, Statusleiste, Hinweise und Dashboard-Kacheln).
  22 Schaltflächen ohne Style verwenden jetzt die Theme-Styles; Verbindungsstatus und Statusleiste nutzen die
  Theme-Statusfarben.
- **Transportregeln:** Bereich vollständig eingedeutscht (Navigation „Transportregeln“, „Posteingangsregeln“, Bereich
  „Automatische Antworten“); Rückfragen beim Erstellen wirksamer Regeln (Erzwingen, Löschen, Umleiten, Quarantäne,
  Ablehnen), beim Aktivieren im Modus „Erzwingen“ und beim Deaktivieren.
- **Anmeldung:** Eingabe des Benutzernamens über den Theme-Eingabedialog statt eines eigenen Fensters; „Abbrechen“
  bricht die Anmeldung sauber ab.
- **Registry:** Beim Start werden nur fehlende Werte angelegt, die Version nur bei Änderung geschrieben; die
  ungenutzten Werte `ThemeColor`/`HeaderLogoURL` werden nicht mehr angelegt.
- **PowerShell-7-Neustart:** Das Fenster wird geordnet geschlossen (kein `exit` im Event-Handler); ein Neustart mit
  Administratorrechten wird nicht mehr angeboten (nicht erforderlich).
- **Health Check:** Der Ping an einen externen DNS-Server (8.8.8.8) entfällt – er brach den Verbindungstest in
  Netzen ohne ICMP ab; DNS- und Port-443-Test sind Hinweise, der Exchange-Online-Test läuft immer.
- **Berichte:** Start-/Enddatum sind nur aktiv, wenn der gewählte Bericht sie verwendet.
- **Nachrichtenverfolgung:** bis zu 5000 Ergebnisse (Hinweis bei Erreichen des Limits).
- **Regionaleinstellungen:** Export als Textdatei statt CSV; Bestätigung auch für einzeln genannte Postfächer.
- **Freigegebene Postfächer:** Weiterleitungen werden serverseitig gefiltert und mit Ziel und „Kopie behalten“ angezeigt.
- Schaltflächen in Cross-Premises, Organisations- und Regionaleinstellungen über `Register-EventHandler`
  (Fehlerbehandlung, Sperre während laufender Vorgänge).
- Troubleshooting-Links auf learn.microsoft.com umgestellt (docs.microsoft.com und ein Drittanbieter-Link wurden von
  der URL-Allowlist blockiert); RPS-Hinweise in der Vergangenheitsform.

### Behoben
- **Einstellungen/Logging:** Das Log-Verzeichnis aus den Einstellungen wurde ignoriert (Dialog las den falschen
  Schlüssel, Logging nutzte einen festen Pfad); Debug-Einträge wurden auch ohne Debug-Modus geschrieben; der Debug-Wert
  wurde mit falschem Typ gespeichert.
- **Launcher:** Der Verweis auf den Bereich Organisationseinstellungen wurde nach dem Laden mit `$null` überschrieben;
  tote Verweise (`tabOrgSettings`, `btnNavOrgSettings`, `btnCheckPrerequisites`) entfernt; fehlerhafte Verwendung von
  `$_` im Loaded-Handler.
- **Spaltenbindungen:** Safe Attachments „Aktiviert“ (`Enable`), Safe Links „E-Mail-Schutz“
  (`EnableSafeLinksForEmail`), Geräte in Quarantäne (`UserDisplayName`, `DeviceAccessState`), Connectors (`Type`).
- **CSV-Export:** Mehrwertige Eigenschaften (z. B. `EmailAddresses`) wurden als Typname exportiert – jetzt als Liste.
- **Abstürze/leere Listen bei genau einem Ergebnis** (fehlendes `@(…)`): Domänen, Gruppen, Ressourcen und
  Ressourcenberechtigungen, Kontakte (MailUser), Berechtigungen und Weiterleitungen freigegebener Postfächer,
  Posteingangsregeln, mobile Geräte, akzeptierte Domänen (Cross-Premises).
- **Postfachberechtigungen:** „Senden als“ wurde bei Benutzern mit Vollzugriff verworfen; Spalte „Berechtigungstyp“ war
  leer; „Senden im Auftrag“ erkannte bestehende Einträge nicht (Vergleich von Anzeigenamen mit Adressen) – Änderungen
  jetzt über `@{Add=…}`/`@{Remove=…}` ohne Neuschreiben der ganzen Liste, Entfernen mit Bestätigung.
- **Freigegebene Postfächer:** „Kopie behalten“ bei Weiterleitungen wurde ignoriert; Fehler beim Laden der
  Weiterleitungen wurden als „keine Weiterleitungen“ gemeldet; Ändern von AutoMapping ohne Bestätigung und ohne
  Wiederherstellung bei Fehlern.
- **Kalender:** Vorhandene Berechtigungen werden aktualisiert statt mit Fehler abzubrechen; Fehlermeldungen wurden von
  einer Erfolgsmeldung überschrieben; „Standardberechtigung für alle“ meldete auch bei Fehlern Erfolg.
- **Kontakte:** MailUser wurden mit `Set-MailContact` bearbeitet (jetzt `Set-MailUser`); Aktualisieren nach dem Löschen
  eines MailUsers schlug fehl.
- **Gruppen:** „Benutzer entfernen“ meldete Erfolg trotz Fehler; „Aus GAL ausblenden“ bei Microsoft 365-Gruppen las
  eine nicht existierende Eigenschaft und blendete Gruppen beim Speichern ungewollt ein; „Absender-Authentifizierung“
  und „Externe Absender zulassen“ widersprachen sich; `New-UnifiedGroup` erhielt Beschreibung und Besitzer über
  ungültige Parameter (jetzt `-Notes`, `-Owner`).
- **Ressourcen:** Liste wurde nach Erstellen/Bearbeiten/Löschen nicht aktualisiert; Standort über `Office` statt
  `ResourceCustom`, kein ungültiger Parameter `-Location` mehr bei `New-Mailbox`; Kapazität nur, wenn angegeben;
  ungültige Zahleneingaben werden gemeldet statt verworfen; Platzhalter im Einstellungsdialog.
- **Transportregeln:** ungültiger Standardmodus „Test“ (jetzt „Audit“, Rückfall bei ungültiger Auswahl); Regeln ohne
  gültige Bedingung oder Aktion (hätten für alle Nachrichten gegolten) werden abgelehnt; Import übergab die
  nicht existierenden Parameter `State`/`Description` (jetzt `Enabled`/`Comments`) und meldete Erfolg trotz Fehlern;
  Listen-Eigenschaften im CSV-Export/-Import; ungültige statische Einträge in den Auswahllisten entfernt.
- **Posteingangsregeln:** Aktivieren, Deaktivieren, Löschen und Verschieben verwendeten eine ungültige Identität;
  Zielordner im falschen Format.
- **Nachrichtenverfolgung:** Der End-Tag war ausgeschlossen; „Lokale Zeit“ wurde nicht umgerechnet; Prüfung
  „Ende nach Start“ ergänzt.
- **Abwesenheitsnotizen:** Deaktivieren mehrerer Benutzer lud die Liste für jeden Benutzer neu.
- **Cross-Premises:** Fehler beim Laden/Ändern von Connectors wurden als Erfolg protokolliert; Inbound-Connector ohne
  Absenderdomänen; Smart Hosts ohne `UseMXRecord $false`; `TlsDomain` nur bei Zertifikatsprüfung „DomainValidation“;
  fehlerhafter Text in der Rückfrage.
- **Microsoft Defender (ATP):** Anti-Phishing-, Safe-Attachments- und Safe-Links-Dialoge verwendeten nicht existierende
  Parameter (u. a. `Description`, `ImpersonationProtectionEnabled`, `SpoofProtectionEnabled`, `EnableRedirect`) – jetzt die dokumentierten Parameter
  (`AdminDisplayName`, `EnableTargetedUserProtection`, `EnableMailboxIntelligenceProtection`, `Enable`, `Redirect`,
  `DeliverMessageAfterScan`, `TrackClicks`, `AllowClickThrough` …); Aktionen für sichere Anlagen
  (Allow/Block/DynamicDelivery); fehlende Regeln werden angelegt, Empfängerbereiche lassen sich leeren. Beim Bearbeiten
  bleiben vorhandene Empfänger ohne `@` (Alias/Name) Empfänger und werden nicht mehr als Domäne gespeichert.
- **Quarantäne:** Es wurde nur die erste Seite geladen; ungültige Typwerte; „Ausgewählte freigeben/löschen“ verarbeitete
  nur eine Nachricht.
- **Mobile Geräte:** `AllowBluetooth` mit ungültigem Wert; ungültiges Feld „Beschreibung“; Mindest-Kennwortlänge ohne
  `PasswordEnabled`; Zulassen/Blockieren ließ die Geräte-ID in der jeweils anderen Liste.
- **Organisationseinstellungen:** „Speichern“ und „Exportieren“ funktionierten erst nach dem ersten Laden.
- **Regionaleinstellungen:** Absturz der Fortschrittsanzeige; „Ordnernamen in Benutzersprache“ wurde falsch gelesen;
  Exchange-Warnungen wurden als Fehler gezählt.
- **Health Check:** Warnungen und Details wurden nie ausgegeben; SMTP-AUTH-Prüfung über `Get-TransportConfig`;
  Modern Auth über `OAuth2ClientProfileEnabled`; Remote-Domäne „Default“; Fehlerauswertung ohne globales `$Error`.
- **Audit:** Regelname fehlte in der Lösch-Empfehlung; `AuditLogAgeLimit` als Zeitspanne ausgewertet; Ordner nach
  Größe in Bytes sortiert; die Option „Vollständige Audit-Details“ war durch fehlerhafte Zeichenketten unerreichbar;
  Statusleiste zeigt das tatsächliche Ergebnis.
- **Berichte:** ungültige Eigenschaft `AuditBypassEnabled`; Fehler bei Postfachstatistiken werden gezählt und
  protokolliert.
- **Diagnosen (Troubleshooting):** Fehler der Diagnosebefehle wurden als Erfolg gemeldet; nicht existierende
  Eigenschaften `PowerShellMax*`; typografische Gedankenstriche als Parameterpräfix; fehlende `-ResultSize Unlimited`.
- **Dashboard:** „Zurücksetzen“ leerte die Statistik-Kacheln nicht.
- **Rückgabewerte:** Gruppen-, Postfachberechtigungs-, Shared-Mailbox- und Abwesenheitsfunktionen gaben neben `$true`/`$false`
  auch MessageBox-Ergebnisse bzw. Exchange-Objekte zurück – Fehlschläge (z. B. Mitglied aus dynamischer Gruppe entfernen,
  teilweise fehlgeschlagenes Auto-Mapping) wurden dadurch als Erfolg gemeldet.

### Sicherheit
- **XAML-Injection:** Betreff (Nachrichtenverfolgung) und Anzeigename (Ressourcen) wurden in das XAML-Markup eingesetzt
  – Daten werden jetzt nach dem Laden über Eigenschaften gesetzt; kein Inline-XAML enthält mehr Variablen.
- **Transportregel-Import (XML):** Nur erlaubte Eigenschaften und einfache Datentypen werden übernommen.
- **Audit:** Abgleich interner Domänen war mit Domänen wie `contoso.com.evil.net` umgehbar.
- **Externe Links:** Admin-Center- und Hilfe-Links (Defender, Organisationseinstellungen) nur noch über
  `Open-ExternalUrl` (https, Allowlist) statt `Start-Process`.
- **PowerShell-7-Installation:** MSI ohne Explorer-Kontextmenü (Befund S2 aus 0.2.0 war nur teilweise umgesetzt).
- Globale Variable `$Global:IsConnectedToExo` entfernt (Verbindungsstatus nur im Script-Scope); Steuerzeichen werden aus
  Statusmeldungen entfernt.

### Entfernt
- Ungenutzte Funktionen: `Test-ModuleInstalled`, `Test-InternetConnection`, `Add-ComboBoxDefaultItem`,
  `Update-ComboBoxItems`, `Write-StatusMessage`, `Get-MailboxPermissionsAction`, `Set-CalendarDefaultPermissionsAction`,
  `Add-CalendarPermission`, `Remove-CalendarPermission`, `Set-AnonymousCalendarPermissionForAll`, `Update-ExoContact`,
  `Search-ExoContacts`, zehn Altfunktionen in `Groups.ps1` (u. a. `Create-DistributionGroupAction`,
  `Get-ExoDistributionGroup`), `Refresh-InboxRuleUserDropdown`, `Get-ThrottlingPolicyAction`,
  `Get-ThrottlingPolicyForTroubleshooting`, `Test-EWSThrottlingPolicy`, `Initialize-OrganizationConfigControls`,
  `Set-EXOSettingsDebugLogging`.
- Wirkungslose Checkbox „Authentifizierung“ im Connector-Dialog, ungenutzte Kopfzeilen-Elemente
  (`headerStatus`, `headerStatusContainer`) und ungenutzte Variablen.

## [0.4.0] - 2026-10-14

Funktions-Release zum Audit: Alle Bereiche und Steuerelemente, die im Layout vorhanden, aber ohne Funktion waren,
sind jetzt angebunden; dazu Fehlerbehebungen bei den Abwesenheitsnotizen und neue Berichte.
Details: [docs/AUDIT.md](docs/AUDIT.md) (Befunde S11, B17–B19, V18–V25, G19–G20, P7).

### Hinzugefügt
- **Hybrid Exchange** (`Features/Hybrid.ps1`): Hybrid-Status prüfen (lokale Organisation, Organisationsbeziehungen,
  IntraOrganization-Connectors, Inbound-/Outbound-Connectors, Migrationsendpunkte), Verbund-Vertrauensstellung prüfen
  (Verbundorganisationsbezeichner, Organisationsbeziehungen, Freigaberichtlinien), Export als CSV, Link zum
  Hybrid Configuration Wizard.
- **Multi-Forest** (`Features/MultiForest.ps1`): Domänen des Tenants laden, Empfänger nach Domäne, Objekttyp und
  Suchbegriff suchen (Spalte „Forest“ mit Domäne und Herkunft AD-synchronisiert/Cloud), Export;
  Microsoft-Entra-Connect-Synchronisation (Delta oder vollständig) starten/stoppen und Status anzeigen – auf dem
  Entra-Connect-Server mit Modul `ADSync`.
- **DLP & Compliance** (`Features/Compliance.ps1`, neuer Bereich statt Platzhalter): DLP-Richtlinien und -Regeln,
  Aufbewahrungsrichtlinien und Vertraulichkeitsbezeichnungen anzeigen und exportieren; Modus einer DLP-Richtlinie
  ändern (Aktiv, Test mit/ohne Benachrichtigungen, Deaktiviert) mit Bestätigung.
- **eDiscovery & Legal Hold**: eDiscovery-Fälle laden und anlegen, Details mit den Aufbewahrungen (Holds) des Falls;
  Legal Hold suchen (ohne Suchbegriff: alle Postfächer mit Legal Hold), für markierte Postfächer aktivieren/entfernen,
  Export.
- **Berichte:** acht neue Berichte – Weiterleitungen, Archiv- und Aufbewahrungsstatus, „Senden als“-Berechtigungen,
  Microsoft 365-Gruppen, Verteilergruppen ohne Besitzer, Raum- und Ressourcenpostfächer (inkl. Buchungsoptionen),
  Postfach-Überwachung (Audit-Status) und externe Weiterleitungen. Kategorieliste filtert die Berichte; Feld
  „Benutzer“ schränkt postfachbezogene Berichte ein.
- **Berichte exportieren:** „Nach Excel exportieren“ (XLSX über das Modul *ImportExcel*, sonst Excel-kompatible CSV),
  „Automatisch als CSV speichern“ (Ordner `Reports`, ersatzweise `Dokumente\easyEXO\Reports`) und „Nach Export öffnen“.
- **Abwesenheitsnotizen – Masseneinrichtung:** dieselbe Notiz für alle markierten Benutzer der Statusliste oder für
  mehrere Adressen im Feld „Benutzer“ (getrennt durch `;` oder `,`), mit Bestätigung, Fortschritt und Abbrechen;
  Deaktivieren ebenfalls für mehrere Benutzer.
- **Exporte:** Postfachberechtigungen (CSV), Audit- und Diagnoseergebnis (Textdatei).
- **Hilfe:** Themen für Berichte, Freigegebene Postfächer, Troubleshooting, Regionaleinstellungen, Abwesenheitsnotizen,
  Hybrid, Multi-Forest, DLP & Compliance und eDiscovery; Hilfe-Links in den Bereichen Kontakte, Abwesenheitsnotizen,
  DLP und eDiscovery.
- Hilfsfunktionen: `Show-InputDialog` (Eingabedialog im Theme), `Export-TextContent`, `Open-ExternalUrl`,
  `Register-HelpLink`, `Get-SelectedGridItems`.

### Geändert
- **Tab-Initialisierung:** eine zentrale Liste `$script:TabInitializers` statt zweier abweichender Listen; ein Fehler in
  einem Bereich hält die übrigen nicht mehr auf.
- **Compliance-Verbindung** importiert zusätzlich `Set-DlpCompliancePolicy`, `Get-ComplianceCase`, `New-ComplianceCase`
  und `Get-CaseHoldPolicy` (weiterhin nur die benötigten Cmdlets).
- **Abwesenheitsstatus** aller Postfächer mit Arbeitsanzeige, Fortschritt und Abbrechen; Status für mehrere Adressen.
- Bereiche eDiscovery, Abwesenheitsnotizen und Multi-Forest verwenden die Button-Styles des Themes.
- Exporte von Audit- und Diagnoseergebnis heißen „Ergebnisse speichern (TXT)“.

### Behoben
- Abwesenheitsnotiz: Platzhalter `{StartDate}`/`{EndDate}` wurden nicht ersetzt; Zeilenumbrüche gingen verloren;
  leere Datumsfelder lösten einen Parameterfehler aus; Start nach Ende wurde nicht geprüft; die Notiz endete bereits um
  00:00 Uhr des gewählten Endtags.
- Abwesenheitsstatus-Export ohne Trennzeichen `;`.
- Berichte „Postfachgrößen“ und „Letzte Anmeldung“: Die Spalte `PrimarySmtpAddress` blieb bei Verwendung der
  REST-Cmdlets leer, da `ExchangeGuid` nicht abgefragt wurde.
- Berichte brachen mit einem Parameterfehler ab, wenn der Benutzerfilter keine Postfächer lieferte (leeres Ergebnis
  statt Fehlermeldung).
- Hilfe-Links mehrerer Bereiche zeigten „Unbekanntes Thema“.
- Masseneinrichtung der Abwesenheitsnotizen meldete „noch nicht implementiert“.

### Sicherheit
- Externe Seiten werden nur über `Open-ExternalUrl` geöffnet (`https`, Allowlist bekannter Microsoft-Hosts).
- Automatisch gespeicherte Berichte (personenbezogene Daten) per `.gitignore` ausgeschlossen; alle neuen Exporte
  laufen über `ConvertTo-SafeCsvObject`, alle neuen Filter mit Benutzereingaben über `ConvertTo-OPathValue` bzw. `-Anr`.
- Ändernde Aktionen (DLP-Modus, Legal Hold, eDiscovery-Fall, Entra-Connect-Synchronisation, Masseneinrichtung) nur
  nach Bestätigung.

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

[0.5.0]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/compare/a81147c...main
[0.4.0]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/compare/db7f1ea...a81147c
[0.3.0]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/compare/cda8c87...db7f1ea
[0.2.0]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/compare/dffe553...cda8c87
[0.1.1]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/commit/dc4d8de
[0.0.13]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/commit/8425e6f
[0.0.12]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/commit/b16bfc8
[0.0.11]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/commit/0986ea6
[0.0.10]: https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI/commit/67b5a5d
