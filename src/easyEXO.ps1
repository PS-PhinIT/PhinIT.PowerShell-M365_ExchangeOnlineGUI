#Requires -Version 5.1
<#
.SYNOPSIS
    easyEXO - grafisches Verwaltungstool für Exchange Online (WPF).

.DESCRIPTION
    Startskript (Launcher) von easyEXO. Es prüft die Umgebung, lädt die Module aus
    src/Modules per Dot-Sourcing, lädt die Oberfläche aus src/GUI (MainWindow.xaml + Theme.xaml)
    und registriert die Event-Handler des Hauptfensters.

    Projektstruktur:
      src/easyEXO.ps1          Launcher (dieses Skript)
      src/Modules/Core         Logging, Konfiguration, Umgebung, Hilfsfunktionen
      src/Modules/UI           Fenster, Dialoge, Statusleiste, Navigation
      src/Modules/Exchange     Exchange Online Verbindung
      src/Modules/Features     Fachfunktionen je Bereich (Postfächer, Gruppen, Mail-Flow, ...)
      src/GUI                  MainWindow.xaml und Theme.xaml

.NOTES
    Keine Administratorrechte erforderlich. Benötigt das Modul ExchangeOnlineManagement (>= 3.0, empfohlen >= 3.7).
    Siehe README.md, SECURITY.md und CHANGELOG.md.

.LINK
    https://github.com/PS-PhinIT/PhinIT.PowerShell-M365_ExchangeOnlineGUI
#>

# -------------------------------------------------
# Version (bei jedem Release anpassen und in CHANGELOG.md dokumentieren)
# -------------------------------------------------
$script:AppVersion = "0.5.1"

