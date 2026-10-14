# Mitwirken (Contributing)

Vielen Dank für Ihr Interesse an **easyEXO**! Beiträge in Form von Issues, Verbesserungsvorschlägen und Pull Requests sind willkommen.

## Repository-Struktur

```
.
├── .github/                 # Workflows (PSScriptAnalyzer, Codacy) und PR-Vorlage
├── docs/
│   ├── AUDIT.md             # Ergebnisse des Code-Audits
│   └── screenshots/         # Ablage für aktuelle Screenshots (README)
├── src/
│   └── easyEXO.ps1          # Hauptskript inkl. eingebetteter WPF-XAML-GUI
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── LICENSE
├── README.md
└── SECURITY.md
```

> Alte Skriptversionen werden **nicht** mehr als Dateikopien im Repository abgelegt. Die Historie ist über Git-Tags,
> Releases und das [CHANGELOG](CHANGELOG.md) nachvollziehbar.

## Ablauf

1. Forken Sie das Repository und erstellen Sie einen Feature-Branch (`feature/<kurzbeschreibung>` bzw. `fix/<kurzbeschreibung>`).
2. Nehmen Sie Ihre Änderungen in `src/easyEXO.ps1` vor.
3. Prüfen Sie Ihre Änderungen lokal:
   ```powershell
   # Syntaxprüfung
   $tokens = $null; $errors = $null
   [System.Management.Automation.Language.Parser]::ParseFile("$PWD\src\easyEXO.ps1", [ref]$tokens, [ref]$errors) | Out-Null
   $errors

   # Statische Analyse
   Install-Module PSScriptAnalyzer -Scope CurrentUser
   Invoke-ScriptAnalyzer -Path .\src\easyEXO.ps1 -Severity Error,Warning
   ```
4. Erhöhen Sie die Versionsnummer in `$script:AppVersion` (`src/easyEXO.ps1`) gemäß [Semantic Versioning](https://semver.org/lang/de/).
5. Tragen Sie Ihre Änderungen in der [CHANGELOG.md](CHANGELOG.md) direkt unter dieser **konkreten Versionsnummer mit Datum** ein
   (z. B. `## [0.1.3] - JJJJ-MM-TT`). Abschnitte ohne Versionsnummer werden nicht geführt.
6. Erstellen Sie einen Pull Request gegen `main` und füllen Sie die PR-Vorlage aus.

## Richtlinien

- **Sprache:** Benutzeroberfläche, Log-Meldungen und Dokumentation sind auf Deutsch.
- **Keine Geheimnisse** (Passwörter, Tokens, Tenant-IDs) in Code, Logs oder Screenshots.
- **Destruktive Aktionen** (Entfernen, Löschen, Freigeben) müssen vor der Ausführung eine Bestätigung anfordern.
- **CSV-Exporte** immer über `ConvertTo-SafeCsvObject` leiten (Schutz vor Formel-Injection).
- **Benutzereingaben** in OPATH-Filtern (`-Filter`) immer mit `ConvertTo-OPathValue` maskieren.
- **Exchange-Cmdlets:** Bevorzugt die REST-basierten `Get-EXO*`-Cmdlets bzw. aktuelle Cmdlets (z. B. `Get-MessageTraceV2`) verwenden.
- **Signatur:** Nach jeder Änderung ist die Authenticode-Signatur ungültig. Releases werden vom Maintainer neu signiert.
