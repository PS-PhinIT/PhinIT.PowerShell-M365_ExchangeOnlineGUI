# easyEXO - Exchange Online Verwaltungstool

![Version](https://img.shields.io/badge/version-0.4.0-blue) ![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.x-5391FE) ![Lizenz](https://img.shields.io/badge/license-MIT-green)

> Screenshots der aktuellen Version werden unter [`docs/screenshots/`](docs/screenshots/) abgelegt.

## Übersicht

**easyEXO** ist ein leistungsstarkes PowerShell-basiertes Tool mit einer grafischen Benutzeroberfläche (WPF), das die Verwaltung von Microsoft Exchange Online vereinfacht. Es bündelt eine Vielzahl von administrativen Aufgaben in einer zentralen Konsole und richtet sich an IT-Administratoren, die eine effiziente Alternative zur webbasierten Exchange-Verwaltungskonsole und zur reinen Kommandozeile suchen.

Das Tool ist modular aufgebaut (ein Launcher plus thematisch getrennte Moduldateien, GUI-Layout und Design als eigene XAML-Dateien) und bietet ein modernes Design mit verschiedenen Bereichen für spezifische Verwaltungsbereiche, von der grundlegenden Postfach- und Kalenderverwaltung bis hin zu komplexen Mailflow-Regeln, Sicherheitsrichtlinien und Fehlerbehebungsdiagnosen.

## Hauptfunktionen

### 📊 Dashboard
- **Statistiken**: Zeigt nach Verbindung eine dynamische Übersicht über wichtige Exchange-Objekte wie Postfächer, Gruppen, Kontakte und Ressourcen.
- **Berichte**: 14 Berichte in fünf Kategorien (Postfächer, Berechtigungen, Gruppen, Ressourcen, Audit) – u. a. Postfachgrößen, letzte Anmeldung, Weiterleitungen, Archiv-/Aufbewahrungsstatus, Vollzugriff, „Senden als“, Kalenderberechtigungen, Microsoft 365-Gruppen, Verteilergruppen ohne Besitzer, Raum-/Ressourcenpostfächer, Audit-Status und externe Weiterleitungen. Optionaler Benutzerfilter, gebündelte Abfragen, abbrechbar; Export als CSV oder für Excel (XLSX mit dem Modul *ImportExcel*), optional automatische Ablage im Ordner `Reports`.

### 🗂️ Grundlegende Verwaltung
- **Kalenderberechtigungen**: Einfaches Anzeigen, Hinzufügen, Ändern und Entfernen von Berechtigungen für Benutzerkalender. Setzen von Standard- und anonymen Berechtigungen.
- **Postfachberechtigungen**: Verwaltung von `FullAccess`, `SendAs` und `SendOnBehalf` Berechtigungen.
- **Freigegebene Postfächer**: Erstellen, Konvertieren und Verwalten von freigegebenen Postfächern und deren Berechtigungen.
- **Gruppen**: Verwaltung von Verteilergruppen, inklusive Mitgliedschaften und Einstellungen.
- **Ressourcen**: Verwaltung von Raum- und Gerätepostfächern (Erstellen, Suchen, Berechtigungen bearbeiten).
- **Kontakte**: Suchen und Bearbeiten von Mail-Kontakten.

### ⚙️ Mailflow
- **Transportregeln**: Erstellen, Anzeigen, Aktivieren/Deaktivieren und Exportieren/Importieren von Mailflow-Regeln.
- **Posteingangsregeln**: Verwaltung von Posteingangsregeln für einzelne Benutzerpostfächer.
- **Nachrichtenverfolgung**: Detaillierte Suche und Analyse von E-Mail-Zustellungen.
- **Automatische Antworten**: Abwesenheitsnotizen für einzelne oder mehrere Benutzer (Masseneinrichtung), Platzhalter `{StartDate}`/`{EndDate}`, Zeilenumbrüche werden übernommen.

### 🛡️ Sicherheit & Compliance
- **Microsoft Defender (ATP)**: Verwaltung von Anti-Phishing-, sicheren Anlagen- und sicheren Links-Richtlinien.
- **Quarantäne**: Anzeigen, Freigeben und Löschen von Nachrichten in Quarantäne.
- **Mobile Device Management (MDM)**: Verwaltung von Geräterichtlinien und Geräten in Quarantäne.
- **DLP & Compliance**: DLP-Richtlinien und -Regeln, Aufbewahrungsrichtlinien und Vertraulichkeitsbezeichnungen anzeigen und exportieren; Modus einer DLP-Richtlinie ändern (benötigt „Compliance verbinden“).
- **eDiscovery & Legal Hold**: eDiscovery-Fälle anzeigen und anlegen (inkl. Aufbewahrungen je Fall); Legal Hold für Postfächer suchen, aktivieren, entfernen und exportieren.

### 🔧 Systemkonfiguration
- **Regionaleinstellungen**: Anpassen von Sprache, Zeitzone sowie Datums- und Zeitformaten für Postfächer.
- **Mail-Routing (Cross-Premises)**: Anzeigen von Mail-Connectors, akzeptierten und Remote-Domänen.
- **Hybrid Exchange**: Hybrid-Status (lokale Organisation, Organisationsbeziehungen, IntraOrganization-Connectors, Connectors, Migrationsendpunkte) und Verbund-Vertrauensstellung prüfen und exportieren; Link zum Hybrid Configuration Wizard.
- **Multi-Forest**: Empfänger je Domäne und Herkunft (AD-synchronisiert/Cloud) suchen und exportieren; Microsoft-Entra-Connect-Synchronisation starten/stoppen (auf dem Entra-Connect-Server mit Modul *ADSync*).

### 📈 Monitoring & Support
- **Health Check**: Umfassende Überprüfung des Exchange Online-Dienststatus, der Konnektivität und wichtiger Konfigurationen.
- **Troubleshooting**: Ausführen von Diagnosen für Postfächer, Abrufen von Drosselungsinformationen (Throttling) und Audit-Logs.

## Voraussetzungen

- **Windows** mit **Windows PowerShell 5.1** oder **PowerShell 7.x** (WPF-Oberfläche, STA-Modus – wird bei Bedarf automatisch neu gestartet)
- **ExchangeOnlineManagement-Modul** ab Version 3.0.0, **empfohlen ab 3.7.0** (für `Get-MessageTraceV2` / `Get-MessageTraceDetailV2` in der Nachrichtenverfolgung). Das Skript prüft beim Start, ob das Modul installiert ist.
- **Exchange-Online-Berechtigungen** passend zu den genutzten Funktionen (Prinzip der minimalen Rechte, z. B. *Recipient Management*, *View-Only Organization Management*, *Organization Management*).
- Für Compliance-Funktionen (DLP, Aufbewahrung, Vertraulichkeitsbezeichnungen, eDiscovery-Fälle) zusätzlich eine Verbindung über `Connect-IPPSSession` (Security & Compliance PowerShell) – in der GUI per Schaltfläche **„Compliance verbinden“** nach der Exchange-Online-Anmeldung.
- Optional: Modul **ImportExcel** (`Install-Module ImportExcel -Scope CurrentUser`) für den XLSX-Export der Berichte; ohne das Modul wird eine Excel-kompatible CSV erstellt.
- **Keine lokalen Administratorrechte erforderlich** – nur für eine optionale, automatische Installation von PowerShell 7 werden ggf. erhöhte Rechte durch den Installer angefordert.
- **Internetverbindung** für die Verbindung zu Exchange Online.

## Anwendung

1.  **Herunterladen**: Klonen Sie das Repository oder laden Sie es als ZIP herunter. Benötigt wird der **vollständige Ordner `src/`** (Launcher `easyEXO.ps1`, `Modules/` und `GUI/`). Bei ZIP-Downloads ggf. vorher `Get-ChildItem .\src -Recurse | Unblock-File` ausführen.
2.  **Signatur / Ausführungsrichtlinie**: Releases werden vom Maintainer mit dem öffentlichen Code-Signing-Zertifikat von https://github.com/PS-easyIT/PowerShell_Certificate signiert – das gilt für den Launcher **und alle Moduldateien** unter `src/Modules/`. Importieren Sie dieses Zertifikat, wenn Ihre Ausführungsrichtlinie (`AllSigned`/`RemoteSigned`) signierte Skripte verlangt. Der Quellstand im Repository ist nach Änderungen unsigniert – siehe [SECURITY.md](SECURITY.md).
3.  **Ausführen**: Starten Sie das Skript in einer PowerShell-Konsole:
    ```powershell
    .\src\easyEXO.ps1
    ```
4.  **Verbinden**: Klicken Sie auf den Button „Mit Exchange Online verbinden“. Nach erfolgreicher Authentifizierung werden die GUI-Elemente aktiviert. Ein erneuter Klick trennt die Verbindung. Für DLP-/Aufbewahrungsfunktionen zusätzlich „Compliance verbinden“ klicken.
5.  **Verwalten**: Navigieren Sie über die linke Navigationsleiste durch die Bereiche. Ändernde und löschende Aktionen werden vor der Ausführung bestätigt; Organisationseinstellungen zeigen vor dem Speichern eine Vorschau der Änderungen.
6.  **Lange Abfragen**: Während Berichte, Gruppen- oder Dashboard-Abfragen laufen, zeigt ein Overlay den Fortschritt an. Über „Abbrechen“ (oder Schließen des Fensters) wird der Vorgang beendet; bereits geladene Teilergebnisse bleiben sichtbar.

## Konfiguration

Das Skript speichert grundlegende Einstellungen in der Windows-Registrierung unter:
`HKCU:\Software\easyIT\easyEXO`

Hier kann z. B. der **Debug-Modus** aktiviert werden, um detailliertere Log-Ausgaben zu erhalten.

## Logging

Alle Aktionen, Fehler und wichtige Informationen werden in einer Log-Datei im Unterordner `Logs` neben dem Launcher gespeichert (`src/Logs/ExchangeTool.log`, UTF-8). Die Logs enthalten u. a. Benutzernamen/E-Mail-Adressen (personenbezogene Daten) – bitte entsprechend schützen und nicht einchecken (`Logs/` ist in `.gitignore` ausgeschlossen).

Automatisch gespeicherte Berichte (Option „Automatisch als CSV speichern“) liegen im Unterordner `Reports` neben dem Launcher bzw. – ohne Schreibrechte dort – unter `Dokumente\easyEXO\Reports`. Auch sie enthalten personenbezogene Daten (`Reports/` ist in `.gitignore` ausgeschlossen).

## Projektstruktur

```text
.
├── src/
│   ├── easyEXO.ps1              # Launcher / Einstiegspunkt (startet die GUI)
│   ├── GUI/
│   │   ├── MainWindow.xaml      # Layout des Hauptfensters
│   │   └── Theme.xaml           # Farben und Styles (modernes Design)
│   └── Modules/
│       ├── Core/                # Logging, Konfiguration (Registry), Umgebung, Hilfsfunktionen
│       ├── UI/                  # Fenster/XAML-Laden, Steuerelemente, Dialoge, Navigation, Arbeitsanzeige (Busy.ps1)
│       ├── Exchange/            # Verbindung zu Exchange Online und Security & Compliance (IPPS)
│       └── Features/            # Fachmodule je Bereich (Postfächer, Gruppen, Mail-Flow, Sicherheit,
│                                #   Compliance/eDiscovery, Hybrid, Multi-Forest, Berichte …)
├── docs/
│   ├── AUDIT.md                 # Audit-Bericht (Sicherheit, Performance, Funktionen, GUI …)
│   └── screenshots/             # Screenshots der aktuellen Version
├── .github/
│   ├── workflows/               # CI (PSScriptAnalyzer, Codacy)
│   └── PULL_REQUEST_TEMPLATE.md
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── LICENSE
├── README.md
└── SECURITY.md
```

Ältere Skriptversionen sind nicht mehr im Repository enthalten; sie bleiben über die Git-Historie verfügbar.

## Weitere Dokumentation

- [CHANGELOG.md](CHANGELOG.md) – Änderungen je Version
- [docs/AUDIT.md](docs/AUDIT.md) – Audit-Bericht inkl. behobener und offener Punkte
- [SECURITY.md](SECURITY.md) – Sicherheitsrichtlinie und Meldung von Schwachstellen
- [CONTRIBUTING.md](CONTRIBUTING.md) – Mitwirken, Prüfungen, Release-Ablauf
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) – Verhaltenskodex

## Lizenz

MIT – siehe [LICENSE](LICENSE).