# WPF benötigt einen STA-Thread (Standard bei Windows PowerShell 5.1 und pwsh 7 unter Windows).
# Bei Start mit -MTA wird das Skript automatisch im STA-Modus neu gestartet.
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
        Write-Warning "easyEXO benötigt den STA-Modus. Bitte mit 'powershell.exe -STA -File <Pfad>\easyEXO.ps1' bzw. 'pwsh.exe -STA -File ...' starten."
        exit 1
    }
    $hostExecutable = (Get-Process -Id $PID).Path
    Start-Process -FilePath $hostExecutable -ArgumentList "-NoProfile -STA -File `"$PSCommandPath`""
    exit
}

# -------------------------------------------------
# WPF-Assemblies laden
# -------------------------------------------------
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# -------------------------------------------------
# Pfade festlegen und Module laden
# -------------------------------------------------
# Alle Module werden per Dot-Sourcing in den Script-Scope dieses Launchers geladen.
# Dadurch teilen sich Funktionen und WPF-Event-Handler weiterhin dieselben $script:-Variablen.
$script:AppRoot = $PSScriptRoot
$script:AppScriptPath = $PSCommandPath
$script:ModuleRoot = Join-Path -Path $script:AppRoot -ChildPath "Modules"
$script:GuiRoot = Join-Path -Path $script:AppRoot -ChildPath "GUI"

$script:ModuleFiles = @(
    'Core/Logging.ps1'
    'Core/Configuration.ps1'
    'Core/Environment.ps1'
    'Core/Helpers.ps1'
    'UI/Window.ps1'
    'UI/Controls.ps1'
    'UI/Busy.ps1'
    'UI/Dialogs.ps1'
    'UI/Navigation.ps1'
    'Exchange/Connection.ps1'
    'Features/Dashboard.ps1'
    'Features/Calendar.ps1'
    'Features/Mailbox.ps1'
    'Features/SharedMailbox.ps1'
    'Features/Groups.ps1'
    'Features/Resources.ps1'
    'Features/Contacts.ps1'
    'Features/MailFlowRules.ps1'
    'Features/InboxRules.ps1'
    'Features/MessageTrace.ps1'
    'Features/AutoReply.ps1'
    'Features/CrossPremises.ps1'
    'Features/Hybrid.ps1'
    'Features/MultiForest.ps1'
    'Features/Security.ps1'
    'Features/Compliance.ps1'
    'Features/MobileDevices.ps1'
    'Features/OrganizationSettings.ps1'
    'Features/RegionSettings.ps1'
    'Features/HealthCheck.ps1'
    'Features/Audit.ps1'
    'Features/Reports.ps1'
    'Features/Troubleshooting.ps1'
)

foreach ($moduleFile in $script:ModuleFiles) {
    $modulePath = Join-Path -Path $script:ModuleRoot -ChildPath $moduleFile
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        Write-Error "easyEXO: Moduldatei nicht gefunden: $modulePath - bitte das vollständige Verzeichnis 'src' verwenden."
        exit 1
    }
    try {
        . $modulePath
    }
    catch {
        Write-Error "easyEXO: Fehler beim Laden von '$moduleFile': $($_.Exception.Message)"
        exit 1
    }
}

# --------------------------------------------------------------
# Initialisiere Debugging und Logging für das Script
# --------------------------------------------------------------
$script:debugMode = $false
$script:logFilePath = Join-Path -Path "$script:AppRoot\Logs" -ChildPath "ExchangeTool.log"

# Statusfarben für Verbindungsstatus und Statusleiste (beide dunkel) - werden nach dem Laden
# des Fensters aus dem Theme (Status*Brush in src/GUI/Theme.xaml) übernommen
$script:connectedBrush = $null
$script:disconnectedBrush = $null
$script:isConnected = $false
$script:RestartPending = $false

# Registry-Pfad und Standardwerte für Konfigurationseinstellungen
$script:registryPath = "HKCU:\Software\easyIT\easyEXO"

try {
    Write-LogEntry "Prüfe und initialisiere Registry-Konfiguration unter '$($script:registryPath)'."
    if (-not (Test-Path -Path $script:registryPath)) {
        New-Item -Path $script:registryPath -Force -ErrorAction Stop | Out-Null
        Write-LogEntry "Registry-Anwendungspfad '$($script:registryPath)' wurde erstellt."
    }

    # Nur fehlende Werte anlegen - vom Benutzer gespeicherte Einstellungen (Debug, Standard-Benutzer,
    # Log-Verzeichnis) bleiben bei einem Versionswechsel erhalten.
    $registryDefaults = [ordered]@{
        Debug       = @{ Value = 0; Type = "DWord" }
        AppName     = @{ Value = "easyEXO | Exchange Online Management Tool"; Type = "String" }
        DefaultUser = @{ Value = ""; Type = "String" }
        LogPath     = @{ Value = (Join-Path -Path $script:AppRoot -ChildPath "Logs"); Type = "String" }
    }
    $existingValues = Get-ItemProperty -Path $script:registryPath -ErrorAction SilentlyContinue
    foreach ($entry in $registryDefaults.GetEnumerator()) {
        if ($null -eq $existingValues -or $null -eq $existingValues.PSObject.Properties[$entry.Key]) {
            New-ItemProperty -Path $script:registryPath -Name $entry.Key -Value $entry.Value.Value -PropertyType $entry.Value.Type -Force -ErrorAction Stop | Out-Null
            Write-LogEntry "Registry-Standardwert '$($entry.Key)' angelegt."
        }
    }
    $storedVersion = if ($null -ne $existingValues -and $null -ne $existingValues.PSObject.Properties["Version"]) { [string]$existingValues.Version } else { $null }
    if ($storedVersion -ne $script:AppVersion) {
        New-ItemProperty -Path $script:registryPath -Name "Version" -Value $script:AppVersion -PropertyType String -Force -ErrorAction Stop | Out-Null
        Write-LogEntry "Registry-Version aktualisiert ('$storedVersion' -> '$($script:AppVersion)')."
    }
}
catch {
    Write-LogEntry "FEHLER bei der Registry-Konfigurationsinitialisierung für '$($script:registryPath)': $($_.Exception.Message)" -Type "Error"
}

# Lade Konfiguration
$script:config = Get-RegistryConfig

# Debug-Modus einschalten, wenn in Registry aktiviert
if ($script:config["General"]["Debug"] -eq "1") {
    $script:debugMode = $true
}

# Log-Verzeichnis aus den Einstellungen übernehmen (Standard: Logs neben dem Launcher)
$null = Initialize-Logging

# -------------------------------------------------
# Abschnitt: GUI laden (src/GUI/MainWindow.xaml + src/GUI/Theme.xaml)
# -------------------------------------------------
try {
    $script:Form = Load-XAML -XamlContent (Get-MainWindowXaml)
    $script:Form.Title = "$($script:Form.Title) | v$($script:AppVersion)"
    $script:connectedBrush = Get-StatusBrush -Type Success
    $script:disconnectedBrush = Get-StatusBrush -Type Error

    # Fenstergröße an den verfügbaren Bildschirmbereich anpassen (kleine Displays / Skalierung)
    $workArea = [System.Windows.SystemParameters]::WorkArea
    if ($script:Form.Width -gt $workArea.Width) {
        $script:Form.Width = [Math]::Max($script:Form.MinWidth, [Math]::Floor($workArea.Width * 0.95))
    }
    if ($script:Form.Height -gt $workArea.Height) {
        $script:Form.Height = [Math]::Max($script:Form.MinHeight, [Math]::Floor($workArea.Height * 0.95))
    }
    Write-Log "XAML erfolgreich geladen und Window-Objekt erstellt" -Type "Success"
}
catch {
    Write-Log "Kritischer Fehler beim Laden des XAML: $($_.Exception.Message)" -Type "Error"
    Write-LogEntry "Anwendung wird beendet aufgrund XAML-Fehler"
    exit 1
}

# Hauptelemente referenzieren
$script:btnConnect          = Get-XamlElement -ElementName "btnConnect" -Required
$script:tabContent          = Get-XamlElement -ElementName "tabContent" -Required
$script:txtStatus           = Get-XamlElement -ElementName "txtStatus" -Required
$script:txtVersion          = Get-XamlElement -ElementName "txtVersion"
$script:txtConnectionStatus = Get-XamlElement -ElementName "txtConnectionStatus" -Required
$script:btnClose            = Get-XamlElement -ElementName "btnClose" -Required

# Dashboard
$script:btnDashboard        = Get-XamlElement -ElementName "btnDashboard"
$script:tabDashboard        = Get-XamlElement -ElementName "tabDashboard"

# Grundlegende Verwaltung - Tabs
$script:tabCalendar         = Get-XamlElement -ElementName "tabCalendar"
$script:tabMailbox          = Get-XamlElement -ElementName "tabMailbox"
$script:tabSharedMailbox    = Get-XamlElement -ElementName "tabSharedMailbox"
$script:tabGroups           = Get-XamlElement -ElementName "tabGroups"
$script:tabResources        = Get-XamlElement -ElementName "tabResources"
$script:tabContacts         = Get-XamlElement -ElementName "tabContacts"

# Grundlegende Verwaltung - Navigation Buttons
$script:btnNavCalendar      = Get-XamlElement -ElementName "btnNavCalendar"
$script:btnNavMailbox       = Get-XamlElement -ElementName "btnNavMailbox"
$script:btnNavSharedMailbox = Get-XamlElement -ElementName "btnNavSharedMailbox"
$script:btnNavGroups        = Get-XamlElement -ElementName "btnNavGroups"
$script:btnNavResources     = Get-XamlElement -ElementName "btnNavResources"
$script:btnNavContacts      = Get-XamlElement -ElementName "btnNavContacts"

# Mail Flow - Tabs
$script:tabMailFlowRules    = Get-XamlElement -ElementName "tabMailFlowRules"
$script:tabInboxRules       = Get-XamlElement -ElementName "tabInboxRules"
$script:tabMessageTrace     = Get-XamlElement -ElementName "tabMessageTrace"
$script:tabAutoReply        = Get-XamlElement -ElementName "tabAutoReply"

# Mail Flow - Navigation Buttons
$script:btnNavMailFlowRules = Get-XamlElement -ElementName "btnNavMailFlowRules"
$script:btnNavInboxRules    = Get-XamlElement -ElementName "btnNavInboxRules"
$script:btnNavMessageTrace  = Get-XamlElement -ElementName "btnNavMessageTrace"
$script:btnNavAutoReply     = Get-XamlElement -ElementName "btnNavAutoReply"

# Sicherheit & Compliance - Tabs
$script:tab_ATP             = Get-XamlElement -ElementName "tab_ATP"
$script:tab_DLP             = Get-XamlElement -ElementName "tab_DLP"
$script:tab_eDiscovery      = Get-XamlElement -ElementName "tab_eDiscovery"
$script:tab_MDM             = Get-XamlElement -ElementName "tab_MDM"

# Sicherheit & Compliance - Navigation Buttons
$script:btnNavATP           = Get-XamlElement -ElementName "btnNavATP"
$script:btnNavDLP           = Get-XamlElement -ElementName "btnNavDLP"
$script:btnNavEDiscovery    = Get-XamlElement -ElementName "btnNavEDiscovery"
$script:btnNavMDM           = Get-XamlElement -ElementName "btnNavMDM"

# Systemkonfiguration - Tabs
$script:tabEXOSettings      = Get-XamlElement -ElementName "tabEXOSettings"
$script:tabRegion           = Get-XamlElement -ElementName "tabRegion"
$script:tab_MailRouting     = Get-XamlElement -ElementName "tab_MailRouting"

# Systemkonfiguration - Navigation Buttons
$script:btnNavEXOSettings   = Get-XamlElement -ElementName "btnNavEXOSettings"
$script:btnNavRegion        = Get-XamlElement -ElementName "btnNavRegion"
$script:btnNavCrossPremises = Get-XamlElement -ElementName "btnNavCrossPremises"

# Erweiterte Verwaltung - Tabs
$script:tab_HybridExchange  = Get-XamlElement -ElementName "tab_HybridExchange"
$script:tab_MultiForest     = Get-XamlElement -ElementName "tab_MultiForest"

# Erweiterte Verwaltung - Navigation Buttons
$script:btnNavHybridExchange = Get-XamlElement -ElementName "btnNavHybridExchange"
$script:btnNavMultiForest   = Get-XamlElement -ElementName "btnNavMultiForest"

# Monitoring & Support - Tabs
$script:tab_HealthCheck     = Get-XamlElement -ElementName "tab_HealthCheck"
$script:tabMailboxAudit     = Get-XamlElement -ElementName "tabMailboxAudit"
$script:tabReports          = Get-XamlElement -ElementName "tabReports"
$script:tabTroubleshooting  = Get-XamlElement -ElementName "tabTroubleshooting"

# Monitoring & Support - Navigation Buttons
$script:btnNavHealthCheck   = Get-XamlElement -ElementName "btnNavHealthCheck"
$script:btnNavAudit         = Get-XamlElement -ElementName "btnNavAudit"
$script:btnNavReports       = Get-XamlElement -ElementName "btnNavReports"
$script:btnNavTroubleshooting = Get-XamlElement -ElementName "btnNavTroubleshooting"

$script:btnInfo             = Get-XamlElement -ElementName "btnInfo"
$script:btnSettings         = Get-XamlElement -ElementName "btnSettings"

# Button-Handler
$script:envCheckDone = $false
$script:btnConnect.Add_Click({
    # Bestehende Verbindung: Button dient zum Trennen
    if ($script:isConnected) {
        $answer = Show-MessageBox -Message "Möchten Sie die Verbindung zu Exchange Online trennen?" -Title "Verbindung trennen" -Type "Question"
        if ($answer -eq [System.Windows.MessageBoxResult]::Yes) {
            Disconnect-ExchangeOnlineSession | Out-Null
            Reset-DashboardStatistics
        }
        return
    }

    # Umgebungsprüfung (PowerShell 7 empfohlen) nur einmal pro Sitzung und nicht blockierend
    if (-not $script:envCheckDone) {
        $script:envCheckDone = $true
        $null = Test-PowerShell7AndAdminRights
        # Neustart mit PowerShell 7 wurde eingeleitet - diese Instanz schließt sich, keine Verbindung mehr aufbauen
        if ($script:RestartPending) { return }
    }
    # Prüfen, ob die erforderlichen Module vorhanden sind, bevor die Verbindung versucht wird.
    if (-not (Check-Prerequisites)) {
        # Die Funktion Check-Prerequisites sollte den Benutzer bereits informiert haben.
        return
    }
    $null = Connect-OwnExchangeOnline
    if ($script:isConnected) {
        $script:btnConnect.Content = "Verbindung trennen"
        $script:btnConnect.Tag = "disconnect"
        Update-DomainList
        Refresh-DashboardStatistics
    }
})

# Zusätzliche Verbindung zu Security & Compliance (DLP, Aufbewahrung, Vertraulichkeitsbezeichnungen)
$script:btnConnectCompliance = Get-XamlElement -ElementName "btnConnectCompliance"
$null = Register-EventHandler -Control $script:btnConnectCompliance -Handler {
    $null = Connect-OwnComplianceSession
} -ControlName "btnConnectCompliance"

# Hinweis: Der Schließen-Button wird im Abschnitt "Kopfzeilen-Buttons" registriert (trennt vorher die Exchange-Verbindung).
# Die Navigations-Buttons werden zentral in Initialize-TabNavigation registriert (keine doppelten Click-Handler).

# Tab-Wechsel protokollieren (Tab-Header werden ausgeblendet, daher den Namen verwenden)
$script:tabContent.Add_SelectionChanged({
    param($tabSource, $selectionArgs)
    # Nur Ereignisse des TabControls selbst (nicht von untergeordneten ComboBoxen/DataGrids) protokollieren
    if ($selectionArgs.OriginalSource -ne $tabSource) { return }
    $selectedTab = $tabSource.SelectedItem
    if ($null -ne $selectedTab) {
        Write-Log "Tab gewechselt zu: $($selectedTab.Name)"
    }
})

# -------------------------------------------------
# Status-Variable für die Organisationseinstellungen (Features/OrganizationSettings.ps1)
# -------------------------------------------------
$script:currentOrganizationConfig = $null

# -------------------------------------------------
# Kopfzeilen-Buttons (Einstellungen, Info, Schließen)
# -------------------------------------------------
try {
    # Versuche, die Buttons über ihre Namen zu finden
    $btnSettings = $script:Form.FindName("btnSettings")
    $btnInfo = $script:Form.FindName("btnInfo")
    $btnClose = $script:Form.FindName("btnClose")

    # Handler für Settings-Button
    if ($null -ne $btnSettings) {
        $btnSettings.Add_Click({ Show-SettingsWindow })
        Write-Log "Event-Handler für btnSettings hinzugefügt." -Type Info
    } else {
        Write-Log "Header Button 'btnSettings' nicht gefunden." -Type Warning
    }

    # Handler für Info-Button
    if ($null -ne $btnInfo) {
        $btnInfo.Add_Click({
            Write-Log "Button 'Info' geklickt." -Type Info
            # Hier später die Funktion Show-InfoDialog aufrufen
            $version = $script:AppVersion
            $appName = "easyEXO"
            try {
                 if ($null -ne $script:config -and $null -ne $script:config['General']) {
                    if ($script:config['General'].ContainsKey('AppName')) { $appName = $script:config['General']['AppName'] }
                 }
             } catch { Write-Log "Fehler beim Lesen der Version/AppName aus Config für Info-Dialog." -Type Warning }

             $infoText = @"
$appName - Version $version

Dieses Tool vereinfacht die Verwaltung gängiger Exchange Online Aufgaben über eine benutzerfreundliche grafische Oberfläche.
Es ermöglicht Administratoren und Helpdesk-Mitarbeitern, schnell und effizient Routineaufgaben durchzuführen, ohne komplexe PowerShell-Skripte manuell ausführen zu müssen.

(c) WWW.PHINIT.DE | Andreas Hepp | $(Get-Date -Format yyyy)
"@
             [System.Windows.MessageBox]::Show($infoText, "Über $appName", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        })
         Write-Log "Event-Handler für btnInfo hinzugefügt." -Type Info
    } else { Write-Log "Header Button 'btnInfo' nicht gefunden." -Type Warning }

    # Handler für Close-Button
    if ($null -ne $btnClose) {
        $btnClose.Add_Click({
            Write-Log "Button 'Close' geklickt." -Type Info
            # Hier später die Funktion Close-Application aufrufen
            try {
                if ($script:isConnected) {
                    Write-Log "Trenne Verbindung vor dem Schließen..." -Type Info
                    # Annahme: Disconnect-ExchangeOnlineSession existiert und funktioniert
                    Disconnect-ExchangeOnlineSession
                }
                Write-Log "Schließe Fenster..." -Type Info
                $script:Form.Close()
            } catch {
                 Write-Log "Fehler beim Schließen: $($_.Exception.Message)" -Type Error
                 # Notfall-Schließung
                 try { $script:Form.Close() } catch {}
            }
        })
        Write-Log "Event-Handler für btnClose hinzugefügt." -Type Info
    } else { Write-Log "Header Button 'btnClose' nicht gefunden." -Type Warning }

    Write-Log "Event-Handler für Header-Buttons erfolgreich registriert." -Type Info
} catch {
    # Fehler beim Finden der Buttons oder Registrieren der Handler
    Write-Log "Kritischer Fehler beim Registrieren der Header-Button-Handler: $($_.Exception.Message)" -Type Error
}

# -------------------------------------------------
# Arbeits-Overlay (UI/Busy.ps1) und Schutz vor dem Schließen während eines Vorgangs
# -------------------------------------------------
$null = Initialize-UIBusyOverlay
$script:Form.Add_Closing({
    param($closingSource, $e)
    if ($script:UIBusyDepth -gt 0) {
        # Während eine Abfrage läuft, nicht schließen, sondern den Vorgang abbrechen
        $e.Cancel = $true
        $script:UICancelRequested = $true
        Update-StatusBar -Message "Vorgang wird abgebrochen - bitte danach erneut schließen." -Type Warning
    }
})

# Event-Handler für das Loaded-Event des Formulars
$script:Form.Add_Loaded({
    Log-Action "GUI-Loaded-Event ausgelöst, initialisiere Komponenten"
    
    # Version anzeigen
    if ($null -ne $script:txtVersion) {
        try {
            if (-not [string]::IsNullOrWhiteSpace($script:AppVersion)) {
                $script:txtVersion.Text = "v$($script:AppVersion)"
            } else {
                Log-Action "Keine Versionsnummer gesetzt (`$script:AppVersion ist leer)."
            }
        } catch {
            Log-Action "Fehler beim Setzen der Version: $($_.Exception.Message)"
        }
    }
    
    # Copyright-Jahr in der Statusleiste aktuell halten
    $txtCopyright = Get-XamlElement -ElementName "txtCopyright"
    if ($null -ne $txtCopyright) {
        $txtCopyright.Text = "Copyright © $(Get-Date -Format yyyy)"
    }

    # Verbindungsstatus initialisieren
    if ($null -ne $script:txtConnectionStatus) {
        $script:txtConnectionStatus.Text = "Nicht verbunden"
        $script:txtConnectionStatus.Foreground = $script:disconnectedBrush
    }
    
    # Statusmeldung aktualisieren
    if ($null -ne $script:txtStatus) {
        $script:txtStatus.Text = "Bereit. Bitte stellen Sie eine Verbindung zu Exchange Online her."
    }
    
    # WICHTIG: UI initialisieren (startet den asynchronen Ladevorgang)
    $result = Initialize-ApplicationUI
    Log-Action "Initialize-ApplicationUI Ergebnis: $result"
    
    # Hilfe-Links initialisieren
    $result = Initialize-HelpLinks
    Log-Action "Initialize-HelpLinks Ergebnis: $result"
})

