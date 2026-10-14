# =====================================================================
# easyEXO - Modul: Exchange Online Organisationseinstellungen (Set-OrganizationConfig)
# Datei: src/Modules/Features/OrganizationSettings.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# Definierte UI-Elemente aus der XAML, die wir erwarten
$script:knownUIElements = @(
    # Benutzereinstellungen Tab
    #   Outlook - Kernfunktionen (GroupBox Header="Outlook - Kernfunktionen")
    "chkAppsForOfficeEnabled",
    "chkFocusedInboxOn",
    "chkReadTrackingEnabled",
    "chkSendFromAliasEnabled",
    "chkLinkPreviewEnabled",
    "chkMessageRecallEnabled",
    "chkRecallReadMessagesEnabled",
    #   Kalenderoptionen (GroupBox Header="Kalenderoptionen")
    "cmbShortenEventScopeDefault",
    "txtDefaultMinutesToReduceShortEventsBy",
    "txtDefaultMinutesToReduceLongEventsBy",
    #   Outlook Web App (OWA) - Verhalten (GroupBox Header="Outlook Web App (OWA) - Verhalten")
    "chkAsyncSendEnabled",
    "chkOutlookGifPickerDisabled",
    "chkWebPushNotificationsDisabled",
    "chkWebSuggestedRepliesDisabled",
    #   Weitere Outlook & OWA Features (GroupBox Header="Weitere Outlook & OWA Features")
    "chkMessageRemindersEnabled",
    "chkOutlookPayEnabled",
    "chkOutlookTextPredictionDisabled",
    "chkEnableOutlookEvents", # War vorher unter Admin & Sicherheit -> Grundlegende Sicherheit
    #   Sitzungs-Timeout (OWA) (GroupBox Header="Sitzungs-Timeout (OWA)")
    "chkActivityBasedAuthenticationTimeoutEnabled",
    "txtActivityBasedAuthenticationTimeoutInterval", # War vorher cmbActivityBasedAuthenticationTimeoutInterval, angepasst an knownUIElements
    "chkActivityBasedAuthenticationTimeoutWithSingleSignOnEnabled",
    "chkOwaRedirectToOD4BThisUserEnabled", # War vorher unter Admin & Sicherheit -> OWA & Speicher
    "chkPublicComputersDetectionEnabled", # War vorher unter Admin & Sicherheit -> OWA & Speicher

    # Bookings - Grundeinstellungen Tab (TabItem Header="Bookings - Grundeinstellungen")
    #   Bookings - Allgemein
    "chkBookingsEnabled",
    "chkBookingsAddressEntryRestricted",
    "chkBookingsAuthEnabled",
    "chkBookingsCreationOfCustomQuestionsRestricted",
    "chkBookingsExposureOfStaffDetailsRestricted",
    "chkBookingsMembershipApprovalRequired",
    "chkBookingsNotesEntryRestricted",
    "chkBookingsPaymentsEnabled",
    "chkBookingsPhoneNumberEntryRestricted",
    "chkBookingsSocialSharingRestricted",
    "chkBookingsSmsMicrosoftEnabled",
    #   Bookings - Richtlinien & Kontrolle
    "chkBookingsSchedulingPolicyEnabled",
    "txtBookingsSchedulingPolicy",
    "chkBookingsStaffControlEnabled",
    "chkBookingsAvailabilityAndPricingEnabled",
    "chkBookingsCustomizationEnabled",
    #   Bookings - Daten & Freigabe
    "chkBookingsInternalSharingEnabled",
    "chkBookingsExternalSharingEnabled",
    "chkBookingsOnlinePaymentEnabled",
    "chkBookingsBusinessHoursEnabled",
    "chkBookingsCustomerDataUsageEnabled",
    "chkBookingsDataExportEnabled",
    "chkBookingsSearchEngineIndexDisabled",
    "chkBookingsPersonalDataCollectionAndUseConsentRequired",

    # Admin & Sicherheit Tab (TabItem Header="Admin & Sicherheit")
    #   Grundlegende Sicherheit & Compliance
    "chkAuditDisabled",
    "chkAutoEnableArchiveMailbox",
    "chkAutoExpandingArchive",
    "chkComplianceEnabled",
    "chkCustomerLockboxEnabled",
    "chkElcProcessingDisabled",
    #   MailTips
    "chkMailTipsExternalRecipientsTipsEnabled",
    "chkMailTipsGroupMetricsEnabled",
    "chkMailTipsLargeAudienceThreshold", # Bezieht sich auf die Aktivierung der Funktion, nicht den Wert selbst
    "txtMailTipsLargeAudienceThreshold", # Der Zahlenwert für den Threshold
    "chkMailTipsMailboxSourcedTipsEnabled",
    #   Konnektoren & Integrationen
    "chkConnectorsEnabled",
    "chkConnectorsActionableMessagesEnabled",
    "chkConnectorsEnabledForOutlook",
    "chkConnectorsEnabledForSharepoint",
    "chkConnectorsEnabledForTeams",
    "chkConnectorsEnabledForYammer",
    "chkSmtpActionableMessagesEnabled",
    #   Zugriffskontrolle & Weiterleitung (GroupBox Header="Zugriffskontrolle & Weiterleitung")
    "chkPublicFolderShowClientControl",
    "chkAutodiscoverPartialDirSync",
    "chkWorkspaceTenantEnabled",
    "chkAdditionalStorageProvidersBlocked", # War vorher unter Admin & Sicherheit -> OWA & Speicher
    #   Public Folder Quotas
    "txtDefaultPublicFolderMaxItemSize",
    "txtDefaultPublicFolderIssueWarningQuota",
    "txtDefaultPublicFolderProhibitPostQuota",
    #   Public Folder Settings (additional)
    "txtDefaultPublicFolderAgeLimit", 
    "txtDefaultPublicFolderDeletedItemRetention", 
    "txtDefaultPublicFolderMovedItemRetention", 
    "txtRemotePublicFolderMailboxes", 


    # Erweitert Tab (TabItem Header="Erweitert")
    #   Protokolle & Leistung (GroupBox Header="Protokolle & Leistung")
    "chkSIPEnabled",
    "chkRemotePublicFolderBlobsEnabled",
    "chkMapiHttpEnabled",
    "chkCalendarVersionStoreEnabled", 
    "chkEcRequiresTls", 
    #   Internationalisierung & Suche (GroupBox Header="Internationalisierung & Suche")
    "chkPreferredInternetCodePageForShiftJis", # Bezieht sich auf die Aktivierung der Funktion
    "txtPreferredInternetCodePageForShiftJis", # Der Zahlenwert
    "chkSearchQueryLanguage", # Bezieht sich auf die Aktivierung der Funktion
    "cmbSearchQueryLanguage", # Die Auswahl der Sprache
    #   Diverse Features (GroupBox Header="Diverse Features")
    "chkVisibilityEnabled",
    "chkOnlineMeetingsByDefaultEnabled",
    "chkDirectReportsGroupAutoCreationEnabled",
    "chkUnblockUnsafeSenderPromptEnabled",
    "chkExecutiveAttestation",
    "chkPDPLocationEnabled",
    #   Ratelimiting (GroupBox Header="Ratelimiting")
    "txtPowerShellMaxConcurrency",
    "txtPowerShellMaxCmdletQueueDepth",
    "txtPowerShellMaxCmdletsExecutionDuration",
    "txtHierarchicalAddressBookRoot",

    # Bisher nicht verdrahtete Steuerelemente (in der XAML vorhanden, wurden aber weder geladen noch gespeichert)
    "chkBookingsBlockedWordsEnabled",
    "chkBookingsNamingPolicyEnabled",
    "chkBookingsNamingPolicyPrefixEnabled",
    "txtBookingsNamingPolicyPrefix",
    "chkBookingsNamingPolicySuffixEnabled",
    "txtBookingsNamingPolicySuffix",
    "chkMailTipsAllTipsEnabled",
    "cmbLargeAudienceThreshold",
    "chkMaskClientIpInReceivedHeadersEnabled",
    "chkComplianceMLBgdCrawlEnabled",
    "txtIPListBlocked",
    "cmbPublicFoldersEnabled",
    "chkOAuth2ClientProfileEnabled",
    "txtDefaultAuthPolicy",
    "chkPerTenantSwitchToESTSEnabled",
    "chkRefreshSessionEnabled",
    "txtWACDiscoveryEndpoint",
    "chkEwsEnabled",
    "cmbEwsAppAccessPolicy",
    "chkEwsAllowEntourage",
    "chkEwsAllowMacOutlook",
    "chkEwsAllowOutlook",
    "txtEwsAllowList",
    "txtEwsBlockList",
    "chkMobileAppEducationEnabled",
    "chkOutlookMobileGCCRestrictionsEnabled"
)


