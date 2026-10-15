# =====================================================================
# easyEXO - Modul: Mobile Geräte (Richtlinien, Quarantäne)
# Datei: src/Modules/Features/MobileDevices.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

#endregion

#region Mobile Device Management
function Get-MobileDevicePoliciesAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }
    Update-StatusBar -Message "Lade Richtlinien für mobile Geräte..." -Type Info
    
    try {
        $policies = @(Get-MobileDeviceMailboxPolicy -ErrorAction Stop)

        if ($null -ne $script:dgMobileDevicePolicies) {
            $script:dgMobileDevicePolicies.Dispatcher.Invoke([Action]{
                $script:dgMobileDevicePolicies.ItemsSource = $policies
            })
        } else {
            Write-Log "DataGrid 'dgMobileDevicePolicies' wurde nicht im Skript-Kontext gefunden." -Type "Warning"
        }

        $policyCount = if ($null -ne $policies) { $policies.Count } else { 0 }
        Update-StatusBar -Message "$policyCount Richtlinien für mobile Geräte geladen." -Type Success
        Log-Action "Richtlinien für mobile Geräte geladen: $policyCount gefunden."
        
        return $policies

    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Laden der Richtlinien für mobile Geräte."
        Update-StatusBar -Message $errorMsg -Type Error
        Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
        Log-Action "Fehler beim Laden der Richtlinien für mobile Geräte: $errorMsg"
        
        if ($null -ne $script:dgMobileDevicePolicies) {
            $script:dgMobileDevicePolicies.Dispatcher.Invoke([Action]{
                $script:dgMobileDevicePolicies.ItemsSource = $null
            })
        }
        return @()
    }
}

