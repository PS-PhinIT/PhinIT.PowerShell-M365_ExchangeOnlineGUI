# =====================================================================
# easyEXO - Modul: Microsoft Defender für Office 365 (Anti-Phishing, Sichere Anlagen/Links) und Quarantäne
# Datei: src/Modules/Features/Security.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

function Get-AntiPhishingPoliciesAction {
    if (-not (Confirm-ExchangeConnection)) { return }
    Update-StatusBar -Message "Anti-Phishing-Richtlinien werden geladen..." -Type Info
    try {
        $policies = Get-AntiPhishPolicy -ErrorAction Stop
        $script:dgAntiPhishingPolicies.Dispatcher.Invoke([Action]{
            $script:dgAntiPhishingPolicies.ItemsSource = $policies
        })
        Update-StatusBar -Message "$($policies.Count) Anti-Phishing-Richtlinien geladen." -Type Success
        Log-Action "Anti-Phishing-Richtlinien geladen: $($policies.Count) gefunden."
    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Laden der Anti-Phishing-Richtlinien."
        Update-StatusBar -Message $errorMsg -Type Error
        Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
        Log-Action "Fehler beim Laden der Anti-Phishing-Richtlinien: $errorMsg"
    }
}

function New-AntiPhishingPolicyAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }
    Update-StatusBar -Message "Öffne Dialog zur Erstellung einer neuen Anti-Phishing-Richtlinie..." -Type Info

    try {
        # XAML für das Dialogfenster
        $xamlDialog = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Neue Anti-Phishing-Richtlinie" Height="550" Width="600"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" Text="Neue Anti-Phishing-Richtlinie erstellen" FontSize="18" FontWeight="Bold" Margin="0,0,0,20"/>
        
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <Label Content="Richtlinienname:" FontWeight="SemiBold"/>
                <TextBox x:Name="txtPolicyName" Margin="0,0,0,10"/>
                
                <Label Content="Beschreibung (optional):" FontWeight="SemiBold"/>
                <TextBox x:Name="txtPolicyDescription" Margin="0,0,0,10" Height="60" TextWrapping="Wrap" AcceptsReturn="True"/>

                <CheckBox x:Name="chkEnabled" Content="Richtlinie aktivieren" IsChecked="True" Margin="0,10,0,10"/>
                
                <GroupBox Header="Schutzeinstellungen" Margin="0,10,0,10">
                    <StackPanel Margin="10">
                        <CheckBox x:Name="chkImpersonationProtectionEnabled" Content="Identitätsschutz aktivieren" IsChecked="True"/>
                        <CheckBox x:Name="chkSpoofProtectionEnabled" Content="Spoofingschutz aktivieren" IsChecked="True"/>
                        <CheckBox x:Name="chkMailboxIntelligenceProtectionEnabled" Content="Schutz durch Postfachintelligenz aktivieren" IsChecked="True"/>
                    </StackPanel>
                </GroupBox>

                <Label Content="Anwenden auf (Benutzer, Gruppen, Domänen - mit Semikolon trennen):" FontWeight="SemiBold"/>
                <TextBox x:Name="txtAppliedTo" Margin="0,0,0,10" ToolTip="z.B. user@contoso.com; marketing@contoso.com; contoso.com"/>

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
        
        # UI-Elemente referenzieren
        $txtPolicyName = $dialog.FindName("txtPolicyName")
        $txtPolicyDescription = $dialog.FindName("txtPolicyDescription")
        $chkEnabled = $dialog.FindName("chkEnabled")
        $chkImpersonationProtectionEnabled = $dialog.FindName("chkImpersonationProtectionEnabled")
        $chkSpoofProtectionEnabled = $dialog.FindName("chkSpoofProtectionEnabled")
        $chkMailboxIntelligenceProtectionEnabled = $dialog.FindName("chkMailboxIntelligenceProtectionEnabled")
        $txtAppliedTo = $dialog.FindName("txtAppliedTo")
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

                Update-StatusBar -Message "Erstelle Anti-Phishing-Richtlinie '$policyName'..." -Type Info

                $policyParams = @{
                    Name = $policyName
                    Enabled = $chkEnabled.IsChecked
                    Description = $txtPolicyDescription.Text.Trim()
                    ImpersonationProtectionEnabled = $chkImpersonationProtectionEnabled.IsChecked
                    SpoofProtectionEnabled = $chkSpoofProtectionEnabled.IsChecked
                    MailboxIntelligenceProtectionEnabled = $chkMailboxIntelligenceProtectionEnabled.IsChecked
                    ErrorAction = 'Stop'
                }

                # Richtlinie erstellen
                New-AntiPhishPolicy @policyParams

                # Regel erstellen und mit Richtlinie verknüpfen
                $appliedToRecipients = $txtAppliedTo.Text.Trim() -split ';' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                if ($appliedToRecipients.Count -gt 0) {
                    $ruleParams = @{
                        Name = "$($policyName)_Rule"
                        AntiPhishPolicy = $policyName
                        RecipientDomainIs = $appliedToRecipients | Where-Object { $_ -notlike "*@*" }
                        SentTo = $appliedToRecipients | Where-Object { $_ -like "*@*" }
                        ErrorAction = 'Stop'
                    }
                    New-AntiPhishRule @ruleParams
                }

                $dialog.DialogResult = $true
                $dialog.Close()
                Show-MessageBox -Message "Die Anti-Phishing-Richtlinie '$policyName' wurde erfolgreich erstellt." -Title "Erfolg" -Type Info
                Log-Action "Neue Anti-Phishing-Richtlinie '$policyName' erstellt."
                
                # Liste aktualisieren
                Get-AntiPhishingPoliciesAction

            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Erstellen der Anti-Phishing-Richtlinie."
                Write-Log $errorMsg -Type Error
                Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
            }
        })

        $dialog.Owner = $script:Form
        [void]$dialog.ShowDialog()

    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Öffnen des Dialogs für neue Anti-Phishing-Richtlinien."
        Write-Log $errorMsg -Type Error
        Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
    }
}

