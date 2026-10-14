# =====================================================================
# easyEXO - Modul: Navigation, Hilfe-Links und Tab-Initialisierung
# Datei: src/Modules/UI/Navigation.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

##############TABSFUNKTIONEN####################

function Initialize-HelpLinks {
    [CmdletBinding()]
    param()
    
    try {
        
        # Da möglicherweise kein HelpLinks-Container existiert,
        # suche nach individuellen Hilfe-Links
        $helpLinks = @(
            $script:Form.FindName("helpLinkCalendar"),
            $script:Form.FindName("helpLinkMailbox"),
            $script:Form.FindName("helpLinkAudit"),
            $script:Form.FindName("helpLinkTroubleshooting")
        )
        
        $foundLinks = 0
        foreach ($link in $helpLinks) {
            if ($null -ne $link) {
                $foundLinks++
                $linkName = $link.Name
                $topic = "General"
                
                # Bestimme das Hilfe-Thema basierend auf dem Link-Namen
                switch -Wildcard ($linkName) {
                    "*Calendar*" { $topic = "Calendar" }
                    "*Mailbox*" { $topic = "Mailbox" }
                    "*Audit*" { $topic = "Audit" }
                    "*Trouble*" { $topic = "Troubleshooting" }
                }
                
                # Topic im Tag hinterlegen. Die Klick-Handler (Show-HelpDialog) werden in den jeweiligen
                # Tab-Initialisierungen registriert - hier bewusst kein zweiter Handler (sonst doppelte Dialoge).
                $link.Tag = $topic
                
            }
        }
        
        if ($foundLinks -eq 0) {
            return $false
        }
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Log-Action "Fehler beim Initialisieren der Hilfe-Links: $errorMsg"
        return $false
    }
}

    # --- Ende Header Button Event Handlers ---

function Set-ActiveNavigationButton {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ButtonName
    )
    
    try {
        Write-Log "Setze aktiven Navigation-Button: $ButtonName" -Type "Debug"
        
        # Liste aller Navigation-Buttons
        $navigationButtons = @(
            'btnDashboard',
            'btnNavCalendar', 'btnNavMailbox', 'btnNavSharedMailbox', 'btnNavGroups', 'btnNavResources', 'btnNavContacts',
            'btnNavMailFlowRules', 'btnNavInboxRules', 'btnNavMessageTrace', 'btnNavAutoReply',
            'btnNavATP', 'btnNavDLP', 'btnNavEDiscovery', 'btnNavMDM',
            'btnNavEXOSettings', 'btnNavRegion', 'btnNavCrossPremises',
            'btnNavHybridExchange', 'btnNavMultiForest',
            'btnNavHealthCheck', 'btnNavAudit', 'btnNavReports', 'btnNavTroubleshooting'
        )
        
        # Alle Navigation-Buttons auf Standard-Style zurücksetzen
        foreach ($btnName in $navigationButtons) {
            $button = $script:Form.FindName($btnName)
            if ($null -ne $button) {
                try {
                    # Standard-Darstellung über den Theme-Style (NavButton) - keine lokalen Farben setzen
                    $button.Dispatcher.Invoke([Action]{
                        $button.Tag = $null
                    }, "Normal")
                }
                catch {
                    Write-Log "Fehler beim Zurücksetzen von Button $btnName - $($_.Exception.Message)" -Type "Warning"
                }
            }
        }
        
        # Aktiven Button hervorheben
        $activeButton = $script:Form.FindName($ButtonName)
        if ($null -ne $activeButton) {
            try {
                # Hervorhebung erfolgt über den Style-Trigger Tag="Active" (siehe GUI/Theme.xaml)
                $activeButton.Dispatcher.Invoke([Action]{
                    $activeButton.Tag = "Active"
                }, "Normal")
                
                Write-Log "Navigation-Button '$ButtonName' als aktiv markiert" -Type "Debug"
            }
            catch {
                Write-Log "Fehler beim Hervorheben von Button $ButtonName - $($_.Exception.Message)" -Type "Warning"
            }
        }
        else {
            Write-Log "Aktiver Navigation-Button '$ButtonName' nicht gefunden" -Type "Warning"
        }
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler in Set-ActiveNavigationButton: $errorMsg" -Type "Error"
        return $false
    }
}