function New-MobileDevicePolicyAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }
    Update-StatusBar -Message "Öffne Dialog zur Erstellung einer neuen Geräterichtlinie..." -Type Info

    try {
        # XAML für das Dialogfenster
        $xamlDialog = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Neue Richtlinie für mobile Geräte" Height="600" Width="500"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Text="Neue Richtlinie für mobile Geräte erstellen" FontSize="18" FontWeight="Bold" Margin="0,0,0,20"/>
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <Label Content="Richtlinienname:" FontWeight="SemiBold"/>
                <TextBox x:Name="txtPolicyName" Margin="0,0,0,10"/>
                <CheckBox x:Name="chkAllowNonProvisionableDevices" Content="Nicht-provisionierbare Geräte zulassen" Margin="0,10,0,10"/>
                <CheckBox x:Name="chkAllowSimplePassword" Content="Einfache Passwörter zulassen" Margin="0,0,0,10"/>
                <Label Content="Minimale Passwortlänge (1-16, optional - aktiviert die Kennwortpflicht):" FontWeight="SemiBold"/>
                <TextBox x:Name="txtMinPasswordLength" Margin="0,0,0,10" ToolTip="Mit einer Mindestlänge wird ein Gerätekennwort erforderlich (PasswordEnabled)."/>
                <CheckBox x:Name="chkRequireDeviceEncryption" Content="Geräteverschlüsselung erforderlich" Margin="0,0,0,10"/>
                <CheckBox x:Name="chkAllowCamera" Content="Kamera erlauben" Margin="0,0,0,10"/>
                <CheckBox x:Name="chkAllowWiFi" Content="WLAN erlauben" Margin="0,0,0,10"/>
                <CheckBox x:Name="chkAllowBluetooth" Content="Bluetooth erlauben" Margin="0,0,0,10"/>
            </StackPanel>
        </ScrollViewer>
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
            <Button x:Name="btnCreate" Content="Erstellen" Width="100" Height="30" Margin="0,0,10,0" IsDefault="True"/>
            <Button x:Name="btnCancel" Content="Abbrechen" Width="80" Height="30" IsCancel="True"/>
        </StackPanel>
    </Grid>
</Window>
"@

        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xamlDialog)
        $dialog = [Windows.Markup.XamlReader]::Load($reader)
        $null = Add-ThemeResource -Window $dialog

        # UI-Elemente referenzieren
        $txtPolicyName = $dialog.FindName("txtPolicyName")
        $chkAllowNonProvisionableDevices = $dialog.FindName("chkAllowNonProvisionableDevices")
        $chkAllowSimplePassword = $dialog.FindName("chkAllowSimplePassword")
        $txtMinPasswordLength = $dialog.FindName("txtMinPasswordLength")
        $chkRequireDeviceEncryption = $dialog.FindName("chkRequireDeviceEncryption")
        $chkAllowCamera = $dialog.FindName("chkAllowCamera")
        $chkAllowWiFi = $dialog.FindName("chkAllowWiFi")
        $chkAllowBluetooth = $dialog.FindName("chkAllowBluetooth")
        $btnCreate = $dialog.FindName("btnCreate")
        $btnCancel = $dialog.FindName("btnCancel")

        $btnCancel.Add_Click({ $dialog.Close() })

        $btnCreate.Add_Click({
            try {
                $policyName = $txtPolicyName.Text.Trim()
                if ([string]::IsNullOrWhiteSpace($policyName)) {
                    Show-MessageBox -Message "Bitte geben Sie einen Richtliniennamen an." -Title "Eingabe fehlt" -Type Warning
                    return
                }

                $params = @{
                    Name = $policyName
                    AllowNonProvisionableDevices = [bool]$chkAllowNonProvisionableDevices.IsChecked
                    AllowSimplePassword = [bool]$chkAllowSimplePassword.IsChecked
                    RequireDeviceEncryption = [bool]$chkRequireDeviceEncryption.IsChecked
                    AllowCamera = [bool]$chkAllowCamera.IsChecked
                    AllowWiFi = [bool]$chkAllowWiFi.IsChecked
                    # AllowBluetooth erwartet Allow, Disable oder HandsfreeOnly (kein Boolean)
                    AllowBluetooth = if ($chkAllowBluetooth.IsChecked) { 'Allow' } else { 'Disable' }
                    ErrorAction = 'Stop'
                }
                if (-not [string]::IsNullOrWhiteSpace($txtMinPasswordLength.Text)) {
                    $minLen = $txtMinPasswordLength.Text.Trim()
                    if ($minLen -notmatch '^\d{1,2}$' -or [int]$minLen -lt 1 -or [int]$minLen -gt 16) {
                        Show-MessageBox -Message "Die minimale Passwortlänge muss eine Zahl zwischen 1 und 16 sein." -Title "Ungültige Eingabe" -Type Warning
                        return
                    }
                    # MinPasswordLength (und AllowSimplePassword) wirken nur, wenn ein Gerätekennwort erforderlich ist
                    $params.PasswordEnabled = $true
                    $params.MinPasswordLength = [int]$minLen
                }

                # Richtlinie erstellen
                $null = New-MobileDeviceMailboxPolicy @params

                $dialog.DialogResult = $true
                $dialog.Close()
                Show-MessageBox -Message "Die Richtlinie '$policyName' wurde erfolgreich erstellt." -Title "Erfolg" -Type Info
                Log-Action "Neue Mobile Device Policy '$policyName' erstellt."

                # Liste aktualisieren
                Get-MobileDevicePoliciesAction

            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Erstellen der Geräterichtlinie."
                Write-Log $errorMsg -Type Error
                Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
            }
        })

        $dialog.Owner = $script:Form
        [void]$dialog.ShowDialog()

    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Öffnen des Dialogs für neue Geräterichtlinien."
        Write-Log $errorMsg -Type Error
        Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
    }
}