# -----------------------------------------------
# EXOSettings Main Functions
# -----------------------------------------------
#region EXOSettings Organization Config Management
function Get-CurrentOrganizationConfig {
    [CmdletBinding()]
    param()
    try {
        if (-not (Confirm-ExchangeConnection)) {
            Show-MessageBox -Message "Bitte verbinden Sie sich zuerst mit Exchange Online." -Title "Nicht verbunden" -Type "Warning"
            if ($null -ne $script:txtStatus) { $script:txtStatus.Text = "Nicht verbunden." }
            return
        }
        Write-Log "Rufe aktuelle Organisationseinstellungen ab..." -Type "Info"
        if ($null -ne $script:txtStatus) { $script:txtStatus.Text = "Lade Organisationseinstellungen..." }
        
        $script:currentOrganizationConfig = Get-OrganizationConfig -ErrorAction Stop
        if ($null -eq $script:currentOrganizationConfig) { throw "Get-OrganizationConfig lieferte keine Daten." }
        Write-Log "Organisationseinstellungen erfolgreich abgerufen." -Type "Info"
        $configProperties = $script:currentOrganizationConfig.PSObject.Properties | ForEach-Object { $_.Name }
        Write-Log "Aktualisiere UI-Elemente und Aktivierungsstatus..." -Type "Debug"

        foreach ($elementName in $script:knownUIElements) {
            $element = $null
            if ($null -ne $script:tabEXOSettings) { $element = $script:tabEXOSettings.FindName($elementName) }
            if ($null -eq $element) { $element = Get-XamlElement -ElementName $elementName }

            if ($null -ne $element) {
                $elementType = "Unknown"
                if ($element -is [System.Windows.Controls.CheckBox]) { $elementType = "CheckBox" }
                elseif ($element -is [System.Windows.Controls.ComboBox]) { $elementType = "ComboBox" }
                elseif ($element -is [System.Windows.Controls.TextBox]) { $elementType = "TextBox" }

                if ($elementType -eq "Unknown") { Write-Log "Element '$elementName' unbekannter Typ." -Type "Debug"; continue }

                # Eigenschaftsname aus dem Elementnamen ableiten (Sonderfälle: $script:OrgConfigPropertyMap / $script:OrgConfigToggleControls)
                $propertyName = Get-OrgConfigPropertyName -ElementName $elementName

                if (-not $propertyName) { Write-Log "Kein OrgConfig PropertyName für UI '$elementName' ($elementType). Überspringe." -Type "Warning"; $element.IsEnabled = $true; continue }

                if ($configProperties -contains $propertyName) {
                    $element.IsEnabled = $true
                    $valueFromConfig = $script:currentOrganizationConfig.$propertyName
                    Write-Log "Eig. '$propertyName' für UI '$elementName' in OrgConfig gefunden. Wert: '$valueFromConfig'" -Type "Debug"
                    try {
                        switch ($elementType) {
                            "CheckBox" {
                                $boolValue = $false
                                if ($null -ne $valueFromConfig) {
                                    if ($valueFromConfig -is [bool]) { $boolValue = $valueFromConfig }
                                    elseif ($valueFromConfig -is [string] -and ($valueFromConfig.ToLower() -eq 'true' -or $valueFromConfig.ToLower() -eq 'false')) { $boolValue = [bool]::Parse($valueFromConfig) }
                                    else {
                                        if ($elementName -eq "chkMailTipsLargeAudienceThreshold" -or $elementName -eq "chkPreferredInternetCodePageForShiftJis") { try { if ([int]$valueFromConfig -ne 0) { $boolValue = $true } else { $boolValue = $false } } catch { $boolValue = $false } }
                                        elseif ($elementName -eq "chkSearchQueryLanguage") { if (-not [string]::IsNullOrEmpty($valueFromConfig.ToString())) { $boolValue = $true } else { $boolValue = $false } }
                                        else { try { $boolValue = [System.Convert]::ToBoolean($valueFromConfig) } catch { Write-Log "Warn: Konnte '$valueFromConfig' für CheckBox '$elementName' nicht in Boolean konvertieren. $false." -Type "Warning" } }
                                    }
                                }
                                $element.IsChecked = $boolValue
                                Write-Log "CheckBox '$elementName' (Prop: $propertyName) gesetzt auf '$boolValue'." -Type "Info"
                            }
                            "ComboBox" {
                                $currentConfigValue = $script:currentOrganizationConfig.$propertyName
                                $configValueAsString = if ($null -ne $currentConfigValue) { $currentConfigValue.ToString() } else { $null }
                                $itemFound = $false; $uiSelectedItem = $null
                                if ($null -ne $configValueAsString) {
                                    foreach ($itemObject in $element.Items) {
                                        $itemContentString = if ($itemObject -is [System.Windows.Controls.ComboBoxItem]) { $itemObject.Content.ToString() } else { $itemObject.ToString() }
                                        $itemTagString = if ($itemObject -is [System.Windows.Controls.ComboBoxItem] -and $null -ne $itemObject.Tag) { $itemObject.Tag.ToString() } else { $null }
                                        
                                        # Prüfe sowohl Content als auch Tag auf Übereinstimmung
                                        if ($itemContentString.Equals($configValueAsString, [System.StringComparison]::OrdinalIgnoreCase) -or 
                                            ($null -ne $itemTagString -and $itemTagString.Equals($configValueAsString, [System.StringComparison]::OrdinalIgnoreCase))) { 
                                            $uiSelectedItem = $itemObject; $itemFound = $true; break 
                                        }
                                    }
                                }
                                if ($itemFound) {
                                    $element.SelectedItem = $uiSelectedItem
                                } else {
                                    $keineDatenItem = $null; foreach ($item in $element.Items) { if (($item -is [System.Windows.Controls.ComboBoxItem] -and $item.Content.ToString() -eq "KEINE DATEN") -or ($item.ToString() -eq "KEINE DATEN")) { $keineDatenItem = $item; break } }
                                    if ($null -ne $keineDatenItem) { $element.SelectedItem = $keineDatenItem; Write-Log "ComboBox '$elementName': Wert '$configValueAsString' nicht gefunden/null. 'KEINE DATEN' ausgewählt." -Type "Info" }
                                    else { if ($element.Items.Count -gt 0) { $element.SelectedIndex = 0 } else { $element.SelectedItem = $null }; Write-Log "ComboBox '$elementName': Wert '$configValueAsString' nicht gefunden/null & 'KEINE DATEN' Item nicht da. Fallback." -Type "Debug" }
                                }
                                Write-Log "ComboBox '$elementName' (Prop: $propertyName) UI auf '$($element.Text)' (OrgConfig: '$configValueAsString')." -Type "Info"
                            }
                            "TextBox" {
                                if ($null -ne $valueFromConfig) {
                                    if ($valueFromConfig -is [array]) { $element.Text = $valueFromConfig -join ", " }
                                    else { $element.Text = $valueFromConfig.ToString() }
                                } else {
                                    $element.Text = "KEINE DATEN"
                                }
                                Write-Log "TextBox '$elementName' (Prop: $propertyName) gesetzt auf '$($element.Text)'." -Type "Info"
                            }
                        }
                    } catch { Write-Log "Fehler Setzen UI '$elementName' (Prop: $propertyName): $($_.Exception.Message)" -Type "Error" }
                } else {
                    $element.IsEnabled = $false
                    Write-Log "Eig. '$propertyName' für UI '$elementName' NICHT in OrgConfig. Deaktiviert." -Type "Info"
                    switch ($elementType) {
                        "CheckBox" { $element.IsChecked = $false }
                        "ComboBox" { 
                            $keineDatenItem = $null; foreach ($item in $element.Items) { if (($item -is [System.Windows.Controls.ComboBoxItem] -and $item.Content.ToString() -eq "KEINE DATEN") -or ($item.ToString() -eq "KEINE DATEN")) { $keineDatenItem = $item; break } }
                            if ($null -ne $keineDatenItem) { $element.SelectedItem = $keineDatenItem } else { if ($element.Items.Count -gt 0) { $element.SelectedIndex = 0 } else { $element.SelectedItem = $null } }
                        }
                        "TextBox"  { $element.Text = "KEINE DATEN" }
                    }
                }
            } else { Write-Log "Element '$elementName' nicht in XAML (UI Update)." -Type "Debug" }
        }
        # Zustand direkt nach dem Laden merken: Beim Speichern werden nur Abweichungen davon übertragen
        $script:orgConfigUiSnapshot = Get-OrgConfigUiState
        if ($null -ne $script:txtStatus) { $script:txtStatus.Text = "Organisationseinstellungen erfolgreich geladen." }
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Schwerer Fehler Get-CurrentOrganizationConfig: $errorMsg" -Type "Error"; Write-Log $_.Exception.StackTrace -Type "Error"
        if ($null -ne $script:txtStatus) { $script:txtStatus.Text = "Fehler Laden Organisationseinstellungen: $errorMsg" }
        Show-MessageBox -Message "Fehler Laden Organisationseinstellungen: $errorMsg" -Title "Fehler" -Type "Error"
    }
}