function Initialize-TabNavigation {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Initialisiere Tab-Navigation..." -Type "Info"
        
        $tabControl = $script:Form.FindName("tabContent")
        if ($null -eq $tabControl) {
            Write-Log "TabControl 'tabContent' nicht gefunden" -Type "Error"
            return $false
        }
        
        # WICHTIG: Verstecke alle Tab-Header
        $tabControl.Dispatcher.Invoke([Action]{
            foreach ($tabItem in $tabControl.Items) {
                if ($tabItem -is [System.Windows.Controls.TabItem]) {
                    # Setze Header auf null oder leer
                    $tabItem.Header = $null
                    # Oder: $tabItem.Visibility = [System.Windows.Visibility]::Collapsed
                }
            }
        }, "Normal")
        
        # Tab-Mapping für Navigation-Buttons zu TabItem-Namen
        $script:tabMapping = @{
            # Dashboard
            'btnDashboard' = 'tabDashboard'
            
            # Grundlegende Verwaltung
            'btnNavCalendar' = 'tabCalendar'
            'btnNavMailbox' = 'tabMailbox'
            'btnNavSharedMailbox' = 'tabSharedMailbox'
            'btnNavGroups' = 'tabGroups'
            'btnNavResources' = 'tabResources'
            'btnNavContacts' = 'tabContacts'
            
            # Mail Flow
            'btnNavMailFlowRules' = 'tabMailFlowRules'
            'btnNavInboxRules' = 'tabInboxRules'
            'btnNavMessageTrace' = 'tabMessageTrace'
            'btnNavAutoReply' = 'tabAutoReply'
            
            # Sicherheit & Compliance
            'btnNavATP' = 'tab_ATP'
            'btnNavDLP' = 'tab_DLP'
            'btnNavEDiscovery' = 'tab_eDiscovery'
            'btnNavMDM' = 'tab_MDM'
            
            # Systemkonfiguration
            'btnNavEXOSettings' = 'tabEXOSettings'
            'btnNavRegion' = 'tabRegion'
            'btnNavCrossPremises' = 'tab_MailRouting'
            
            # Erweiterte Verwaltung
            'btnNavHybridExchange' = 'tab_HybridExchange'
            'btnNavMultiForest' = 'tab_MultiForest'
            
            # Monitoring & Support
            'btnNavHealthCheck' = 'tab_HealthCheck'
            'btnNavAudit' = 'tabMailboxAudit'
            'btnNavReports' = 'tabReports'
            'btnNavTroubleshooting' = 'tabTroubleshooting'
        }
        
  
        # Event-Handler registrieren...
        foreach ($btnName in $script:tabMapping.Keys) {
            $button = $script:Form.FindName($btnName)
            $targetTabName = $script:tabMapping[$btnName]
            
            if ($null -ne $button) {
                $targetTabItem = $null
                foreach ($tabItem in $tabControl.Items) {
                    if ($tabItem.Name -eq $targetTabName) {
                        $targetTabItem = $tabItem
                        break
                    }
                }
                
                if ($null -ne $targetTabItem) {
                    $button.Add_Click({
                        param($sender, $e)
                        try {
                            $clickedButton = $sender
                            $buttonName = $clickedButton.Name
                            $targetTabName = $script:tabMapping[$buttonName]
                            
                            $tc = $script:Form.FindName("tabContent")
                            if ($null -ne $tc) {
                                foreach ($item in $tc.Items) {
                                    if ($item.Name -eq $targetTabName) {
                                        $tc.SelectedItem = $item
                                        Set-ActiveNavigationButton -ButtonName $buttonName
                                        break
                                    }
                                }
                            }
                        }
                        catch {
                            Write-Log "Fehler bei Tab-Navigation: $($_.Exception.Message)" -Type "Error"
                        }
                    })
                }
            }
        }
        
        # Initial ersten Tab auswählen
        if ($tabControl.Items.Count -gt 0) {
            $tabControl.SelectedIndex = 0
        }
        
        Write-Log "Tab-Navigation erfolgreich initialisiert" -Type "Success"
        return $true
    }
    catch {
        Write-Log "Fehler bei Tab-Navigation Initialisierung: $($_.Exception.Message)" -Type "Error"
        return $false
    }
}