function Remove-MobileDevicePolicyAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }

    $selectedPolicy = $script:dgMobileDevicePolicies.SelectedItem
    if ($null -eq $selectedPolicy) {
        Show-MessageBox -Message "Bitte wählen Sie eine Richtlinie zum Löschen aus." -Title "Keine Auswahl" -Type "Warning"
        return
    }

    $policyName = $selectedPolicy.Name
    $confirmMessage = "Möchten Sie die Richtlinie für mobile Geräte '$policyName' wirklich löschen?`n`nDiese Aktion kann nicht rückgängig gemacht werden."
    
    if ($PSCmdlet.ShouldProcess($policyName, "Richtlinie für mobile Geräte löschen")) {
        $confirmResult = Show-MessageBox -Message $confirmMessage -Title "Löschen bestätigen" -Type "YesNo" -Icon "Question"
        if ($confirmResult -ne 'Yes') {
            Update-StatusBar -Message "Löschvorgang abgebrochen." -Type "Info"
            return
        }

        Update-StatusBar -Message "Lösche Richtlinie '$policyName'..." -Type "Info"
        try {
            # Die Richtlinie löschen
            Remove-MobileDeviceMailboxPolicy -Identity $policyName -Confirm:$false -ErrorAction Stop

            Show-MessageBox -Message "Die Richtlinie '$policyName' wurde erfolgreich gelöscht." -Title "Erfolg" -Type "Info"
            Log-Action "Richtlinie für mobile Geräte '$policyName' gelöscht."
            
            # Liste aktualisieren, um die gelöschte Richtlinie zu entfernen
            Get-MobileDevicePoliciesAction

        } catch {
            $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Löschen der Richtlinie für mobile Geräte."
            Write-Log $errorMsg -Type "Error"
            Update-StatusBar -Message $errorMsg -Type "Error"
            Show-MessageBox -Message $errorMsg -Title "Fehler" -Type "Error"
            Log-Action "Fehler beim Löschen der Richtlinie für mobile Geräte '$policyName': $errorMsg"
        }
    }
}

function Get-QuarantinedDevicesAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }
    Update-StatusBar -Message "Lade unter Quarantäne gestellte Geräte..." -Type Info
    
    try {
        # Get-MobileDevice mit Filter für Quarantäne-Status
        $devices = @(Get-MobileDevice -Filter "DeviceAccessState -eq 'Quarantined'" -ResultSize Unlimited -ErrorAction Stop)

        # DataGrid im UI-Thread aktualisieren
        if ($null -ne $script:dgQuarantinedDevices) {
            $script:dgQuarantinedDevices.Dispatcher.Invoke([Action]{
                $script:dgQuarantinedDevices.ItemsSource = $devices
            })
        } else {
            Write-Log "DataGrid 'dgQuarantinedDevices' wurde nicht im Skript-Kontext gefunden." -Type "Warning"
        }

        $deviceCount = $devices.Count
        Update-StatusBar -Message "$deviceCount unter Quarantäne gestellte(s) Gerät(e) gefunden." -Type Success
        Log-Action "Unter Quarantäne gestellte Geräte geladen: $deviceCount gefunden."
        
        return $devices

    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Laden der unter Quarantäne gestellten Geräte."
        Update-StatusBar -Message $errorMsg -Type Error
        Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
        Log-Action "Fehler beim Laden der unter Quarantäne gestellten Geräte: $errorMsg"
        
        # DataGrid bei Fehler leeren
        if ($null -ne $script:dgQuarantinedDevices) {
            $script:dgQuarantinedDevices.Dispatcher.Invoke([Action]{
                $script:dgQuarantinedDevices.ItemsSource = $null
            })
        }
        return @()
    }
}

function Set-MobileDeviceAccessState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Device,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Allowed", "Blocked")]
        [string]$AccessState
    )

    # Die Identity eines Mobilgeräts hat das Format "<Postfach>\ExchangeActiveSyncDevices\<Gerät>"
    $deviceIdentity = [string]$Device.Identity
    $mailboxIdentity = ($deviceIdentity -split '\\ExchangeActiveSyncDevices\\', 2)[0]
    if ([string]::IsNullOrWhiteSpace($mailboxIdentity) -or $mailboxIdentity -eq $deviceIdentity) {
        throw "Postfach des Geräts '$deviceIdentity' konnte nicht ermittelt werden."
    }
    if ([string]::IsNullOrWhiteSpace([string]$Device.DeviceId)) {
        throw "Das Gerät '$deviceIdentity' besitzt keine DeviceId."
    }

    # Gerät in die eine Liste aufnehmen und gleichzeitig aus der jeweils anderen entfernen,
    # damit ein früherer Eintrag (z.B. "blockiert") die neue Entscheidung nicht überstimmt.
    $deviceId = [string]$Device.DeviceId
    if ($AccessState -eq "Allowed") {
        Set-CASMailbox -Identity $mailboxIdentity -ActiveSyncAllowedDeviceIDs @{ Add = $deviceId } -ActiveSyncBlockedDeviceIDs @{ Remove = $deviceId } -ErrorAction Stop
    }
    else {
        Set-CASMailbox -Identity $mailboxIdentity -ActiveSyncBlockedDeviceIDs @{ Add = $deviceId } -ActiveSyncAllowedDeviceIDs @{ Remove = $deviceId } -ErrorAction Stop
    }
    Write-Log "Mobilgerät '$($Device.DeviceId)' für '$mailboxIdentity' auf '$AccessState' gesetzt." -Type "Info"
}

