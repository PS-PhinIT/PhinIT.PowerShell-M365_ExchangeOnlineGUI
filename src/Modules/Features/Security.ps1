# =====================================================================
# easyEXO - Modul: Microsoft Defender für Office 365 (Anti-Phishing, Sichere Anlagen/Links) und Quarantäne
# Datei: src/Modules/Features/Security.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# Teilt die Eingabe "Anwenden auf" (mit Semikolon getrennt) in Domänen und Empfänger auf.
# Empfänger sind Einträge mit "@", Einträge ohne Punkt (Alias/Name) sowie Einträge, die bereits als
# Empfänger in der Regel stehen (-KnownRecipients, z. B. $rule.SentTo); alle übrigen gelten als Domänen.
# Leere Listen werden als $null geliefert - bei Set-*Rule entfernt das die jeweilige Bedingung.
function ConvertTo-SecurityRuleScope {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text,

        [AllowNull()]
        [object[]]$KnownRecipients
    )

    $known = @($KnownRecipients | Where-Object { $null -ne $_ } | ForEach-Object { "$_".Trim() } | Where-Object { $_ -ne "" })
    $entries = @("$Text" -split ';' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $isRecipient = { param($entry) $entry -like "*@*" -or $entry -notlike "*.*" -or $known -contains $entry }
    $domains = @($entries | Where-Object { -not (& $isRecipient $_) })
    $recipients = @($entries | Where-Object { & $isRecipient $_ })
    [PSCustomObject]@{
        Domains    = if ($domains.Count -gt 0) { [string[]]$domains } else { $null }
        Recipients = if ($recipients.Count -gt 0) { [string[]]$recipients } else { $null }
        Count      = $entries.Count
    }
}

# Fasst mehrere boolesche Einstellungen für eine Checkbox zusammen: $true/$false, wenn alle gleich sind,
# sonst $null (Checkbox "unbestimmt" - der Wert wird dann beim Speichern nicht verändert).
function Get-CombinedCheckState {
    [CmdletBinding()]
    param(
        [object[]]$Values
    )

    $flags = @($Values | ForEach-Object { $_ -eq $true })
    if ($flags -notcontains $false) { return $true }
    if ($flags -notcontains $true) { return $false }
    return $null
}

# Prüft, ob eine Regel nach dem Leeren von "Anwenden auf" noch eine Empfängerbedingung (Gruppen) behält
function Test-SecurityRuleKeepsCondition {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        $Rule,

        [Parameter(Mandatory = $true)]
        $Scope
    )

    if ($null -eq $Rule -or $Scope.Count -gt 0) { return $true }
    return (@($Rule.SentToMemberOf | Where-Object { $null -ne $_ -and "$_" -ne "" }).Count -gt 0)
}

# Legt die Regel einer Defender-Richtlinie an (falls Empfänger angegeben sind) oder aktualisiert
# Empfängerbereich und - wenn -Enabled angegeben ist - den Status (Enable-/Disable-*Rule) der vorhandenen Regel.
function Sync-SecurityPolicyRule {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("AntiPhish", "SafeAttachment", "SafeLinks")]
        [string]$RuleType,

        [Parameter(Mandatory = $true)]
        [string]$PolicyName,

        [AllowNull()]
        $Rule,

        [Parameter(Mandatory = $true)]
        $Scope,

        [Nullable[bool]]$Enabled
    )

    $commands = @{
        AntiPhish      = @{ New = "New-AntiPhishRule"; Set = "Set-AntiPhishRule"; Enable = "Enable-AntiPhishRule"; Disable = "Disable-AntiPhishRule"; PolicyParameter = "AntiPhishPolicy" }
        SafeAttachment = @{ New = "New-SafeAttachmentRule"; Set = "Set-SafeAttachmentRule"; Enable = "Enable-SafeAttachmentRule"; Disable = "Disable-SafeAttachmentRule"; PolicyParameter = "SafeAttachmentPolicy" }
        SafeLinks      = @{ New = "New-SafeLinksRule"; Set = "Set-SafeLinksRule"; Enable = "Enable-SafeLinksRule"; Disable = "Disable-SafeLinksRule"; PolicyParameter = "SafeLinksPolicy" }
    }[$RuleType]

    if ($null -ne $Rule) {
        if ($PSCmdlet.ShouldProcess($Rule.Name, "Regel aktualisieren")) {
            # Beide Bedingungen immer übergeben: $null entfernt eine geleerte Bedingung
            $setParams = @{
                Identity          = $Rule.Name
                RecipientDomainIs = $Scope.Domains
                SentTo            = $Scope.Recipients
                ErrorAction       = 'Stop'
            }
            & $commands.Set @setParams
            Write-Log "Regel '$($Rule.Name)' für Richtlinie '$PolicyName' aktualisiert." -Type "Info"

            if ($null -ne $Enabled -and $Enabled -ne ([string]$Rule.State -eq 'Enabled')) {
                $stateCommand = if ($Enabled) { $commands.Enable } else { $commands.Disable }
                & $stateCommand -Identity $Rule.Name -Confirm:$false -ErrorAction Stop
                Write-Log "Regel '$($Rule.Name)' wurde $(if ($Enabled) { 'aktiviert' } else { 'deaktiviert' })." -Type "Info"
            }
        }
        return
    }

    if ($Scope.Count -eq 0) { return }

    $ruleName = "$($PolicyName)_Rule"
    if ($PSCmdlet.ShouldProcess($ruleName, "Regel erstellen")) {
        $newParams = @{
            Name        = $ruleName
            ErrorAction = 'Stop'
        }
        $newParams[$commands.PolicyParameter] = $PolicyName
        if ($null -ne $Enabled) { $newParams.Enabled = [bool]$Enabled }
        if ($null -ne $Scope.Domains) { $newParams.RecipientDomainIs = $Scope.Domains }
        if ($null -ne $Scope.Recipients) { $newParams.SentTo = $Scope.Recipients }
        $null = & $commands.New @newParams
        Write-Log "Neue Regel '$ruleName' für Richtlinie '$PolicyName' erstellt." -Type "Info"
    }
}