# Initialisiert die wesentliche UI und startet die asynchrone Initialisierung der restlichen Tabs
function Initialize-ApplicationUI {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Initialisiere wesentliche UI-Komponenten..." -Type "Info"

        # 1. Tab-Navigation initialisieren, damit die Buttons funktionieren
        $navResult = Initialize-TabNavigation
        if (-not $navResult) {
            Write-Log "Kritisch: Tab-Navigation konnte nicht initialisiert werden. Abbruch." -Type "Error"
            return $false
        }
        Write-Log "Tab-Navigation erfolgreich initialisiert." -Type "Success"

        # 2. Dashboard-Tab als Start-Tab festlegen
        $tabControl = $script:Form.FindName("tabContent")
        $dashboardTab = $script:Form.FindName("tabDashboard")
        if ($null -ne $tabControl -and $null -ne $dashboardTab) {
            $tabControl.SelectedItem = $dashboardTab
            Set-ActiveNavigationButton -ButtonName 'btnDashboard'
            Write-Log "Dashboard-Tab als Startansicht festgelegt." -Type "Info"
        } else {
            Write-Log "Dashboard-Tab oder Haupt-TabControl nicht gefunden. Kann Startansicht nicht festlegen." -Type "Warning"
        }

        # 3. Asynchrone Initialisierung der restlichen Tabs über Background-Job starten
        Start-AsyncTabInitialization
        
        return $true
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler bei der Initialisierung der Anwendungs-UI."
        Write-Log $errorMsg -Type "Error"
        return $false
    }
}

# Initialisiert die restlichen Tabs im Hintergrund über einen separaten Thread
# Zentrale Liste aller Tab-Initialisierungen (Name -> Funktion), von
# Initialize-RemainingTabs und Start-AsyncTabInitialization gemeinsam genutzt.
$script:TabInitializers = [ordered]@{
    EXOSettings     = "Initialize-EXOSettingsTab"
    Calendar        = "Initialize-CalendarTab"
    Mailbox         = "Initialize-MailboxTab"
    Audit           = "Initialize-AuditTab"
    Troubleshooting = "Initialize-TroubleshootingTab"
    Groups          = "Initialize-GroupsTab"
    SharedMailbox   = "Initialize-SharedMailboxTab"
    Contacts        = "Initialize-ContactsTab"
    Resources       = "Initialize-ResourcesTab"
    Reports         = "Initialize-ReportsTab"
    RegionSettings  = "Initialize-RegionSettingsTab"
    MailFlowRules   = "Initialize-MailFlowRulesTab"
    InboxRules      = "Initialize-InboxRulesTab"
    MessageTrace    = "Initialize-MessageTraceTab"
    AutoReply       = "Initialize-AutoReplyTab"
    HealthCheck     = "Initialize-HealthCheckTab"
    CrossPremises   = "Initialize-CrossPremisesTab"
    ATP             = "Initialize-ATPTab"
    DLP             = "Initialize-DLPTab"
    eDiscovery      = "Initialize-eDiscoveryTab"
    MDM             = "Initialize-MDMTab"
    HybridExchange  = "Initialize-HybridExchangeTab"
    MultiForest     = "Initialize-MultiForestTab"
}

# Führt alle Tab-Initialisierungen aus; ein Fehler in einem Tab hält die übrigen nicht auf.
function Invoke-TabInitializers {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $results = @{}
    foreach ($entry in $script:TabInitializers.GetEnumerator()) {
        try {
            if (-not (Get-Command -Name $entry.Value -CommandType Function -ErrorAction SilentlyContinue)) {
                Write-Log "Initialisierungsfunktion nicht gefunden: $($entry.Value)" -Type "Warning"
                $results[$entry.Key] = $false
                continue
            }
            $results[$entry.Key] = ((@(& $entry.Value) | Select-Object -Last 1) -eq $true)
        }
        catch {
            Write-Log "Fehler bei der Initialisierung von $($entry.Key): $($_.Exception.Message)" -Type "Error"
            $results[$entry.Key] = $false
        }
    }
    return $results
}

