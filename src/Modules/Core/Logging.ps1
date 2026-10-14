# =====================================================================
# easyEXO - Modul: Protokollierung (Log-Datei, Konsole, Debug)
# Datei: src/Modules/Core/Logging.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# -------------------------------------------------
# Grundlegende Logging-Funktionen
# Simple internal logging function to ensure logging works before the main Log-Action is defined
function Write-LogEntry {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    # Gleiche Datei wie Log-Action (Pfad aus den Einstellungen, siehe Initialize-Logging)
    $logFile = if (-not [string]::IsNullOrWhiteSpace($script:logFilePath)) { $script:logFilePath } else { Join-Path -Path (Join-Path -Path $script:AppRoot -ChildPath "Logs") -ChildPath "ExchangeTool.log" }
    $logFolder = Split-Path -Path $logFile -Parent
    if (-not (Test-Path $logFolder)) {
        New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    # Steuerzeichen (z. B. Zeilenumbrüche aus Benutzereingaben) entfernen, um Log-Injection zu verhindern
    $sanitizedMessage = $Message -replace '[\x00-\x1F\x7F]', ' '
    Add-Content -Path $logFile -Value "$timestamp - [$Type] $sanitizedMessage" -Encoding UTF8
}

# --------------------------------------------------------------
# Verbesserte Debug- und Logging-Funktionen
# --------------------------------------------------------------
function Log-Action {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message
    )
    
    try {
        # Steuerzeichen (z. B. Zeilenumbrüche) entfernen, um Log-Injection zu verhindern - Umlaute bleiben erhalten
        $sanitizedMessage = $Message -replace '[\x00-\x1F\x7F]', ' '
        
        # Zeitstempel erzeugen
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Logverzeichnis erstellen, falls nicht vorhanden
        $logFolder = Split-Path -Path $script:logFilePath -Parent
        if (-not (Test-Path $logFolder)) {
            New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
            Write-LogEntry  "Logverzeichnis wurde erstellt: $logFolder" -Type "Info" # Konsolenausgabe hiervon wird durch Write-Log gesteuert
        }
        
        # Log-Eintrag schreiben
        Add-Content -Path $script:logFilePath -Value "[$timestamp] $sanitizedMessage" -Encoding UTF8
        
        # Bei zu langer Logdatei (>10 MB) rotieren
        $logFile = Get-Item -Path $script:logFilePath -ErrorAction SilentlyContinue
        if ($logFile -and $logFile.Length -gt 10MB) {
            $backupLogPath = "$($script:logFilePath)_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
            Move-Item -Path $script:logFilePath -Destination $backupLogPath -Force
            Write-LogEntry  "Logdatei wurde rotiert: $backupLogPath" -Type "Info" # Konsolenausgabe hiervon wird durch Write-Log gesteuert
        }
    }
    catch {
        # Fallback für Fehler in der Log-Funktion
        try {
            $errorMsg = $_.Exception.Message -replace '[\x00-\x1F\x7F]', ' '
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $fallbackLogFile = Join-Path -Path "$script:AppRoot\Logs" -ChildPath "log_fallback.log"
            $fallbackLogFolder = Split-Path -Path $fallbackLogFile -Parent
            
            if (-not (Test-Path $fallbackLogFolder)) {
                New-Item -ItemType Directory -Path $fallbackLogFolder -Force | Out-Null
            }
            
            Add-Content -Path $fallbackLogFile -Value "[$timestamp] Fehler in Log-Action: $errorMsg" -Encoding UTF8
            Add-Content -Path $fallbackLogFile -Value "[$timestamp] Ursprüngliche Nachricht: $sanitizedMessage" -Encoding UTF8
        }
        catch {
            # Absoluter Fallback - ignoriere Fehler um Programmablauf nicht zu stören
        }
    }
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet("Info", "Warning", "Error", "Success", "Debug")]
        [string]$Type = "Info",

        [Parameter(Mandatory = $false)]
        [switch]$NoLog,

        [Parameter(Mandatory = $false)]
        [switch]$NoConsole
    )

    try {
        # Farbzuordnung für verschiedene Nachrichtentypen
        $colorMap = @{
            "Info"     = "White"
            "Warning"  = "Yellow"
            "Error"    = "Red"
            "Success"  = "Green"
            "Debug"    = "Cyan"
        }

        # Zeitstempel erzeugen
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Nachricht formatieren für Konsolenausgabe
        $formattedMessage = "[$timestamp] [$Type] $Message"

        # Ausgabe in Konsole, wenn nicht unterdrückt UND Debug-Modus aktiv ist
        if (-not $NoConsole -and $script:debugMode) {
            # Prüfen, ob die aktuelle Host-Umgebung Farben unterstützt oder der Parameter vorhanden ist.
            try {
                # Versuch mit Farbe
                Write-Host $formattedMessage -ForegroundColor $colorMap[$Type]
            }
            catch [System.Management.Automation.ParameterBindingException] {
                # Speziell den Parameter-Fehler abfangen
                if ($_.Exception.Message -like "*ForegroundColor*") {
                    # Fallback ohne Farbe, wenn -ForegroundColor nicht unterstützt wird
                    Write-Host $formattedMessage
                } else {
                    # Anderen Parameterfehler weiterwerfen (könnte im äußeren Catch landen)
                    throw
                }
            }
            catch {
                # Anderen Fehler beim Schreiben behandeln -> Fallback ohne Farbe
                 Write-Host $formattedMessage # Sicherer Fallback
            }
        }

        # Logging mit Log-Action, wenn nicht unterdrückt und Log-Pfad gesetzt ist.
        # Debug-Meldungen nur im Debug-Modus schreiben (sonst wird die Log-Datei bei jeder Statusänderung vergrößert).
        if (-not $NoLog -and $script:logFilePath -and ($Type -ne "Debug" -or $script:debugMode)) {
            try {
                Log-Action -Message "[$Type] $Message"
            }
            catch {
                if ($script:debugMode) {
                    # Sanitize die Fehlermeldung für die Konsolenausgabe
                    $logActionCallError = $($_.Exception.Message) -replace '[^\x20-\x7E\r\n]', '?'
                    Write-Host "Fehler beim Aufruf von Log-Action innerhalb von Write-Log: $logActionCallError" -ForegroundColor Red
                }
            }
        }
    }
    catch {
        # Fallback bei Fehlern innerhalb der Write-Log Funktion selbst (z.B. durch 'throw' oben oder andere unerwartete Fehler)
        try {
            $errorDetail = "Unbekannter Fehler in Write-Log"
            if ($_) { # Prüfen ob $_ (Fehlerobjekt) existiert
                 if ($_.Exception) { $errorDetail = $_.Exception.ToString() } # Komplette Exception für mehr Details
                 elseif ($_.Message) { $errorDetail = $_.Message }
                 else { $errorDetail = $_.ToString() }
            }
            # Sanitize für den Fall, dass die Fehlermeldung selbst problematische Zeichen enthält
            $sanitizedErrorDetail = $errorDetail -replace '[^\x20-\x7E\r\n]', '?'

            $errorMessage = "Kritischer Fehler in Write-Log Funktion: $sanitizedErrorDetail"

            # Direkter Fallback zur Ausgabe ohne Farbe auf der Konsole, nur wenn Debug-Modus aktiv ist
            if ($script:debugMode) {
                Write-Host $errorMessage -ForegroundColor Red
            }

            # Versuch, den Fehler mit Log-Action zu loggen, falls möglich und Log-Pfad vorhanden
            if ($script:logFilePath) {
                try {
                    # Log-Action kümmert sich um Zeitstempel und Fehlerbehandlung beim Schreiben.
                    Log-Action -Message $errorMessage
                }
                catch {
                    if ($script:debugMode) {
                        $criticalLogActionError = $($_.Exception.Message) -replace '[^\x20-\x7E\r\n]', '?'
                        Write-Host "Kritischer Fehler: Log-Action konnte den Fehler in Write-Log nicht protokollieren. Fehler beim Aufruf von Log-Action: $criticalLogActionError" -ForegroundColor Red
                    }
                }
            }
        }
        catch {
        }
    }
}

