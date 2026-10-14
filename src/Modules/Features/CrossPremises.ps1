# =====================================================================
# easyEXO - Modul: Mail-Routing / Connectors / Domänen (Cross-Premises)
# Datei: src/Modules/Features/CrossPremises.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# -------------------------------------------------
# Abschnitt: Cross-Premises-Funktionen
# -------------------------------------------------

# Lädt und zeigt Mail-Connectors an
function Get-MailConnectors {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Lade Mail-Connectors..." -Type "Info"
        
        # Prüfe Exchange Online Verbindung
        if (-not $script:isConnected) {
            Write-Log "Keine Exchange Online Verbindung verfügbar" -Type "Error"
            [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Verbindung erforderlich", "OK", "Warning")
            return
        }

        # DataGrid für Connectors finden
        $dgConnectors = $script:Form.FindName("dgConnectors")
        
        if ($null -eq $dgConnectors) {
            Write-Log "DataGrid für Connectors nicht gefunden" -Type "Warning"
            return
        }

        # Connectors abrufen (Fehler werden im catch-Block gemeldet)
        $connectors = @(Get-InboundConnector -ErrorAction Stop)
        $outboundConnectors = @(Get-OutboundConnector -ErrorAction Stop)
        
        # Alle Connectors zusammenfassen
        $allConnectors = @()
        
        if ($connectors) {
            foreach ($connector in $connectors) {
                $allConnectors += [PSCustomObject]@{
                    Name = $connector.Name
                    Type = "Inbound"
                    Enabled = $connector.Enabled
                    SenderDomains = ($connector.SenderDomains -join ", ")
                    TlsSenderCertificateName = $connector.TlsSenderCertificateName
                }
            }
        }
        
        if ($outboundConnectors) {
            foreach ($connector in $outboundConnectors) {
                $allConnectors += [PSCustomObject]@{
                    Name = $connector.Name
                    Type = "Outbound"
                    Enabled = $connector.Enabled
                    RecipientDomains = ($connector.RecipientDomains -join ", ")
                    SmartHosts = ($connector.SmartHosts -join ", ")
                }
            }
        }

        $dgConnectors.ItemsSource = $allConnectors
        Write-Log "Mail-Connectors erfolgreich geladen ($($allConnectors.Count) Connectors)" -Type "Success"
        Update-StatusBar -Message "Mail-Connectors geladen"
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Laden der Mail-Connectors."
        Write-Log $errorMsg -Type "Error"
        [System.Windows.MessageBox]::Show($errorMsg, "Fehler", "OK", "Error")
        Update-StatusBar -Message "Fehler beim Laden der Mail-Connectors"
    }
}

# Ändert den Status eines Connectors
function Set-ConnectorStatus {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Ändere Connector-Status..." -Type "Info"
        
        # Prüfe Exchange Online Verbindung
        if (-not $script:isConnected) {
            Write-Log "Keine Exchange Online Verbindung verfügbar" -Type "Error"
            [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Verbindung erforderlich", "OK", "Warning")
            return
        }

        # DataGrid für Connectors finden
        $dgConnectors = $script:Form.FindName("dgConnectors")
        
        if ($null -eq $dgConnectors -or $null -eq $dgConnectors.SelectedItem) {
            [System.Windows.MessageBox]::Show("Bitte wählen Sie einen Connector aus der Liste aus.", "Kein Connector ausgewählt", "OK", "Warning")
            return
        }

        $selectedConnector = $dgConnectors.SelectedItem
        $newStatus = -not $selectedConnector.Enabled
        
        # Bestätigung anfordern
        $statusText = if ($newStatus) { "aktivieren" } else { "deaktivieren" }
        $result = [System.Windows.MessageBox]::Show("Möchten Sie den Connector '$($selectedConnector.Name)' wirklich $($statusText)?", "Status ändern", "YesNo", "Question")
        
        if ($result -eq "Yes") {
            if ($selectedConnector.Type -eq "Inbound") {
                Set-InboundConnector -Identity $selectedConnector.Name -Enabled $newStatus -ErrorAction Stop
            } else {
                Set-OutboundConnector -Identity $selectedConnector.Name -Enabled $newStatus -ErrorAction Stop
            }
            
            Write-Log "Connector-Status erfolgreich geändert: $($selectedConnector.Name) -> $newStatus" -Type "Success"
            [System.Windows.MessageBox]::Show("Connector-Status wurde erfolgreich geändert.", "Status geändert", "OK", "Information")
            
            # Liste aktualisieren
            Get-MailConnectors
        }

        Update-StatusBar -Message "Connector-Status-Änderung abgeschlossen"
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Ändern des Connector-Status."
        Write-Log $errorMsg -Type "Error"
        [System.Windows.MessageBox]::Show($errorMsg, "Fehler", "OK", "Error")
        Update-StatusBar -Message "Fehler beim Ändern des Connector-Status"
    }
}