function Set-AntiPhishingPolicyAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }

    $selectedPolicy = $script:dgAntiPhishingPolicies.SelectedItem
    if ($null -eq $selectedPolicy) {
        Show-MessageBox -Message "Bitte wählen Sie eine Richtlinie aus der Liste aus, um sie zu bearbeiten." -Title "Keine Auswahl" -Type "Warning"
        return
    }

    Update-StatusBar -Message "Lade Details für Richtlinie '$($selectedPolicy.Name)'..." -Type Info

    try {
        # Zugehörige Regel finden
        $rule = Get-AntiPhishRule | Where-Object { $_.AntiPhishPolicy -eq $selectedPolicy.Name } | Select-Object -First 1

        # XAML für das Dialogfenster (ähnlich wie bei 'New', aber zum Bearbeiten)
        $xamlDialog = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Anti-Phishing-Richtlinie bearbeiten" Height="550" Width="600"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" Text="Anti-Phishing-Richtlinie bearbeiten" FontSize="18" FontWeight="Bold" Margin="0,0,0,20"/>
        
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <Label Content="Richtlinienname:" FontWeight="SemiBold"/>
                <TextBox x:Name="txtPolicyName" Margin="0,0,0,10" IsReadOnly="True" Background="#EEEEEE"/>
                
                <Label Content="Beschreibung (optional):" FontWeight="SemiBold"/>
                <TextBox x:Name="txtPolicyDescription" Margin="0,0,0,10" Height="60" TextWrapping="Wrap" AcceptsReturn="True"/>

                <CheckBox x:Name="chkEnabled" Content="Richtlinie aktivieren" Margin="0,10,0,10"/>
                
                <GroupBox Header="Schutzeinstellungen" Margin="0,10,0,10">
                    <StackPanel Margin="10">
                        <CheckBox x:Name="chkImpersonationProtectionEnabled" Content="Identitätsschutz aktivieren" Margin="0,5"/>
                        <CheckBox x:Name="chkSpoofProtectionEnabled" Content="Spoof-Schutz aktivieren" Margin="0,5"/>
                        <CheckBox x:Name="chkMailboxIntelligenceProtectionEnabled" Content="Postfachintelligenz-Schutz aktivieren" Margin="0,5"/>
                    </StackPanel>
                </GroupBox>

                <Label Content="Anwenden auf (Benutzer, Gruppen, Domänen - mit Semikolon trennen):" FontWeight="SemiBold"/>
                <TextBox x:Name="txtAppliedTo" Margin="0,0,0,10" ToolTip="z.B. user@contoso.com; marketing@contoso.com; contoso.com"/>

            </StackPanel>
        </ScrollViewer>
        
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
            <Button x:Name="btnSave" Content="Speichern" Width="100" Height="30" Margin="0,0,10,0" IsDefault="True"/>
            <Button x:Name="btnCancel" Content="Abbrechen" Width="80" Height="30" IsCancel="True"/>
        </StackPanel>
    </Grid>
</Window>
"@

        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xamlDialog)
        $dialog = [Windows.Markup.XamlReader]::Load($reader)
        
        # UI-Elemente referenzieren
        $txtPolicyName = $dialog.FindName("txtPolicyName")
        $txtPolicyDescription = $dialog.FindName("txtPolicyDescription")
        $chkEnabled = $dialog.FindName("chkEnabled")
        $chkImpersonationProtectionEnabled = $dialog.FindName("chkImpersonationProtectionEnabled")
        $chkSpoofProtectionEnabled = $dialog.FindName("chkSpoofProtectionEnabled")
        $chkMailboxIntelligenceProtectionEnabled = $dialog.FindName("chkMailboxIntelligenceProtectionEnabled")
        $txtAppliedTo = $dialog.FindName("txtAppliedTo")
        $btnSave = $dialog.FindName("btnSave")
        $btnCancel = $dialog.FindName("btnCancel")

        # Dialog mit vorhandenen Werten füllen
        $txtPolicyName.Text = $selectedPolicy.Name
        $txtPolicyDescription.Text = $selectedPolicy.Description
        $chkEnabled.IsChecked = $selectedPolicy.Enabled
        $chkImpersonationProtectionEnabled.IsChecked = $selectedPolicy.ImpersonationProtectionEnabled
        $chkSpoofProtectionEnabled.IsChecked = $selectedPolicy.SpoofProtectionEnabled
        $chkMailboxIntelligenceProtectionEnabled.IsChecked = $selectedPolicy.MailboxIntelligenceProtectionEnabled
        
        if ($null -ne $rule) {
            $appliedTo = @()
            if ($rule.SentTo) { $appliedTo += $rule.SentTo }
            if ($rule.RecipientDomainIs) { $appliedTo += $rule.RecipientDomainIs }
            $txtAppliedTo.Text = $appliedTo -join "; "
        }

        $btnCancel.Add_Click({ $dialog.Close() })

        $btnSave.Add_Click({
            try {
                $policyName = $txtPolicyName.Text
                Update-StatusBar -Message "Aktualisiere Anti-Phishing-Richtlinie '$policyName'..." -Type Info

                $policyParams = @{
                    Identity = $policyName
                    Enabled = $chkEnabled.IsChecked
                    Description = $txtPolicyDescription.Text.Trim()
                    ImpersonationProtectionEnabled = $chkImpersonationProtectionEnabled.IsChecked
                    SpoofProtectionEnabled = $chkSpoofProtectionEnabled.IsChecked
                    MailboxIntelligenceProtectionEnabled = $chkMailboxIntelligenceProtectionEnabled.IsChecked
                    ErrorAction = 'Stop'
                }

                # Richtlinie aktualisieren
                Set-AntiPhishPolicy @policyParams

                # Regel aktualisieren, falls vorhanden
                if ($null -ne $rule) {
                    $appliedToRecipients = $txtAppliedTo.Text.Trim() -split ';' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                    $ruleParams = @{
                        Identity = $rule.Name
                        RecipientDomainIs = $appliedToRecipients | Where-Object { $_ -notlike "*@*" }
                        SentTo = $appliedToRecipients | Where-Object { $_ -like "*@*" }
                        ErrorAction = 'Stop'
                    }
                    Set-AntiPhishRule @ruleParams
                }

                $dialog.DialogResult = $true
                $dialog.Close()
                Show-MessageBox -Message "Die Anti-Phishing-Richtlinie '$policyName' wurde erfolgreich aktualisiert." -Title "Erfolg" -Type Info
                Log-Action "Anti-Phishing-Richtlinie '$policyName' aktualisiert."
                
                # Liste aktualisieren
                Get-AntiPhishingPoliciesAction

            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Aktualisieren der Anti-Phishing-Richtlinie."
                Write-Log $errorMsg -Type Error
                Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
            }
        })

        $dialog.Owner = $script:Form
        [void]$dialog.ShowDialog()

    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Öffnen des Dialogs zum Bearbeiten der Anti-Phishing-Richtlinie."
        Write-Log $errorMsg -Type Error
        Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
    }
}

function Export-AntiPhishingPoliciesAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }
    Export-DataGridContent -DataGrid $script:dgAntiPhishingPolicies -DefaultFileName "AntiPhishingPolicies"
}

function Remove-AntiPhishingPolicyAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }

    $selectedPolicy = $script:dgAntiPhishingPolicies.SelectedItem
    if ($null -eq $selectedPolicy) {
        Show-MessageBox -Message "Bitte wählen Sie eine Richtlinie zum Löschen aus." -Title "Keine Auswahl" -Type "Warning"
        return
    }

    $policyName = $selectedPolicy.Name
    $confirmMessage = "Möchten Sie die Anti-Phishing-Richtlinie '$policyName' und die zugehörige Regel wirklich löschen?"
    
    if ($PSCmdlet.ShouldProcess($policyName, "Anti-Phishing-Richtlinie und Regel löschen")) {
        $confirmResult = Show-MessageBox -Message $confirmMessage -Title "Löschen bestätigen" -Type "YesNo" -Icon "Question"
        if ($confirmResult -ne 'Yes') {
            Update-StatusBar -Message "Löschvorgang abgebrochen." -Type "Info"
            return
        }

        Update-StatusBar -Message "Lösche Richtlinie '$policyName'..." -Type "Info"
        try {
            # Zuerst die Regel löschen, falls vorhanden
            $rule = Get-AntiPhishRule | Where-Object { $_.AntiPhishPolicy -eq $policyName } | Select-Object -First 1
            if ($null -ne $rule) {
                Remove-AntiPhishRule -Identity $rule.Name -Confirm:$false -ErrorAction Stop
                Write-Log "Zugehörige Regel '$($rule.Name)' für Richtlinie '$policyName' gelöscht." -Type "Info"
            }

            # Dann die Richtlinie löschen
            Remove-AntiPhishPolicy -Identity $policyName -Confirm:$false -ErrorAction Stop

            Show-MessageBox -Message "Die Anti-Phishing-Richtlinie '$policyName' wurde erfolgreich gelöscht." -Title "Erfolg" -Type "Info"
            Log-Action "Anti-Phishing-Richtlinie '$policyName' gelöscht."
            
            # Liste aktualisieren
            Get-AntiPhishingPoliciesAction

        } catch {
            $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Löschen der Anti-Phishing-Richtlinie."
            Write-Log $errorMsg -Type "Error"
            Show-MessageBox -Message $errorMsg -Title "Fehler" -Type "Error"
        }
    }
}

function Get-SafeAttachmentPoliciesAction {
    Update-StatusBar -Message "Safe Attachment-Richtlinien werden geladen..."
    # Implementierung: Get-SafeAttachmentPolicy
    $policies = Get-SafeAttachmentPolicy -ErrorAction SilentlyContinue
    $script:dgSafeAttachmentPolicies.Dispatcher.Invoke([Action]{
        $script:dgSafeAttachmentPolicies.ItemsSource = $policies
    })
    Update-StatusBar -Message "$($policies.Count) Safe Attachment-Richtlinien geladen." -Type Success
}

function New-SafeAttachmentPolicyAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }
    Update-StatusBar -Message "Öffne Dialog zur Erstellung einer neuen Safe Attachment-Richtlinie..." -Type Info

    try {
        # XAML für das Dialogfenster
        $xamlDialog = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Neue Safe Attachment-Richtlinie" Height="500" Width="600"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" Text="Neue Safe Attachment-Richtlinie erstellen" FontSize="18" FontWeight="Bold" Margin="0,0,0,20"/>
        
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <Label Content="Richtlinienname:" FontWeight="SemiBold"/>
                <TextBox x:Name="txtPolicyName" Margin="0,0,0,10"/>
                
                <Label Content="Beschreibung (optional):" FontWeight="SemiBold"/>
                <TextBox x:Name="txtPolicyDescription" Margin="0,0,0,10" Height="60" TextWrapping="Wrap" AcceptsReturn="True"/>

                <CheckBox x:Name="chkEnabled" Content="Richtlinie aktivieren" IsChecked="True" Margin="0,10,0,10"/>
                
                <Label Content="Aktion bei schädlichen Anhängen:" FontWeight="SemiBold"/>
                <ComboBox x:Name="cmbAction" Margin="0,0,0,10">
                    <ComboBoxItem Content="Block" Tag="Block"/>
                    <ComboBoxItem Content="Replace" Tag="Replace"/>
                    <ComboBoxItem Content="Quarantine" Tag="Quarantine"/>
                    <ComboBoxItem Content="DynamicDelivery" Tag="DynamicDelivery"/>
                </ComboBox>

                <CheckBox x:Name="chkEnableRedirect" Content="Umleitung aktivieren" Margin="0,10,0,0"/>
                <TextBox x:Name="txtRedirectAddress" Margin="0,0,0,10" ToolTip="E-Mail-Adresse für Umleitung" IsEnabled="False"/>

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
        
        # UI-Elemente referenzieren
        $txtPolicyName = $dialog.FindName("txtPolicyName")
        $txtPolicyDescription = $dialog.FindName("txtPolicyDescription")
        $chkEnabled = $dialog.FindName("chkEnabled")
        $cmbAction = $dialog.FindName("cmbAction")
        $chkEnableRedirect = $dialog.FindName("chkEnableRedirect")
        $txtRedirectAddress = $dialog.FindName("txtRedirectAddress")
        $btnCreate = $dialog.FindName("btnCreate")
        $btnCancel = $dialog.FindName("btnCancel")

        # Redirect-Textbox aktivieren/deaktivieren
        $chkEnableRedirect.Add_Checked({
            $txtRedirectAddress.IsEnabled = $true
        })
        $chkEnableRedirect.Add_Unchecked({
            $txtRedirectAddress.IsEnabled = $false
            $txtRedirectAddress.Text = ""
        })

        $btnCancel.Add_Click({ $dialog.Close() })

        $btnCreate.Add_Click({
            try {
                $policyName = $txtPolicyName.Text.Trim()
                if ([string]::IsNullOrWhiteSpace($policyName)) {
                    Show-MessageBox -Message "Bitte geben Sie einen Richtliniennamen an." -Title "Eingabe fehlt" -Type Warning
                    return
                }

                Update-StatusBar -Message "Erstelle Safe Attachment-Richtlinie '$policyName'..." -Type Info

                $selectedActionItem = $cmbAction.SelectedItem
                $actionValue = if ($selectedActionItem -and $selectedActionItem.Tag) { $selectedActionItem.Tag } else { "Block" }

                $policyParams = @{
                    Name = $policyName
                    Enabled = $chkEnabled.IsChecked
                    Action = $actionValue
                    Description = $txtPolicyDescription.Text.Trim()
                    ErrorAction = 'Stop'
                }

                if ($chkEnableRedirect.IsChecked -and -not [string]::IsNullOrWhiteSpace($txtRedirectAddress.Text)) {
                    $policyParams.Add("RedirectAddress", $txtRedirectAddress.Text.Trim())
                }

                # Richtlinie erstellen
                New-SafeAttachmentPolicy @policyParams

                $dialog.DialogResult = $true
                $dialog.Close()
                Show-MessageBox -Message "Die Safe Attachment-Richtlinie '$policyName' wurde erfolgreich erstellt." -Title "Erfolg" -Type Info
                Log-Action "Neue Safe Attachment-Richtlinie '$policyName' erstellt."
                
                # Liste aktualisieren
                Get-SafeAttachmentPoliciesAction

            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Erstellen der Safe Attachment-Richtlinie."
                Write-Log $errorMsg -Type Error
                Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
            }
        })

        $dialog.Owner = $script:Form
        [void]$dialog.ShowDialog()

    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Öffnen des Dialogs für neue Safe Attachment-Richtlinien."
        Write-Log $errorMsg -Type Error
        Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
    }
}

function Set-SafeAttachmentPolicyAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }

    $selectedPolicy = $script:dgSafeAttachmentPolicies.SelectedItem
    if ($null -eq $selectedPolicy) {
        Show-MessageBox -Message "Bitte wählen Sie eine Richtlinie aus der Liste aus, um sie zu bearbeiten." -Title "Keine Auswahl" -Type "Warning"
        return
    }

    Update-StatusBar -Message "Lade Details für Richtlinie '$($selectedPolicy.Name)'..." -Type Info

    try {
        # Zugehörige Regel finden
        $rule = $null
        try {
            $rule = Get-SafeAttachmentRule | Where-Object { $_.SafeAttachmentPolicy -eq $selectedPolicy.Name } | Select-Object -First 1
        } catch {}

        # XAML für das Dialogfenster
        $xamlDialog = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Safe Attachment-Richtlinie bearbeiten" Height="550" Width="600"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" Text="Safe Attachment-Richtlinie bearbeiten" FontSize="18" FontWeight="Bold" Margin="0,0,0,20"/>
        
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <Label Content="Richtlinienname:" FontWeight="SemiBold"/>
                <TextBox x:Name="txtPolicyName" Margin="0,0,0,10" IsReadOnly="True" Background="#EEEEEE"/>
                
                <Label Content="Beschreibung (optional):" FontWeight="SemiBold"/>
                <TextBox x:Name="txtPolicyDescription" Margin="0,0,0,10" Height="60" TextWrapping="Wrap" AcceptsReturn="True"/>

                <CheckBox x:Name="chkEnabled" Content="Richtlinie aktivieren" Margin="0,10,0,10"/>
                
                <Label Content="Aktion bei schädlichen Anhängen:" FontWeight="SemiBold"/>
                <ComboBox x:Name="cmbAction" Margin="0,0,0,10">
                    <ComboBoxItem Content="Blockieren (Block)" Tag="Block"/>
                    <ComboBoxItem Content="Ersetzen (Replace)" Tag="Replace"/>
                    <ComboBoxItem Content="In Quarantäne verschieben (Quarantine)" Tag="Quarantine"/>
                    <ComboBoxItem Content="Dynamische Zustellung (DynamicDelivery)" Tag="DynamicDelivery"/>
                </ComboBox>

                <CheckBox x:Name="chkEnableRedirect" Content="Umleitung für erkannte Anhänge aktivieren" Margin="0,10,0,0"/>
                <TextBox x:Name="txtRedirectAddress" Margin="0,5,0,10" ToolTip="E-Mail-Adresse für Umleitung" IsEnabled="False"/>

                <Label Content="Anwenden auf (Benutzer, Gruppen, Domänen - mit Semikolon trennen):" FontWeight="SemiBold"/>
                <TextBox x:Name="txtAppliedTo" Margin="0,0,0,10" ToolTip="z.B. user@contoso.com; marketing@contoso.com; contoso.com"/>

            </StackPanel>
        </ScrollViewer>
        
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
            <Button x:Name="btnSave" Content="Speichern" Width="100" Height="30" Margin="0,0,10,0" IsDefault="True"/>
            <Button x:Name="btnCancel" Content="Abbrechen" Width="80" Height="30" IsCancel="True"/>
        </StackPanel>
    </Grid>
</Window>
"@

        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xamlDialog)
        $dialog = [Windows.Markup.XamlReader]::Load($reader)
        
        # UI-Elemente referenzieren
        $txtPolicyName = $dialog.FindName("txtPolicyName")
        $txtPolicyDescription = $dialog.FindName("txtPolicyDescription")
        $chkEnabled = $dialog.FindName("chkEnabled")
        $cmbAction = $dialog.FindName("cmbAction")
        $chkEnableRedirect = $dialog.FindName("chkEnableRedirect")
        $txtRedirectAddress = $dialog.FindName("txtRedirectAddress")
        $txtAppliedTo = $dialog.FindName("txtAppliedTo")
        $btnSave = $dialog.FindName("btnSave")
        $btnCancel = $dialog.FindName("btnCancel")

        # Dialog mit vorhandenen Werten füllen
        $txtPolicyName.Text = $selectedPolicy.Name
        $txtPolicyDescription.Text = $selectedPolicy.Description
        $chkEnabled.IsChecked = $selectedPolicy.Enabled

        # Aktion in ComboBox auswählen
        $actionItem = $cmbAction.Items | Where-Object { $_.Tag -eq $selectedPolicy.Action } | Select-Object -First 1
        if ($null -ne $actionItem) { $cmbAction.SelectedItem = $actionItem }

        # Umleitungseinstellungen
        $chkEnableRedirect.IsChecked = $selectedPolicy.EnableRedirect
        $txtRedirectAddress.IsEnabled = $selectedPolicy.EnableRedirect
        $txtRedirectAddress.Text = $selectedPolicy.RedirectAddress

        # Empfänger aus Regel laden
        if ($null -ne $rule) {
            $appliedTo = @()
            if ($rule.SentTo) { $appliedTo += $rule.SentTo }
            if ($rule.RecipientDomainIs) { $appliedTo += $rule.RecipientDomainIs }
            $txtAppliedTo.Text = $appliedTo -join "; "
        }

        # Event-Handler
        $chkEnableRedirect.Add_Checked({ $txtRedirectAddress.IsEnabled = $true })
        $chkEnableRedirect.Add_Unchecked({ $txtRedirectAddress.IsEnabled = $false; $txtRedirectAddress.Text = "" })
        $btnCancel.Add_Click({ $dialog.Close() })

        $btnSave.Add_Click({
            try {
                $policyName = $txtPolicyName.Text
                Update-StatusBar -Message "Aktualisiere Safe Attachment-Richtlinie '$policyName'..." -Type Info

                $selectedActionItem = $cmbAction.SelectedItem
                $actionValue = if ($selectedActionItem -and $selectedActionItem.Tag) { $selectedActionItem.Tag } else { "Block" }

                $policyParams = @{
                    Identity = $policyName
                    Enabled = $chkEnabled.IsChecked
                    Action = $actionValue
                    Description = $txtPolicyDescription.Text.Trim()
                    ErrorAction = 'Stop'
                }
                # Umleitung nur setzen, wenn aktiviert und Adresse angegeben
                if ($chkEnableRedirect.IsChecked -and -not [string]::IsNullOrWhiteSpace($txtRedirectAddress.Text)) {
                    $policyParams.EnableRedirect = $true
                    $policyParams.RedirectAddress = $txtRedirectAddress.Text.Trim()
                } else {
                    $policyParams.EnableRedirect = $false
                }

                # Richtlinie aktualisieren
                Set-SafeAttachmentPolicy @policyParams

                # Regel aktualisieren, falls vorhanden
                if ($null -ne $rule) {
                    $appliedToRecipients = $txtAppliedTo.Text.Trim() -split ';' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                    $ruleParams = @{
                        Identity = $rule.Name
                        RecipientDomainIs = $appliedToRecipients | Where-Object { $_ -notlike "*@*" }
                        SentTo = $appliedToRecipients | Where-Object { $_ -like "*@*" }
                        ErrorAction = 'Stop'
                    }
                    Set-SafeAttachmentRule @ruleParams
                }

                $dialog.DialogResult = $true
                $dialog.Close()
                Show-MessageBox -Message "Die Safe Attachment-Richtlinie '$policyName' wurde erfolgreich aktualisiert." -Title "Erfolg" -Type Info
                Log-Action "Safe Attachment-Richtlinie '$policyName' aktualisiert."
                
                # Liste aktualisieren
                Get-SafeAttachmentPoliciesAction

            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Aktualisieren der Safe Attachment-Richtlinie."
                Write-Log $errorMsg -Type Error
                Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
            }
        })

        $dialog.Owner = $script:Form
        [void]$dialog.ShowDialog()

    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Öffnen des Dialogs zum Bearbeiten der Safe Attachment-Richtlinie."
        Write-Log $errorMsg -Type Error
        Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
    }
}

function Export-SafeAttachmentPoliciesAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }

    try {
        # Die Hilfsfunktion aufrufen, die die Logik für den Export enthält
        Export-DataGridContent -DataGrid $script:dgSafeAttachmentPolicies -DefaultFileName "SafeAttachmentPolicies"
        Log-Action "Safe Attachment-Richtlinien exportiert."
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Ein unerwarteter Fehler ist beim Export der Safe Attachment-Richtlinien aufgetreten."
        Write-Log $errorMsg -Type "Error"
        Log-Action "Fehler beim Export der Safe Attachment-Richtlinien: $errorMsg"
        Show-MessageBox -Message $errorMsg -Title "Export-Fehler" -Type "Error"
    }
}

function Remove-SafeAttachmentPolicyAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }

    $selectedPolicy = $script:dgSafeAttachmentPolicies.SelectedItem
    if ($null -eq $selectedPolicy) {
        Show-MessageBox -Message "Bitte wählen Sie eine Richtlinie zum Löschen aus." -Title "Keine Auswahl" -Type "Warning"
        return
    }

    $policyName = $selectedPolicy.Name
    $confirmMessage = "Möchten Sie die Safe Attachment-Richtlinie '$policyName' und die zugehörige Regel wirklich löschen?"
    
    if ($PSCmdlet.ShouldProcess($policyName, "Safe Attachment-Richtlinie und Regel löschen")) {
        $confirmResult = Show-MessageBox -Message $confirmMessage -Title "Löschen bestätigen" -Type "YesNo" -Icon "Question"
        if ($confirmResult -ne 'Yes') {
            Update-StatusBar -Message "Löschvorgang abgebrochen." -Type "Info"
            return
        }

        Update-StatusBar -Message "Lösche Richtlinie '$policyName'..." -Type "Info"
        try {
            # Zuerst die Regel löschen, falls vorhanden
            $rule = Get-SafeAttachmentRule | Where-Object { $_.SafeAttachmentPolicy -eq $policyName } | Select-Object -First 1
            if ($null -ne $rule) {
                Remove-SafeAttachmentRule -Identity $rule.Name -Confirm:$false -ErrorAction Stop
                Write-Log "Zugehörige Regel '$($rule.Name)' für Richtlinie '$policyName' gelöscht." -Type "Info"
            }

            # Dann die Richtlinie löschen
            Remove-SafeAttachmentPolicy -Identity $policyName -Confirm:$false -ErrorAction Stop

            Show-MessageBox -Message "Die Safe Attachment-Richtlinie '$policyName' wurde erfolgreich gelöscht." -Title "Erfolg" -Type "Info"
            Log-Action "Safe Attachment-Richtlinie '$policyName' gelöscht."
            
            # Liste aktualisieren
            Get-SafeAttachmentPoliciesAction

        } catch {
            $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Löschen der Safe Attachment-Richtlinie."
            Write-Log $errorMsg -Type "Error"
            Show-MessageBox -Message $errorMsg -Title "Fehler" -Type "Error"
        }
    }
}

function Get-SafeLinksPoliciesAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }
    Update-StatusBar -Message "Safe Links-Richtlinien werden geladen..." -Type Info
    
    try {
        # Safe Links-Richtlinien abrufen
        $policies = Get-SafeLinksPolicy -ErrorAction Stop
        
        # DataGrid im UI-Thread aktualisieren
        $script:dgSafeLinksPolicies.Dispatcher.Invoke([Action]{
            $script:dgSafeLinksPolicies.ItemsSource = $policies
        })
        
        $policyCount = if ($null -ne $policies) { $policies.Count } else { 0 }
        Update-StatusBar -Message "$policyCount Safe Links-Richtlinien geladen." -Type Success
        Log-Action "Safe Links-Richtlinien geladen: $policyCount gefunden."
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Laden der Safe Links-Richtlinien."
        Update-StatusBar -Message $errorMsg -Type Error
        Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
        Log-Action "Fehler beim Laden der Safe Links-Richtlinien: $errorMsg"
    }
}

