# =====================================================================
# easyEXO - Modul: Statusleiste, Textausgaben und ComboBox-Hilfen
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

# Funktion zum Aktualisieren des Status in der GUI
function Write-StatusMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Type = "Info"
    )
    
    try {
        # Logge die Nachricht auch
        Write-Log  -Message $Message -Type $Type # Konsolenausgabe hiervon wird durch Write-Log gesteuert
        
        # Bestimme die Farbe basierend auf dem Nachrichtentyp
        $color = switch ($Type) {
            "Success" { $script:connectedBrush }
            "Error" { $script:disconnectedBrush }
            "Warning" { New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Orange) }
            "Info" { $null }
            default { $null }
        }
        
        # Aktualisiere das Status-Textfeld in der GUI
        if ($null -ne $script:txtStatus) {
            Update-GuiText -TextElement $script:txtStatus -Message $Message -Color $color
        }
    } 
    catch {
        # Bei Fehler einfach eine Debug-Meldung ausgeben
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler in Write-StatusMessage: $errorMsg" -Type "Error" # Konsolenausgabe hiervon wird durch Write-Log gesteuert
    }
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
        # Zugriff auf das UI-Element muss im UI-Thread erfolgen.
        # Wenn diese Funktion aus einem anderen Thread aufgerufen wird, $script:Form.Dispatcher.Invoke verwenden.
        # Für die meisten Anwendungsfälle in diesem Skript wird sie wahrscheinlich aus dem UI-Thread aufgerufen.
        
        $script:txtStatus.Text = $Message
        
        # Standardfarben basierend auf dem Typ definieren
        $foregroundColor = $null
        if ($PSBoundParameters.ContainsKey('OverrideForegroundColor') -and $null -ne $OverrideForegroundColor) {
            $foregroundColor = $OverrideForegroundColor
        } else {
            switch ($Type) {
                "Success" { $foregroundColor = [System.Windows.Media.Brushes]::Green }
                "Warning" { $foregroundColor = [System.Windows.Media.Brushes]::OrangeRed } # Oder DarkOrange
                "Error"   { $foregroundColor = [System.Windows.Media.Brushes]::Red }
                "Debug"   { $foregroundColor = [System.Windows.Media.Brushes]::BlueViolet } 
                "Info"    { 
                            # Für "Info" die Standard-Vordergrundfarbe verwenden (oft Schwarz)
                            # Oder, falls das Control eine spezifische Standardfarbe hat, diese beibehalten.
                            # Der Einfachheit halber setzen wir es auf Schwarz, wenn keine Override-Farbe angegeben ist.
                            $foregroundColor = [System.Windows.Media.Brushes]::Black 
                          }
                default   { $foregroundColor = [System.Windows.Media.Brushes]::Black }
            }
        }
        
        $script:txtStatus.Foreground = $foregroundColor
        
        # Loggen der Statusänderung (Typ Debug, um Logs nicht zu überfluten)
        Write-Log -Message "StatusBar aktualisiert: [$Type] $Message" -Type Debug 
        
    } catch {
        $errorDetail = $_.Exception.Message
        Write-Log -Message "Fehler in Update-StatusBar beim Setzen von Text/Farbe: $errorDetail. Ursprüngliche Meldung: '$Message'" -Type Error
        # Versuch, den Fehler selbst in der Statusleiste anzuzeigen (als Fallback)
        try {
            $script:txtStatus.Text = "Fehler in StatusBar: $errorDetail"
            $script:txtStatus.Foreground = [System.Windows.Media.Brushes]::Red
        } catch {
            # Wenn selbst das Setzen der Fehlermeldung fehlschlägt, ist das UI-Element möglicherweise nicht mehr gültig.
            Write-Log -Message "Konnte Fehler nicht in StatusBar anzeigen. txtStatus möglicherweise ungültig." -Type Error
        }
    }
}