# -------------------------------------------------
# Fenster anzeigen
# -------------------------------------------------
try {
    Log-Action "Öffne GUI-Fenster"
    
    if ($null -eq $script:Form) {
        throw "Form-Objekt ist null"
    }
    
    $tabContent = $script:Form.FindName("tabContent")
    if ($null -eq $tabContent) {
        throw "TabControl nicht gefunden"
    }
    
    if ($null -eq $tabContent.Items) {
        throw "TabControl.Items ist null"
    }
    
    if ($tabContent.Items.Count -eq 0) {
        throw "TabControl enthält keine Tabs"
    }
    
    Log-Action "TabControl Status vor ShowDialog: Items=$($tabContent.Items.Count)"
    foreach ($item in $tabContent.Items) {
        Log-Action "Tab vorhanden: $($item.Name)"
    }
    
    [void]$script:Form.ShowDialog()
    Log-Action "GUI-Fenster wurde geschlossen"
}
catch {
    $errorMsg = $_.Exception.Message
    Write-Log "Kritischer Fehler beim Laden oder Anzeigen der GUI: $errorMsg"  
    Log-Action "Stack Trace: $($_.Exception.StackTrace)"
    
    # Falls die XAML-Datei nicht geladen werden kann, zeige einen alternativen Fehlerhinweis
    try {
        [System.Windows.MessageBox]::Show(
            "Kritischer Fehler beim Laden oder Anzeigen der GUI: $errorMsg`n`nBitte stellen Sie sicher, dass die XAML-Datei vorhanden und korrekt formatiert ist.", 
            "Fehler", 
            [System.Windows.MessageBoxButton]::OK, 
            [System.Windows.MessageBoxImage]::Error
        )
    }
    catch {
        Write-Log "Konnte keine MessageBox anzeigen. Zusätzlicher Fehler: $($_.Exception.Message)"  
    }
}
finally {
    # Aufräumarbeiten - Exchange-Verbindung auch im Fehlerfall sauber trennen
    if ($script:isConnected) {
        Log-Action "Trenne Exchange Online-Verbindung..."
        try { Disconnect-ExchangeOnlineSession | Out-Null } catch { Log-Action "Fehler beim Trennen der Verbindung: $($_.Exception.Message)" }
    }
    if ($null -ne $script:Form) {
        try {
            $script:Form.Close()
            $script:Form = $null
        } catch {
            Write-Log "Fehler beim Schließen des Formulars im finally-Block: $($_.Exception.Message)" -Type Warning
        }
    }
    Log-Action "Aufräumarbeiten abgeschlossen"
}