function Allow-QuarantinedDeviceAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }

    $selectedDevice = $script:dgQuarantinedDevices.SelectedItem
    if ($null -eq $selectedDevice) {
        Show-MessageBox -Message "Bitte wählen Sie ein Gerät aus der Liste aus, um es zuzulassen." -Title "Keine Auswahl" -Type "Warning"
        return
    }

    $deviceName = $selectedDevice.FriendlyName
    $deviceUser = $selectedDevice.UserDisplayName
    $actionDescription = "Das unter Quarantäne gestellte Gerät '$deviceName' für Benutzer '$deviceUser' zulassen."
    
    if ($PSCmdlet.ShouldProcess("$deviceName ($deviceUser)", "Gerät aus Quarantäne freigeben")) {
        $confirmResult = Show-MessageBox -Message $actionDescription -Title "Zulassen bestätigen" -Type "YesNo" -Icon "Question"
        if ($confirmResult -ne 'Yes') {
            Update-StatusBar -Message "Zulassungsvorgang abgebrochen." -Type "Info"
            return
        }

        Update-StatusBar -Message "Erlaube Gerät '$deviceName'..." -Type "Info"
        try {
            # Das Gerät explizit zulassen (Set-MobileDevice existiert in Exchange Online nicht -> Set-CASMailbox)
            Set-MobileDeviceAccessState -Device $selectedDevice -AccessState Allowed

            Show-MessageBox -Message "Das Gerät '$deviceName' wurde erfolgreich zugelassen." -Title "Erfolg" -Type "Info"
            Log-Action "Unter Quarantäne gestelltes Gerät zugelassen: $($selectedDevice.Identity)"
            
            # Liste aktualisieren, um das zugelassene Gerät zu entfernen
            Get-QuarantinedDevicesAction

        } catch {
            $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Zulassen des Geräts."
            Write-Log $errorMsg -Type "Error"
            Update-StatusBar -Message $errorMsg -Type "Error"
            Show-MessageBox -Message $errorMsg -Title "Fehler" -Type "Error"
            Log-Action "Fehler beim Zulassen des Geräts '$($selectedDevice.Identity)': $errorMsg"
        }
    }
}

function Block-QuarantinedDeviceAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }

    $selectedDevice = $script:dgQuarantinedDevices.SelectedItem
    if ($null -eq $selectedDevice) {
        Show-MessageBox -Message "Bitte wählen Sie ein Gerät aus der Liste aus, um es zu blockieren." -Title "Keine Auswahl" -Type "Warning"
        return
    }

    $deviceName = $selectedDevice.FriendlyName
    $deviceUser = $selectedDevice.UserDisplayName
    $actionDescription = "Das unter Quarantäne gestellte Gerät '$deviceName' für Benutzer '$deviceUser' blockieren."
    
    if ($PSCmdlet.ShouldProcess("$deviceName ($deviceUser)", "Gerät blockieren")) {
        $confirmResult = Show-MessageBox -Message $actionDescription -Title "Blockieren bestätigen" -Type "YesNo" -Icon "Question"
        if ($confirmResult -ne 'Yes') {
            Update-StatusBar -Message "Blockiervorgang abgebrochen." -Type "Info"
            return
        }

        Update-StatusBar -Message "Blockiere Gerät '$deviceName'..." -Type "Info"
        try {
            # Das Gerät explizit blockieren (Set-MobileDevice existiert in Exchange Online nicht -> Set-CASMailbox)
            Set-MobileDeviceAccessState -Device $selectedDevice -AccessState Blocked

            Show-MessageBox -Message "Das Gerät '$deviceName' wurde erfolgreich blockiert." -Title "Erfolg" -Type "Info"
            Log-Action "Unter Quarantäne gestelltes Gerät blockiert: $($selectedDevice.Identity)"
            
            # Liste der unter Quarantäne gestellten Geräte aktualisieren
            Get-QuarantinedDevicesAction

        } catch {
            $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Blockieren des Geräts."
            Write-Log $errorMsg -Type "Error"
            Update-StatusBar -Message $errorMsg -Type "Error"
            Show-MessageBox -Message $errorMsg -Title "Fehler" -Type "Error"
            Log-Action "Fehler beim Blockieren des Geräts '$($selectedDevice.Identity)': $errorMsg"
        }
    }
}