function New-SafeLinksPolicyAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }
    Update-StatusBar -Message "Öffne Dialog zur Erstellung einer neuen Safe Links-Richtlinie..." -Type Info

    try {
        # XAML für das Dialogfenster
        $xamlDialog = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Neue Safe Links-Richtlinie" Height="700" Width="650"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" Text="Neue Safe Links-Richtlinie erstellen" FontSize="18" FontWeight="Bold" Margin="0,0,0,20"/>
        
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <Label Content="Richtlinienname:" FontWeight="SemiBold"/>
                <TextBox x:Name="txtPolicyName" Margin="0,0,0,10"/>
                
                <Label Content="Beschreibung (optional):" FontWeight="SemiBold"/>
                <TextBox x:Name="txtPolicyDescription" Margin="0,0,0,10" Height="60" TextWrapping="Wrap" AcceptsReturn="True"/>

                <CheckBox x:Name="chkEnabled" Content="Richtlinie aktivieren" IsChecked="True" Margin="0,10,0,10"/>
                
                <GroupBox Header="Schutzeinstellungen" Margin="0,5,0,10">
                    <StackPanel Margin="10">
                        <CheckBox x:Name="chkScanUrlsInEmail" Content="URLs in E-Mails auf schädliche Links überprüfen" IsChecked="True" ToolTip="Aktiviert den Schutz für Links in E-Mail-Nachrichten."/>
                        <CheckBox x:Name="chkScanUrlsInOffice" Content="URLs in Office 365-Apps auf schädliche Links überprüfen" IsChecked="True" ToolTip="Aktiviert den Schutz für Links in Office-Dokumenten (Word, Excel, PowerPoint)."/>
                        <CheckBox x:Name="chkWaitForScan" Content="Warten, bis die URL-Überprüfung abgeschlossen ist" ToolTip="Verhindert die Zustellung von Nachrichten mit potenziell schädlichen Links, bis die Überprüfung abgeschlossen ist."/>
                    </StackPanel>
                </GroupBox>

                <GroupBox Header="Klickschutz-Einstellungen" Margin="0,5,0,10">
                    <StackPanel Margin="10">
                        <CheckBox x:Name="chkDoNotTrackClicks" Content="Benutzerklicks nicht nachverfolgen" ToolTip="Verhindert, dass Klicks auf sichere Links protokolliert werden."/>
                        <CheckBox x:Name="chkDoNotAllowClickThrough" Content="Benutzern nicht erlauben, zur ursprünglichen URL durchzuklicken" ToolTip="Blockiert den Zugriff auf die ursprüngliche URL, wenn sie als schädlich eingestuft wird."/>
                        <CheckBox x:Name="chkDisplayBranding" Content="Organisations-Branding auf Benachrichtigungsseiten anzeigen" ToolTip="Zeigt Ihr Firmenlogo auf den Warnseiten von Safe Links an."/>
                    </StackPanel>
                </GroupBox>

                <Label Content="Folgende URLs nicht umschreiben (mit Semikolon trennen):" FontWeight="SemiBold"/>
                <TextBox x:Name="txtDoNotRewriteUrls" Margin="0,0,0,10" Height="50" TextWrapping="Wrap" AcceptsReturn="True" ToolTip="z.B. *.contoso.com;*.fabrikam.com"/>

                <Label Content="Anwenden auf (Benutzer, Gruppen, Domänen - mit Semikolon trennen):" FontWeight="SemiBold"/>
                <TextBox x:Name="txtAppliedTo" Margin="0,0,0,10" ToolTip="z.B. user@contoso.com; marketing@contoso.com; contoso.com"/>

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
        
        # UI-Elemente referenzieren
        $txtPolicyName = $dialog.FindName("txtPolicyName")
        $txtPolicyDescription = $dialog.FindName("txtPolicyDescription")
        $chkEnabled = $dialog.FindName("chkEnabled")
        $chkScanUrlsInEmail = $dialog.FindName("chkScanUrlsInEmail")
        $chkScanUrlsInOffice = $dialog.FindName("chkScanUrlsInOffice")
        $chkWaitForScan = $dialog.FindName("chkWaitForScan")
        $chkDoNotTrackClicks = $dialog.FindName("chkDoNotTrackClicks")
        $chkDoNotAllowClickThrough = $dialog.FindName("chkDoNotAllowClickThrough")
        $chkDisplayBranding = $dialog.FindName("chkDisplayBranding")
        $txtDoNotRewriteUrls = $dialog.FindName("txtDoNotRewriteUrls")
        $txtAppliedTo = $dialog.FindName("txtAppliedTo")
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

                Update-StatusBar -Message "Erstelle Safe Links-Richtlinie '$policyName'..." -Type Info

                $policyParams = @{
                    Name = $policyName
                    Enabled = $chkEnabled.IsChecked
                    Description = $txtPolicyDescription.Text.Trim()
                    EnableSafeLinksForEmail = $chkScanUrlsInEmail.IsChecked
                    EnableSafeLinksForOffice = $chkScanUrlsInOffice.IsChecked
                    ScanUrls = $chkWaitForScan.IsChecked
                    DoNotTrackUserClicks = $chkDoNotTrackClicks.IsChecked
                    DoNotAllowClickThrough = $chkDoNotAllowClickThrough.IsChecked
                    EnableOrganizationBranding = $chkDisplayBranding.IsChecked
                    ErrorAction = 'Stop'
                }

                $doNotRewriteUrlsList = $txtDoNotRewriteUrls.Text.Trim() -split ';' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                if ($doNotRewriteUrlsList.Count -gt 0) {
                    $policyParams.Add("DoNotRewriteUrls", $doNotRewriteUrlsList)
                }

                # Richtlinie erstellen
                New-SafeLinksPolicy @policyParams

                # Regel erstellen und mit Richtlinie verknüpfen
                $appliedToRecipients = $txtAppliedTo.Text.Trim() -split ';' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                if ($appliedToRecipients.Count -gt 0) {
                    $ruleParams = @{
                        Name = "$($policyName)_Rule"
                        SafeLinksPolicy = $policyName
                        RecipientDomainIs = $appliedToRecipients | Where-Object { $_ -notlike "*@*" }
                        SentTo = $appliedToRecipients | Where-Object { $_ -like "*@*" }
                        ErrorAction = 'Stop'
                    }
                    New-SafeLinksRule @ruleParams
                }

                $dialog.DialogResult = $true
                $dialog.Close()
                Show-MessageBox -Message "Die Safe Links-Richtlinie '$policyName' wurde erfolgreich erstellt." -Title "Erfolg" -Type Info
                Log-Action "Neue Safe Links-Richtlinie '$policyName' erstellt."
                
                # Liste aktualisieren
                Get-SafeLinksPoliciesAction

            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Erstellen der Safe Links-Richtlinie."
                Write-Log $errorMsg -Type Error
                Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
            }
        })

        $dialog.Owner = $script:Form
        [void]$dialog.ShowDialog()

    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Öffnen des Dialogs für neue Safe Links-Richtlinien."
        Write-Log $errorMsg -Type Error
        Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
    }
}

