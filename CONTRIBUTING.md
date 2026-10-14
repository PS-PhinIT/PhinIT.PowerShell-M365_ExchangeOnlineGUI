# Mitwirken (Contributing)

Vielen Dank für Ihr Interesse an **easyEXO**! Beiträge in Form von Issues, Verbesserungsvorschlägen und Pull Requests sind willkommen.

## Repository-Struktur

```
.
├── .github/
│   ├── ISSUE_TEMPLATE/      # Vorlagen für Fehlerberichte und Funktionswünsche
│   ├── workflows/           # CI (PSScriptAnalyzer, Codacy)
│   └── PULL_REQUEST_TEMPLATE.md
├── docs/
│   ├── AUDIT.md             # Ergebnisse des Code-Audits
│   └── screenshots/         # Nur aktuelle Screenshots, Dateiname ohne Version (siehe README dort)
├── src/
│   ├── easyEXO.ps1          # Launcher: Umgebung, Module laden, Fenster, zentrale Event-Handler
│   ├── GUI/
│   │   ├── MainWindow.xaml  # Layout des Hauptfensters (Platzhalter <!-- @THEME@ --> für das Theme)
│   │   └── Theme.xaml       # Farben und Styles (einzige Stelle für Farben)
│   └── Modules/
│       ├── Core/            # Logging, Konfiguration, Umgebung, Hilfsfunktionen
│       ├── UI/              # Fenster/XAML, Steuerelemente, Dialoge, Navigation, Arbeitsanzeige (Busy.ps1)
│       ├── Exchange/        # Verbindung zu Exchange Online und Security & Compliance (IPPS)
│       └── Features/        # Fachmodule je Bereich
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── LICENSE
├── README.md
└── SECURITY.md
```

> Alte Skriptversionen und veraltete Screenshots werden **nicht** im Repository abgelegt. Dateinamen enthalten keine
> Versionsnummer (der Launcher heißt immer `src/easyEXO.ps1`); die Version steht ausschließlich in `$script:AppVersion`,
> in der README (Badge) und im [CHANGELOG](CHANGELOG.md). Die Historie ist über Git, Releases und das CHANGELOG
> nachvollziehbar. Temporäre Dateien (Analyse-Ausgaben, Hilfsskripte) gehören nicht ins Repository.

## Ablauf

1. Forken Sie das Repository und erstellen Sie einen Feature-Branch (`feature/<kurzbeschreibung>` bzw. `fix/<kurzbeschreibung>`).
2. Nehmen Sie Ihre Änderungen in der passenden Datei vor (Fachlogik in `src/Modules/Features/<Bereich>.ps1`,
   Layout in `src/GUI/MainWindow.xaml`, Farben/Styles in `src/GUI/Theme.xaml`).
3. Prüfen Sie Ihre Änderungen lokal:
   ```powershell
   # Syntaxprüfung aller Skriptdateien
   Get-ChildItem .\src -Recurse -Filter *.ps1 | ForEach-Object {
       $tokens = $null; $errors = $null
       [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
       $errors
   }

   # XAML-Dateien auf Wohlgeformtheit prüfen
   Get-ChildItem .\src\GUI -Filter *.xaml | ForEach-Object { [xml](Get-Content $_.FullName -Raw -Encoding UTF8) | Out-Null }

   # Statische Analyse
   Install-Module PSScriptAnalyzer -Scope CurrentUser
   Invoke-ScriptAnalyzer -Path .\src -Recurse -Severity Error,Warning
   ```