function Initialize-MDMTab {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Initialisiere Mobile Device Management (MDM) Tab..." -Type "Info"

        # --- ActiveSync Policies ---
        $btnGetMobileDevicePolicies = Get-XamlElement -ElementName "btnGetMobileDevicePolicies"
        $btnNewMobileDevicePolicy = Get-XamlElement -ElementName "btnNewMobileDevicePolicy"
        $btnRemoveMobileDevicePolicy = Get-XamlElement -ElementName "btnRemoveMobileDevicePolicy"
        $dgMobileDevicePolicies = Get-XamlElement -ElementName "dgMobileDevicePolicies"
        $txtMobilePolicyDetails = Get-XamlElement -ElementName "txtMobilePolicyDetails"
        
        # --- Quarantined Devices ---
        $btnGetQuarantinedDevices = Get-XamlElement -ElementName "btnGetQuarantinedDevices"
        $btnAllowDevice = Get-XamlElement -ElementName "btnAllowDevice"
        $btnBlockDevice = Get-XamlElement -ElementName "btnBlockDevice"
        $dgQuarantinedDevices = Get-XamlElement -ElementName "dgQuarantinedDevices"

        # Store references in script scope
        $script:dgMobileDevicePolicies = $dgMobileDevicePolicies
        $script:txtMobilePolicyDetails = $txtMobilePolicyDetails
        $script:dgQuarantinedDevices = $dgQuarantinedDevices

        # --- Event Handlers ---

        # ActiveSync Policies
        $null = Register-EventHandler -Control $btnGetMobileDevicePolicies -Handler { Get-MobileDevicePoliciesAction } -ControlName "btnGetMobileDevicePolicies"
        $null = Register-EventHandler -Control $btnNewMobileDevicePolicy -Handler { New-MobileDevicePolicyAction } -ControlName "btnNewMobileDevicePolicy"
        $null = Register-EventHandler -Control $btnRemoveMobileDevicePolicy -Handler { Remove-MobileDevicePolicyAction } -ControlName "btnRemoveMobileDevicePolicy"

        # Quarantined Devices
        $null = Register-EventHandler -Control $btnGetQuarantinedDevices -Handler { Get-QuarantinedDevicesAction } -ControlName "btnGetQuarantinedDevices"
        $null = Register-EventHandler -Control $btnAllowDevice -Handler { Allow-QuarantinedDeviceAction } -ControlName "btnAllowDevice"
        $null = Register-EventHandler -Control $btnBlockDevice -Handler { Block-QuarantinedDeviceAction } -ControlName "btnBlockDevice"

        # Handler for policy selection change
        if ($null -ne $dgMobileDevicePolicies) {
            $dgMobileDevicePolicies.Add_SelectionChanged({
                param($eventSender)
                $selectedPolicy = $eventSender.SelectedItem
                if ($null -ne $selectedPolicy -and $null -ne $script:txtMobilePolicyDetails) {
                    # In a real implementation, you would get the full policy object and format it.
                    $details = $selectedPolicy | Out-String
                    $script:txtMobilePolicyDetails.Text = $details
                }
            })
        }

        Write-Log "MDM Tab erfolgreich initialisiert." -Type "Success"
        return $true
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler bei der Initialisierung des MDM Tabs."
        Write-Log $errorMsg -Type "Error"
        return $false
    }
}