# -----------------------------------------------
# Zuordnung UI-Element -> Eigenschaft von Get-/Set-OrganizationConfig
# -----------------------------------------------
# Elemente, deren Eigenschaftsname nicht direkt aus dem Namen (ohne chk/cmb/txt) folgt
$script:OrgConfigPropertyMap = @{
    "cmbLargeAudienceThreshold" = "MailTipsLargeAudienceThreshold"
    "cmbEwsAppAccessPolicy"     = "EwsApplicationAccessPolicy"
    "txtDefaultAuthPolicy"      = "DefaultAuthenticationPolicy"
}

# Steuer-Checkboxen ohne eigenen booleschen Wert: Sie schalten nur das zugehörige Wertfeld frei
$script:OrgConfigToggleControls = @{
    "chkMailTipsLargeAudienceThreshold"       = "txtMailTipsLargeAudienceThreshold"
    "chkPreferredInternetCodePageForShiftJis" = "txtPreferredInternetCodePageForShiftJis"
    "chkSearchQueryLanguage"                  = "cmbSearchQueryLanguage"
}

# Eigenschaften, die als ganze Zahl übergeben werden müssen
$script:OrgConfigNumericProperties = @(
    "DefaultMinutesToReduceShortEventsBy",
    "DefaultMinutesToReduceLongEventsBy",
    "MailTipsLargeAudienceThreshold",
    "PreferredInternetCodePageForShiftJis"
)

