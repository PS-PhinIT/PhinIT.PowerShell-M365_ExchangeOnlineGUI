# =====================================================================
# easyEXO - Modul: Umgebungsprüfung (PowerShell 7, Module, Internet, Voraussetzungen)
# Datei: src/Modules/Core/Environment.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

function Test-PowerShell7AndAdminRights {
    [CmdletBinding()]
    param()

    try {
        $psVersion = $PSVersionTable.PSVersion
        $isPSCore = $psVersion.Major -ge 7
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        # Pfad des Startskripts (wird im Launcher gesetzt; $PSCommandPath wäre hier der Pfad der Moduldatei)
        $scriptPath = $script:AppScriptPath
        $currentPSEnginePath = (Get-Process -Id $PID).Path # Pfad zur aktuellen powershell.exe oder pwsh.exe

        Write-LogEntry "Aktueller Status: PowerShell Version $($psVersion.ToString()), Läuft als Administrator: $isAdmin"

        # Lokale Administratorrechte sind für Exchange Online NICHT erforderlich (Least Privilege).
        # Es wird daher nur noch PowerShell 7 empfohlen; ein erzwungener Neustart mit erhöhten Rechten entfällt.
        if ($isPSCore) {
            Write-LogEntry "Ausführungsbedingungen erfüllt (PowerShell 7+)."
            return $true
        }

        # PowerShell 7 Pfad suchen (nur wenn nicht bereits PS7+ und $ps7ExecutablePath noch nicht gesetzt)
        $ps7ExecutablePath = $null
        if (-not $isPSCore) {
            $ps7SearchPaths = @(
                Join-Path $env:ProgramFiles "PowerShell\7\pwsh.exe"
                Join-Path $env:ProgramFiles "(x86)\PowerShell\7\pwsh.exe"
                Join-Path $env:LOCALAPPDATA "Programs\PowerShell\7\pwsh.exe"
                # Versuche, pwsh.exe aus dem PATH zu finden, das nicht die Windows PowerShell ist
                (Get-Command pwsh -ErrorAction SilentlyContinue | Where-Object { $_.Source -and $_.Source -notlike "*\System32\WindowsPowerShell\*" -and $_.Source -notlike "*\SysWOW64\WindowsPowerShell\*" } | Select-Object -ExpandProperty Source -First 1)
            )
            $ps7ExecutablePath = $ps7SearchPaths | Where-Object { $_ -ne $null -and (Test-Path $_ -PathType Leaf) } | Select-Object -First 1
            
            if ($ps7ExecutablePath) {
                Write-LogEntry "PowerShell 7 gefunden unter: $ps7ExecutablePath"
            } else {
                Write-LogEntry "PowerShell 7 wurde auf dem System nicht gefunden."
            }
        }

        # Bedingungen für Neustart oder Installation
        $needsAdminPrivileges = (-not $isAdmin)
        $needsPS7Upgrade = (-not $isPSCore -and $null -ne $ps7ExecutablePath) # PS7 ist da, aber wir nutzen es nicht
        $needsPS7Installation = (-not $isPSCore -and $null -eq $ps7ExecutablePath) # PS7 ist nicht da und wir nutzen es nicht

        # Fall 1: PowerShell 7 muss installiert werden
        if ($needsPS7Installation) {
            $installMsg = "PowerShell 7 wird für dieses Skript empfohlen, wurde aber nicht gefunden."
            $installMsg += " Für die Installation sind einmalig Administratorrechte erforderlich (UAC-Abfrage)."
            $installMsg += " Möchten Sie PowerShell 7 jetzt installieren?"
            
            $userChoiceInstall = [System.Windows.MessageBox]::Show($installMsg, "PowerShell 7 Installation", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
            
            if ($userChoiceInstall -eq [System.Windows.MessageBoxResult]::No) {
                Write-LogEntry "Benutzer hat die Installation von PowerShell 7 abgelehnt."
                [System.Windows.MessageBox]::Show("Ohne PowerShell 7 können einige Funktionen des Skripts eingeschränkt sein.", "Hinweis", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                return $false 
            }

            Write-LogEntry "Benutzer hat der Installation von PowerShell 7 zugestimmt."
            $useWinget = $false
            try {
                $null = winget --version # Einfacher Test, ob winget existiert und funktioniert
                if ($LASTEXITCODE -eq 0) { $useWinget = $true }
            } catch { $useWinget = $false }

            if ($useWinget) {
                Write-LogEntry "Versuche PowerShell 7 Installation via winget."
                # Winget benötigt Admin für systemweite Installation. Start-Process mit RunAs für winget selbst.
                try {
                    Start-Process -FilePath "winget" -ArgumentList "install --id Microsoft.PowerShell --exact --source winget --accept-package-agreements --accept-source-agreements" -Verb RunAs -Wait
                    Write-LogEntry "Winget-Installation von PowerShell 7 abgeschlossen (oder versucht)."
                } catch {
                     Write-LogEntry "Fehler beim Starten der Winget-Installation als Admin: $($_.Exception.Message)"
                    [System.Windows.MessageBox]::Show("Fehler beim Starten der Winget-Installation für PowerShell 7: $($_.Exception.Message)`nVersuchen Sie, die Installation manuell als Administrator durchzuführen.", "Installationsfehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                    return $false
                }
            } else {
                Write-LogEntry "Winget nicht verfügbar. Versuche PowerShell 7 Installation via MSI."
                $installerUrl = "https://aka.ms/install-powershell-msi" # Offizieller Microsoft-Link auf das aktuelle stabile MSI (x64)
                # Eindeutiges Verzeichnis, um ein Austauschen der Datei zwischen Download und Installation zu erschweren
                $installerDir = Join-Path $env:TEMP ("easyEXO_PS7_" + [guid]::NewGuid().ToString("N"))
                $installerPath = Join-Path $installerDir "PowerShell-win-x64.msi"
                try {
                    New-Item -ItemType Directory -Path $installerDir -Force | Out-Null
                    Write-LogEntry "Downloade PowerShell 7 MSI von $installerUrl"
                    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
                    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing

                    # Integritätsprüfung: Das MSI muss gültig von Microsoft signiert sein
                    $signature = Get-AuthenticodeSignature -FilePath $installerPath
                    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or
                        $null -eq $signature.SignerCertificate -or
                        $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
                        throw "Die Signatur des heruntergeladenen Installationspakets ist ungültig (Status: $($signature.Status)). Installation abgebrochen."
                    }
                    Write-LogEntry "PowerShell 7 MSI heruntergeladen und Signatur geprüft ($($signature.SignerCertificate.Subject)). Starte Installation."
                    # MSI Installation benötigt Admin. Start-Process mit RunAs. (Kein ENABLE_PSREMOTING - WinRM wird nicht aktiviert)
                    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$installerPath`" /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 REGISTER_MANIFEST=1" -Verb RunAs -Wait
                    Write-LogEntry "MSI-Installation von PowerShell 7 abgeschlossen (oder versucht)."
                } catch {
                    Write-LogEntry "FEHLER bei MSI Download/Installation: $($_.Exception.Message)"
                    [System.Windows.MessageBox]::Show("Fehler beim Herunterladen oder Installieren von PowerShell 7 via MSI: $($_.Exception.Message)`nVersuchen Sie, die Installation manuell als Administrator durchzuführen.", "Installationsfehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                    return $false
                } finally {
                    if (Test-Path $installerDir) { Remove-Item -Path $installerDir -Recurse -Force -ErrorAction SilentlyContinue }
                }
            }
            
            # Pfad nach Installation erneut suchen
            $ps7SearchPathsAfterInstall = @(
                Join-Path $env:ProgramFiles "PowerShell\7\pwsh.exe"
                Join-Path $env:ProgramFiles "(x86)\PowerShell\7\pwsh.exe"
                Join-Path $env:LOCALAPPDATA "Programs\PowerShell\7\pwsh.exe"
                (Get-Command pwsh -ErrorAction SilentlyContinue | Where-Object { $_.Source -and $_.Source -notlike "*\System32\WindowsPowerShell\*" -and $_.Source -notlike "*\SysWOW64\WindowsPowerShell\*" } | Select-Object -ExpandProperty Source -First 1)
            )
            $ps7ExecutablePath = $ps7SearchPathsAfterInstall | Where-Object { $_ -ne $null -and (Test-Path $_ -PathType Leaf) } | Select-Object -First 1

            if (-not $ps7ExecutablePath) {
                Write-LogEntry "PowerShell 7 konnte nach der Installation nicht gefunden werden."
                [System.Windows.MessageBox]::Show("PowerShell 7 wurde installiert, konnte aber nicht automatisch gefunden werden. Bitte starten Sie das Skript manuell mit PowerShell 7 (und ggf. Administratorrechten).", "Installationshinweis", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                return $false
            }
            Write-LogEntry "PowerShell 7 nach Installation gefunden unter: $ps7ExecutablePath"
            $needsPS7Upgrade = $true # Da wir gerade installiert haben, wollen wir es auch nutzen.
            $needsPS7Installation = $false # Nicht mehr relevant
        }

        # Administratorrechte werden für den Betrieb nicht benötigt - nur ein PS7-Upgrade löst einen Neustart aus
        $needsAdminPrivileges = $false

        # Fall 2: Neustart erforderlich (PS7-Upgrade)
        # Die Bedingung ($needsAdminPrivileges -or $needsPS7Upgrade) deckt folgende Fälle ab:
        # 1. PowerShell < 7 ohne Admin-Rechte: $needsAdminPrivileges ist true, $needsPS7Upgrade ist true (falls PS7 gefunden). Neustart mit PS7 und Admin.
        # 2. PowerShell < 7 mit Admin-Rechten: $needsAdminPrivileges ist false, $needsPS7Upgrade ist true (falls PS7 gefunden). Neustart mit PS7 und Admin.
        # 3. PowerShell 7 ohne Admin-Rechte: $needsAdminPrivileges ist true, $needsPS7Upgrade ist false. Neustart mit aktueller PS7 und Admin. (Dies erfüllt die Anforderung)
        if ($needsAdminPrivileges -or $needsPS7Upgrade) {
            $restartMsgParts = @()
            $targetExecutableForRestart = $currentPSEnginePath # Standard: aktuelle PS-Engine

            if ($needsPS7Upgrade) { # PS7 ist verfügbar (oder gerade installiert) und wir sind nicht in PS7
                $restartMsgParts += "PowerShell 7"
                $targetExecutableForRestart = $ps7ExecutablePath
            }
            if ($needsAdminPrivileges) {
                $restartMsgParts += "Administratorrechten"
            }
            
            $reasonForRestart = $restartMsgParts -join " und "
            $currentContextDesc = "Sie verwenden derzeit PowerShell $($psVersion.Major).$($psVersion.Minor)"
            if ($isAdmin) { $currentContextDesc += " mit Administratorrechten." } else { $currentContextDesc += " ohne Administratorrechte."}

            $restartQueryMsg = "$currentContextDesc Für optimale Funktionalität wird ein Neustart mit $reasonForRestart empfohlen."
            if ($needsPS7Upgrade -and $ps7ExecutablePath) {
                 $restartQueryMsg += " PowerShell 7 ist unter '$ps7ExecutablePath' verfügbar."
            }
            $restartQueryMsg += " Möchten Sie das Skript jetzt neu starten?"

            $userChoiceRestart = [System.Windows.MessageBox]::Show($restartQueryMsg, "Neustart empfohlen", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)

            if ($userChoiceRestart -eq [System.Windows.MessageBoxResult]::Yes) {
                Write-LogEntry "Benutzer stimmt Neustart zu. Ziel-Executable: $targetExecutableForRestart"
                if ([string]::IsNullOrWhiteSpace($scriptPath)) {
                    throw "Der Skriptpfad konnte nicht ermittelt werden. Bitte das Skript manuell mit PowerShell 7 starten."
                }
                $argumentsForRestart = "-NoProfile -STA -File `"$scriptPath`""
                try {
                    Start-Process -FilePath $targetExecutableForRestart -ArgumentList $argumentsForRestart
                    Write-LogEntry "Neustart-Prozess wurde initiiert."
                    exit # Aktuelles Skript beenden, da der neue Prozess gestartet wird
                } catch {
                    $errMsg = $_.Exception.Message
                    Write-LogEntry "FEHLER beim Versuch, das Skript neu zu starten: $errMsg"
                    [System.Windows.MessageBox]::Show("Fehler beim Versuch, das Skript neu zu starten: $errMsg", "Neustartfehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                    return $false # Neustart ist fehlgeschlagen
                }
            } else {
                Write-LogEntry "Benutzer hat den empfohlenen Neustart abgelehnt."
                [System.Windows.MessageBox]::Show("Ohne PowerShell 7 können einige Funktionen des Skripts eingeschränkt sein.", "Hinweis", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                return $false 
            }
        }

        # Wenn wir hier ankommen, bedeutet das, dass entweder die Bedingungen initial nicht optimal waren
        # und der Benutzer die Korrekturmaßnahmen (Installation/Neustart) abgelehnt hat.
        Write-LogEntry "Die optimalen Ausführungsbedingungen wurden nicht erreicht oder vom Benutzer abgelehnt."
        return $false
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-LogEntry "Ein schwerwiegender Fehler ist in der Funktion Test-PowerShell7AndAdminRights aufgetreten: $errorMsg"
        Write-LogEntry "KRITISCHER FEHLER (Test-PowerShell7AndAdminRights): Ein interner Fehler ist bei der Überprüfung der Ausführungsumgebung aufgetreten: $errorMsg. Das Skript wird möglicherweise nicht korrekt funktionieren."
        return $false # Im Falle eines unerwarteten Fehlers in der Funktion selbst
    }
}

# -------------------------------------------------
# Abschnitt: Selbstdiagnose
# -------------------------------------------------
function Test-ModuleInstalled {
    param([string]$ModuleName)
    try {
        if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
            # Return false without throwing an error
            return $false
        }
        return $true
    } catch {
        # Log the error silently without Write-Error
        $errorMessage = $_.Exception.Message
        Log-Action "Fehler beim Prüfen des Moduls $ModuleName - $errorMessage"
        return $false
    }
}

function Test-InternetConnection {
    try {
        $ping = Test-Connection -ComputerName "www.google.com" -Count 1 -Quiet
        if (-not $ping) { throw "Keine Internetverbindung." }
        return $true
    } catch {
        Write-Error $_.Exception.Message
        return $false
    }
}

# Funktion zum Überprüfen der Voraussetzungen (Module)
function Check-Prerequisites {
    [CmdletBinding()]
    param()
    
    try {
        $missingModules = @()
        $requiredModules = @(
            @{Name = "ExchangeOnlineManagement"; MinVersion = "3.0.0"; Description = "Exchange Online Management"}
        )
        $allModulesInstalled = $true

        foreach ($moduleInfo in $requiredModules) {
            $moduleName = $moduleInfo.Name
            $minVersion = $moduleInfo.MinVersion
            $module = Get-Module -Name $moduleName -ListAvailable -ErrorAction SilentlyContinue
            if ($null -ne $module) {
                $latestVersion = ($module | Sort-Object Version -Descending | Select-Object -First 1).Version
                if ($null -ne $minVersion -and $latestVersion -lt [Version]$minVersion) {
                    $missingModules += $moduleInfo
                    $allModulesInstalled = $false
                }
            } else {
                $missingModules += $moduleInfo
                $allModulesInstalled = $false
            }
        }

        if (-not $allModulesInstalled) {
            $msg = "Es fehlen erforderliche PowerShell-Module:`n"
            foreach ($mod in $missingModules) {
                $msg += "- $($mod.Name) (mindestens Version $($mod.MinVersion)): $($mod.Description)`n"
            }
            [System.Windows.MessageBox]::Show(
                $msg,
                "Modul-Voraussetzungen fehlen",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            )
        }
        return $allModulesInstalled
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler bei der Überprüfung der Module: $errorMsg" -Type "Error"
        [System.Windows.MessageBox]::Show(
            "Fehler bei der Überprüfung der Module: $errorMsg",
            "Fehler",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
        return $false
    }
}
