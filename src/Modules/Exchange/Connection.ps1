# =====================================================================
# easyEXO - Modul: Exchange Online Verbindung (Verbinden, Trennen, Prüfen)
# Datei: src/Modules/Exchange/Connection.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# -------------------------------------------------
# Abschnitt: Exchange Online Verbindung
# -------------------------------------------------
function Connect-OwnExchangeOnline {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Verbindungsversuch zu Exchange Online..." -Type "Info"
        
        # Modul laden
        Import-Module ExchangeOnlineManagement -ErrorAction Stop
        
        # Variable für die E-Mail-Adresse im Skript-Bereich definieren
        $script:userPrincipalName = $null
        
        # Prüfen ob ein Standard-Benutzer in den Settings gespeichert ist
        $defaultUser = $null
        if ($null -ne $script:config -and $script:config.ContainsKey("General") -and $script:config["General"].ContainsKey("DefaultUser")) {
            $defaultUser = $script:config["General"]["DefaultUser"]
            if (-not [string]::IsNullOrWhiteSpace($defaultUser)) {
                Write-Log "Standard-Benutzer aus Settings gefunden: $defaultUser" -Type "Info"
                $script:userPrincipalName = $defaultUser
            }
        }
        
        # Nur wenn kein Standard-Benutzer vorhanden ist, Dialog anzeigen
        if ([string]::IsNullOrWhiteSpace($script:userPrincipalName)) {
            Write-Log "Kein Standard-Benutzer gefunden, zeige Anmeldedialog..." -Type "Info"
            
            # WPF-Fenster für die Benutzereingabe erstellen
            $inputXaml = @"
            <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                    Title="Exchange Online Anmeldung" Height="150" Width="400" WindowStartupLocation="CenterScreen">
                <Grid Margin="10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <Label Grid.Row="0" Content="EXO Administrativer Logins:"/>
                    <TextBox Grid.Row="1" Name="txtEmail" Margin="0,5"/>
                    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
                        <Button Name="btnOK" Content="OK" Width="75" Margin="0,0,5,0"/>
                        <Button Name="btnCancel" Content="Abbrechen" Width="75"/>
                    </StackPanel>
                </Grid>
            </Window>
"@
            
            $xmlDoc = New-Object System.Xml.XmlDocument
            $xmlDoc.LoadXml($inputXaml)
            $reader = New-Object System.Xml.XmlNodeReader $xmlDoc
            $window = [Windows.Markup.XamlReader]::Load($reader)
            
            $txtEmail = $window.FindName("txtEmail")
            $btnOK = $window.FindName("btnOK")
            $btnCancel = $window.FindName("btnCancel")
            
            $btnOK.Add_Click({
                if (-not [string]::IsNullOrWhiteSpace($txtEmail.Text)) {
                    $script:userPrincipalName = $txtEmail.Text
                    $window.DialogResult = $true
                    $window.Close()
                }
            })
            
            $btnCancel.Add_Click({
                $window.DialogResult = $false
                $window.Close()
            })
            
            $result = $window.ShowDialog()
            
            if (-not $result) {
                $errorMsg = "Anmeldung abgebrochen."
                Write-Log $errorMsg -Type "Warning"
                $null = Show-MessageBox -Message $errorMsg -Title "Abgebrochen" -Type "Warning"
                Update-StatusBar -Message "Anmeldung abgebrochen." -Type "Error"
                return $false
            }
            
            # Überprüfen, ob die E-Mail-Adresse erfolgreich gespeichert wurde
            if ([string]::IsNullOrWhiteSpace($script:userPrincipalName)) {
                $errorMsg = "Keine E-Mail-Adresse eingegeben oder erkannt. Verbindung abgebrochen."
                Write-Log $errorMsg -Type "Warning"
                $null = Show-MessageBox -Message $errorMsg -Title "Abgebrochen" -Type "Warning"
                Update-StatusBar -Message "Keine E-Mail-Adresse eingegeben oder erkannt. Verbindung abgebrochen." -Type "Warning"
                return $false
            }
        }

        # Verbindungsparameter für V3
        $connectParams = @{
            UserPrincipalName = $script:userPrincipalName
            ErrorAction = "Stop"
        }
        
        # Prüfen, ob der ShowBanner-Parameter unterstützt wird
        $cmdInfo = Get-Command -Name Connect-ExchangeOnline -Module ExchangeOnlineManagement -ErrorAction SilentlyContinue
        if ($cmdInfo -and $cmdInfo.Parameters.ContainsKey('ShowBanner')) {
            $connectParams.Add('ShowBanner', $false)
        }
        
        # Verbindung herstellen
        Write-Log "Versuche, Verbindung zu Exchange Online herzustellen für $script:userPrincipalName" -Type "Info"
        ExchangeOnlineManagement\Connect-ExchangeOnline @connectParams
        
        # Verbindung testen
        $null = Get-OrganizationConfig -ErrorAction Stop
        
        # Globale und Skript-Variablen setzen, um den Verbindungsstatus zu speichern
        $Global:IsConnectedToExo = $true
        $script:isConnected = $true
        
        Write-Log "Exchange Online Verbindung erfolgreich hergestellt für $script:userPrincipalName" -Type "Success"
        $script:txtConnectionStatus.Text = "Verbunden mit Exchange Online ($script:userPrincipalName)"
        $script:txtConnectionStatus.Foreground = $script:connectedBrush
        $script:LastConnectionCheck = [datetime]::UtcNow
        Update-ComplianceButtonState
        Update-StatusBar -Message "Exchange Online Verbindung erfolgreich hergestellt für $script:userPrincipalName" -Type "Success"
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Verbinden mit Exchange Online: $errorMsg" -Type "Error"
        $script:txtConnectionStatus.Text = "Nicht verbunden"
        $script:txtConnectionStatus.Foreground = $script:disconnectedBrush
        $Global:IsConnectedToExo = $false
        $script:isConnected = $false
        $null = Show-MessageBox -Message "Fehler beim Verbinden mit Exchange Online: $errorMsg" -Title "Verbindungsfehler" -Type "Error"
        Update-StatusBar -Message "Fehler beim Verbinden mit Exchange Online: $errorMsg" -Type "Error"
        return $false
    }
}