# Mehrwertige Eigenschaften (Eingabe kommagetrennt)
$script:OrgConfigMultiValueProperties = @(
    "EwsAllowList",
    "EwsBlockList",
    "IPListBlocked",
    "RemotePublicFolderMailboxes"
)

function Get-OrgConfigPropertyName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ElementName
    )

    if ($script:OrgConfigPropertyMap.ContainsKey($ElementName)) { return $script:OrgConfigPropertyMap[$ElementName] }
    if ($script:OrgConfigToggleControls.ContainsKey($ElementName)) {
        return (Get-OrgConfigPropertyName -ElementName $script:OrgConfigToggleControls[$ElementName])
    }
    if ($ElementName -match '^(chk|cmb|txt)(.+)$') { return $Matches[2] }
    return $null
}

function Test-OrgConfigChecked {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ElementName
    )

    $control = Get-XamlElement -ElementName $ElementName
    return ($null -ne $control -and $control.IsChecked -eq $true)
}

# Liest den effektiven Zustand aller Organisationseinstellungs-Felder aus der Oberfläche.
# Ergebnis: Hashtable Eigenschaftsname -> @{ Value = <Text>; Kind = CheckBox|ComboBox|TextBox; Element = <Name> }
# Deaktivierte Felder, Steuer-Checkboxen und nicht freigeschaltete Wertfelder werden ausgelassen.
function Get-OrgConfigUiState {
    [CmdletBinding()]
    param()

    $state = @{}
    if ($null -eq $script:currentOrganizationConfig) { return $state }
    $configProperties = @($script:currentOrganizationConfig.PSObject.Properties.Name)

    $valueToToggle = @{}
    foreach ($toggleName in $script:OrgConfigToggleControls.Keys) { $valueToToggle[$script:OrgConfigToggleControls[$toggleName]] = $toggleName }

    foreach ($elementName in $script:knownUIElements) {
        if ($script:OrgConfigToggleControls.ContainsKey($elementName)) { continue }

        $element = Get-XamlElement -ElementName $elementName
        if ($null -eq $element -or -not $element.IsEnabled) { continue }

        $propertyName = Get-OrgConfigPropertyName -ElementName $elementName
        if ([string]::IsNullOrEmpty($propertyName) -or $configProperties -notcontains $propertyName) { continue }

        # Abhängige Wertfelder nur berücksichtigen, wenn sie freigeschaltet sind
        if ($valueToToggle.ContainsKey($elementName) -and -not (Test-OrgConfigChecked -ElementName $valueToToggle[$elementName])) { continue }
        if ($elementName -eq "cmbLargeAudienceThreshold" -and (Test-OrgConfigChecked -ElementName "chkMailTipsLargeAudienceThreshold")) { continue }
        if ($elementName -eq "txtActivityBasedAuthenticationTimeoutInterval" -and -not (Test-OrgConfigChecked -ElementName "chkActivityBasedAuthenticationTimeoutEnabled")) { continue }

        $kind = $null
        $value = $null
        if ($element -is [System.Windows.Controls.CheckBox]) {
            $kind = "CheckBox"
            $value = [string]($element.IsChecked -eq $true)
        }
        elseif ($element -is [System.Windows.Controls.ComboBox]) {
            $kind = "ComboBox"
            $item = $element.SelectedItem
            if ($item -is [System.Windows.Controls.ComboBoxItem]) {
                $value = if ($null -ne $item.Tag -and "$($item.Tag)" -ne "") { "$($item.Tag)" } else { "$($item.Content)" }
            }
            elseif ($null -ne $item) { $value = "$item" }
            else { $value = "$($element.Text)" }
        }
        elseif ($element -is [System.Windows.Controls.TextBox]) {
            $kind = "TextBox"
            $value = "$($element.Text)"
        }
        else { continue }

        $value = $value.Trim()
        if ($value -eq "KEINE DATEN") { $value = "" }
        $state[$propertyName] = [PSCustomObject]@{ Value = $value; Kind = $kind; Element = $elementName }
    }
    return $state
}

