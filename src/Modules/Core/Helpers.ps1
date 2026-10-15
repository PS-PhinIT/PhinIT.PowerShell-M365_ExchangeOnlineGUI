# =====================================================================
# easyEXO - Modul: Allgemeine Hilfsfunktionen (Validierung, Maskierung, sichere CSV-Exporte, Fehlerformatierung)
# Datei: src/Modules/Core/Helpers.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# -------------------------------------------------
# Abschnitt: Eingabevalidierung
# -------------------------------------------------
function  Validate-Email{
    param([string]$Email)
    # Erlaubt auch gültige Sonderzeichen im lokalen Teil (z. B. "vorname+tag@" oder "o'neil@")
    $regex = "^[\w\.\-\+'%]+@([\w\-]+\.)+[a-zA-Z]{2,}$"
    return $Email -match $regex
}

# Maskiert Benutzereingaben für die Verwendung innerhalb eines OPATH-Filters (-Filter "Attribut -like '...'")
# und verhindert so Filter-Injection durch einfache Anführungszeichen.
function ConvertTo-OPathValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )
    return ($Value -replace "'", "''")
}

##############TABSFUNKTIONEN####################
# -------------------------------------------------
# Abschnitt: Regionaleinstellungen-Funktionen
# -------------------------------------------------

# Hilfsfunktion zur formatierten Ausgabe von Fehlermeldungen
function Get-FormattedError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter(Mandatory = $false)]
        [string]$DefaultText = "Ein unbekannter Fehler ist aufgetreten."
    )

    try {
        if ($null -ne $ErrorRecord) {
            # Versuche, die aussagekräftigste Fehlermeldung zu extrahieren
            $errorMessage = $ErrorRecord.ToString() # Startet mit der Standard-ToString()-Methode

            # Wenn eine Exception vorhanden ist, nutze deren Nachricht (oft detaillierter)
            if ($null -ne $ErrorRecord.Exception) {
                $errorMessage = $ErrorRecord.Exception.Message

                # Füge Nachrichten von inneren Exceptions hinzu, falls vorhanden
                $innerEx = $ErrorRecord.Exception.InnerException
                $depth = 0 # Begrenzung der Tiefe, um Endlosschleifen zu vermeiden
                while ($null -ne $innerEx -and $depth -lt 5) {
                    if (-not [string]::IsNullOrWhiteSpace($innerEx.Message)) {
                        $errorMessage += " --> $($innerEx.Message)"
                    }
                    $innerEx = $innerEx.InnerException
                    $depth++
                }
            }

            # Füge Informationen zum Skript und zur Zeilennummer hinzu, falls verfügbar
            $scriptInfo = ""
            if ($null -ne $ErrorRecord.InvocationInfo) {
                $scriptName = $ErrorRecord.InvocationInfo.ScriptName
                $lineNumber = $ErrorRecord.InvocationInfo.ScriptLineNumber
                if (-not [string]::IsNullOrWhiteSpace($scriptName) -and $lineNumber -gt 0) {
                    $scriptInfo = " (Skript: '$(Split-Path -Leaf $scriptName)', Zeile: $lineNumber)"
                } elseif ($lineNumber -gt 0) {
                     $scriptInfo = " (Zeile: $lineNumber)"
                }
            }

            # Kombiniere die Meldung und die Skriptinformationen
            $formattedMessage = "$errorMessage$scriptInfo"

            # Bereinige die Nachricht von überflüssigen Zeilenumbrüchen am Anfang/Ende
            return $formattedMessage.Trim()

        } else {
            # Wenn kein ErrorRecord übergeben wurde, gib den Standardtext zurück
            return $DefaultText
        }
    } catch {
        # Fallback, falls beim Formatieren der Fehlermeldung selbst ein Fehler auftritt
        Write-Warning "Kritischer Fehler in Get-FormattedError beim Verarbeiten von `$ErrorRecord: $($_.Exception.Message)"
        # Versuche zumindest die ursprüngliche ToString()-Methode oder den Standardtext zurückzugeben
        if ($null -ne $ErrorRecord) {
            try {
                return $ErrorRecord.ToString()
            } catch {
                return $DefaultText
            }
        } else {
            return $DefaultText
        }
    }
}