# Funktion zum Hinzufügen eines Standard-Elements zu einer ComboBox
function Add-ComboBoxDefaultItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ComboBox]$Control,

        [Parameter(Mandatory = $true)]
        [string]$DefaultItemText,

        [Parameter(Mandatory = $true)]
        $DefaultItemValue
    )

    try {
        # Sicherstellen, dass das Control gültig ist
        if ($null -eq $Control) {
            Write-Log "Add-ComboBoxDefaultItem: Control ist null." -Type Warning
            return
        }

        # Standard-Element erstellen
        $defaultItem = New-Object System.Windows.Controls.ComboBoxItem
        $defaultItem.Content = $DefaultItemText
        $defaultItem.Tag = $DefaultItemValue # Wert im Tag speichern

        # Element zur ComboBox hinzufügen (im UI-Thread)
        $Control.Dispatcher.Invoke({
            param($ItemToAdd)
            # Prüfen, ob das Element bereits existiert (basierend auf Tag)
            $exists = $false
            foreach ($item in $Control.Items) {
                if ($item -is [System.Windows.Controls.ComboBoxItem] -and $item.Tag -eq $ItemToAdd.Tag) {
                    $exists = $true
                    break
                }
            }
            if (-not $exists) {
                $Control.Items.Insert(0, $ItemToAdd) # Am Anfang einfügen
                # Optional: Standardmäßig auswählen, wenn die Box leer war
                if ($Control.Items.Count -eq 1) {
                    $Control.SelectedIndex = 0
                }
            }
        }, "Normal", $defaultItem) | Out-Null

    } catch {
        # Use ${} for clarity
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Hinzufügen des Standard-Elements '${DefaultItemText}' zur ComboBox."
        Write-Log $errorMsg -Type Error
        Log-Action "FEHLER: Add-ComboBoxDefaultItem - ${errorMsg}"
    }
}

# Funktion zum Aktualisieren der Elemente einer ComboBox aus einer Datenquelle
function Update-ComboBoxItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ComboBox]$Control,

        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$DataSource,

        [Parameter(Mandatory = $true)]
        [string]$DisplayMember, # Eigenschaft für die Anzeige

        [Parameter(Mandatory = $true)]
        [string]$ValueMember,   # Eigenschaft für den Wert (im Tag gespeichert)

        [string]$DefaultItemText = "(Auswählen)", # Optionaler Text für das Standardelement
        $DefaultItemValue = $null                 # Optionaler Wert für das Standardelement
    )

    try {
        # Sicherstellen, dass das Control gültig ist
        if ($null -eq $Control) {
            Write-Log "Update-ComboBoxItems: Control ist null." -Type Warning
            return
        }

        # Ausführung im UI-Thread sicherstellen
        $Control.Dispatcher.Invoke({
            # ComboBox leeren
            $Control.Items.Clear()

            # Standard-Element hinzufügen, falls definiert
            if (-not [string]::IsNullOrEmpty($DefaultItemText)) {
                Add-ComboBoxDefaultItem -Control $Control -DefaultItemText $DefaultItemText -DefaultItemValue $DefaultItemValue
            }

            # Elemente aus der Datenquelle hinzufügen
            if ($null -ne $DataSource) {
                foreach ($item in $DataSource) {
                    try {
                        $display = $item.$DisplayMember
                        $value = $item.$ValueMember

                        $comboBoxItem = New-Object System.Windows.Controls.ComboBoxItem
                        $comboBoxItem.Content = $display
                        $comboBoxItem.Tag = $value # Wert im Tag speichern

                        $Control.Items.Add($comboBoxItem)
                    } catch {
                        # Use ${} for clarity
                        $itemIdentifier = try { $item | Out-String -Stream } catch { "Unbekanntes Element" }
                        Write-Log "Fehler beim Verarbeiten eines Elements für ComboBox: $($_.Exception.Message). Element: ${itemIdentifier}" -Type Warning
                        # Überspringe dieses Element und fahre fort
                    }
                }
            }

            # Standardmäßig das erste Element (meist das DefaultItem) auswählen
            if ($Control.Items.Count -gt 0) {
                $Control.SelectedIndex = 0
            }

        }, "Normal") | Out-Null # Invoke

    } catch {
        # Use ${} for clarity
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Aktualisieren der ComboBox-Elemente."
        Write-Log $errorMsg -Type Error
        Log-Action "FEHLER: Update-ComboBoxItems - ${errorMsg}"
    }
}