function Disconnect-ExchangeOnlineSession {
    [CmdletBinding()]
    param()
    
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Stop
        Log-Action "Exchange Online Verbindung getrennt"
        
        # Setze alle Verbindungsvariablen zurück (Disconnect-ExchangeOnline trennt auch die Compliance-Sitzung)
        $Global:IsConnectedToExo = $false
        $script:isConnected = $false
        $script:isComplianceConnected = $false
        $script:LastConnectionCheck = [datetime]::MinValue
        Update-ComplianceButtonState
        
        if ($null -ne $script:txtStatus) {
            $script:txtStatus.Text = "Exchange Verbindung getrennt"
        }
        if ($null -ne $script:txtConnectionStatus) {
            $script:txtConnectionStatus.Text = "Nicht verbunden"
            $script:txtConnectionStatus.Foreground = $script:disconnectedBrush
        }
        
        # Button-Status aktualisieren
        if ($null -ne $script:btnConnect) {
            $script:btnConnect.Content = "Mit Exchange verbinden"
            $script:btnConnect.Tag = "connect"
        }
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        if ($null -ne $script:txtStatus) {
            $script:txtStatus.Text = "Fehler beim Trennen der Verbindung: $errorMsg"
        }
        Log-Action "Fehler beim Trennen der Verbindung: $errorMsg"
        
        # Zeige Fehlermeldung an den Benutzer
        Write-Log "Fehler beim Trennen der Verbindung: $errorMsg" -Type "Error"
        $null = Show-MessageBox -Message "Fehler beim Trennen der Verbindung: $errorMsg" -Title "Fehler" -Type "Error"
        
        return $false
    }
}

# Funktion zur Überprüfung der Exchange Online-Verbindung.
# Ein erfolgreiches Ergebnis wird für $script:ConnectionCheckCacheSeconds zwischengespeichert, damit nicht
# jede Aktion einen zusätzlichen Roundtrip (früher Get-OrganizationConfig) zu Exchange Online auslöst.
$script:LastConnectionCheck = [datetime]::MinValue
$script:ConnectionCheckCacheSeconds = 120

