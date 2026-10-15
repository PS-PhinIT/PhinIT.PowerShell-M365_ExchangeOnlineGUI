# =====================================================================
# easyEXO - Modul: Arbeitsanzeige (Busy-Overlay), Fortschritt und Abbrechen
# Datei: src/Modules/UI/Busy.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
#
# Hintergrund: Die Exchange-Online-Sitzung (EXO V3) ist an den Runspace gebunden,
# in dem Connect-ExchangeOnline ausgeführt wurde. Abfragen können daher nicht in
# einen Hintergrund-Runspace ausgelagert werden, ohne sich erneut anzumelden.
# Stattdessen hält dieses Modul die Oberfläche kooperativ reaktionsfähig:
# Lange Abfragen zeigen ein Overlay mit Fortschritt, verarbeiten zwischendurch
# die WPF-Nachrichtenschleife und lassen sich über "Abbrechen" beenden.
# =====================================================================

$script:UIBusyDepth = 0
$script:UICancelRequested = $false
$script:UILastDoEvents = [datetime]::MinValue
$script:UIClickHandlers = New-Object 'System.Collections.Generic.Dictionary[object,object]'

# Verarbeitet anstehende WPF-Nachrichten (Rendern, Eingaben), gedrosselt auf ca. 10x pro Sekunde.
function Invoke-UIDoEvents {
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    if ($null -eq $script:Form) { return }
    $now = [datetime]::UtcNow
    if (-not $Force -and ($now - $script:UILastDoEvents).TotalMilliseconds -lt 100) { return }
    $script:UILastDoEvents = $now
    try {
        $script:Form.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
    }
    catch {
        Write-Log "UI-Nachrichtenverarbeitung fehlgeschlagen: $($_.Exception.Message)" -Type "Debug"
    }
}

# Zeigt das Arbeits-Overlay an. Verschachtelte Aufrufe werden gezählt.
function Start-UIBusy {
    [CmdletBinding()]
    param(
        [string]$Message = "Bitte warten...",
        [string]$Title = "Vorgang läuft",
        [switch]$Cancelable
    )

    $script:UIBusyDepth++
    if ($script:UIBusyDepth -gt 1) {
        Update-UIBusy -Message $Message
        return
    }

    $script:UICancelRequested = $false
    try {
        if ($null -ne $script:Form) {
            $overlay = $script:Form.FindName("gridBusyOverlay")
            $titleControl = $script:Form.FindName("txtBusyTitle")
            $text = $script:Form.FindName("txtBusyMessage")
            $bar = $script:Form.FindName("prgBusy")
            $cancel = $script:Form.FindName("btnBusyCancel")

            if ($null -ne $titleControl) { $titleControl.Text = $Title }
            if ($null -ne $text) { $text.Text = $Message }
            if ($null -ne $bar) { $bar.IsIndeterminate = $true; $bar.Value = 0 }
            if ($null -ne $cancel) {
                $cancel.IsEnabled = $true
                $cancel.Content = "Abbrechen"
                $cancel.Visibility = if ($Cancelable) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            }
            if ($null -ne $overlay) { $overlay.Visibility = [System.Windows.Visibility]::Visible }
        }
        [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
    }
    catch {
        Write-Log "Arbeitsanzeige konnte nicht angezeigt werden: $($_.Exception.Message)" -Type "Debug"
    }

    Invoke-UIDoEvents -Force
}

# Aktualisiert Meldung und (optional) den Fortschritt des Overlays.
function Update-UIBusy {
    [CmdletBinding()]
    param(
        [string]$Message,
        [int]$Current = -1,
        [int]$Total = 0
    )

    if ($script:UIBusyDepth -le 0 -or $null -eq $script:Form) { return }
    try {
        $text = $script:Form.FindName("txtBusyMessage")
        $bar = $script:Form.FindName("prgBusy")

        if ($null -ne $bar) {
            if ($Total -gt 0 -and $Current -ge 0) {
                $bar.IsIndeterminate = $false
                $bar.Maximum = $Total
                $bar.Value = [Math]::Min($Current, $Total)
            }
            else {
                $bar.IsIndeterminate = $true
            }
        }
        if ($null -ne $text -and -not [string]::IsNullOrEmpty($Message)) {
            if ($Total -gt 0 -and $Current -ge 0) {
                $text.Text = "$Message ($Current von $Total)"
            }
            else {
                $text.Text = $Message
            }
        }
    }
    catch {
        Write-Log "Arbeitsanzeige konnte nicht aktualisiert werden: $($_.Exception.Message)" -Type "Debug"
    }

    Invoke-UIDoEvents
}

# Blendet das Arbeits-Overlay aus (erst wenn alle verschachtelten Aufrufe beendet sind).
function Stop-UIBusy {
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    if ($Force) { $script:UIBusyDepth = 0 }
    elseif ($script:UIBusyDepth -gt 0) { $script:UIBusyDepth-- }
    if ($script:UIBusyDepth -gt 0) { return }

    try {
        if ($null -ne $script:Form) {
            $overlay = $script:Form.FindName("gridBusyOverlay")
            if ($null -ne $overlay) { $overlay.Visibility = [System.Windows.Visibility]::Collapsed }
        }
        [System.Windows.Input.Mouse]::OverrideCursor = $null
    }
    catch {
        Write-Log "Arbeitsanzeige konnte nicht ausgeblendet werden: $($_.Exception.Message)" -Type "Debug"
    }
}

# Gibt $true zurück, wenn der Benutzer "Abbrechen" gewählt hat (verarbeitet vorher anstehende Eingaben).
function Test-UICancelRequested {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($script:UIBusyDepth -le 0) { return $false }
    Invoke-UIDoEvents
    return [bool]$script:UICancelRequested
}

# Löst eine OperationCanceledException aus, wenn der Benutzer abgebrochen hat.
function Assert-UINotCancelled {
    [CmdletBinding()]
    param()

    if (Test-UICancelRequested) {
        throw [System.OperationCanceledException]::new("Vorgang wurde vom Benutzer abgebrochen.")
    }
}

# Pipeline-Durchreichung: zählt Objekte, aktualisiert das Overlay und hält die Oberfläche
# reaktionsfähig. Bei "Abbrechen" wird die Pipeline (inkl. laufender EXO-Abfrage) beendet.
function Step-UIProgress {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject,

        [string]$Activity = "Lade Daten",

        [int]$Total = 0
    )

    begin {
        $stepCount = 0
        $lastUpdate = [datetime]::MinValue
    }
    process {
        $stepCount++
        if ($script:UIBusyDepth -gt 0 -and $script:UICancelRequested) {
            throw [System.OperationCanceledException]::new("Vorgang wurde vom Benutzer abgebrochen.")
        }
        $now = [datetime]::UtcNow
        if (($now - $lastUpdate).TotalMilliseconds -ge 150) {
            $lastUpdate = $now
            if ($Total -gt 0) {
                Update-UIBusy -Message $Activity -Current $stepCount -Total $Total
            }
            else {
                Update-UIBusy -Message "$Activity ($stepCount Objekte)"
            }
        }
        Assert-UINotCancelled
        $InputObject
    }
    end {
        Assert-UINotCancelled
    }
}