function Get-AntiPhishingPoliciesAction {
    if (-not (Confirm-ExchangeConnection)) { return }
    Update-StatusBar -Message "Anti-Phishing-Richtlinien werden geladen..." -Type Info
    try {
        $policies = @(Get-AntiPhishPolicy -ErrorAction Stop)
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
        $null = Add-ThemeResource -Window $dialog
        
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

                $impersonationEnabled = [bool]$chkImpersonationProtectionEnabled.IsChecked
                $mailboxIntelligenceEnabled = [bool]$chkMailboxIntelligenceProtectionEnabled.IsChecked
                $policyParams = @{
                    Name = $policyName
                    Enabled = [bool]$chkEnabled.IsChecked
                    EnableTargetedUserProtection = $impersonationEnabled
                    EnableOrganizationDomainsProtection = $impersonationEnabled
                    EnableSpoofIntelligence = [bool]$chkSpoofProtectionEnabled.IsChecked
                    EnableMailboxIntelligence = $mailboxIntelligenceEnabled
                    EnableMailboxIntelligenceProtection = $mailboxIntelligenceEnabled
                    ErrorAction = 'Stop'
                }
                $adminDisplayName = $txtPolicyDescription.Text.Trim()
                if (-not [string]::IsNullOrWhiteSpace($adminDisplayName)) {
                    $policyParams.AdminDisplayName = $adminDisplayName
                }

                # Richtlinie erstellen
                $null = New-AntiPhishPolicy @policyParams

                # Regel erstellen und mit Richtlinie verknüpfen (der Status der Regel bestimmt, ob die Richtlinie aktiv ist)
                $scope = ConvertTo-SecurityRuleScope -Text $txtAppliedTo.Text
                Sync-SecurityPolicyRule -RuleType AntiPhish -PolicyName $policyName -Rule $null -Scope $scope -Enabled ([bool]$chkEnabled.IsChecked)

                $dialog.DialogResult = $true
                $dialog.Close()
                $successMessage = "Die Anti-Phishing-Richtlinie '$policyName' wurde erfolgreich erstellt."
                if ($scope.Count -eq 0) {
                    $successMessage += "`n`nHinweis: Ohne Angabe unter 'Anwenden auf' wurde keine Regel erstellt - die Richtlinie ist noch nicht wirksam."
                }
                Show-MessageBox -Message $successMessage -Title "Erfolg" -Type Info
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
        $rule = $null
        $ruleLookupFailed = $false
        try {
            $rule = Get-AntiPhishRule -ErrorAction Stop | Where-Object { $_.AntiPhishPolicy -eq $selectedPolicy.Name } | Select-Object -First 1
        } catch {
            $ruleLookupFailed = $true
            Write-Log "Anti-Phishing-Regel für '$($selectedPolicy.Name)' konnte nicht abgerufen werden: $($_.Exception.Message)" -Type "Warning"
            Show-MessageBox -Message "Die zugehörige Anti-Phishing-Regel konnte nicht abgerufen werden. 'Anwenden auf' und der Regelstatus werden daher nicht geändert.`n`n$($_.Exception.Message)" -Title "Regel nicht verfügbar" -Type "Warning"
        }

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
                <TextBox x:Name="txtPolicyName" Margin="0,0,0,10" IsReadOnly="True" Background="{DynamicResource SurfaceHoverBrush}"/>
                
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
        $null = Add-ThemeResource -Window $dialog
        
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
        $txtPolicyDescription.Text = [string]$selectedPolicy.AdminDisplayName
        # Ob eine Anti-Phishing-Richtlinie aktiv ist, steuert der Status der zugehörigen Regel
        $chkEnabled.IsChecked = if ($null -ne $rule) { [string]$rule.State -eq 'Enabled' } else { $selectedPolicy.Enabled -eq $true }
        $chkImpersonationProtectionEnabled.IsChecked = Get-CombinedCheckState -Values @($selectedPolicy.EnableTargetedUserProtection, $selectedPolicy.EnableOrganizationDomainsProtection)
        $chkSpoofProtectionEnabled.IsChecked = $selectedPolicy.EnableSpoofIntelligence -eq $true
        $chkMailboxIntelligenceProtectionEnabled.IsChecked = Get-CombinedCheckState -Values @($selectedPolicy.EnableMailboxIntelligence, $selectedPolicy.EnableMailboxIntelligenceProtection)
        $txtAppliedTo.IsEnabled = -not $ruleLookupFailed
        
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
                $scope = ConvertTo-SecurityRuleScope -Text $txtAppliedTo.Text -KnownRecipients $(if ($null -ne $rule) { @($rule.SentTo) })
                if (-not $ruleLookupFailed -and -not (Test-SecurityRuleKeepsCondition -Rule $rule -Scope $scope)) {
                    Show-MessageBox -Message "Die zugehörige Regel '$($rule.Name)' benötigt mindestens einen Empfänger oder eine Domäne unter 'Anwenden auf'." -Title "Eingabe fehlt" -Type Warning
                    return
                }

                Update-StatusBar -Message "Aktualisiere Anti-Phishing-Richtlinie '$policyName'..." -Type Info

                $policyParams = @{
                    Identity = $policyName
                    Enabled = [bool]$chkEnabled.IsChecked
                    EnableSpoofIntelligence = [bool]$chkSpoofProtectionEnabled.IsChecked
                    ErrorAction = 'Stop'
                }
                # Unbestimmte Checkboxen (gemischte Werte) lassen die Einstellungen unverändert
                if ($null -ne $chkImpersonationProtectionEnabled.IsChecked) {
                    $policyParams.EnableTargetedUserProtection = [bool]$chkImpersonationProtectionEnabled.IsChecked
                    $policyParams.EnableOrganizationDomainsProtection = [bool]$chkImpersonationProtectionEnabled.IsChecked
                }
                if ($null -ne $chkMailboxIntelligenceProtectionEnabled.IsChecked) {
                    $policyParams.EnableMailboxIntelligence = [bool]$chkMailboxIntelligenceProtectionEnabled.IsChecked
                    $policyParams.EnableMailboxIntelligenceProtection = [bool]$chkMailboxIntelligenceProtectionEnabled.IsChecked
                }
                $adminDisplayName = $txtPolicyDescription.Text.Trim()
                if ($adminDisplayName -ne ([string]$selectedPolicy.AdminDisplayName).Trim()) {
                    $policyParams.AdminDisplayName = $adminDisplayName
                }

                # Richtlinie aktualisieren
                Set-AntiPhishPolicy @policyParams

                # Regel aktualisieren bzw. anlegen, wenn noch keine existiert und Empfänger angegeben sind
                if (-not $ruleLookupFailed) {
                    Sync-SecurityPolicyRule -RuleType AntiPhish -PolicyName $policyName -Rule $rule -Scope $scope -Enabled ([bool]$chkEnabled.IsChecked)
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
            # Zuerst alle Regeln löschen, die auf die Richtlinie verweisen
            $rules = @(Get-AntiPhishRule -ErrorAction Stop | Where-Object { $_.AntiPhishPolicy -eq $policyName })
            foreach ($rule in $rules) {
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
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }
    Update-StatusBar -Message "Safe Attachment-Richtlinien werden geladen..." -Type Info

    try {
        $policies = @(Get-SafeAttachmentPolicy -ErrorAction Stop)
        $script:dgSafeAttachmentPolicies.Dispatcher.Invoke([Action]{
            $script:dgSafeAttachmentPolicies.ItemsSource = $policies
        })
        Update-StatusBar -Message "$($policies.Count) Safe Attachment-Richtlinien geladen." -Type Success
        Log-Action "Safe Attachment-Richtlinien geladen: $($policies.Count) gefunden."
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Laden der Safe Attachment-Richtlinien."
        Update-StatusBar -Message $errorMsg -Type Error
        Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
        Log-Action "Fehler beim Laden der Safe Attachment-Richtlinien: $errorMsg"
    }
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
        Title="Neue Safe Attachment-Richtlinie" Height="550" Width="600"
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
                    <ComboBoxItem Content="Zulassen (Allow)" Tag="Allow"/>
                    <ComboBoxItem Content="Blockieren (Block)" Tag="Block" IsSelected="True"/>
                    <ComboBoxItem Content="Dynamische Zustellung (DynamicDelivery)" Tag="DynamicDelivery"/>
                </ComboBox>

                <CheckBox x:Name="chkEnableRedirect" Content="Umleitung aktivieren" Margin="0,10,0,0" ToolTip="Nur wirksam mit der Aktion 'Zulassen (Allow)'."/>
                <TextBox x:Name="txtRedirectAddress" Margin="0,0,0,10" ToolTip="E-Mail-Adresse für Umleitung" IsEnabled="False"/>

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
        $null = Add-ThemeResource -Window $dialog
        
        # UI-Elemente referenzieren
        $txtPolicyName = $dialog.FindName("txtPolicyName")
        $txtPolicyDescription = $dialog.FindName("txtPolicyDescription")
        $chkEnabled = $dialog.FindName("chkEnabled")
        $cmbAction = $dialog.FindName("cmbAction")
        $chkEnableRedirect = $dialog.FindName("chkEnableRedirect")
        $txtRedirectAddress = $dialog.FindName("txtRedirectAddress")
        $txtAppliedTo = $dialog.FindName("txtAppliedTo")
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
                if ($chkEnableRedirect.IsChecked -and [string]::IsNullOrWhiteSpace($txtRedirectAddress.Text)) {
                    Show-MessageBox -Message "Bitte geben Sie eine E-Mail-Adresse für die Umleitung an." -Title "Eingabe fehlt" -Type Warning
                    return
                }

                Update-StatusBar -Message "Erstelle Safe Attachment-Richtlinie '$policyName'..." -Type Info

                $selectedActionItem = $cmbAction.SelectedItem
                $actionValue = if ($null -ne $selectedActionItem -and $selectedActionItem.Tag) { [string]$selectedActionItem.Tag } else { "Block" }

                $policyParams = @{
                    Name = $policyName
                    Enable = [bool]$chkEnabled.IsChecked
                    Action = $actionValue
                    ErrorAction = 'Stop'
                }
                $adminDisplayName = $txtPolicyDescription.Text.Trim()
                if (-not [string]::IsNullOrWhiteSpace($adminDisplayName)) {
                    $policyParams.AdminDisplayName = $adminDisplayName
                }

                # RedirectAddress wird nur zusammen mit Redirect = $true ausgewertet
                if ($chkEnableRedirect.IsChecked) {
                    $policyParams.Redirect = $true
                    $policyParams.RedirectAddress = $txtRedirectAddress.Text.Trim()
                }

                # Richtlinie erstellen
                $null = New-SafeAttachmentPolicy @policyParams

                # Regel erstellen, wenn Empfänger angegeben sind (ohne Regel ist die Richtlinie nicht wirksam)
                $scope = ConvertTo-SecurityRuleScope -Text $txtAppliedTo.Text
                Sync-SecurityPolicyRule -RuleType SafeAttachment -PolicyName $policyName -Rule $null -Scope $scope -Enabled $true

                $dialog.DialogResult = $true
                $dialog.Close()
                $successMessage = "Die Safe Attachment-Richtlinie '$policyName' wurde erfolgreich erstellt."
                if ($scope.Count -eq 0) {
                    $successMessage += "`n`nHinweis: Ohne Angabe unter 'Anwenden auf' wurde keine Regel erstellt - die Richtlinie ist noch nicht wirksam."
                }
                Show-MessageBox -Message $successMessage -Title "Erfolg" -Type Info
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
        $ruleLookupFailed = $false
        try {
            $rule = Get-SafeAttachmentRule -ErrorAction Stop | Where-Object { $_.SafeAttachmentPolicy -eq $selectedPolicy.Name } | Select-Object -First 1
        } catch {
            $ruleLookupFailed = $true
            Write-Log "Safe Attachment-Regel für '$($selectedPolicy.Name)' konnte nicht abgerufen werden: $($_.Exception.Message)" -Type "Warning"
            Show-MessageBox -Message "Die zugehörige Safe Attachment-Regel konnte nicht abgerufen werden. 'Anwenden auf' wird daher nicht geändert.`n`n$($_.Exception.Message)" -Title "Regel nicht verfügbar" -Type "Warning"
        }

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
                <TextBox x:Name="txtPolicyName" Margin="0,0,0,10" IsReadOnly="True" Background="{DynamicResource SurfaceHoverBrush}"/>
                
                <Label Content="Beschreibung (optional):" FontWeight="SemiBold"/>
                <TextBox x:Name="txtPolicyDescription" Margin="0,0,0,10" Height="60" TextWrapping="Wrap" AcceptsReturn="True"/>

                <CheckBox x:Name="chkEnabled" Content="Richtlinie aktivieren" Margin="0,10,0,10"/>
                
                <Label Content="Aktion bei schädlichen Anhängen:" FontWeight="SemiBold"/>
                <ComboBox x:Name="cmbAction" Margin="0,0,0,10">
                    <ComboBoxItem Content="Zulassen (Allow)" Tag="Allow"/>
                    <ComboBoxItem Content="Blockieren (Block)" Tag="Block"/>
                    <ComboBoxItem Content="Dynamische Zustellung (DynamicDelivery)" Tag="DynamicDelivery"/>
                </ComboBox>

                <CheckBox x:Name="chkEnableRedirect" Content="Umleitung für erkannte Anhänge aktivieren" Margin="0,10,0,0" ToolTip="Nur wirksam mit der Aktion 'Zulassen (Allow)'."/>
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
        $null = Add-ThemeResource -Window $dialog
        
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
        $txtPolicyDescription.Text = [string]$selectedPolicy.AdminDisplayName
        $chkEnabled.IsChecked = $selectedPolicy.Enable -eq $true

        # Aktion in ComboBox auswählen
        $currentAction = [string]$selectedPolicy.Action
        $actionItem = $cmbAction.Items | Where-Object { [string]$_.Tag -eq $currentAction } | Select-Object -First 1
        if ($null -ne $actionItem) {
            $cmbAction.SelectedItem = $actionItem
        } elseif (-not [string]::IsNullOrWhiteSpace($currentAction)) {
            Write-Log "Unbekannte Safe Attachment-Aktion '$currentAction' bei Richtlinie '$($selectedPolicy.Name)' - die Aktion bleibt unverändert, solange keine Auswahl getroffen wird." -Type "Warning"
        }

        # Umleitungseinstellungen
        $chkEnableRedirect.IsChecked = $selectedPolicy.Redirect -eq $true
        $txtRedirectAddress.IsEnabled = $selectedPolicy.Redirect -eq $true
        $txtRedirectAddress.Text = [string]$selectedPolicy.RedirectAddress
        $txtAppliedTo.IsEnabled = -not $ruleLookupFailed

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
                if ($chkEnableRedirect.IsChecked -and [string]::IsNullOrWhiteSpace($txtRedirectAddress.Text)) {
                    Show-MessageBox -Message "Bitte geben Sie eine E-Mail-Adresse für die Umleitung an." -Title "Eingabe fehlt" -Type Warning
                    return
                }
                $scope = ConvertTo-SecurityRuleScope -Text $txtAppliedTo.Text -KnownRecipients $(if ($null -ne $rule) { @($rule.SentTo) })
                if (-not $ruleLookupFailed -and -not (Test-SecurityRuleKeepsCondition -Rule $rule -Scope $scope)) {
                    Show-MessageBox -Message "Die zugehörige Regel '$($rule.Name)' benötigt mindestens einen Empfänger oder eine Domäne unter 'Anwenden auf'." -Title "Eingabe fehlt" -Type Warning
                    return
                }

                Update-StatusBar -Message "Aktualisiere Safe Attachment-Richtlinie '$policyName'..." -Type Info

                $policyParams = @{
                    Identity = $policyName
                    Enable = [bool]$chkEnabled.IsChecked
                    ErrorAction = 'Stop'
                }
                # Ohne Auswahl (unbekannter bisheriger Wert) bleibt die Aktion unverändert
                $selectedActionItem = $cmbAction.SelectedItem
                if ($null -ne $selectedActionItem -and $selectedActionItem.Tag) {
                    $policyParams.Action = [string]$selectedActionItem.Tag
                }
                $adminDisplayName = $txtPolicyDescription.Text.Trim()
                if ($adminDisplayName -ne ([string]$selectedPolicy.AdminDisplayName).Trim()) {
                    $policyParams.AdminDisplayName = $adminDisplayName
                }
                # RedirectAddress wird nur zusammen mit Redirect = $true ausgewertet
                if ($chkEnableRedirect.IsChecked) {
                    $policyParams.Redirect = $true
                    $policyParams.RedirectAddress = $txtRedirectAddress.Text.Trim()
                } else {
                    $policyParams.Redirect = $false
                }

                # Richtlinie aktualisieren
                Set-SafeAttachmentPolicy @policyParams

                # Regel aktualisieren bzw. anlegen, wenn noch keine existiert und Empfänger angegeben sind
                if (-not $ruleLookupFailed) {
                    Sync-SecurityPolicyRule -RuleType SafeAttachment -PolicyName $policyName -Rule $rule -Scope $scope
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
            # Zuerst alle Regeln löschen, die auf die Richtlinie verweisen
            $rules = @(Get-SafeAttachmentRule -ErrorAction Stop | Where-Object { $_.SafeAttachmentPolicy -eq $policyName })
            foreach ($rule in $rules) {
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
        $policies = @(Get-SafeLinksPolicy -ErrorAction Stop)
        
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
                        <CheckBox x:Name="chkWaitForScan" Content="Warten, bis die URL-Überprüfung abgeschlossen ist" IsChecked="True" ToolTip="Verhindert die Zustellung von Nachrichten mit potenziell schädlichen Links, bis die Überprüfung abgeschlossen ist."/>
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
        $null = Add-ThemeResource -Window $dialog
        
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

                # Ob die Richtlinie aktiv ist, steuert die zugehörige Regel (Safe Links-Richtlinien haben keinen Enabled-Parameter)
                $policyParams = @{
                    Name = $policyName
                    EnableSafeLinksForEmail = [bool]$chkScanUrlsInEmail.IsChecked
                    EnableSafeLinksForOffice = [bool]$chkScanUrlsInOffice.IsChecked
                    DeliverMessageAfterScan = [bool]$chkWaitForScan.IsChecked
                    TrackClicks = -not [bool]$chkDoNotTrackClicks.IsChecked
                    AllowClickThrough = -not [bool]$chkDoNotAllowClickThrough.IsChecked
                    EnableOrganizationBranding = [bool]$chkDisplayBranding.IsChecked
                    ErrorAction = 'Stop'
                }
                # Warten auf den Scan setzt die Echtzeitüberprüfung von URLs voraus
                if ($chkWaitForScan.IsChecked) {
                    $policyParams.ScanUrls = $true
                }
                $adminDisplayName = $txtPolicyDescription.Text.Trim()
                if (-not [string]::IsNullOrWhiteSpace($adminDisplayName)) {
                    $policyParams.AdminDisplayName = $adminDisplayName
                }

                $doNotRewriteUrlsList = @($txtDoNotRewriteUrls.Text.Trim() -split ';' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                if ($doNotRewriteUrlsList.Count -gt 0) {
                    $policyParams.Add("DoNotRewriteUrls", $doNotRewriteUrlsList)
                }

                # Richtlinie erstellen
                $null = New-SafeLinksPolicy @policyParams

                # Regel erstellen und mit Richtlinie verknüpfen, wenn Empfänger angegeben sind
                $scope = ConvertTo-SecurityRuleScope -Text $txtAppliedTo.Text
                Sync-SecurityPolicyRule -RuleType SafeLinks -PolicyName $policyName -Rule $null -Scope $scope -Enabled ([bool]$chkEnabled.IsChecked)

                $dialog.DialogResult = $true
                $dialog.Close()
                $successMessage = "Die Safe Links-Richtlinie '$policyName' wurde erfolgreich erstellt."
                if ($scope.Count -eq 0) {
                    $successMessage += "`n`nHinweis: Ohne Angabe unter 'Anwenden auf' wurde keine Regel erstellt - die Richtlinie ist noch nicht wirksam."
                }
                Show-MessageBox -Message $successMessage -Title "Erfolg" -Type Info
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
        $ruleLookupFailed = $false
        try {
            $rule = Get-SafeLinksRule -ErrorAction Stop | Where-Object { $_.SafeLinksPolicy -eq $selectedPolicy.Name } | Select-Object -First 1
        } catch {
            $ruleLookupFailed = $true
            Write-Log "Safe Links-Regel für '$($selectedPolicy.Name)' konnte nicht abgerufen werden: $($_.Exception.Message)" -Type "Warning"
            Show-MessageBox -Message "Die zugehörige Safe Links-Regel konnte nicht abgerufen werden. 'Anwenden auf' und der Regelstatus werden daher nicht geändert.`n`n$($_.Exception.Message)" -Title "Regel nicht verfügbar" -Type "Warning"
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
                <TextBox x:Name="txtPolicyName" Margin="0,0,0,10" IsReadOnly="True" Background="{DynamicResource SurfaceHoverBrush}"/>
                
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
        $null = Add-ThemeResource -Window $dialog
        
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
        $txtPolicyDescription.Text = [string]$selectedPolicy.AdminDisplayName
        # Ob die Richtlinie aktiv ist, steuert der Status der zugehörigen Regel
        $chkEnabled.IsChecked = if ($null -ne $rule) { [string]$rule.State -eq 'Enabled' } else { $true }
        $chkEnabled.IsEnabled = -not $ruleLookupFailed
        
        # Schutzeinstellungen setzen
        $chkScanUrlsInEmail.IsChecked = $selectedPolicy.EnableSafeLinksForEmail -eq $true
        $chkScanUrlsInOffice.IsChecked = $selectedPolicy.EnableSafeLinksForOffice -eq $true
        $chkWaitForScan.IsChecked = $selectedPolicy.DeliverMessageAfterScan -eq $true

        # Klickschutz-Einstellungen setzen
        $chkDoNotTrackClicks.IsChecked = $selectedPolicy.TrackClicks -eq $false
        $chkDoNotAllowClickThrough.IsChecked = $selectedPolicy.AllowClickThrough -eq $false
        $chkDisplayBranding.IsChecked = $selectedPolicy.EnableOrganizationBranding -eq $true
        $txtAppliedTo.IsEnabled = -not $ruleLookupFailed

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
                $scope = ConvertTo-SecurityRuleScope -Text $txtAppliedTo.Text -KnownRecipients $(if ($null -ne $rule) { @($rule.SentTo) })
                if (-not $ruleLookupFailed -and -not (Test-SecurityRuleKeepsCondition -Rule $rule -Scope $scope)) {
                    Show-MessageBox -Message "Die zugehörige Regel '$($rule.Name)' benötigt mindestens einen Empfänger oder eine Domäne unter 'Anwenden auf'." -Title "Eingabe fehlt" -Type Warning
                    return
                }

                Update-StatusBar -Message "Aktualisiere Safe Links-Richtlinie '$policyName'..." -Type Info

                # Parameter für die Richtlinie vorbereiten (der Aktiv-Status wird über die Regel gesteuert)
                $policyParams = @{
                    Identity = $policyName
                    EnableSafeLinksForEmail = [bool]$chkScanUrlsInEmail.IsChecked
                    EnableSafeLinksForOffice = [bool]$chkScanUrlsInOffice.IsChecked
                    DeliverMessageAfterScan = [bool]$chkWaitForScan.IsChecked
                    TrackClicks = -not [bool]$chkDoNotTrackClicks.IsChecked
                    AllowClickThrough = -not [bool]$chkDoNotAllowClickThrough.IsChecked
                    EnableOrganizationBranding = [bool]$chkDisplayBranding.IsChecked
                    ErrorAction = 'Stop'
                }
                # Warten auf den Scan setzt die Echtzeitüberprüfung von URLs voraus
                if ($chkWaitForScan.IsChecked) {
                    $policyParams.ScanUrls = $true
                }
                $adminDisplayName = $txtPolicyDescription.Text.Trim()
                if ($adminDisplayName -ne ([string]$selectedPolicy.AdminDisplayName).Trim()) {
                    $policyParams.AdminDisplayName = $adminDisplayName
                }

                # DoNotRewriteUrls-Liste aufbereiten
                $doNotRewriteUrlsList = @($txtDoNotRewriteUrls.Text.Trim() -split ';' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                if ($doNotRewriteUrlsList.Count -gt 0) {
                    $policyParams.Add("DoNotRewriteUrls", $doNotRewriteUrlsList)
                } else {
                    # Wenn keine URLs angegeben sind, Liste leeren
                    $policyParams.Add("DoNotRewriteUrls", $null)
                }

                # Richtlinie aktualisieren
                Set-SafeLinksPolicy @policyParams

                # Regel aktualisieren (Empfängerbereich und Status) oder neu erstellen, falls Empfänger angegeben sind
                if (-not $ruleLookupFailed) {
                    Sync-SecurityPolicyRule -RuleType SafeLinks -PolicyName $policyName -Rule $rule -Scope $scope -Enabled ([bool]$chkEnabled.IsChecked)
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

function Remove-SafeLinksPolicyAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if (-not (Confirm-ExchangeConnection)) { return }

    $selectedPolicy = $script:dgSafeLinksPolicies.SelectedItem
    if ($null -eq $selectedPolicy) {
        Show-MessageBox -Message "Bitte wählen Sie eine Richtlinie zum Löschen aus." -Title "Keine Auswahl" -Type "Warning"
        return
    }

    $policyName = $selectedPolicy.Name
    $confirmMessage = "Möchten Sie die Safe Links-Richtlinie '$policyName' und die zugehörige Regel wirklich löschen?"

    if ($PSCmdlet.ShouldProcess($policyName, "Safe Links-Richtlinie und Regel löschen")) {
        $confirmResult = Show-MessageBox -Message $confirmMessage -Title "Löschen bestätigen" -Type "Question" -Icon "Warning"
        if ($confirmResult -ne 'Yes') {
            Update-StatusBar -Message "Löschvorgang abgebrochen." -Type "Info"
            return
        }

        Update-StatusBar -Message "Lösche Richtlinie '$policyName'..." -Type "Info"
        try {
            # Zuerst alle Regeln löschen, die auf die Richtlinie verweisen
            $rules = @(Get-SafeLinksRule -ErrorAction Stop | Where-Object { $_.SafeLinksPolicy -eq $policyName })
            foreach ($rule in $rules) {
                Remove-SafeLinksRule -Identity $rule.Name -Confirm:$false -ErrorAction Stop
                Write-Log "Zugehörige Regel '$($rule.Name)' für Richtlinie '$policyName' gelöscht." -Type "Info"
            }

            # Dann die Richtlinie löschen
            Remove-SafeLinksPolicy -Identity $policyName -Confirm:$false -ErrorAction Stop

            Show-MessageBox -Message "Die Safe Links-Richtlinie '$policyName' wurde erfolgreich gelöscht." -Title "Erfolg" -Type "Info"
            Log-Action "Safe Links-Richtlinie '$policyName' gelöscht."

            # Liste aktualisieren
            Get-SafeLinksPoliciesAction

        } catch {
            $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Löschen der Safe Links-Richtlinie."
            Write-Log $errorMsg -Type "Error"
            Show-MessageBox -Message $errorMsg -Title "Fehler" -Type "Error"
        }
    }
}

function Get-QuarantineMessagesAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$NoDefaultFilter,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1000)]
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
        [ValidateSet("Bulk", "DataLossPrevention", "HighConfPhish", "Malware", "Phish", "Spam", "SPOMalware", "TransportRule")]
        [string]$Type,

        # Sicherheitsgrenze: maximal so viele Seiten abrufen
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100)]
        [int]$MaxPages = 10
    )

    $busyStarted = $false
    try {
        # Prüfen, ob eine Verbindung zu Exchange Online besteht
        if (-not (Confirm-ExchangeConnection)) {
            Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Nicht verbunden" -Type "Warning"
            return
        }

        # Status aktualisieren
        Update-StatusBar -Message "Quarantäne-Nachrichten werden abgerufen..." -Type "Info"
        Write-Log "Get-QuarantineMessagesAction: Rufe Quarantäne-Nachrichten ab" -Type "Info"
        Start-UIBusy -Message "Quarantäne-Nachrichten werden abgerufen..." -Title "Quarantäne" -Cancelable
        $busyStarted = $true
        
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

        # Quarantäne-Nachrichten seitenweise abrufen, bis eine Seite weniger als PageSize Einträge liefert
        Write-Log "Get-QuarantineMessagesAction: Führe Get-QuarantineMessage mit Parametern aus: $($quarantineParams | ConvertTo-Json -Compress)" -Type "Debug"
        $messages = [System.Collections.Generic.List[object]]::new()
        $isTruncated = $false
        $isCancelled = $false
        for ($page = 1; $page -le $MaxPages; $page++) {
            if (Test-UICancelRequested) {
                $isCancelled = $true
                break
            }
            Update-UIBusy -Message "Quarantäne-Nachrichten werden abgerufen (Seite $page, bisher $($messages.Count) Nachrichten)..."
            $pageItems = @(Get-QuarantineMessage @quarantineParams -Page $page)
            foreach ($item in $pageItems) { $messages.Add($item) }
            if ($pageItems.Count -lt $PageSize) { break }
            if ($page -eq $MaxPages) { $isTruncated = $true }
        }
        
        # Wenn keine Nachrichten gefunden wurden
        if ($messages.Count -eq 0) {
            $emptyMessage = if ($isCancelled) { "Abruf der Quarantäne-Nachrichten abgebrochen." } else { "Keine Nachrichten in der Quarantäne gefunden." }
            Update-StatusBar -Message $emptyMessage -Type "Warning"
            Write-Log "Get-QuarantineMessagesAction: $emptyMessage" -Type "Info"
            
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
        $messagesForDisplay = @($messages | ForEach-Object {
            # Zusätzliche Eigenschaften für bessere Darstellung hinzufügen
            $_ | Add-Member -NotePropertyName ReceivedTimeLocal -NotePropertyValue $_.ReceivedTime.ToLocalTime() -Force
            $_ | Add-Member -NotePropertyName Size -NotePropertyValue "$([math]::Round($_.Size / 1KB, 2)) KB" -Force
            $_
        })
        $messageCount = $messagesForDisplay.Count
        
        # Daten im DataGrid anzeigen
        if ($null -ne $script:dgQuarantineMessages) {
            $script:dgQuarantineMessages.Dispatcher.Invoke([Action]{
                $script:dgQuarantineMessages.ItemsSource = $messagesForDisplay
            })
            
            # Status aktualisieren
            if ($isTruncated) {
                Update-StatusBar -Message "$messageCount Nachricht(en) geladen - Obergrenze von $MaxPages Seiten erreicht, es sind evtl. weitere Nachrichten vorhanden. Bitte Filter verwenden." -Type "Warning"
                Write-Log "Get-QuarantineMessagesAction: Abruf nach $MaxPages Seiten ($messageCount Nachrichten) begrenzt" -Type "Warning"
            } elseif ($isCancelled) {
                Update-StatusBar -Message "Abruf abgebrochen - $messageCount Nachricht(en) bis dahin geladen." -Type "Warning"
                Write-Log "Get-QuarantineMessagesAction: Abruf abgebrochen nach $messageCount Nachrichten" -Type "Warning"
            } else {
                Update-StatusBar -Message "$messageCount Nachricht(en) in Quarantäne gefunden." -Type "Success"
                Write-Log "Get-QuarantineMessagesAction: $messageCount Quarantäne-Nachrichten geladen" -Type "Success"
            }
            
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
        if ($busyStarted) {
            Stop-UIBusy
            $busyStarted = $false
        }
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
    finally {
        if ($busyStarted) { Stop-UIBusy }
    }
}

# Führt Freigabe bzw. Löschen für alle übergebenen Quarantäne-Nachrichten aus (mit Arbeitsanzeige)
# und gibt ein Ergebnisobjekt mit Erfolgs-/Fehlerzahlen zurück.
function Invoke-QuarantineMessageOperation {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Messages,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Release", "Delete")]
        [string]$Operation
    )

    $verb = if ($Operation -eq "Release") { "Freigabe" } else { "Löschen" }
    $succeeded = 0
    $failures = [System.Collections.Generic.List[string]]::new()
    $cancelled = $false
    $total = $Messages.Count
    $current = 0

    Start-UIBusy -Message "$verb der Quarantäne-Nachrichten..." -Title "Quarantäne" -Cancelable
    try {
        foreach ($message in $Messages) {
            if (Test-UICancelRequested) {
                $cancelled = $true
                break
            }
            $current++
            Update-UIBusy -Message "$verb der Quarantäne-Nachrichten" -Current $current -Total $total

            $identity = [string]$message.Identity
            if (-not $PSCmdlet.ShouldProcess($identity, "Quarantäne-Nachricht: $verb")) { continue }
            try {
                if ($Operation -eq "Release") {
                    Release-QuarantineMessage -Identity $identity -ReleaseToAll -Confirm:$false -ErrorAction Stop
                } else {
                    Delete-QuarantineMessage -Identity $identity -Confirm:$false -ErrorAction Stop
                }
                $succeeded++
                Log-Action "Quarantäne-Nachricht ($verb): $identity"
            }
            catch {
                $failures.Add("$($message.Subject) [$identity]: $($_.Exception.Message)")
                Write-Log "Quarantäne-Nachricht '$identity' ($verb) fehlgeschlagen: $($_.Exception.Message)" -Type "Error"
            }
        }
    }
    finally {
        Stop-UIBusy
    }

    return [PSCustomObject]@{
        Succeeded = $succeeded
        Failures  = @($failures)
        Cancelled = $cancelled
        Total     = $total
    }
}

# Zeigt die Zusammenfassung einer Freigabe-/Lösch-Aktion an.
function Show-QuarantineOperationSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Result,

        [Parameter(Mandatory = $true)]
        [string]$ActionText
    )

    $summary = "$($Result.Succeeded) von $($Result.Total) Nachricht(en) $ActionText."
    if ($Result.Cancelled) {
        $summary += "`nDer Vorgang wurde abgebrochen."
    }
    if ($Result.Failures.Count -gt 0) {
        $shownFailures = @($Result.Failures | Select-Object -First 10)
        $summary += "`n`nFehler ($($Result.Failures.Count)):`n" + ($shownFailures -join "`n")
        if ($Result.Failures.Count -gt $shownFailures.Count) {
            $summary += "`n... (weitere Details im Log)"
        }
        Update-StatusBar -Message "$($Result.Succeeded) von $($Result.Total) Nachricht(en) $ActionText, $($Result.Failures.Count) Fehler." -Type "Warning"
        $null = Show-MessageBox -Message $summary -Title "Teilweise erfolgreich" -Type "Warning"
    } else {
        $statusType = if ($Result.Cancelled) { "Warning" } else { "Success" }
        Update-StatusBar -Message "$($Result.Succeeded) von $($Result.Total) Nachricht(en) $ActionText." -Type $statusType
        $null = Show-MessageBox -Message $summary -Title "Ergebnis" -Type "Info"
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

    $selectedItems = @(Get-SelectedGridItems -DataGrid $script:dgQuarantineMessages)
    if ($selectedItems.Count -eq 0) {
        Show-MessageBox -Message "Bitte wählen Sie mindestens eine Nachricht aus der Quarantäne-Liste aus." -Title "Keine Auswahl" -Type "Warning"
        return
    }

    # Bestätigungsdialog anzeigen
    $confirmMessage = if ($selectedItems.Count -eq 1) {
        "Möchten Sie die ausgewählte Nachricht von '$($selectedItems[0].SenderAddress)' mit dem Betreff '$($selectedItems[0].Subject)' wirklich an alle ursprünglichen Empfänger freigeben?"
    } else {
        "Möchten Sie die $($selectedItems.Count) ausgewählten Nachrichten wirklich an alle ursprünglichen Empfänger freigeben?"
    }
    $confirmResult = Show-MessageBox -Message $confirmMessage -Title "Freigabe bestätigen" -Type "Question"
    if ($confirmResult -ne "Yes") {
        Update-StatusBar -Message "Freigabe abgebrochen." -Type "Info"
        return
    }

    try {
        Update-StatusBar -Message "Freigabe von $($selectedItems.Count) Nachricht(en) wird durchgeführt..." -Type "Info"
        Write-Log "Release-QuarantineMessageAction: Freigabe für $($selectedItems.Count) Nachricht(en) gestartet." -Type "Info"

        $result = Invoke-QuarantineMessageOperation -Messages $selectedItems -Operation Release
        Show-QuarantineOperationSummary -Result $result -ActionText "freigegeben"

        # Liste aktualisieren
        $null = Get-QuarantineMessagesAction
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Freigeben der Quarantäne-Nachrichten: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Fehler beim Freigeben der Nachrichten: $errorMsg" -Type "Error"
        Show-MessageBox -Message "Fehler beim Freigeben der Nachrichten:`n$errorMsg" -Title "Fehler" -Type "Error"
        Log-Action "Fehler beim Freigeben der Quarantäne-Nachrichten: $errorMsg"
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

    $selectedItems = @(Get-SelectedGridItems -DataGrid $script:dgQuarantineMessages)
    if ($selectedItems.Count -eq 0) {
        Show-MessageBox -Message "Bitte wählen Sie mindestens eine Nachricht aus der Quarantäne-Liste aus, um sie zu löschen." -Title "Keine Auswahl" -Type "Warning"
        return
    }

    # Bestätigungsdialog anzeigen, da dies eine endgültige Aktion ist
    $confirmMessage = if ($selectedItems.Count -eq 1) {
        "Möchten Sie die ausgewählte Nachricht von '$($selectedItems[0].SenderAddress)' mit dem Betreff '$($selectedItems[0].Subject)' wirklich endgültig löschen?"
    } else {
        "Möchten Sie die $($selectedItems.Count) ausgewählten Nachrichten wirklich endgültig löschen?"
    }
    $confirmMessage += "`n`nDiese Aktion kann nicht rückgängig gemacht werden."
    $confirmResult = Show-MessageBox -Message $confirmMessage -Title "Löschen bestätigen" -Type "Question" -Icon "Warning"
    if ($confirmResult -ne "Yes") {
        Update-StatusBar -Message "Löschvorgang abgebrochen." -Type "Info"
        return
    }

    try {
        Update-StatusBar -Message "Lösche $($selectedItems.Count) Nachricht(en)..." -Type "Info"
        Write-Log "Delete-QuarantineMessageAction: Löschen für $($selectedItems.Count) Nachricht(en) gestartet." -Type "Info"

        $result = Invoke-QuarantineMessageOperation -Messages $selectedItems -Operation Delete
        Show-QuarantineOperationSummary -Result $result -ActionText "gelöscht"

        # Liste aktualisieren, um die gelöschten Nachrichten zu entfernen
        $null = Get-QuarantineMessagesAction
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Löschen der Quarantäne-Nachrichten"
        Write-Log "Fehler beim Löschen der Quarantäne-Nachrichten: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Fehler beim Löschen der Nachrichten: $errorMsg" -Type "Error"
        Show-MessageBox -Message "Fehler beim Löschen der Nachrichten:`n$errorMsg" -Title "Fehler" -Type "Error"
        Log-Action "Fehler beim Löschen der Quarantäne-Nachrichten: $errorMsg"
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
        $btnRemoveAntiPhishing = Get-XamlElement -ElementName "btnRemoveAntiPhishing"
        $dgAntiPhishingPolicies = Get-XamlElement -ElementName "dgAntiPhishingPolicies"
        $btnExportAntiPhishing = Get-XamlElement -ElementName "btnExportAntiPhishing"
        $script:dgAntiPhishingPolicies = $dgAntiPhishingPolicies

        # --- Safe Attachments ---
        $btnGetSafeAttachment = Get-XamlElement -ElementName "btnGetSafeAttachment"
        $btnNewSafeAttachment = Get-XamlElement -ElementName "btnNewSafeAttachment"
        $btnSetSafeAttachment = Get-XamlElement -ElementName "btnSetSafeAttachment"
        $btnRemoveSafeAttachment = Get-XamlElement -ElementName "btnRemoveSafeAttachment"
        $dgSafeAttachmentPolicies = Get-XamlElement -ElementName "dgSafeAttachmentPolicies"
        $btnExportSafeAttachment = Get-XamlElement -ElementName "btnExportSafeAttachment"
        $script:dgSafeAttachmentPolicies = $dgSafeAttachmentPolicies

        # --- Safe Links ---
        $btnGetSafeLinks = Get-XamlElement -ElementName "btnGetSafeLinks"
        $btnNewSafeLinks = Get-XamlElement -ElementName "btnNewSafeLinks"
        $btnSetSafeLinks = Get-XamlElement -ElementName "btnSetSafeLinks"
        $btnRemoveSafeLinks = Get-XamlElement -ElementName "btnRemoveSafeLinks"
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
                if (-not (Open-ExternalUrl -Url "https://learn.microsoft.com/de-de/microsoft-365/security/office-365-security/microsoft-defender-for-office-365")) {
                    Update-StatusBar -Message "Die Hilfeseite konnte nicht geöffnet werden." -Type "Warning"
                }
            })
        }

        # Anti-Phishing Handler
        $null = Register-EventHandler -Control $btnGetAntiPhishing -Handler { Get-AntiPhishingPoliciesAction } -ControlName "btnGetAntiPhishing"
        $null = Register-EventHandler -Control $btnNewAntiPhishing -Handler { New-AntiPhishingPolicyAction } -ControlName "btnNewAntiPhishing"
        $null = Register-EventHandler -Control $btnSetAntiPhishing -Handler { Set-AntiPhishingPolicyAction } -ControlName "btnSetAntiPhishing"
        $null = Register-EventHandler -Control $btnRemoveAntiPhishing -Handler { Remove-AntiPhishingPolicyAction } -ControlName "btnRemoveAntiPhishing"
        $null = Register-EventHandler -Control $btnExportAntiPhishing -Handler { Export-AntiPhishingPoliciesAction } -ControlName "btnExportAntiPhishing"

        # Safe Attachments Handler
        $null = Register-EventHandler -Control $btnGetSafeAttachment -Handler { Get-SafeAttachmentPoliciesAction } -ControlName "btnGetSafeAttachment"
        $null = Register-EventHandler -Control $btnNewSafeAttachment -Handler { New-SafeAttachmentPolicyAction } -ControlName "btnNewSafeAttachment"
        $null = Register-EventHandler -Control $btnSetSafeAttachment -Handler { Set-SafeAttachmentPolicyAction } -ControlName "btnSetSafeAttachment"
        $null = Register-EventHandler -Control $btnRemoveSafeAttachment -Handler { Remove-SafeAttachmentPolicyAction } -ControlName "btnRemoveSafeAttachment"
        $null = Register-EventHandler -Control $btnExportSafeAttachment -Handler { Export-SafeAttachmentPoliciesAction } -ControlName "btnExportSafeAttachment"

        # Safe Links Handler
        $null = Register-EventHandler -Control $btnGetSafeLinks -Handler { Get-SafeLinksPoliciesAction } -ControlName "btnGetSafeLinks"
        $null = Register-EventHandler -Control $btnNewSafeLinks -Handler { New-SafeLinksPolicyAction } -ControlName "btnNewSafeLinks"
        $null = Register-EventHandler -Control $btnSetSafeLinks -Handler { Set-SafeLinksPolicyAction } -ControlName "btnSetSafeLinks"
        $null = Register-EventHandler -Control $btnRemoveSafeLinks -Handler { Remove-SafeLinksPolicyAction } -ControlName "btnRemoveSafeLinks"
        $null = Register-EventHandler -Control $btnExportSafeLinks -Handler { Export-SafeLinksPoliciesAction } -ControlName "btnExportSafeLinks"

        # Quarantäne Handler
        $null = Register-EventHandler -Control $btnGetQuarantineMessages -Handler { Get-QuarantineMessagesAction } -ControlName "btnGetQuarantineMessages"
        $null = Register-EventHandler -Control $btnReleaseQuarantine -Handler { Release-QuarantineMessageAction } -ControlName "btnReleaseQuarantine"
        $null = Register-EventHandler -Control $btnDeleteQuarantine -Handler { Delete-QuarantineMessageAction } -ControlName "btnDeleteQuarantine"
        $null = Register-EventHandler -Control $btnExportQuarantine -Handler { Export-QuarantineMessagesAction } -ControlName "btnExportQuarantine"

        Write-Log "ATP Tab erfolgreich initialisiert." -Type "Success"
        return $true
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler bei der Initialisierung des ATP Tabs."
        Write-Log $errorMsg -Type "Error"
        return $false
    }
}