# Wandelt einen UI-Wert in den passenden Parametertyp für Set-OrganizationConfig um.
function ConvertTo-OrgConfigParameterValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PropertyName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [string]$Kind
    )

    if ($Kind -eq "CheckBox") { return [bool]::Parse($Value) }
    if ([string]::IsNullOrWhiteSpace($Value)) {
        if ($script:OrgConfigNumericProperties -contains $PropertyName) {
            throw "Der Wert für '$PropertyName' darf nicht leer sein (ganze Zahl erwartet)."
        }
        return $null
    }

    $current = $script:currentOrganizationConfig.$PropertyName
    $isNumeric = $script:OrgConfigNumericProperties -contains $PropertyName
    if (-not $isNumeric -and $null -ne $current -and $current -isnot [enum] -and $current -isnot [bool]) {
        $typeCode = [System.Type]::GetTypeCode($current.GetType())
        $isNumeric = ($typeCode -ge [System.TypeCode]::Int16 -and $typeCode -le [System.TypeCode]::Decimal)
    }
    if ($isNumeric) {
        $number = 0L
        if (-not [long]::TryParse($Value, [ref]$number)) {
            throw "Der Wert für '$PropertyName' ('$Value') muss eine ganze Zahl sein."
        }
        return $number
    }

    $isMultiValue = $script:OrgConfigMultiValueProperties -contains $PropertyName -or
        ($null -ne $current -and $current -is [System.Collections.IEnumerable] -and $current -isnot [string])
    if ($isMultiValue) {
        return [string[]]@($Value -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
    }

    if ($PropertyName -eq "ActivityBasedAuthenticationTimeoutInterval") {
        $timeoutValue = ($Value -split ' ')[0]
        if ($timeoutValue -notmatch '^(\d+\.)?\d{1,2}:\d{2}:\d{2}$') {
            throw "Ungültiges Format für das Sitzungs-Timeout ('$Value'). Erwartet wird HH:MM:SS, z. B. 06:00:00."
        }
        return $timeoutValue
    }

    return $Value
}