function Set-SafeLinksPolicyAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }

    $selectedPolicy = $script:dgSafeLinksPolicies.SelectedItem
    if ($null -eq $selectedPolicy) {
        Show-MessageBox -Message "Bitte wählen Sie eine Richtlinie aus der Liste aus, um sie zu bearbeiten." -Title "Keine Auswahl" -Type "Warning"
        return
    }

    Update-StatusBar -Message "Lade Details für Richtlinie '$($selectedPolicy.Name)'..." -Type Info

    try {
        # Zugehörige Regel finden, um den Geltungsbereich zu bearbeiten
        $rule = $null
        try {
            $rule = Get-SafeLinksRule | Where-Object { $_.SafeLinksPolicy -eq $selectedPolicy.Name } | Select-Object -First 1
        } catch {
            Write-Log "Keine zugehörige Safe Links-Regel für '$($selectedPolicy.Name)' gefunden oder Fehler beim Abruf." -Type "Info"
        }

        # XAML für das Dialogfenster (basiert auf dem Dialog für 'New')
        $xamlDialog = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Safe Links-Richtlinie bearbeiten" Height="700" Width="650"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" Text="Safe Links-Richtlinie bearbeiten" FontSize="18" FontWeight="Bold" Margin="0,0,0,20"/>
        
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <Label Content="Richtlinienname:" FontWeight="SemiBold"/>
                <TextBox x:Name="txtPolicyName" Margin="0,0,0,10" IsReadOnly="True" Background="#EEEEEE"/>
                
                <Label Content="Beschreibung (optional):" FontWeight="SemiBold"/>
                <TextBox x:Name="txtPolicyDescription" Margin="0,0,0,10" Height="60" TextWrapping="Wrap" AcceptsReturn="True"/>

                <CheckBox x:Name="chkEnabled" Content="Richtlinie aktivieren" Margin="0,10,0,10"/>
                
                <GroupBox Header="Schutzeinstellungen für E-Mail &amp; Office" Margin="0,5,0,10">
                    <StackPanel Margin="10">
                        <CheckBox x:Name="chkScanUrlsInEmail" Content="URLs in E-Mails scannen" IsChecked="True" Margin="0,5"/>
                        <CheckBox x:Name="chkScanUrlsInOffice" Content="URLs in Office-Anwendungen scannen" IsChecked="True" Margin="0,5"/>
                        <CheckBox x:Name="chkWaitForScan" Content="Auf Abschluss des URL-Scans warten, bevor die Nachricht zugestellt wird" Margin="0,5"/>
                    </StackPanel>
                </GroupBox>

                <GroupBox Header="Klickschutz-Einstellungen" Margin="0,5,0,10">
                    <StackPanel Margin="10">
                        <CheckBox x:Name="chkDoNotTrackClicks" Content="Benutzerklicks nicht nachverfolgen" Margin="0,5"/>
                        <CheckBox x:Name="chkDoNotAllowClickThrough" Content="Benutzern nicht erlauben, sich zur ursprünglichen URL durchzuklicken" Margin="0,5"/>
                        <CheckBox x:Name="chkDisplayBranding" Content="Organisations-Branding auf Benachrichtigungs- und Warnseiten anzeigen" Margin="0,5"/>
                    </StackPanel>
                </GroupBox>

                <Label Content="Folgende URLs nicht umschreiben (mit Semikolon trennen):" FontWeight="SemiBold"/>
                <TextBox x:Name="txtDoNotRewriteUrls" Margin="0,0,0,10" Height="50" TextWrapping="Wrap" AcceptsReturn="True" ToolTip="z.B. *.contoso.com;*.fabrikam.com"/>

                <Label Content="Anwenden auf (Benutzer, Gruppen, Domänen - mit Semikolon trennen):" FontWeight="SemiBold"/>
                <TextBox x:Name="txtAppliedTo" Margin="0,0,0,10" ToolTip="z.B. user@contoso.com; marketing@contoso.com; contoso.com"/>

            </StackPanel>
        </ScrollViewer>
        
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
            <Button x:Name="btnSave" Content="Speichern" Width="100" Height="30" Margin="0,0,10,0" IsDefault="True"/>
            <Button x:Name="btnCancel" Content="Abbrechen" Width="80" Height="30" IsCancel="True"/>
        </StackPanel>
    </Grid>
</Window>
"@

        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xamlDialog)
        $dialog = [Windows.Markup.XamlReader]::Load($reader)
        
        # UI-Elemente referenzieren
        $txtPolicyName = $dialog.FindName("txtPolicyName")
        $txtPolicyDescription = $dialog.FindName("txtPolicyDescription")
        $chkEnabled = $dialog.FindName("chkEnabled")
        $chkScanUrlsInEmail = $dialog.FindName("chkScanUrlsInEmail")
        $chkScanUrlsInOffice = $dialog.FindName("chkScanUrlsInOffice")
        $chkWaitForScan = $dialog.FindName("chkWaitForScan")
        $chkDoNotTrackClicks = $dialog.FindName("chkDoNotTrackClicks")
        $chkDoNotAllowClickThrough = $dialog.FindName("chkDoNotAllowClickThrough")
        $chkDisplayBranding = $dialog.FindName("chkDisplayBranding")
        $txtDoNotRewriteUrls = $dialog.FindName("txtDoNotRewriteUrls")
        $txtAppliedTo = $dialog.FindName("txtAppliedTo")
        $btnSave = $dialog.FindName("btnSave")
        $btnCancel = $dialog.FindName("btnCancel")

        # Dialog mit vorhandenen Werten füllen
        $txtPolicyName.Text = $selectedPolicy.Name
        $txtPolicyDescription.Text = $selectedPolicy.Description
        $chkEnabled.IsChecked = $selectedPolicy.Enabled
        
        # Schutzeinstellungen setzen
        $chkScanUrlsInEmail.IsChecked = $selectedPolicy.EnableSafeLinksForEmail
        $chkScanUrlsInOffice.IsChecked = $selectedPolicy.EnableSafeLinksForOffice
        $chkWaitForScan.IsChecked = $selectedPolicy.ScanUrls

        # Klickschutz-Einstellungen setzen
        $chkDoNotTrackClicks.IsChecked = $selectedPolicy.DoNotTrackUserClicks
        $chkDoNotAllowClickThrough.IsChecked = $selectedPolicy.DoNotAllowClickThrough
        $chkDisplayBranding.IsChecked = $selectedPolicy.EnableOrganizationBranding

        # DoNotRewriteUrls setzen, wenn vorhanden
        if ($null -ne $selectedPolicy.DoNotRewriteUrls -and $selectedPolicy.DoNotRewriteUrls.Count -gt 0) {
            $txtDoNotRewriteUrls.Text = ($selectedPolicy.DoNotRewriteUrls -join "; ")
        }
        
        # Empfänger aus Regel laden
        if ($null -ne $rule) {
            $appliedTo = @()
            if ($rule.SentTo) { $appliedTo += $rule.SentTo }
            if ($rule.RecipientDomainIs) { $appliedTo += $rule.RecipientDomainIs }
            $txtAppliedTo.Text = $appliedTo -join "; "
        }

        $btnCancel.Add_Click({ $dialog.Close() })

        $btnSave.Add_Click({
            try {
                $policyName = $txtPolicyName.Text
                Update-StatusBar -Message "Aktualisiere Safe Links-Richtlinie '$policyName'..." -Type Info

                # Parameter für die Richtlinie vorbereiten
                $policyParams = @{
                    Identity = $policyName
                    Enabled = $chkEnabled.IsChecked
                    Description = $txtPolicyDescription.Text.Trim()
                    EnableSafeLinksForEmail = $chkScanUrlsInEmail.IsChecked
                    EnableSafeLinksForOffice = $chkScanUrlsInOffice.IsChecked
                    ScanUrls = $chkWaitForScan.IsChecked
                    DoNotTrackUserClicks = $chkDoNotTrackClicks.IsChecked
                    DoNotAllowClickThrough = $chkDoNotAllowClickThrough.IsChecked
                    EnableOrganizationBranding = $chkDisplayBranding.IsChecked
                    ErrorAction = 'Stop'
                }

                # DoNotRewriteUrls-Liste aufbereiten
                $doNotRewriteUrlsList = $txtDoNotRewriteUrls.Text.Trim() -split ';' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                if ($doNotRewriteUrlsList.Count -gt 0) {
                    $policyParams.Add("DoNotRewriteUrls", $doNotRewriteUrlsList)
                } else {
                    # Wenn keine URLs angegeben sind, leeres Array setzen
                    $policyParams.Add("DoNotRewriteUrls", @())
                }

                # Richtlinie aktualisieren
                Set-SafeLinksPolicy @policyParams

                # Regel aktualisieren oder neu erstellen, falls notwendig
                $appliedToRecipients = $txtAppliedTo.Text.Trim() -split ';' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                
                if ($appliedToRecipients.Count -gt 0) {
                    $domains = $appliedToRecipients | Where-Object { $_ -notlike "*@*" }
                    $recipients = $appliedToRecipients | Where-Object { $_ -like "*@*" }
                    
                    if ($null -ne $rule) {
                        # Bestehende Regel aktualisieren
                        $ruleParams = @{
                            Identity = $rule.Name
                            SafeLinksPolicy = $policyName
                            ErrorAction = 'Stop'
                        }
                        
                        if ($domains.Count -gt 0) {
                            $ruleParams.Add("RecipientDomainIs", $domains)
                        }
                        
                        if ($recipients.Count -gt 0) {
                            $ruleParams.Add("SentTo", $recipients)
                        }
                        
                        Set-SafeLinksRule @ruleParams
                        Write-Log "Safe Links-Regel '$($rule.Name)' für Richtlinie '$policyName' aktualisiert." -Type "Success"
                    }
                    else {
                        # Neue Regel erstellen
                        $ruleName = "$($policyName)_Rule"
                        $ruleParams = @{
                            Name = $ruleName
                            SafeLinksPolicy = $policyName
                            ErrorAction = 'Stop'
                        }
                        
                        if ($domains.Count -gt 0) {
                            $ruleParams.Add("RecipientDomainIs", $domains)
                        }
                        
                        if ($recipients.Count -gt 0) {
                            $ruleParams.Add("SentTo", $recipients)
                        }
                        
                        New-SafeLinksRule @ruleParams
                        Write-Log "Neue Safe Links-Regel '$ruleName' für Richtlinie '$policyName' erstellt." -Type "Success"
                    }
                }

                $dialog.DialogResult = $true
                $dialog.Close()
                Show-MessageBox -Message "Die Safe Links-Richtlinie '$policyName' wurde erfolgreich aktualisiert." -Title "Erfolg" -Type Info
                Log-Action "Safe Links-Richtlinie '$policyName' aktualisiert."
                
                # Liste aktualisieren
                Get-SafeLinksPoliciesAction

            } catch {
                $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Aktualisieren der Safe Links-Richtlinie."
                Write-Log $errorMsg -Type Error
                Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
            }
        })

        $dialog.Owner = $script:Form
        [void]$dialog.ShowDialog()

    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Öffnen des Dialogs zum Bearbeiten der Safe Links-Richtlinie."
        Write-Log $errorMsg -Type Error
        Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
    }
}

function Export-SafeLinksPoliciesAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }

    try {
        # Die Hilfsfunktion aufrufen, die die Logik für den Export enthält
        Export-DataGridContent -DataGrid $script:dgSafeLinksPolicies -DefaultFileName "SafeLinksPolicies"
        Log-Action "Safe Links-Richtlinien exportiert."
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Ein unerwarteter Fehler ist beim Export der Safe Links-Richtlinien aufgetreten."
        Write-Log $errorMsg -Type "Error"
        Log-Action "Fehler beim Export der Safe Links-Richtlinien: $errorMsg"
        Show-MessageBox -Message $errorMsg -Title "Export-Fehler" -Type "Error"
    }
}