function Open-AdminCenterLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$DiagnosticIndex
    )
    
    try {
        $diagnostic = $script:exchangeDiagnostics[$DiagnosticIndex]
        
        if (-not [string]::IsNullOrEmpty($diagnostic.AdminCenterLink)) {
            Write-Log  "Öffne Admin Center Link: $($diagnostic.AdminCenterLink)" -Type "Info"
            
            # Status aktualisieren
            if ($null -ne $txtStatus) {
                Update-GuiText -TextElement $txtStatus -Message "Öffne Exchange Admin Center..."
            }
            
            # Link nur über die Allowlist (https, Microsoft-Hosts) öffnen
            if (-not (Open-ExternalUrl -Url $diagnostic.AdminCenterLink)) {
                throw "Die Adresse '$($diagnostic.AdminCenterLink)' ist nicht zulässig."
            }
            
            Log-Action "Admin Center Link geöffnet: $($diagnostic.Name)"
            if ($null -ne $txtStatus) {
                Update-GuiText -TextElement $txtStatus -Message "Exchange Admin Center geöffnet." -Color $script:connectedBrush
            }
            
            return $true
        }
        else {
            Write-Log  "Kein Admin Center Link für diese Diagnose vorhanden" -Type "Warning"
            if ($null -ne $txtStatus) {
                Update-GuiText -TextElement $txtStatus -Message "Kein Admin Center Link für diese Diagnose vorhanden."
            }
            
            return $false
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Öffnen des Admin Center Links: $errorMsg" -Type "Error"
        
        if ($null -ne $txtStatus) {
            Update-GuiText -TextElement $txtStatus -Message "Fehler beim Öffnen des Admin Center Links: $errorMsg"
        }
        
        Log-Action "Fehler beim Öffnen des Admin Center Links: $errorMsg"
        return $false
    }
}


# Hilfsfunktion zum Exportieren von DataGrid-Inhalten
# Schützt CSV-Exporte vor Formel-Injection (CSV Injection): Werte, die mit =, +, -, @ oder Tab/CR beginnen,
# werden mit einem Hochkomma versehen, damit Excel & Co. sie nicht als Formel ausführen.
function ConvertTo-SafeCsvObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowNull()]
        $InputObject,

        # Trennzeichen für mehrwertige Eigenschaften (z. B. EmailAddresses, ForwardTo)
        [string]$ListSeparator = ", "
    )
    process {
        if ($null -eq $InputObject) { return }
        $safeObject = [ordered]@{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $value = $property.Value
            # Mehrwertige Eigenschaften zusammenfassen - Export-Csv schreibt sonst nur den Typnamen
            # (z. B. "System.Collections.ArrayList") statt der Werte.
            if ($null -ne $value -and $value -isnot [string] -and $value -isnot [System.Collections.IDictionary] -and $value -is [System.Collections.IEnumerable]) {
                $value = (@($value) | ForEach-Object { "$_" }) -join $ListSeparator
            }
            if ($value -is [string] -and $value -match '^[=+\-@\t\r]') {
                $value = "'" + $value
            }
            $safeObject[$property.Name] = $value
        }
        [PSCustomObject]$safeObject
    }
}

function Export-DataGridContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.DataGrid]$DataGrid,

        [Parameter(Mandatory = $true)]
        [string]$DefaultFileName
    )

    try {
        $dataToExport = $DataGrid.ItemsSource
        if ($null -eq $dataToExport) {
            # Fallback für DataGrids, die über Items.Add() befüllt werden
            $dataToExport = @($DataGrid.Items)
        }
        if ($null -eq $dataToExport -or @($dataToExport).Count -eq 0) {
            Show-MessageBox -Message "Es sind keine Daten zum Exportieren vorhanden." -Title "Keine Daten" -Type "Warning"
            return
        }

        $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveFileDialog.Filter = "CSV-Dateien (*.csv)|*.csv|Alle Dateien (*.*)|*.*"
        $saveFileDialog.FileName = "$($DefaultFileName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        
        if ($saveFileDialog.ShowDialog() -eq $true) {
            $exportPath = $saveFileDialog.FileName
            $dataToExport | ConvertTo-SafeCsvObject | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8 -Delimiter ";"
            Update-StatusBar -Message "Daten erfolgreich nach '$exportPath' exportiert." -Type "Success"
            Show-MessageBox -Message "Die Daten wurden erfolgreich exportiert." -Title "Export erfolgreich" -Type "Info"
        }
    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Exportieren der Daten."
        Write-Log $errorMsg -Type "Error"
        Update-StatusBar -Message "Fehler beim Exportieren der Daten." -Type "Error"
        Show-MessageBox -Message $errorMsg -Title "Export-Fehler" -Type "Error"
    }
}

