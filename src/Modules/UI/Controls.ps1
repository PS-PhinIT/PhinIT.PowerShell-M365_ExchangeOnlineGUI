# =====================================================================
# easyEXO - Modul: Statusleiste und Textausgaben
# Datei: src/Modules/UI/Controls.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# Funktion zum Aktualisieren der GUI-Textanzeige mit Fehlerbehandlung
function Update-GuiText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.TextBlock]$TextElement,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [System.Windows.Media.Brush]$Color = $null,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxLength = 10000
    )
    
    try {
        if ($null -eq $TextElement) {
            Write-Log  "GUI-Element ist null in Update-GuiText" -Type "Warning"
            return
        }
        
        # Nur Steuerzeichen entfernen (Zeilenumbrüche/Tabs bleiben erlaubt) - Umlaute werden korrekt angezeigt
        $sanitizedMessage = $Message -replace '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', ''
        
        # Nachricht auf maximale Länge begrenzen
        if ($sanitizedMessage.Length -gt $MaxLength) {
            $sanitizedMessage = $sanitizedMessage.Substring(0, $MaxLength) + "..."
        }
        
        # GUI-Element im UI-Thread aktualisieren mit Überprüfung des Dispatcher-Status
        if ($null -ne $TextElement.Dispatcher -and $TextElement.Dispatcher.CheckAccess()) {
            # Wir sind bereits im UI-Thread
            $TextElement.Text = $sanitizedMessage
            if ($null -ne $Color) {
                $TextElement.Foreground = $Color
            }
        } 
        else {
            # Dispatcher verwenden für Thread-Sicherheit
            $TextElement.Dispatcher.Invoke([Action]{
                $TextElement.Text = $sanitizedMessage
                if ($null -ne $Color) {
                    $TextElement.Foreground = $Color
                }
            }, "Normal")
        }
    }
    catch {
        try {
            $errorMsg = $_.Exception.Message
            Write-Log  "Fehler in Update-GuiText: $errorMsg" -Type "Error"
            Log-Action "GUI-Ausgabefehler: $errorMsg"
        }
        catch {
            # Ignoriere Fehler in der Fehlerbehandlung
        }
    }
}

# Liefert die Theme-Farbe (src/GUI/Theme.xaml) für einen Statustyp.
# Die Statusleiste ist dunkel - daher keine Standardfarben wie Schwarz/Rot/Grün verwenden.
function Get-StatusBrush {
    [CmdletBinding()]
    [OutputType([System.Windows.Media.Brush])]
    param(
        [ValidateSet("Info", "Success", "Warning", "Error", "Debug")]
        [string]$Type = "Info"
    )

    $resourceKey = "Status$($Type)Brush"
    if ($null -ne $script:Form) {
        $brush = $script:Form.TryFindResource($resourceKey)
        if ($brush -is [System.Windows.Media.Brush]) { return $brush }
    }

    # Fallback, falls das Theme (noch) nicht geladen ist - gleiche Werte wie in Theme.xaml
    $fallbackColor = switch ($Type) {
        "Success" { "#6CCB5F" }
        "Warning" { "#FFC83D" }
        "Error"   { "#FF6B6B" }
        "Debug"   { "#9FB3C8" }
        default   { "#E2E2E2" }
    }
    return [System.Windows.Media.SolidColorBrush][System.Windows.Media.ColorConverter]::ConvertFromString($fallbackColor)
}

# Funktion zum Aktualisieren des Status in der GUI (protokolliert zusätzlich)
function Write-StatusMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Success", "Warning", "Error", "Debug")]
        [string]$Type = "Info"
    )

    Write-Log -Message $Message -Type $Type
    Update-StatusBar -Message $Message -Type $Type
}

# -------------------------------------------------
# Abschnitt: StatusBar Aktualisierung
# -------------------------------------------------

function Update-StatusBar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet("Info", "Success", "Warning", "Error", "Debug")]
        [string]$Type = "Info",

        [Parameter(Mandatory = $false)]
        [System.Windows.Media.Brush]$OverrideForegroundColor
    )

    if ($null -eq $script:txtStatus) {
        Write-Log -Message "Update-StatusBar: Status-Textfeld (script:txtStatus) wurde nicht gefunden oder ist nicht initialisiert. Meldung: '$Message'" -Type Warning
        return
    }

    try {
        # Steuerzeichen entfernen; Zugriff erfolgt im UI-Thread (alle Aufrufer laufen im Dispatcher-Thread)
        $script:txtStatus.Text = $Message -replace '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', ''

        if ($PSBoundParameters.ContainsKey('OverrideForegroundColor') -and $null -ne $OverrideForegroundColor) {
            $script:txtStatus.Foreground = $OverrideForegroundColor
        } else {
            $script:txtStatus.Foreground = Get-StatusBrush -Type $Type
        }

        # Loggen der Statusänderung (Typ Debug, um Logs nicht zu überfluten)
        Write-Log -Message "StatusBar aktualisiert: [$Type] $Message" -Type Debug
    } catch {
        $errorDetail = $_.Exception.Message
        Write-Log -Message "Fehler in Update-StatusBar beim Setzen von Text/Farbe: $errorDetail. Ursprüngliche Meldung: '$Message'" -Type Error
    }
}