function Set-CustomOrganizationConfig {
    [CmdletBinding()]
    param()

    try {
        # Prüfen, ob wir mit Exchange verbunden sind
        if (-not (Confirm-ExchangeConnection)) {
            Show-MessageBox -Message "Bitte verbinden Sie sich zuerst mit Exchange Online." -Title "Nicht verbunden" -Type "Warning"
            return
        }

        if ($null -eq $script:currentOrganizationConfig -or $null -eq $script:orgConfigUiSnapshot) {
            Show-MessageBox -Message "Bitte laden Sie zuerst die aktuellen Organisationseinstellungen." -Title "Einstellungen nicht geladen" -Type "Info"
            return
        }

        if ((Test-OrgConfigChecked -ElementName "chkActivityBasedAuthenticationTimeoutEnabled")) {
            $txtActivityTimeout = Get-XamlElement -ElementName "txtActivityBasedAuthenticationTimeoutInterval"
            if ($null -ne $txtActivityTimeout -and $txtActivityTimeout.IsEnabled -and ([string]::IsNullOrWhiteSpace($txtActivityTimeout.Text) -or $txtActivityTimeout.Text.Trim() -eq "KEINE DATEN")) {
                Show-MessageBox -Message "Wenn 'Inaktive Sitzungs-Timeout aktivieren' ausgewählt ist, muss ein Timeout-Intervall angegeben werden." -Title "Fehlende Eingabe" -Type "Error"
                return
            }
        }

        # Nur Parameter senden, die Set-OrganizationConfig tatsächlich kennt
        $validParameters = @()
        try { $validParameters = @((Get-Command -Name Set-OrganizationConfig -ErrorAction Stop).Parameters.Keys) }
        catch { Write-Log "Parameterliste von Set-OrganizationConfig nicht ermittelbar: $($_.Exception.Message)" -Type "Warning" }

        # Nur geänderte Werte ermitteln (Vergleich mit dem Zustand direkt nach dem Laden)
        $currentState = Get-OrgConfigUiState
        $paramsToSet = @{}
        $changeLines = New-Object 'System.Collections.Generic.List[string]'
        $skipped = New-Object 'System.Collections.Generic.List[string]'

        foreach ($propertyName in ($currentState.Keys | Sort-Object)) {
            $entry = $currentState[$propertyName]
            $originalValue = $null
            if ($script:orgConfigUiSnapshot.ContainsKey($propertyName)) { $originalValue = $script:orgConfigUiSnapshot[$propertyName].Value }
            if ($null -ne $originalValue -and $originalValue -ceq $entry.Value) { continue }

            if ($validParameters.Count -gt 0 -and $validParameters -notcontains $propertyName) {
                $skipped.Add($propertyName)
                continue
            }

            $paramsToSet[$propertyName] = ConvertTo-OrgConfigParameterValue -PropertyName $propertyName -Value $entry.Value -Kind $entry.Kind
            $oldText = if ([string]::IsNullOrEmpty($originalValue)) { "(leer)" } else { $originalValue }
            $newText = if ([string]::IsNullOrEmpty($entry.Value)) { "(leer)" } else { $entry.Value }
            $changeLines.Add("- ${propertyName}: $oldText -> $newText")
        }

        if ($skipped.Count -gt 0) {
            Write-Log "Folgende geänderte Felder werden von Set-OrganizationConfig nicht unterstützt und übersprungen: $($skipped -join ', ')" -Type "Warning"
        }

        if ($paramsToSet.Count -eq 0) {
            $message = "Es wurden keine Änderungen zum Speichern gefunden."
            if ($skipped.Count -gt 0) { $message += "`n`nNicht unterstützte Felder (übersprungen): $($skipped -join ', ')" }
            Show-MessageBox -Message $message -Title "Keine Änderungen" -Type "Info"
            Update-StatusBar -Message "Keine Änderungen zum Speichern." -Type Info
            return
        }

        $preview = @($changeLines | Select-Object -First 25)
        if ($changeLines.Count -gt 25) { $preview += "... und $($changeLines.Count - 25) weitere" }
        $confirmText = "Folgende Organisationseinstellungen werden geändert:`n`n$($preview -join "`n")`n`nJetzt speichern?"
        $confirmResult = Show-MessageBox -Message $confirmText -Title "Einstellungen speichern" -Type "Question"
        if ($confirmResult -ne "Yes") {
            Update-StatusBar -Message "Speichern abgebrochen." -Type Info
            return
        }

        foreach ($key in $paramsToSet.Keys | Sort-Object) {
            Write-Log "Set-OrganizationConfig Parameter: $key = '$($paramsToSet[$key])'" -Type "Debug"
        }

        Update-StatusBar -Message "Speichere Organisationseinstellungen..." -Type Info
        Start-UIBusy -Message "Speichere $($paramsToSet.Count) Organisationseinstellung(en)..." -Title "Organisationseinstellungen"
        try {
            Set-OrganizationConfig @paramsToSet -ErrorAction Stop
        }
        finally {
            Stop-UIBusy
        }

        Write-Log "Organisationseinstellungen gespeichert: $($paramsToSet.Keys -join ', ')" -Type "Success"
        Log-Action "Organisationseinstellungen geändert: $($paramsToSet.Keys -join ', ')"
        Update-StatusBar -Message "Organisationseinstellungen erfolgreich gespeichert ($($paramsToSet.Count) Änderung(en))." -Type Success
        Show-MessageBox -Message "Die Organisationseinstellungen wurden erfolgreich gespeichert." -Title "Erfolg" -Type "Info"

        # Aktuelle Konfiguration neu laden, um Änderungen zu sehen
        Get-CurrentOrganizationConfig
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Speichern der Organisationseinstellungen: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Fehler beim Speichern der Organisationseinstellungen: $errorMsg" -Type Error
        Show-MessageBox -Message "Fehler beim Speichern der Organisationseinstellungen: $errorMsg" -Title "Fehler" -Type "Error"
    }
}

function Export-OrganizationConfig {
    [CmdletBinding()]
    param()
    
    try {
        # Prüfen, ob wir mit Exchange verbunden sind
        if (-not (Confirm-ExchangeConnection)) {
            Show-MessageBox -Message "Bitte verbinden Sie sich zuerst mit Exchange Online." -Title "Nicht verbunden" -Type "Warning"
            return
        }
        
        # Prüfen, ob aktuelle Konfiguration verfügbar ist
        if ($null -eq $script:currentOrganizationConfig) {
            # Versuche zuerst die Konfiguration zu laden
            Get-CurrentOrganizationConfig
            
            if ($null -eq $script:currentOrganizationConfig) {
                Show-MessageBox -Message "Die Organisationseinstellungen konnten nicht geladen werden." -Title "Fehler" -Type "Error"
                return
            }
        }
        
        # SaveFileDialog anzeigen, nur für HTML-Export
        $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveFileDialog.Filter = "HTML-Dateien (*.html)|*.html"
        $saveFileDialog.FileName = "ExchangeOnline_OrgConfig_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        $saveFileDialog.DefaultExt = ".html"
        $saveFileDialog.AddExtension = $true
        
        $result = $saveFileDialog.ShowDialog()
        if ($result -ne $true) {
            return # Benutzer hat Abbrechen gewählt
        }
        
        $exportPath = $saveFileDialog.FileName
        
        # Objekt für den Export vorbereiten, unerwünschte Eigenschaften entfernen
        $objectToExport = $script:currentOrganizationConfig | 
            Select-Object * -ExcludeProperty RunspaceId, PSComputerName, PSShowComputerName, PSSourceJobInstanceId, PSObject, PSCmdlet, PSPath, PSParentPath, PSChildName, PSDrive, PSProvider, PSTypeNames
        
        # HTML-Header für besseres Styling
        $htmlHeader = @"
<meta http-equiv='Content-Type' content='text/html; charset=utf-8'>
<style>
    body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background-color: #f4f4f4; color: #333; }
    h1 { color: #005a9e; border-bottom: 2px solid #005a9e; padding-bottom: 10px; }
    table { 
        border-collapse: collapse; 
        width: 90%; 
        margin-top: 20px; 
        box-shadow: 0 2px 15px rgba(0,0,0,0.1); 
        background-color: #fff;
    }
    th, td { 
        text-align: left; 
        padding: 12px 15px; 
        border: 1px solid #ddd; 
    }
    th { 
        background-color: #0078d4; 
        color: white; 
        font-weight: bold; 
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }
    td:first-child { 
        font-weight: bold; 
        background-color: #f8f8f8; 
        width: 35%; /* Breite der Eigenschaftsspalte */
    }
    tr:nth-child(even) td:not(:first-child) { 
        background-color: #eef6fc; 
    }
    tr:hover td:not(:first-child) { 
        background-color: #dcf0ff; 
    }
</style>
"@
        $reportDate = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
        $title = "Exchange Online Organisationseinstellungen - Exportiert am $reportDate"

        # Als HTML exportieren (Listenansicht ist für ein einzelnes Konfigurationsobjekt besser geeignet)
        $objectToExport | ConvertTo-Html -As List -Property * -Head $htmlHeader -Title $title -Body "<h1>$title</h1>" | Out-File -FilePath $exportPath -Encoding utf8
        
        if ($null -ne $script:txtStatus) {
            $script:txtStatus.Text = "Organisationseinstellungen exportiert nach $exportPath"
        }
        Show-MessageBox -Message "Die Organisationseinstellungen wurden erfolgreich nach '$exportPath' exportiert." -Title "Export erfolgreich" -Type "Info"
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Exportieren der Organisationseinstellungen: $errorMsg" -Type "Error"
        Write-Log $_.Exception.StackTrace -Type "Error"
        if ($null -ne $script:txtStatus) {
            $script:txtStatus.Text = "Fehler beim Exportieren der Organisationseinstellungen: $errorMsg"
        }
        Show-MessageBox -Message "Fehler beim Exportieren der Organisationseinstellungen: $errorMsg" -Title "Fehler" -Type "Error"
    }
}

#endregion EXOSettings Organization Config Management

#region EXOSettings Tab Initialization
function Initialize-EXOSettingsTab {
    [CmdletBinding()]
    param()

    Write-Log "Beginne Initialisierung: EXO Settings Tab" -Type "Info"
    [bool]$success = $true

    try {
        # Speichere Referenz auf den Tab selbst für spätere Verwendung
        $script:tabEXOSettings = Get-XamlElement -ElementName "tabEXOSettings"
        if ($null -eq $script:tabEXOSettings) {
            Write-Log "EXOSettingsTab: Tab-Element nicht gefunden!" -Type "Warning"
        }

        # Textfeld für Status finden
        if ($null -eq $script:txtStatus) {
            $script:txtStatus = Get-XamlElement -ElementName "txtStatus"
        }

        # Event-Handler für Help-Link
        $helpLinkEXOSettings = Get-XamlElement -ElementName "helpLinkEXOSettings"
        if ($null -ne $helpLinkEXOSettings) {
            $helpLinkEXOSettings.Add_MouseLeftButtonDown({
                if (-not (Open-ExternalUrl -Url "https://learn.microsoft.com/de-de/powershell/module/exchange/set-organizationconfig?view=exchange-ps")) {
                    Update-StatusBar -Message "Die Hilfeseite konnte nicht geöffnet werden." -Type "Warning"
                }
            })
            Write-Log "EXOSettingsTab: HelpLink Handler registriert." -Type "Debug"
        } else { Write-Log "EXOSettingsTab: helpLinkEXOSettings nicht gefunden." -Type "Warning"; $success = $false }

        # Buttons "Aktuelle Einstellungen laden", "Speichern" und "Exportieren".
        # Speichern/Exportieren prüfen selbst, ob die Einstellungen bereits geladen wurden.
        $buttonHandlers = [ordered]@{
            "btnGetOrganizationConfig"    = { Get-CurrentOrganizationConfig }
            "btnSetOrganizationConfig"    = { Set-CustomOrganizationConfig }
            "btnExportOrganizationConfig" = { Export-OrganizationConfig }
        }
        foreach ($buttonName in $buttonHandlers.Keys) {
            $button = Get-XamlElement -ElementName $buttonName
            if ($null -eq $button -or -not (Register-EventHandler -Control $button -Handler $buttonHandlers[$buttonName] -ControlName $buttonName)) {
                Write-Log "EXOSettingsTab: $buttonName nicht gefunden oder Handler nicht registriert." -Type "Warning"
                $success = $false
            }
        }

        foreach ($elementName in $script:knownUIElements) {
            $element = Get-XamlElement -ElementName $elementName
            if ($null -ne $element) {
                $element.Visibility = [System.Windows.Visibility]::Visible
            } else {
                Write-Log "EXOSettingsTab: Element '$elementName' aus knownUIElements nicht gefunden in XAML." -Type "Warning"
            }
        }
        Write-Log "EXOSettingsTab: Sichtbarkeit für Elemente in knownUIElements überprüft." -Type "Debug"

        # Stelle sicher, dass der Tab selbst sichtbar ist
        if ($null -ne $script:tabEXOSettings) {
            $script:tabEXOSettings.Visibility = [System.Windows.Visibility]::Visible
            Write-Log "EXOSettingsTab: Tab auf sichtbar gesetzt." -Type "Debug"
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Initialisieren des EXO Settings Tab: $errorMsg" -Type "Error"
        Write-Log $_.Exception.StackTrace -Type "Error"
        $success = $false
    }

    $messageType = if ($success) { "Success" } else { "Error" }
    Write-Log "Abschluss Initialisierung: EXO Settings Tab (Erfolg: $success)" -Type $messageType
    return $success
}
#endregion EXOSettings Tab Initialization
