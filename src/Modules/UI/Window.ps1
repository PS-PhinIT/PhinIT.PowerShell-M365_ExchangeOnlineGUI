# =====================================================================
# easyEXO - Modul: Hauptfenster laden (XAML + Theme) und Elemente referenzieren
# Datei: src/Modules/UI/Window.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# -------------------------------------------------
# Abschnitt: GUI Design (WPF/XAML) und Initialisierung
# -------------------------------------------------

function Load-XAML {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$XamlContent
    )
    
    try {
        # Lade XAML aus dem übergebenen String
        Write-Log "Lade XAML aus String-Variable..." -Type "Info"
        
        # XML parsen (Event-Handler werden ausschließlich im Code registriert, nicht per XAML-Attribut)
        [xml]$xmlContent = $XamlContent
        
        # Parse XAML
        $reader = New-Object System.Xml.XmlNodeReader $xmlContent
        
        try {
            $window = [System.Windows.Markup.XamlReader]::Load($reader)
        }
        catch {
            Write-Log "Fehler beim Laden des XAML: $($_.Exception.Message)" -Type "Error"
            throw
        }
        
        if ($null -eq $window) {
            throw "XamlReader.Load gab ein null-Window-Objekt zurück"
        }
        
        # TabControl überprüfen
        $tabControl = $window.FindName("tabContent")
        if ($null -eq $tabControl) {
            throw "TabControl 'tabContent' nicht im XAML gefunden"
        }
        
        # WICHTIG: Stelle sicher, dass Items-Sammlung initialisiert ist
        if ($null -eq $tabControl.Items) {
            Write-Log "Warnung: TabControl.Items ist null - initialisiere" -Type "Warning"
            # Stellen Sie sicher, dass TabControl korrekt initialisiert ist
            $tabControl.UpdateLayout()
        }
        
        # Überprüfe jeden Tab
        if ($null -ne $tabControl.Items) {
            Write-Log "TabControl hat $($tabControl.Items.Count) Items" -Type "Info"
            foreach ($item in $tabControl.Items) {
                Write-Log "Tab gefunden: Name=$($item.Name), Header=$($item.Header), Visibility=$($item.Visibility)" -Type "Info"
            }
        } else {
            Write-Log "TabControl.Items ist immer noch null!" -Type "Error"
        }
        
        # Speichere das Window-Objekt im Script-Scope
        $script:Form = $window
        
        return $window
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler in Load-XAML: $errorMsg" -Type "Error"
        throw
    }
}

# -------------------------------------------------
# Abschnitt: GUI-Elemente referenzieren
# -------------------------------------------------
function Get-XamlElement {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ElementName,

        [Parameter(Mandatory = $false)]
        [switch]$Required
    )

    try {
        if ($null -eq $script:Form) {
            throw "Form-Objekt ist nicht initialisiert"
        }

        $element = $script:Form.FindName($ElementName)
        if ($null -eq $element -and $Required.IsPresent) {
            throw "Erforderliches Element nicht gefunden: $ElementName"
        }
        return $element
    }
    catch {
        if ($Required.IsPresent) { throw }
        Write-Log "Get-XamlElement '$ElementName': $($_.Exception.Message)" -Type "Debug"
        return $null
    }
}

# Funktion zum sicheren Hinzufügen eines Event-Handlers
function Register-EventHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        $Control,
        
        [Parameter(Mandatory=$true)]
        $Handler,
        
        [Parameter(Mandatory=$false)]
        [string]$ControlName = "UnknownControl",
        
        [Parameter(Mandatory=$false)]
        [string]$EventName = "Click"
    )
    
    if ($null -eq $Control) {
        Write-Log  "Control nicht gefunden: $ControlName" -Type "Warning"
        return $false
    }
    
    try {
        if ($EventName -eq "Click" -and $null -ne $script:UIClickDispatcher -and $Handler -is [scriptblock]) {
            # Click-Handler laufen über den zentralen Verteiler (UI/Busy.ps1):
            # Warte-Cursor, Schutz vor Doppelklicks während eines Vorgangs und Fehlerabfang.
            $controlKey = $Control.PSObject.BaseObject
            $handlerList = $null
            if (-not $script:UIClickHandlers.TryGetValue($controlKey, [ref]$handlerList)) {
                $handlerList = New-Object 'System.Collections.Generic.List[scriptblock]'
                $script:UIClickHandlers[$controlKey] = $handlerList
                $Control.Add_Click($script:UIClickDispatcher)
            }
            $handlerList.Add($Handler)
        }
        else {
            # Event-Handler direkt hinzufügen
            $addMethodName = "Add_$EventName"
            $Control.$addMethodName($Handler)
        }
        Write-Log  "Event-Handler für $ControlName.$EventName registriert" -Type "Info"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Registrieren des Event-Handlers für $ControlName - $errorMsg" -Type "Error"
        return $false
    }
}

function Get-MainWindowXaml {
    <#
    .SYNOPSIS
        Liest MainWindow.xaml und fügt das Theme (Theme.xaml) in die Window-Ressourcen ein.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]$GuiPath = $script:GuiRoot
    )

    $windowFile = Join-Path -Path $GuiPath -ChildPath "MainWindow.xaml"
    $themeFile = Join-Path -Path $GuiPath -ChildPath "Theme.xaml"
    foreach ($file in @($windowFile, $themeFile)) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            throw "GUI-Datei nicht gefunden: $file"
        }
    }

    $windowXaml = Get-Content -LiteralPath $windowFile -Raw -Encoding UTF8
    [xml]$themeXml = Get-Content -LiteralPath $themeFile -Raw -Encoding UTF8

    $placeholder = '<!-- @THEME@ -->'
    if (-not $windowXaml.Contains($placeholder)) {
        throw "Platzhalter '$placeholder' fehlt in MainWindow.xaml."
    }

    Write-Log "GUI geladen: $windowFile (Theme: $themeFile)" -Type "Debug"
    return $windowXaml.Replace($placeholder, $themeXml.DocumentElement.InnerXml)
}

function Add-ThemeResource {
    <#
    .SYNOPSIS
        Stellt die Farben und Styles aus Theme.xaml in einem zusätzlichen Fenster (Dialog) bereit.
    .DESCRIPTION
        Eigene Fenster erben die Ressourcen des Hauptfensters nicht. Direkt nach dem Laden des
        Dialogs aufrufen; im Inline-XAML Theme-Ressourcen mit {DynamicResource <Key>} verwenden.
        Die impliziten Styles (Button, TextBox, DataGrid …) gelten danach auch im Dialog.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.FrameworkElement]$Window
    )

    try {
        if ([string]::IsNullOrEmpty($script:ThemeXamlCache)) {
            $themeFile = Join-Path -Path $script:GuiRoot -ChildPath "Theme.xaml"
            $script:ThemeXamlCache = Get-Content -LiteralPath $themeFile -Raw -Encoding UTF8
        }
        # Je Fenster ein eigenes ResourceDictionary (keine geteilten Style-/Brush-Instanzen zwischen Fenstern)
        $themeDictionary = [System.Windows.Markup.XamlReader]::Parse($script:ThemeXamlCache)
        $Window.Resources.MergedDictionaries.Add($themeDictionary)
        return $true
    }
    catch {
        Write-Log "Theme konnte nicht auf das Fenster angewendet werden: $($_.Exception.Message)" -Type "Warning"
        return $false
    }
}