# Speichert einen Text (z. B. Audit- oder Diagnose-Ergebnis) als UTF-8-Textdatei
function Export-TextContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$DefaultFileName
    )

    try {
        if ([string]::IsNullOrWhiteSpace($Text)) {
            Show-MessageBox -Message "Es sind keine Ergebnisse zum Speichern vorhanden." -Title "Keine Daten" -Type "Warning"
            return
        }

        $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveFileDialog.Filter = "Textdateien (*.txt)|*.txt|Alle Dateien (*.*)|*.*"
        $saveFileDialog.FileName = "$($DefaultFileName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

        if ($saveFileDialog.ShowDialog() -eq $true) {
            $exportPath = $saveFileDialog.FileName
            [System.IO.File]::WriteAllText($exportPath, $Text, (New-Object System.Text.UTF8Encoding($true)))
            Update-StatusBar -Message "Ergebnisse gespeichert: $exportPath" -Type "Success"
            Write-Log "Ergebnisse gespeichert: $exportPath" -Type "Info"
        }
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Speichern der Ergebnisse."
        Write-Log $errorMsg -Type "Error"
        Show-MessageBox -Message $errorMsg -Title "Export-Fehler" -Type "Error"
    }
}

# Öffnet eine Web-Adresse im Standardbrowser. Erlaubt sind nur HTTPS-Adressen bekannter
# Microsoft-Domänen, damit über manipulierte Daten keine beliebigen Programme gestartet werden.
$script:AllowedExternalUrlHosts = @(
    "aka.ms",
    "learn.microsoft.com",
    "admin.exchange.microsoft.com",
    "admin.microsoft.com",
    "purview.microsoft.com",
    "compliance.microsoft.com",
    "security.microsoft.com",
    "entra.microsoft.com"
)

function Open-ExternalUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    try {
        $uri = $null
        if (-not [System.Uri]::TryCreate($Url, [System.UriKind]::Absolute, [ref]$uri) -or
            $uri.Scheme -ne [System.Uri]::UriSchemeHttps -or
            $script:AllowedExternalUrlHosts -notcontains $uri.Host.ToLowerInvariant()) {
            Write-Log "Adresse wurde nicht geöffnet (nicht zulässig): $Url" -Type "Warning"
            return $false
        }
        Start-Process -FilePath $uri.AbsoluteUri
        Write-Log "Öffne $($uri.AbsoluteUri)" -Type "Info"
        return $true
    }
    catch {
        Write-Log "Adresse konnte nicht geöffnet werden ($Url): $($_.Exception.Message)" -Type "Error"
        return $false
    }
}

# Hinterlegt Hilfe-Thema und Klick-Handler an einem Hilfe-Link (TextBlock)
function Register-HelpLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ElementName,

        [Parameter(Mandatory = $true)]
        [string]$Topic
    )

    $link = Get-XamlElement -ElementName $ElementName
    if ($null -eq $link) { return $false }
    $link.Tag = $Topic
    $link.Add_MouseLeftButtonDown({
        try { Show-HelpDialog -Topic ([string]$this.Tag) }
        catch { Write-Log "Hilfe konnte nicht angezeigt werden: $($_.Exception.Message)" -Type "Error" }
    })
    return $true
}

# Liefert die ausgewählten Zeilen eines DataGrids (Mehrfachauswahl); Aufruf mit @(...)
function Get-SelectedGridItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $DataGrid
    )

    if ($null -eq $DataGrid) { return }
    $items = @($DataGrid.SelectedItems | Where-Object { $null -ne $_ })
    if ($items.Count -eq 0 -and $null -ne $DataGrid.SelectedItem) { $items = @($DataGrid.SelectedItem) }
    return $items
}