function Get-QuarantineMessagesAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$NoDefaultFilter,
        
        [Parameter(Mandatory = $false)]
        [int]$PageSize = 1000,
        
        [Parameter(Mandatory = $false)]
        [string]$SenderAddress,
        
        [Parameter(Mandatory = $false)]
        [string]$RecipientAddress,
        
        [Parameter(Mandatory = $false)]
        [datetime]$StartReceivedDate,
        
        [Parameter(Mandatory = $false)]
        [datetime]$EndReceivedDate,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Spam", "HighConfidenceSpam", "Phish", "HighConfidencePhish", "BulkMail", "TransportRule")]
        [string]$Type
    )

    try {
        # Prüfen, ob eine Verbindung zu Exchange Online besteht
        if (-not (Confirm-ExchangeConnection)) {
            Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Nicht verbunden" -Type "Warning"
            return
        }

        # Status aktualisieren
        Update-StatusBar -Message "Quarantäne-Nachrichten werden abgerufen..." -Type "Info"
        Write-Log "Get-QuarantineMessagesAction: Rufe Quarantäne-Nachrichten ab" -Type "Info"
        
        # Parameter für Get-QuarantineMessage aufbauen
        $quarantineParams = @{
            ErrorAction = "Stop"
            PageSize = $PageSize
        }
        
        # Filterparameter hinzufügen, wenn angegeben
        if (-not [string]::IsNullOrEmpty($SenderAddress)) {
            $quarantineParams.Add("SenderAddress", $SenderAddress)
        }
        
        if (-not [string]::IsNullOrEmpty($RecipientAddress)) {
            $quarantineParams.Add("RecipientAddress", $RecipientAddress)
        }
        
        if ($null -ne $StartReceivedDate) {
            $quarantineParams.Add("StartReceivedDate", $StartReceivedDate)
        } elseif (-not $NoDefaultFilter) {
            # Standard-Datumsbereich von 30 Tagen verwenden - da Nachrichten maximal 30 Tage aufbewahrt werden.
            $quarantineParams.Add("StartReceivedDate", (Get-Date).AddDays(-30))
        }
        
        if ($null -ne $EndReceivedDate) {
            $quarantineParams.Add("EndReceivedDate", $EndReceivedDate)
        }
        
        if (-not [string]::IsNullOrEmpty($Type)) {
            $quarantineParams.Add("Type", $Type)
        }

        # Quarantäne-Nachrichten abrufen
        Write-Log "Get-QuarantineMessagesAction: Führe Get-QuarantineMessage mit Parametern aus: $($quarantineParams | ConvertTo-Json -Compress)" -Type "Debug"
        $messages = Get-QuarantineMessage @quarantineParams
        
        # Wenn keine Nachrichten gefunden wurden
        if ($null -eq $messages -or $messages.Count -eq 0) {
            Update-StatusBar -Message "Keine Nachrichten in der Quarantäne gefunden." -Type "Warning"
            Write-Log "Get-QuarantineMessagesAction: Keine Quarantäne-Nachrichten gefunden" -Type "Info"
            
            # DataGrid leeren
            if ($null -ne $script:dgQuarantineMessages) {
                $script:dgQuarantineMessages.Dispatcher.Invoke([Action]{
                    $script:dgQuarantineMessages.ItemsSource = $null
                })
            } else {
                Write-Log "Get-QuarantineMessagesAction: Variable dgQuarantineMessages ist nicht initialisiert" -Type "Warning"
            }
            
            return
        }
        
        # Daten für die Anzeige aufbereiten
        $messagesForDisplay = $messages | ForEach-Object {
            # Zusätzliche Eigenschaften für bessere Darstellung hinzufügen
            $_ | Add-Member -NotePropertyName ReceivedTimeLocal -NotePropertyValue $_.ReceivedTime.ToLocalTime() -Force
            $_ | Add-Member -NotePropertyName Size -NotePropertyValue "$([math]::Round($_.Size / 1KB, 2)) KB" -Force
            $_
        }
        
        # Daten im DataGrid anzeigen
        if ($null -ne $script:dgQuarantineMessages) {
            $script:dgQuarantineMessages.Dispatcher.Invoke([Action]{
                $script:dgQuarantineMessages.ItemsSource = $messagesForDisplay
            })
            
            # Status aktualisieren
            $messageCount = $messagesForDisplay.Count
            Update-StatusBar -Message "$messageCount Nachricht(en) in Quarantäne gefunden." -Type "Success"
            Write-Log "Get-QuarantineMessagesAction: $messageCount Quarantäne-Nachrichten geladen" -Type "Success"
            
            # Wenn vorhanden, Anzahl-Feld aktualisieren
            if ($null -ne $script:txtQuarantineCount) {
                $script:txtQuarantineCount.Dispatcher.Invoke([Action]{
                    $script:txtQuarantineCount.Text = "Anzahl: $messageCount"
                })
            }
        } else {
            Write-Log "Get-QuarantineMessagesAction: Variable dgQuarantineMessages ist nicht initialisiert" -Type "Warning"
        }
        
        # Erfolgreich abgeschlossen
        Log-Action "Quarantäne-Nachrichten abgerufen: $messageCount gefunden"
        return $messagesForDisplay
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Abrufen der Quarantäne-Nachrichten"
        Write-Log "Get-QuarantineMessagesAction: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Fehler beim Abrufen der Quarantäne-Nachrichten" -Type "Error"
        Show-MessageBox -Message $errorMsg -Title "Fehler" -Type "Error"
        Log-Action "Fehler beim Abrufen der Quarantäne-Nachrichten: $errorMsg"
        
        # DataGrid leeren bei Fehler
        if ($null -ne $script:dgQuarantineMessages) {
            $script:dgQuarantineMessages.Dispatcher.Invoke([Action]{
                $script:dgQuarantineMessages.ItemsSource = $null
            })
        }
        
        return $null
    }
}

function Release-QuarantineMessageAction {
    [CmdletBinding()]
    param()

    # Prüfe, ob eine Verbindung zu Exchange Online besteht
    if (-not (Confirm-ExchangeConnection)) {
        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Nicht verbunden" -Type "Warning"
        return
    }

    $selectedItem = $script:dgQuarantineMessages.SelectedItem
    if ($null -eq $selectedItem) {
        Show-MessageBox -Message "Bitte wählen Sie eine Nachricht aus der Quarantäne-Liste aus." -Title "Keine Auswahl" -Type "Warning"
        return
    }

    # Bestätigungsdialog anzeigen
    $confirmResult = Show-MessageBox -Message "Möchten Sie die ausgewählte Nachricht wirklich freigeben?" -Title "Freigabe bestätigen" -Type "YesNo" -Icon "Question"
    if ($confirmResult -ne "Yes") {
        Update-StatusBar -Message "Freigabe abgebrochen." -Type "Info"
        return
    }

    try {
        Update-StatusBar -Message "Freigabe der Nachricht wird durchgeführt..." -Type "Info"
        Write-Log "Release-QuarantineMessageAction: Freigabe für Nachricht mit Identity '$($selectedItem.Identity)' gestartet." -Type "Info"

        # Quarantäne-Nachricht freigeben
        Release-QuarantineMessage -Identity $selectedItem.Identity -ReleaseToAll -ErrorAction Stop

        Show-MessageBox -Message "Die ausgewählte Nachricht wurde erfolgreich freigegeben." -Title "Erfolg" -Type "Info"
        Update-StatusBar -Message "Nachricht erfolgreich freigegeben." -Type "Success"
        Log-Action "Quarantäne-Nachricht freigegeben: $($selectedItem.Identity)"

        # Liste aktualisieren
        Get-QuarantineMessagesAction
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Freigeben der Quarantäne-Nachricht: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Fehler beim Freigeben der Nachricht: $errorMsg" -Type "Error"
        Show-MessageBox -Message "Fehler beim Freigeben der Nachricht:`n$errorMsg" -Title "Fehler" -Type "Error"
        Log-Action "Fehler beim Freigeben der Quarantäne-Nachricht: $errorMsg"
    }
}