4. Erhöhen Sie die Versionsnummer in `$script:AppVersion` (`src/easyEXO.ps1`) gemäß [Semantic Versioning](https://semver.org/lang/de/).
5. Tragen Sie Ihre Änderungen in der [CHANGELOG.md](CHANGELOG.md) direkt unter dieser **konkreten Versionsnummer mit Datum** ein
   (z. B. `## [0.5.1] - JJJJ-MM-TT`), gegliedert nach *Hinzugefügt*, *Geändert*, *Behoben*, *Sicherheit*, *Entfernt*.
   Abschnitte ohne Versionsnummer (z. B. „Unreleased“) werden nicht geführt. Badge in der README anpassen und in
   `SECURITY.md` die unterstützte Version prüfen.
6. Erstellen Sie einen Pull Request gegen `main` und füllen Sie die PR-Vorlage aus.

## Richtlinien

- **Sprache:** Benutzeroberfläche, Log-Meldungen und Dokumentation sind auf Deutsch.
- **Module:** Neue Funktionen gehören in die thematisch passende Datei unter `src/Modules/`. Neue Moduldateien müssen
  in `$script:ModuleFiles` (`src/easyEXO.ps1`) eingetragen werden. Module werden per Dot-Sourcing geladen und teilen
  sich den Script-Scope – Pfade daher über `$script:AppRoot` bilden, nicht über `$PSScriptRoot`.
- **Kodierung:** `.ps1`-Dateien als UTF-8 **mit BOM** speichern (Umlaute unter Windows PowerShell 5.1).
- **GUI/Design:** Keine fest kodierten Farben im XAML oder Code; Farben und Styles ausschließlich in `src/GUI/Theme.xaml`
  definieren und per `StaticResource` verwenden (`SecondaryButton`, `SuccessButton`, `DangerButton`, `WarningButton`,
  `NavButton`, `*Brush` …). Statusmeldungen über `Update-StatusBar -Message … -Type Info|Success|Warning|Error`
  (Farben aus `Status*Brush`). Eigene Fenster/Dialoge erben die Ressourcen des Hauptfensters nicht – Styles dort per
  `$script:Form.TryFindResource('<Key>')` zuweisen oder `Show-InputDialog` verwenden.
- **XAML:** Keine Event-Attribute (`Click="…"`, `SelectionChanged="…"`) – Ereignisse werden im Code registriert.
  Daten aus Exchange (Namen, Betreffzeilen …) nie in XAML-Zeichenketten einsetzen, sondern nach dem Laden über
  Eigenschaften (`.Text`, `.ItemsSource`) zuweisen. Spaltenbindungen (`Binding="{Binding …}"`) müssen den
  tatsächlichen Eigenschaftsnamen der Cmdlet-Ausgabe entsprechen.
- **Exchange-Parameter** vor der Verwendung mit der aktuellen Cmdlet-Dokumentation (learn.microsoft.com) abgleichen;
  Ergebnisse von Cmdlets und Hilfsfunktionen mit `@(…)` umschließen, damit einzelne oder leere Ergebnisse als Liste
  behandelt werden. Erfolgsmeldungen erst nach erfolgreichem Aufruf (`-ErrorAction Stop`) ausgeben.
- **Lange Exchange-Abfragen** möglichst mit `-ResultSize`/`-PropertySets` begrenzen und nicht in Schleifen pro Objekt ausführen.
  Listenabfragen ohne Identität immer mit `-ResultSize Unlimited` (Standard sind nur 1000 Einträge).
- **Arbeitsanzeige:** Länger laufende Vorgänge in `Start-UIBusy -Message … -Cancelable` / `Stop-UIBusy` (im `finally`)
  einschließen und Pipelines mit `Step-UIProgress` bzw. Schleifen mit `Update-UIBusy`/`Assert-UINotCancelled` versehen
  (`src/Modules/UI/Busy.ps1`). Die Exchange-Online-Sitzung ist an den Runspace der GUI gebunden – Abfragen daher nicht
  in Hintergrund-Runspaces auslagern.
- **Click-Handler** über `Register-EventHandler` registrieren (zentraler Verteiler mit Fehlerbehandlung und Sperre während
  laufender Vorgänge) statt direkt per `Add_Click`. In `Initialize-*Tab`-Funktionen den Rückgabewert verwerfen
  (`$null = Register-EventHandler …`), damit die Funktion nur `$true`/`$false` zurückgibt.
- **Neue Bereiche (Tabs):** Die Initialisierungsfunktion in `$script:TabInitializers` (`src/Modules/UI/Navigation.ps1`)
  eintragen; Hilfe-Links mit `Register-HelpLink` und einem Thema in `Show-HelpDialog` (`src/Modules/UI/Dialogs.ps1`) anbinden.
- **Compliance-Cmdlets** (DLP, Aufbewahrung, Bezeichnungen, eDiscovery) vorher mit `Test-ComplianceConnection` prüfen und auf
  „Compliance verbinden“ hinweisen. Neue Compliance-Cmdlets in `$script:ComplianceCommandNames`
  (`src/Modules/Exchange/Connection.ps1`) eintragen – nur diese werden von `Connect-IPPSSession` importiert.
- **Externe Links** nur über `Open-ExternalUrl` öffnen (nur `https` und Hosts aus `$script:AllowedExternalUrlHosts`).
- **Keine Geheimnisse** (Passwörter, Tokens, Tenant-IDs) in Code, Logs oder Screenshots.
- **Destruktive Aktionen** (Entfernen, Löschen, Freigeben) müssen vor der Ausführung eine Bestätigung anfordern.
- **CSV-Exporte** immer über `ConvertTo-SafeCsvObject` leiten (Schutz vor Formel-Injection).
- **Benutzereingaben** in OPATH-Filtern (`-Filter`) immer mit `ConvertTo-OPathValue` maskieren.
- **Exchange-Cmdlets:** Bevorzugt die REST-basierten `Get-EXO*`-Cmdlets bzw. aktuelle Cmdlets (z. B. `Get-MessageTraceV2`) verwenden.
- **Signatur:** Nach jeder Änderung ist die Authenticode-Signatur ungültig. Releases werden vom Maintainer neu signiert
  (Launcher **und** alle Dateien unter `src/Modules/`).