# Zentraler Click-Verteiler: Wird von Register-EventHandler einmal pro Steuerelement registriert.
# Ignoriert Klicks während ein Vorgang läuft, zeigt den Warte-Cursor an und fängt Fehler ab,
# damit eine Ausnahme im Handler nicht die gesamte Anwendung beendet.
$script:UIClickDispatcher = {
    param($uiSource, $e)

    if ($script:UIBusyDepth -gt 0) {
        Write-Log "Klick ignoriert - es läuft bereits ein Vorgang." -Type "Debug"
        return
    }

    $__uiHandlerList = $null
    if (-not $script:UIClickHandlers.TryGetValue($uiSource.PSObject.BaseObject, [ref]$__uiHandlerList)) { return }

    $__uiPreviousCursor = [System.Windows.Input.Mouse]::OverrideCursor
    try {
        [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
        foreach ($__uiHandler in @($__uiHandlerList)) {
            try {
                & $__uiHandler $uiSource $e
            }
            catch {
                $__uiName = if ($uiSource -is [System.Windows.FrameworkElement]) { $uiSource.Name } else { "$uiSource" }
                Write-Log "Unbehandelter Fehler im Click-Handler von '$__uiName': $($_.Exception.Message)" -Type "Error"
                Update-StatusBar -Message "Fehler: $($_.Exception.Message)" -Type Error
            }
        }
    }
    finally {
        if ($script:UIBusyDepth -le 0) {
            [System.Windows.Input.Mouse]::OverrideCursor = $__uiPreviousCursor
        }
    }
}

# Registriert den "Abbrechen"-Button des Overlays (direkt, nicht über den Click-Verteiler,
# damit er auch während eines laufenden Vorgangs reagiert).
function Initialize-UIBusyOverlay {
    [CmdletBinding()]
    param()

    if ($null -eq $script:Form) { return $false }
    $cancel = $script:Form.FindName("btnBusyCancel")
    if ($null -eq $cancel) {
        Write-Log "Abbrechen-Button des Arbeits-Overlays nicht gefunden." -Type "Warning"
        return $false
    }
    $cancel.Add_Click({
        $script:UICancelRequested = $true
        $this.IsEnabled = $false
        $this.Content = "Wird abgebrochen..."
        Write-Log "Abbruch durch Benutzer angefordert." -Type "Info"
    })
    return $true
}