function Confirm-ExchangeConnection {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Zwischenspeicher ignorieren und die Verbindung sofort prüfen
        [switch]$Force
    )
    
    try {
        if (-not ($Global:IsConnectedToExo -eq $true -or $script:isConnected -eq $true)) {
            return $false
        }

        if (-not $Force -and ([datetime]::UtcNow - $script:LastConnectionCheck).TotalSeconds -lt $script:ConnectionCheckCacheSeconds) {
            return $true
        }

        $connected = $false
        if (Get-Command -Name Get-ConnectionInformation -ErrorAction SilentlyContinue) {
            # Lokale Prüfung ohne Netzwerkzugriff (ExchangeOnlineManagement V3)
            $exoConnections = @(Get-ConnectionInformation -ErrorAction SilentlyContinue | Where-Object {
                $_.State -eq "Connected" -and -not $_.IsEopSession
            })
            $connected = $exoConnections.Count -gt 0
        }
        else {
            $null = Get-OrganizationConfig -ErrorAction Stop
            $connected = $true
        }

        if ($connected) {
            $Global:IsConnectedToExo = $true
            $script:isConnected = $true
            $script:LastConnectionCheck = [datetime]::UtcNow
            return $true
        }

        # Verbindung ist nicht mehr gültig, Status zurücksetzen
        $Global:IsConnectedToExo = $false
        $script:isConnected = $false
        $script:LastConnectionCheck = [datetime]::MinValue
        Write-Log "Exchange Online Verbindung ist nicht mehr aktiv." -Type "Warning"
        if ($null -ne $script:txtConnectionStatus) {
            $script:txtConnectionStatus.Text = "Nicht verbunden"
            $script:txtConnectionStatus.Foreground = $script:disconnectedBrush
        }
        return $false
    }
    catch {
        $Global:IsConnectedToExo = $false
        $script:isConnected = $false
        $script:LastConnectionCheck = [datetime]::MinValue
        Write-Log "Fehler bei der Überprüfung der Exchange Online-Verbindung: $($_.Exception.Message)" -Type "Error"
        return $false
    }
}

# -------------------------------------------------
# Abschnitt: Security & Compliance (Connect-IPPSSession)
# -------------------------------------------------
# Cmdlets, die aus der Compliance-Sitzung importiert werden. Die Einschränkung verhindert,
# dass gleichnamige Exchange-Online-Cmdlets der bestehenden Sitzung überschrieben werden.
$script:ComplianceCommandNames = @(
    "Get-RetentionCompliancePolicy",
    "Get-RetentionComplianceRule",
    "Get-DlpCompliancePolicy",
    "Get-DlpComplianceRule",
    "Set-DlpCompliancePolicy",
    "Get-Label",
    "Get-LabelPolicy",
    "Get-ComplianceCase",
    "New-ComplianceCase",
    "Get-CaseHoldPolicy"
)
$script:isComplianceConnected = $false

function Update-ComplianceButtonState {
    [CmdletBinding()]
    param()

    $button = $script:btnConnectCompliance
    if ($null -eq $button -and $null -ne $script:Form) { $button = $script:Form.FindName("btnConnectCompliance") }
    if ($null -eq $button) { return }

    $button.IsEnabled = ($script:isConnected -eq $true -and $script:isComplianceConnected -ne $true)
    $button.Content = if ($script:isComplianceConnected -eq $true) { "Compliance verbunden" } else { "Compliance verbinden" }
}

function Test-ComplianceConnection {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($script:isComplianceConnected -ne $true) { return $false }
    return [bool](Get-Command -Name "Get-DlpCompliancePolicy" -ErrorAction SilentlyContinue)
}