function Initialize-RemainingTabs {
    [CmdletBinding()]
    param()

    Write-Log "Beginne mit der Initialisierung der verbleibenden Tabs." -Type "Info"
    
    # Status über Dispatcher aktualisieren
    $script:Form.Dispatcher.Invoke([Action]{
        Update-StatusBar -Message "Lade Module im Hintergrund..."
    }, "Background")

    $results = Invoke-TabInitializers

    $successCount = ($results.Values | Where-Object { $_ -eq $true }).Count
    $totalCount = $results.Count
    $failedTabs = ($results.Keys | Where-Object { $results[$_] -eq $false }) -join ", "

    Write-Log "Zusammenfassung der Tab-Initialisierung:" -Type "Info"
    foreach ($tab in $results.Keys | Sort-Object) {
        $status = if ($results[$tab]) { "Erfolgreich" } else { "Fehlgeschlagen" }
        Write-Log "- $tab`: $status" -Type "Debug"
    }

    # Status über Dispatcher aktualisieren
    $script:Form.Dispatcher.Invoke([Action]{
        if ($successCount -eq $totalCount) {
            Update-StatusBar -Message "Alle Module erfolgreich geladen - Bereit - Bitte mit Exchange Online verbinden." -Type "Success"
            Write-Log "Alle Tabs wurden erfolgreich initialisiert." -Type "Success"
        } else {
            Update-StatusBar -Message "Einige Module konnten nicht geladen werden. Details im Log." -Type "Warning"
            Write-Log "Initialisierung für folgende Tabs fehlgeschlagen: $failedTabs" -Type "Warning"
        }
    }, "Background")
}

function Start-AsyncTabInitialization {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Starte asynchrone Tab-Initialisierung..." -Type "Info"
        
        # Statt Runspace verwenden wir die echte Initialisierung direkt
        # aber in einem Background-Thread über Dispatcher
        $script:Form.Dispatcher.BeginInvoke([Action]{
            try {
                Write-Log "Beginne synchrone Tab-Initialisierung im Hintergrund..." -Type "Debug"
                
                $results = Invoke-TabInitializers
                
                $successCount = ($results.Values | Where-Object { $_ -eq $true }).Count
                $totalCount = $results.Count
                $failedTabs = ($results.Keys | Where-Object { $results[$_] -eq $false }) -join ", "
                
                Write-Log "Tab-Initialisierung abgeschlossen: $successCount/$totalCount erfolgreich" -Type "Info"
                
                if ($successCount -eq $totalCount) {
                    Update-StatusBar -Message "Alle Module erfolgreich geladen - Bereit - Bitte mit Exchange Online verbinden." -Type "Success"
                    Write-Log "Alle Tabs wurden erfolgreich initialisiert." -Type "Success"
                } else {
                    Update-StatusBar -Message "Einige Module konnten nicht geladen werden. Details im Log." -Type "Warning"
                    Write-Log "Initialisierung für folgende Tabs fehlgeschlagen: $failedTabs" -Type "Warning"
                }
                
                # Detailliertes Logging
                foreach ($tab in $results.Keys | Sort-Object) {
                    $status = if ($results[$tab]) { "Erfolgreich" } else { "Fehlgeschlagen" }
                    Write-Log "- $tab`: $status" -Type "Debug"
                }
                
            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler bei der Tab-Initialisierung."
                Write-Log $errorMsg -Type "Error"
                Update-StatusBar -Message "Fehler beim Laden der Module." -Type "Error"
            }
        }, [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null
        
        Write-Log "Asynchrone Tab-Initialisierung gestartet" -Type "Success"
        return $true
        
    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Starten der asynchronen Tab-Initialisierung."
        Write-Log $errorMsg -Type "Error"
        
        # Fallback: Direkte synchrone Initialisierung
        try {
            Write-Log "Fallback: Starte direkte Tab-Initialisierung..." -Type "Warning"
            Update-StatusBar -Message "Lade Module direkt..." -Type "Warning"
            Initialize-RemainingTabs
            return $true
        } catch {
            $fallbackError = Get-FormattedError -ErrorRecord $_ -DefaultText "Auch direkte Tab-Initialisierung fehlgeschlagen."
            Write-Log $fallbackError -Type "Error"
            Update-StatusBar -Message "Fehler beim Laden der Module." -Type "Error"
            return $false
        }
    }
}