# Lädt und zeigt akzeptierte Domänen an
function Get-AcceptedDomainsList {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Lade akzeptierte Domänen..." -Type "Info"
        
        # Prüfe Exchange Online Verbindung
        if (-not $script:isConnected) {
            Write-Log "Keine Exchange Online Verbindung verfügbar" -Type "Error"
            [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Verbindung erforderlich", "OK", "Warning")
            return
        }

        # DataGrid für Accepted Domains finden
        $dgAcceptedDomains = $script:Form.FindName("dgAcceptedDomains")
        
        if ($null -eq $dgAcceptedDomains) {
            Write-Log "DataGrid für akzeptierte Domänen nicht gefunden" -Type "Warning"
            return
        }

        # Akzeptierte Domänen abrufen
        $acceptedDomains = Get-AcceptedDomain -ErrorAction Stop
        
        # Daten für die Anzeige aufbereiten
        $domainsForGrid = @(foreach ($domain in $acceptedDomains) {
            [PSCustomObject]@{
                Name = $domain.Name
                DomainName = $domain.DomainName
                DomainType = $domain.DomainType
                Default = $domain.Default
                InitialDomain = $domain.InitialDomain
                AuthenticationType = $domain.AuthenticationType
            }
        })

        $dgAcceptedDomains.ItemsSource = $domainsForGrid
        Write-Log "Akzeptierte Domänen erfolgreich geladen ($($domainsForGrid.Count) Domänen)" -Type "Success"
        Update-StatusBar -Message "Akzeptierte Domänen geladen"
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Laden der akzeptierten Domänen."
        Write-Log $errorMsg -Type "Error"
        [System.Windows.MessageBox]::Show($errorMsg, "Fehler", "OK", "Error")
        Update-StatusBar -Message "Fehler beim Laden der akzeptierten Domänen"
    }
}

# Lädt und zeigt Remote-Domänen an
function Get-RemoteDomainsList {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Lade Remote-Domänen..." -Type "Info"
        
        # Prüfe Exchange Online Verbindung
        if (-not $script:isConnected) {
            Write-Log "Keine Exchange Online Verbindung verfügbar" -Type "Error"
            [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Verbindung erforderlich", "OK", "Warning")
            return
        }

        # DataGrid für Remote Domains finden
        $dgRemoteDomains = $script:Form.FindName("dgRemoteDomains")
        
        if ($null -eq $dgRemoteDomains) {
            Write-Log "DataGrid für Remote-Domänen nicht gefunden" -Type "Warning"
            return
        }

        # Remote-Domänen abrufen
        $remoteDomains = Get-RemoteDomain -ErrorAction Stop
        
        # Daten für die Anzeige aufbereiten - als Array statt einzelne PSCustomObjects
        $domainsForGrid = @()
        foreach ($domain in $remoteDomains) {
            $domainsForGrid += [PSCustomObject]@{
                Name = $domain.Name
                DomainName = $domain.DomainName
                AllowedOOFType = $domain.AllowedOOFType
                AutoReplyEnabled = $domain.AutoReplyEnabled
                AutoForwardEnabled = $domain.AutoForwardEnabled
                DeliveryReportEnabled = $domain.DeliveryReportEnabled
                NDREnabled = $domain.NDREnabled
                CharacterSet = $domain.CharacterSet
            }
        }

        # ItemsSource als Array zuweisen um IEnumerable-Konvertierungsfehler zu vermeiden
        $dgRemoteDomains.ItemsSource = $domainsForGrid
        Write-Log "Remote-Domänen erfolgreich geladen ($($domainsForGrid.Count) Domänen)" -Type "Success"
        Update-StatusBar -Message "Remote-Domänen geladen"
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Laden der Remote-Domänen."
        Write-Log $errorMsg -Type "Error"
        [System.Windows.MessageBox]::Show($errorMsg, "Fehler", "OK", "Error")
        Update-StatusBar -Message "Fehler beim Laden der Remote-Domänen"
    }
}

