# Sicherheitsrichtlinie (Security Policy)

## Unterstützte Versionen

Sicherheitsupdates werden ausschließlich für die jeweils aktuelle Version auf dem `main`-Branch bereitgestellt.
Ältere Skriptstände (`easyEXO_V0.0.x`, `easyEXO_V0.1.1`) werden nicht mehr gepflegt.

| Version | Unterstützt |
|---------|-------------|
| 0.4.x   | ✅          |
| < 0.4.0 | ❌          |

## Sicherheitslücke melden

Bitte melden Sie Sicherheitslücken **nicht** über öffentliche Issues.

1. Nutzen Sie die Funktion **„Report a vulnerability“** (GitHub Private Vulnerability Reporting) im Reiter *Security* dieses Repositories, oder
2. kontaktieren Sie den Maintainer direkt über das GitHub-Profil.

Bitte beschreiben Sie:

- betroffene Version / Commit,
- Schritte zur Reproduktion,
- mögliche Auswirkungen,
- ggf. einen Vorschlag zur Behebung.

Sie erhalten in der Regel innerhalb von 7 Tagen eine erste Rückmeldung.

## Hinweise zum sicheren Betrieb

- **Code-Signatur prüfen:** Releases werden mit dem öffentlichen Code-Signing-Zertifikat von
  <https://github.com/PS-easyIT/PowerShell_Certificate> signiert. Prüfen Sie die Signatur vor der Ausführung mit
  `Get-ChildItem .\src -Recurse -Filter *.ps1 | Get-AuthenticodeSignature` (Launcher und alle Moduldateien). Unsignierte Entwicklungsstände (z. B. direkt aus `main`) sollten
  nur nach eigener Prüfung ausgeführt werden.
- **Least Privilege:** Für die meisten Funktionen genügen Exchange-Online-Rollen wie *Exchange Administrator* oder
  *Recipient Management*. Lokale Windows-Administratorrechte sind für die Verbindung zu Exchange Online **nicht** erforderlich.
- **Integrität der Module:** Der Launcher lädt ausschließlich die in `$script:ModuleFiles` festgelegten Dateien aus
  `src\Modules\`. Schützen Sie den Programmordner vor Schreibzugriff durch Dritte.
- **Logs:** Die Logdateien unter `src\Logs\` können Benutzer-/Postfachnamen (personenbezogene Daten) enthalten.
  Behandeln Sie diese entsprechend Ihren Datenschutzvorgaben und löschen Sie sie regelmäßig.
- **Exporte:** CSV/HTML-Exporte enthalten Mandantendaten – speichern Sie diese nur an geschützten Orten.