function Delete-QuarantineMessageAction {
    [CmdletBinding()]
    param()

    # Prüfen, ob eine Verbindung zu Exchange Online besteht
    if (-not (Confirm-ExchangeConnection)) {
        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Nicht verbunden" -Type "Warning"
        return
    }

    $selectedItem = $script:dgQuarantineMessages.SelectedItem
    if ($null -eq $selectedItem) {
        Show-MessageBox -Message "Bitte wählen Sie eine Nachricht aus der Quarantäne-Liste aus, um sie zu löschen." -Title "Keine Auswahl" -Type "Warning"
        return
    }

    # Bestätigungsdialog anzeigen, da dies eine endgültige Aktion ist
    $confirmMessage = "Möchten Sie die ausgewählte Nachricht von '$($selectedItem.SenderAddress)' mit dem Betreff '$($selectedItem.Subject)' wirklich endgültig löschen?`n`nDiese Aktion kann nicht rückgängig gemacht werden."
    $confirmResult = Show-MessageBox -Message $confirmMessage -Title "Löschen bestätigen" -Type "YesNo" -Icon "Warning"
    if ($confirmResult -ne "Yes") {
        Update-StatusBar -Message "Löschvorgang abgebrochen." -Type "Info"
        return
    }

    try {
        Update-StatusBar -Message "Lösche Nachricht..." -Type "Info"
        Write-Log "Delete-QuarantineMessageAction: Löschen für Nachricht mit Identity '$($selectedItem.Identity)' gestartet." -Type "Info"

        # Quarantäne-Nachricht löschen
        Delete-QuarantineMessage -Identity $selectedItem.Identity -Confirm:$false -ErrorAction Stop

        Show-MessageBox -Message "Die ausgewählte Nachricht wurde erfolgreich gelöscht." -Title "Erfolg" -Type "Info"
        Update-StatusBar -Message "Nachricht erfolgreich gelöscht." -Type "Success"
        Log-Action "Quarantäne-Nachricht gelöscht: $($selectedItem.Identity)"

        # Liste aktualisieren, um die gelöschte Nachricht zu entfernen
        Get-QuarantineMessagesAction
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Löschen der Quarantäne-Nachricht"
        Write-Log "Fehler beim Löschen der Quarantäne-Nachricht: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Fehler beim Löschen der Nachricht: $errorMsg" -Type "Error"
        Show-MessageBox -Message "Fehler beim Löschen der Nachricht:`n$errorMsg" -Title "Fehler" -Type "Error"
        Log-Action "Fehler beim Löschen der Quarantäne-Nachricht: $errorMsg"
    }
}

function Export-QuarantineMessagesAction {
    [CmdletBinding()]
    param()

    try {
        # Prüfen, ob eine Verbindung zu Exchange Online besteht
        if (-not (Confirm-ExchangeConnection)) {
            Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Nicht verbunden" -Type "Warning"
            return
        }

        # Prüfen, ob das DataGrid-Element vorhanden ist
        if ($null -eq $script:dgQuarantineMessages) {
            Write-Log "Export-QuarantineMessagesAction: Das DataGrid 'dgQuarantineMessages' ist nicht initialisiert." -Type "Error"
            Show-MessageBox -Message "Ein interner Fehler ist aufgetreten: Das Quarantäne-Datenraster wurde nicht gefunden." -Title "UI-Fehler" -Type "Error"
            return
        }

        # Die wiederverwendbare Export-Funktion aufrufen
        Export-DataGridContent -DataGrid $script:dgQuarantineMessages -DefaultFileName "QuarantineMessages"
        Log-Action "Quarantäne-Nachrichten exportiert."

    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Ein unerwarteter Fehler ist beim Export der Quarantäne-Nachrichten aufgetreten."
        Write-Log $errorMsg -Type "Error"
        Log-Action "Fehler beim Export der Quarantäne-Nachrichten: $errorMsg"
        Show-MessageBox -Message $errorMsg -Title "Export-Fehler" -Type "Error"
        Update-StatusBar -Message "Fehler beim Export der Quarantäne-Nachrichten." -Type "Error"
    }
}

function Initialize-ATPTab {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Initialisiere Advanced Threat Protection (ATP) Tab..." -Type "Info"

        # --- Allgemeine Elemente ---
        $helpLinkATP = Get-XamlElement -ElementName "helpLinkATP"

        # --- Anti-Phishing ---
        $btnGetAntiPhishing = Get-XamlElement -ElementName "btnGetAntiPhishing"
        $btnNewAntiPhishing = Get-XamlElement -ElementName "btnNewAntiPhishing"
        $btnSetAntiPhishing = Get-XamlElement -ElementName "btnSetAntiPhishing"
        $dgAntiPhishingPolicies = Get-XamlElement -ElementName "dgAntiPhishingPolicies"
        $btnExportAntiPhishing = Get-XamlElement -ElementName "btnExportAntiPhishing"
        $script:dgAntiPhishingPolicies = $dgAntiPhishingPolicies

        # --- Safe Attachments ---
        $btnGetSafeAttachment = Get-XamlElement -ElementName "btnGetSafeAttachment"
        $btnNewSafeAttachment = Get-XamlElement -ElementName "btnNewSafeAttachment"
        $btnSetSafeAttachment = Get-XamlElement -ElementName "btnSetSafeAttachment"
        $dgSafeAttachmentPolicies = Get-XamlElement -ElementName "dgSafeAttachmentPolicies"
        $btnExportSafeAttachment = Get-XamlElement -ElementName "btnExportSafeAttachment"
        $script:dgSafeAttachmentPolicies = $dgSafeAttachmentPolicies

        # --- Safe Links ---
        $btnGetSafeLinks = Get-XamlElement -ElementName "btnGetSafeLinks"
        $btnNewSafeLinks = Get-XamlElement -ElementName "btnNewSafeLinks"
        $btnSetSafeLinks = Get-XamlElement -ElementName "btnSetSafeLinks"
        $dgSafeLinksPolicies = Get-XamlElement -ElementName "dgSafeLinksPolicies"
        $btnExportSafeLinks = Get-XamlElement -ElementName "btnExportSafeLinks"
        $script:dgSafeLinksPolicies = $dgSafeLinksPolicies

        # --- Quarantäne ---
        $btnGetQuarantineMessages = Get-XamlElement -ElementName "btnGetQuarantineMessages"
        $btnReleaseQuarantine = Get-XamlElement -ElementName "btnReleaseQuarantine"
        $btnDeleteQuarantine = Get-XamlElement -ElementName "btnDeleteQuarantine"
        $dgQuarantineMessages = Get-XamlElement -ElementName "dgQuarantineMessages"
        $btnExportQuarantine = Get-XamlElement -ElementName "btnExportQuarantine"
        $script:dgQuarantineMessages = $dgQuarantineMessages

        # --- Event Handler ---

        # Hilfe-Link
        if ($null -ne $helpLinkATP) {
            $helpLinkATP.Add_MouseLeftButtonDown({
                try { Start-Process "https://learn.microsoft.com/de-de/microsoft-365/security/office-365-security/microsoft-defender-for-office-365" } catch { }
            })
        }

        # Anti-Phishing Handler
        Register-EventHandler -Control $btnGetAntiPhishing -Handler { Get-AntiPhishingPoliciesAction } -ControlName "btnGetAntiPhishing"
        Register-EventHandler -Control $btnNewAntiPhishing -Handler { New-AntiPhishingPolicyAction } -ControlName "btnNewAntiPhishing"
        Register-EventHandler -Control $btnSetAntiPhishing -Handler { Set-AntiPhishingPolicyAction } -ControlName "btnSetAntiPhishing"
        Register-EventHandler -Control $btnExportAntiPhishing -Handler { Export-AntiPhishingPoliciesAction } -ControlName "btnExportAntiPhishing"

        # Safe Attachments Handler
        Register-EventHandler -Control $btnGetSafeAttachment -Handler { Get-SafeAttachmentPoliciesAction } -ControlName "btnGetSafeAttachment"
        Register-EventHandler -Control $btnNewSafeAttachment -Handler { New-SafeAttachmentPolicyAction } -ControlName "btnNewSafeAttachment"
        Register-EventHandler -Control $btnSetSafeAttachment -Handler { Set-SafeAttachmentPolicyAction } -ControlName "btnSetSafeAttachment"
        Register-EventHandler -Control $btnExportSafeAttachment -Handler { Export-SafeAttachmentPoliciesAction } -ControlName "btnExportSafeAttachment"

        # Safe Links Handler
        Register-EventHandler -Control $btnGetSafeLinks -Handler { Get-SafeLinksPoliciesAction } -ControlName "btnGetSafeLinks"
        Register-EventHandler -Control $btnNewSafeLinks -Handler { New-SafeLinksPolicyAction } -ControlName "btnNewSafeLinks"
        Register-EventHandler -Control $btnSetSafeLinks -Handler { Set-SafeLinksPolicyAction } -ControlName "btnSetSafeLinks"
        Register-EventHandler -Control $btnExportSafeLinks -Handler { Export-SafeLinksPoliciesAction } -ControlName "btnExportSafeLinks"

        # Quarantäne Handler
        Register-EventHandler -Control $btnGetQuarantineMessages -Handler { Get-QuarantineMessagesAction } -ControlName "btnGetQuarantineMessages"
        Register-EventHandler -Control $btnReleaseQuarantine -Handler { Release-QuarantineMessageAction } -ControlName "btnReleaseQuarantine"
        Register-EventHandler -Control $btnDeleteQuarantine -Handler { Delete-QuarantineMessageAction } -ControlName "btnDeleteQuarantine"
        Register-EventHandler -Control $btnExportQuarantine -Handler { Export-QuarantineMessagesAction } -ControlName "btnExportQuarantine"

        Write-Log "ATP Tab erfolgreich initialisiert." -Type "Success"
        return $true
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler bei der Initialisierung des ATP Tabs."
        Write-Log $errorMsg -Type "Error"
        return $false
    }
}