# Funktion zum Hinzufügen eines neuen Connectors
function Add-NewConnector {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Öffne Dialog zum Hinzufügen eines neuen Connectors" -Type "Info"
        
        # Prüfe Exchange Online Verbindung
        if (-not $script:isConnected) {
            Write-Log "Keine Exchange Online Verbindung verfügbar" -Type "Error"
            [System.Windows.MessageBox]::Show("Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her.", "Verbindung erforderlich", "OK", "Warning")
            return
        }

        # XAML für das Connector-Dialog-Fenster
        $xamlConnectorDialog = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Neuen Connector hinzufügen" Height="600" Width="800"
        WindowStartupLocation="CenterOwner" ResizeMode="CanResize">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Header -->
        <TextBlock Grid.Row="0" Text="Neuen Mail-Connector erstellen" FontSize="16" FontWeight="Bold" Margin="0,0,0,15"/>
        
        <!-- Main Content -->
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <!-- Connector-Typ -->
                <GroupBox Header="Connector-Typ" Margin="0,0,0,10">
                    <StackPanel Margin="10">
                        <RadioButton x:Name="rbInbound" Content="Inbound Connector (Eingehend)" IsChecked="True" Margin="0,5"/>
                        <RadioButton x:Name="rbOutbound" Content="Outbound Connector (Ausgehend)" Margin="0,5"/>
                    </StackPanel>
                </GroupBox>
                
                <!-- Grundeinstellungen -->
                <GroupBox Header="Grundeinstellungen" Margin="0,0,0,10">
                    <Grid Margin="10">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="150"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        
                        <Label Grid.Row="0" Grid.Column="0" Content="Name:" VerticalAlignment="Center"/>
                        <TextBox x:Name="txtConnectorName" Grid.Row="0" Grid.Column="1" Margin="5"/>
                        
                        <Label Grid.Row="1" Grid.Column="0" Content="Beschreibung:" VerticalAlignment="Top"/>
                        <TextBox x:Name="txtDescription" Grid.Row="1" Grid.Column="1" Margin="5" Height="60" TextWrapping="Wrap" AcceptsReturn="True"/>
                        
                        <Label Grid.Row="2" Grid.Column="0" Content="Aktiviert:" VerticalAlignment="Center"/>
                        <CheckBox x:Name="chkEnabled" Grid.Row="2" Grid.Column="1" IsChecked="True" Margin="5" VerticalAlignment="Center"/>
                        
                        <Label Grid.Row="3" Grid.Column="0" Content="Connector-Typ:" VerticalAlignment="Center"/>
                        <ComboBox x:Name="cmbConnectorType" Grid.Row="3" Grid.Column="1" Margin="5">
                            <ComboBoxItem Content="Partner" Tag="Partner"/>
                            <ComboBoxItem Content="OnPremises" Tag="OnPremises"/>
                        </ComboBox>
                    </Grid>
                </GroupBox>
                
                <!-- Inbound-spezifische Einstellungen -->
                <GroupBox x:Name="grpInbound" Header="Inbound Connector Einstellungen" Margin="0,0,0,10">
                    <Grid Margin="10">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="150"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        
                        <Label Grid.Row="0" Grid.Column="0" Content="Sender-Domänen:" VerticalAlignment="Top"/>
                        <TextBox x:Name="txtSenderDomains" Grid.Row="0" Grid.Column="1" Margin="5" Height="60" TextWrapping="Wrap" AcceptsReturn="True" 
                                 ToolTip="Eine Domäne pro Zeile eingeben (z.B. contoso.com), * für alle Domänen (Pflichtfeld)"/>
                        
                        <Label Grid.Row="1" Grid.Column="0" Content="Sender-IP-Adressen:" VerticalAlignment="Top"/>
                        <TextBox x:Name="txtSenderIPAddresses" Grid.Row="1" Grid.Column="1" Margin="5" Height="60" TextWrapping="Wrap" AcceptsReturn="True"
                                 ToolTip="Eine IP-Adresse oder IP-Bereich pro Zeile (z.B. 192.168.1.1 oder 192.168.1.0/24)"/>
                        
                        <Label Grid.Row="2" Grid.Column="0" Content="TLS erforderlich:" VerticalAlignment="Center"/>
                        <CheckBox x:Name="chkRequireTls" Grid.Row="2" Grid.Column="1" Margin="5" VerticalAlignment="Center"/>
                        
                        <Label Grid.Row="3" Grid.Column="0" Content="TLS-Zertifikat:" VerticalAlignment="Center"/>
                        <TextBox x:Name="txtTlsCertificate" Grid.Row="3" Grid.Column="1" Margin="5" 
                                 ToolTip="TLS-Zertifikat-Name (optional)"/>
                        
                        <Label Grid.Row="4" Grid.Column="0" Content="Behandlung als:" VerticalAlignment="Center"/>
                        <ComboBox x:Name="cmbTreatMessagesAs" Grid.Row="4" Grid.Column="1" Margin="5">
                            <ComboBoxItem Content="Internal" Tag="Internal"/>
                            <ComboBoxItem Content="External" Tag="External"/>
                        </ComboBox>
                    </Grid>
                </GroupBox>
                
                <!-- Outbound-spezifische Einstellungen -->
                <GroupBox x:Name="grpOutbound" Header="Outbound Connector Einstellungen" Margin="0,0,0,10" Visibility="Collapsed">
                    <Grid Margin="10">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="150"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        
                        <Label Grid.Row="0" Grid.Column="0" Content="Empfänger-Domänen:" VerticalAlignment="Top"/>
                        <TextBox x:Name="txtRecipientDomains" Grid.Row="0" Grid.Column="1" Margin="5" Height="60" TextWrapping="Wrap" AcceptsReturn="True"
                                 ToolTip="Eine Domäne pro Zeile eingeben (z.B. contoso.com)"/>
                        
                        <Label Grid.Row="1" Grid.Column="0" Content="Smart Hosts:" VerticalAlignment="Top"/>
                        <TextBox x:Name="txtSmartHosts" Grid.Row="1" Grid.Column="1" Margin="5" Height="60" TextWrapping="Wrap" AcceptsReturn="True"
                                 ToolTip="FQDN oder IP-Adresse der Ziel-Server (eine pro Zeile)"/>
                        
                        <Label Grid.Row="2" Grid.Column="0" Content="TLS-Einstellungen:" VerticalAlignment="Center"/>
                        <ComboBox x:Name="cmbTlsSettings" Grid.Row="2" Grid.Column="1" Margin="5">
                            <ComboBoxItem Content="EncryptionOnly" Tag="EncryptionOnly"/>
                            <ComboBoxItem Content="CertificateValidation" Tag="CertificateValidation"/>
                            <ComboBoxItem Content="DomainValidation" Tag="DomainValidation"/>
                        </ComboBox>
                        
                        <Label Grid.Row="3" Grid.Column="0" Content="TLS-Domäne:" VerticalAlignment="Center"/>
                        <TextBox x:Name="txtTlsDomain" Grid.Row="3" Grid.Column="1" Margin="5"
                                 ToolTip="Domäne für die TLS-Validierung (nur bei DomainValidation, dort erforderlich)"/>
                        
                        <Label Grid.Row="4" Grid.Column="0" Content="Test-Modus:" VerticalAlignment="Center"/>
                        <CheckBox x:Name="chkTestMode" Grid.Row="4" Grid.Column="1" Margin="5" VerticalAlignment="Center"
                                  ToolTip="Connector im Test-Modus erstellen"/>
                    </Grid>
                </GroupBox>
            </StackPanel>
        </ScrollViewer>
        
        <!-- Buttons -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,15,0,0">
            <Button x:Name="btnCreate" Content="Connector erstellen" Width="120" Height="30" Margin="0,0,10,0"/>
            <Button x:Name="btnCancel" Content="Abbrechen" Width="80" Height="30"/>
        </StackPanel>
    </Grid>
</Window>
"@

        # XAML laden
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xamlConnectorDialog)
        $connectorWindow = [Windows.Markup.XamlReader]::Load($reader)
        $null = Add-ThemeResource -Window $connectorWindow
        
        # UI-Elemente referenzieren
        $rbInbound = $connectorWindow.FindName("rbInbound")
        $rbOutbound = $connectorWindow.FindName("rbOutbound")
        $grpInbound = $connectorWindow.FindName("grpInbound")
        $grpOutbound = $connectorWindow.FindName("grpOutbound")
        $txtConnectorName = $connectorWindow.FindName("txtConnectorName")
        $txtDescription = $connectorWindow.FindName("txtDescription")
        $chkEnabled = $connectorWindow.FindName("chkEnabled")
        $cmbConnectorType = $connectorWindow.FindName("cmbConnectorType")
        $btnCreate = $connectorWindow.FindName("btnCreate")
        $btnCancel = $connectorWindow.FindName("btnCancel")
        
        # Inbound-Elemente
        $txtSenderDomains = $connectorWindow.FindName("txtSenderDomains")
        $txtSenderIPAddresses = $connectorWindow.FindName("txtSenderIPAddresses")
        $chkRequireTls = $connectorWindow.FindName("chkRequireTls")
        $txtTlsCertificate = $connectorWindow.FindName("txtTlsCertificate")
        $cmbTreatMessagesAs = $connectorWindow.FindName("cmbTreatMessagesAs")
        
        # Outbound-Elemente
        $txtRecipientDomains = $connectorWindow.FindName("txtRecipientDomains")
        $txtSmartHosts = $connectorWindow.FindName("txtSmartHosts")
        $cmbTlsSettings = $connectorWindow.FindName("cmbTlsSettings")
        $txtTlsDomain = $connectorWindow.FindName("txtTlsDomain")
        $chkTestMode = $connectorWindow.FindName("chkTestMode")
        
        # Standardwerte setzen
        $cmbConnectorType.SelectedIndex = 0
        $cmbTreatMessagesAs.SelectedIndex = 1  # External als Standard
        $cmbTlsSettings.SelectedIndex = 0      # EncryptionOnly als Standard
        
        # Event-Handler für Connector-Typ-Wechsel
        $rbInbound.Add_Checked({
            $grpInbound.Visibility = "Visible"
            $grpOutbound.Visibility = "Collapsed"
        })
        
        $rbOutbound.Add_Checked({
            $grpInbound.Visibility = "Collapsed"
            $grpOutbound.Visibility = "Visible"
        })
        
        # Event-Handler für Abbrechen-Button
        $btnCancel.Add_Click({
            $connectorWindow.DialogResult = $false
            $connectorWindow.Close()
        })
        
        # Event-Handler für Erstellen-Button
        $btnCreate.Add_Click({
            try {
                # Validierung
                if ([string]::IsNullOrWhiteSpace($txtConnectorName.Text)) {
                    [System.Windows.MessageBox]::Show("Bitte geben Sie einen Namen für den Connector ein.", "Validierungsfehler", "OK", "Warning")
                    return
                }
                
                $isInbound = $rbInbound.IsChecked
                $connectorName = $txtConnectorName.Text.Trim()
                $description = $txtDescription.Text.Trim()
                $enabled = $chkEnabled.IsChecked
                $connectorType = $cmbConnectorType.SelectedItem.Tag
                
                if ($isInbound) {
                    # Inbound Connector erstellen
                    $senderDomains = @()
                    if (-not [string]::IsNullOrWhiteSpace($txtSenderDomains.Text)) {
                        $senderDomains = @($txtSenderDomains.Text.Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
                    }
                    
                    $senderIPAddresses = @()
                    if (-not [string]::IsNullOrWhiteSpace($txtSenderIPAddresses.Text)) {
                        $senderIPAddresses = @($txtSenderIPAddresses.Text.Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
                    }
                    
                    # New-InboundConnector verlangt -SenderDomains
                    if ($senderDomains.Count -eq 0) {
                        $null = [System.Windows.MessageBox]::Show("Bitte geben Sie mindestens eine Sender-Domäne ein (oder * für alle Domänen).", "Validierungsfehler", "OK", "Warning")
                        return
                    }
                    
                    $requireTls = $chkRequireTls.IsChecked
                    $tlsCertificate = $txtTlsCertificate.Text.Trim()
                    $treatMessagesAs = $cmbTreatMessagesAs.SelectedItem.Tag
                    
                    # Parameter für New-InboundConnector vorbereiten
                    $inboundParams = @{
                        Name = $connectorName
                        Enabled = $enabled
                        ConnectorType = $connectorType
                    }
                    
                    if (-not [string]::IsNullOrWhiteSpace($description)) {
                        $inboundParams.Comment = $description
                    }
                    
                    if ($senderDomains.Count -gt 0) {
                        $inboundParams.SenderDomains = $senderDomains
                    }
                    
                    if ($senderIPAddresses.Count -gt 0) {
                        $inboundParams.SenderIPAddresses = $senderIPAddresses
                    }
                    
                    if ($requireTls) {
                        $inboundParams.RequireTls = $true
                        if (-not [string]::IsNullOrWhiteSpace($tlsCertificate)) {
                            $inboundParams.TlsSenderCertificateName = $tlsCertificate
                        }
                    }
                    
                    if ($treatMessagesAs -eq "Internal") {
                        $inboundParams.TreatMessagesAsInternal = $true
                    }
                    
                    Write-Log "Erstelle Inbound Connector: $connectorName" -Type "Info"
                    $null = New-InboundConnector @inboundParams -ErrorAction Stop
                    
                } else {
                    # Outbound Connector erstellen
                    $recipientDomains = @()
                    if (-not [string]::IsNullOrWhiteSpace($txtRecipientDomains.Text)) {
                        $recipientDomains = @($txtRecipientDomains.Text.Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
                    }
                    
                    $smartHosts = @()
                    if (-not [string]::IsNullOrWhiteSpace($txtSmartHosts.Text)) {
                        $smartHosts = @($txtSmartHosts.Text.Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
                    }
                    
                    if ($recipientDomains.Count -eq 0) {
                        [System.Windows.MessageBox]::Show("Bitte geben Sie mindestens eine Empfänger-Domäne ein.", "Validierungsfehler", "OK", "Warning")
                        return
                    }
                    
                    if ($smartHosts.Count -eq 0) {
                        [System.Windows.MessageBox]::Show("Bitte geben Sie mindestens einen Smart Host ein.", "Validierungsfehler", "OK", "Warning")
                        return
                    }
                    
                    $tlsSettings = $cmbTlsSettings.SelectedItem.Tag
                    $tlsDomain = $txtTlsDomain.Text.Trim()
                    $testMode = $chkTestMode.IsChecked
                    
                    # TlsDomain ist nur bei DomainValidation gültig und dort erforderlich
                    if ($tlsSettings -eq "DomainValidation" -and [string]::IsNullOrWhiteSpace($tlsDomain)) {
                        $null = [System.Windows.MessageBox]::Show("Für die TLS-Einstellung 'DomainValidation' muss eine TLS-Domäne angegeben werden.", "Validierungsfehler", "OK", "Warning")
                        return
                    }
                    
                    # Parameter für New-OutboundConnector vorbereiten
                    # Smart Hosts werden nur verwendet, wenn das MX-Routing deaktiviert ist
                    $outboundParams = @{
                        Name = $connectorName
                        Enabled = $enabled
                        ConnectorType = $connectorType
                        RecipientDomains = $recipientDomains
                        UseMXRecord = $false
                        SmartHosts = $smartHosts
                        TlsSettings = $tlsSettings
                    }
                    
                    if (-not [string]::IsNullOrWhiteSpace($description)) {
                        $outboundParams.Comment = $description
                    }
                    
                    if ($tlsSettings -eq "DomainValidation") {
                        $outboundParams.TlsDomain = $tlsDomain
                    }
                    elseif (-not [string]::IsNullOrWhiteSpace($tlsDomain)) {
                        Write-Log "TLS-Domäne '$tlsDomain' wird ignoriert, da sie nur bei TLS-Einstellung 'DomainValidation' gilt (gewählt: $tlsSettings)." -Type "Warning"
                    }
                    
                    if ($testMode) {
                        $outboundParams.TestMode = $true
                    }
                    
                    Write-Log "Erstelle Outbound Connector: $connectorName" -Type "Info"
                    $null = New-OutboundConnector @outboundParams -ErrorAction Stop
                }
                
                Write-Log "Connector '$connectorName' erfolgreich erstellt" -Type "Success"
                [System.Windows.MessageBox]::Show("Connector '$connectorName' wurde erfolgreich erstellt.", "Erfolg", "OK", "Information")
                
                $connectorWindow.DialogResult = $true
                $connectorWindow.Close()
                
                # Connector-Liste aktualisieren
                Get-MailConnectors
                
            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Erstellen des Connectors."
                Write-Log $errorMsg -Type "Error"
                [System.Windows.MessageBox]::Show($errorMsg, "Fehler", "OK", "Error")
            }
        })
        
        # Dialog anzeigen
        $connectorWindow.Owner = $script:Form
        $result = $connectorWindow.ShowDialog()
        
        Write-Log "Connector-Dialog geschlossen mit Ergebnis: $result" -Type "Debug"
        
    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Öffnen des Connector-Dialogs."
        Write-Log $errorMsg -Type "Error"
        [System.Windows.MessageBox]::Show($errorMsg, "Fehler", "OK", "Error")
    }
}

# Initialisiert das Cross-Premises Tab
function Initialize-CrossPremisesTab {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Initialisiere Cross-Premises Tab..." -Type "Info"

        # Connector Buttons
        $btnGetConnectors = $script:Form.FindName("btnGetConnectors")
        $btnSetConnectorStatus = $script:Form.FindName("btnSetConnectorStatus")
        
        # Accepted Domains Button
        $btnGetAcceptedDomains = $script:Form.FindName("btnGetAcceptedDomains")
        
        # Remote Domains Button
        $btnGetRemoteDomains = $script:Form.FindName("btnGetRemoteDomains")
        
        # Add Connector Button
        $btnAddConnector = $script:Form.FindName("btnAddConnector")

        # Event Handler (zentraler Click-Verteiler: Warte-Cursor, Doppelklick-Schutz)
        $null = Register-EventHandler -Control $btnGetConnectors -ControlName "btnGetConnectors" -Handler {
            try {
                Update-StatusBar -Message "Lade Connectors..."
                Get-MailConnectors
            } catch {
                Write-Log "Fehler beim Laden der Connectors: $($_.Exception.Message)" -Type "Error"
                Update-StatusBar -Message "Fehler beim Laden der Connectors"
            }
        }

        $null = Register-EventHandler -Control $btnAddConnector -ControlName "btnAddConnector" -Handler {
            try {
                Update-StatusBar -Message "Öffne Connector-Dialog..."
                Add-NewConnector
            } catch {
                Write-Log "Fehler beim Öffnen des Connector-Dialogs: $($_.Exception.Message)" -Type "Error"
                Update-StatusBar -Message "Fehler beim Öffnen des Connector-Dialogs"
            }
        }

        $null = Register-EventHandler -Control $btnSetConnectorStatus -ControlName "btnSetConnectorStatus" -Handler {
            try {
                Update-StatusBar -Message "Ändere Connector-Status..."
                Set-ConnectorStatus
            } catch {
                Write-Log "Fehler beim Ändern des Connector-Status: $($_.Exception.Message)" -Type "Error"
                Update-StatusBar -Message "Fehler beim Ändern des Connector-Status"
            }
        }

        # Event Handler für Accepted Domains
        $null = Register-EventHandler -Control $btnGetAcceptedDomains -ControlName "btnGetAcceptedDomains" -Handler {
            try {
                Update-StatusBar -Message "Lade akzeptierte Domänen..."
                Get-AcceptedDomainsList
            } catch {
                Write-Log "Fehler beim Laden der akzeptierten Domänen: $($_.Exception.Message)" -Type "Error"
                Update-StatusBar -Message "Fehler beim Laden der akzeptierten Domänen"
            }
        }

        # Event Handler für Remote Domains
        $null = Register-EventHandler -Control $btnGetRemoteDomains -ControlName "btnGetRemoteDomains" -Handler {
            try {
                Update-StatusBar -Message "Lade Remote-Domänen..."
                Get-RemoteDomainsList
            } catch {
                Write-Log "Fehler beim Laden der Remote-Domänen: $($_.Exception.Message)" -Type "Error"
                Update-StatusBar -Message "Fehler beim Laden der Remote-Domänen"
            }
        }

        Write-Log "Cross-Premises Tab erfolgreich initialisiert" -Type "Success"
        return $true
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler bei der Initialisierung des Cross-Premises Tabs."
        Write-Log $errorMsg -Type "Error"
        return $false
    }
}