function Connect-OwnComplianceSession {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        if (-not (Confirm-ExchangeConnection)) {
            $null = Show-MessageBox -Message "Bitte verbinden Sie sich zuerst mit Exchange Online." -Title "Nicht verbunden" -Type "Warning"
            return $false
        }
        if (-not (Get-Command -Name Connect-IPPSSession -ErrorAction SilentlyContinue)) {
            throw "Connect-IPPSSession ist nicht verfügbar. Bitte das Modul ExchangeOnlineManagement aktualisieren."
        }

        $upn = $script:userPrincipalName
        if ([string]::IsNullOrWhiteSpace($upn) -and (Get-Command -Name Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
            $upn = [string](Get-ConnectionInformation -ErrorAction SilentlyContinue | Where-Object { -not $_.IsEopSession } | Select-Object -First 1 -ExpandProperty UserPrincipalName)
        }

        $connectParams = @{
            CommandName = $script:ComplianceCommandNames
            ErrorAction = "Stop"
        }
        if (-not [string]::IsNullOrWhiteSpace($upn)) { $connectParams["UserPrincipalName"] = $upn }
        $cmdInfo = Get-Command -Name Connect-IPPSSession -ErrorAction SilentlyContinue
        if ($cmdInfo -and $cmdInfo.Parameters.ContainsKey("ShowBanner")) { $connectParams["ShowBanner"] = $false }

        Write-Log "Verbinde mit Security & Compliance (Connect-IPPSSession) für $upn" -Type "Info"
        Update-StatusBar -Message "Verbinde mit Security & Compliance..." -Type Info
        Connect-IPPSSession @connectParams

        if (-not (Get-Command -Name "Get-DlpCompliancePolicy" -ErrorAction SilentlyContinue)) {
            throw "Die Compliance-Cmdlets wurden nach der Anmeldung nicht bereitgestellt."
        }

        $script:isComplianceConnected = $true
        Update-ComplianceButtonState
        Write-Log "Security & Compliance Verbindung hergestellt." -Type "Success"
        Log-Action "Security & Compliance Verbindung hergestellt ($upn)"
        Update-StatusBar -Message "Security & Compliance verbunden (DLP/Aufbewahrung verfügbar)." -Type Success
        return $true
    }
    catch {
        $script:isComplianceConnected = $false
        Update-ComplianceButtonState
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler bei Connect-IPPSSession: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Compliance-Verbindung fehlgeschlagen: $errorMsg" -Type Error
        $null = Show-MessageBox -Message "Die Verbindung zu Security & Compliance konnte nicht hergestellt werden:`n$errorMsg" -Title "Compliance-Verbindung" -Type "Error"
        return $false
    }
}

# Neue Funktion zum Aktualisieren der Domain-Liste
function Update-DomainList {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log  "Aktualisiere Domain-Liste für die ComboBox" -Type "Info"
        
        # Prüfen, ob die ComboBox existiert
        if ($null -eq $script:cmbSharedMailboxDomain) {
            $script:cmbSharedMailboxDomain = Get-XamlElement -ElementName "cmbSharedMailboxDomain"
            if ($null -eq $script:cmbSharedMailboxDomain) {
                Write-Log  "Domain-ComboBox nicht gefunden" -Type "Warning"
                return $false
            }
        }
        
        # Prüfen, ob eine Verbindung besteht
        if (-not $script:isConnected) {
            Write-Log  "Keine Exchange-Verbindung für Domain-Abfrage" -Type "Warning"
            return $false
        }
        
        # Domains abrufen und ComboBox befüllen
        $domains = Get-AcceptedDomain | Select-Object -ExpandProperty DomainName
        
        # Dispatcher verwenden für Thread-Sicherheit
        $script:cmbSharedMailboxDomain.Dispatcher.Invoke([Action]{
            $script:cmbSharedMailboxDomain.Items.Clear()
            foreach ($domain in $domains) {
                [void]$script:cmbSharedMailboxDomain.Items.Add($domain)
            }
            if ($script:cmbSharedMailboxDomain.Items.Count -gt 0) {
                $script:cmbSharedMailboxDomain.SelectedIndex = 0
            }
        }, "Normal")
        
        Write-Log  "Domain-Liste erfolgreich aktualisiert: $($domains.Count) Domains geladen" -Type "Success"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Aktualisieren der Domain-Liste: $errorMsg" -Type "Error"
        return $false
    }
}