# Legt die Log-Datei fest: Verzeichnis aus den Einstellungen (Registry-Wert "LogPath", Dialog "Einstellungen"),
# sonst "Logs" neben dem Launcher. Ist das Verzeichnis nicht beschreibbar, wird der Standardordner verwendet.
function Initialize-Logging {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $logFileName = "ExchangeTool.log"
    $defaultLogDirectory = Join-Path -Path $script:AppRoot -ChildPath "Logs"
    $logDirectoryToUse = $defaultLogDirectory

    try {
        if ($null -ne $script:config -and
            $script:config.ContainsKey("Paths") -and
            ($null -ne $script:config["Paths"]) -and
            $script:config["Paths"].ContainsKey("LogPath") -and
            -not [string]::IsNullOrWhiteSpace($script:config["Paths"]["LogPath"])) {

            $configuredLogPathDir = [string]$script:config["Paths"]["LogPath"]

            # Relative Pfade beziehen sich auf den Programmordner
            if (-not [System.IO.Path]::IsPathRooted($configuredLogPathDir)) {
                $configuredLogPathDir = Join-Path -Path $script:AppRoot -ChildPath $configuredLogPathDir
            }
            $configuredLogPathDir = [System.IO.Path]::GetFullPath($configuredLogPathDir)

            if (-not (Test-Path -LiteralPath $configuredLogPathDir -PathType Container)) {
                New-Item -ItemType Directory -Path $configuredLogPathDir -Force -ErrorAction Stop | Out-Null
            }
            $logDirectoryToUse = $configuredLogPathDir
        }
    }
    catch {
        $logDirectoryToUse = $defaultLogDirectory
        $script:logFilePath = Join-Path -Path $logDirectoryToUse -ChildPath $logFileName
        Write-LogEntry "Konfiguriertes Log-Verzeichnis ist nicht verwendbar, Standard wird genutzt ($logDirectoryToUse): $($_.Exception.Message)" -Type "Warning"
        return $false
    }

    $script:logFilePath = Join-Path -Path $logDirectoryToUse -ChildPath $logFileName
    if ($logDirectoryToUse -ne $defaultLogDirectory) {
        Write-LogEntry "Log-Datei: $($script:logFilePath)"
    }
    return $true
}
