# =====================================================================
# easyEXO - Modul: Transportregeln (Mail-Flow-Regeln)
# Datei: src/Modules/Features/MailFlowRules.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# -------------------------------------------------
# Abschnitt: MailFlow-Funktionen
# -------------------------------------------------

function New-MailFlowRuleAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RuleName,
        
        [Parameter(Mandatory = $true)]
        [string]$ConditionType,
        
        [Parameter(Mandatory = $false)]
        [string]$ConditionValue,
        
        [Parameter(Mandatory = $true)]
        [string]$ActionType,
        
        [Parameter(Mandatory = $false)]
        [string]$ActionValue,
        
        [Parameter(Mandatory = $false)]
        [string]$Mode = "Test"
    )
    
    try {
        Write-Log "Erstelle neue Transport Rule: $RuleName" -Type "Info"
        
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange Online verbunden."
        }
        
        # Parameter für die Regel aufbauen
        $ruleParams = @{
            Name = $RuleName
            Mode = $Mode
            ErrorAction = "Stop"
        }
        
        # Bedingungen setzen
        switch ($ConditionType) {
            "FromAddressContainsWords" {
                if (-not [string]::IsNullOrWhiteSpace($ConditionValue)) {
                    $ruleParams.Add("FromAddressContainsWords", $ConditionValue.Split(',').Trim())
                }
            }
            "SubjectContainsWords" {
                if (-not [string]::IsNullOrWhiteSpace($ConditionValue)) {
                    $ruleParams.Add("SubjectContainsWords", $ConditionValue.Split(',').Trim())
                }
            }
            "RecipientDomainIs" {
                if (-not [string]::IsNullOrWhiteSpace($ConditionValue)) {
                    $ruleParams.Add("RecipientDomainIs", $ConditionValue.Split(',').Trim())
                }
            }
            "SenderDomainIs" {
                if (-not [string]::IsNullOrWhiteSpace($ConditionValue)) {
                    $ruleParams.Add("SenderDomainIs", $ConditionValue.Split(',').Trim())
                }
            }
            "AttachmentNameMatchesPatterns" {
                if (-not [string]::IsNullOrWhiteSpace($ConditionValue)) {
                    $ruleParams.Add("AttachmentNameMatchesPatterns", $ConditionValue.Split(',').Trim())
                }
            }
            "MessageSizeOver" {
                if (-not [string]::IsNullOrWhiteSpace($ConditionValue)) {
                    $ruleParams.Add("MessageSizeOver", "$ConditionValue KB")
                }
            }
        }
        
        # Aktionen setzen
        switch ($ActionType) {
            "RedirectMessageTo" {
                if (-not [string]::IsNullOrWhiteSpace($ActionValue)) {
                    $ruleParams.Add("RedirectMessageTo", $ActionValue.Split(',').Trim())
                }
            }
            "BlindCopyTo" {
                if (-not [string]::IsNullOrWhiteSpace($ActionValue)) {
                    $ruleParams.Add("BlindCopyTo", $ActionValue.Split(',').Trim())
                }
            }
            "RejectMessageReasonText" {
                if (-not [string]::IsNullOrWhiteSpace($ActionValue)) {
                    $ruleParams.Add("RejectMessageReasonText", $ActionValue)
                }
            }
            "DeleteMessage" {
                $ruleParams.Add("DeleteMessage", $true)
            }
            "ModerateMessageByUser" {
                if (-not [string]::IsNullOrWhiteSpace($ActionValue)) {
                    $ruleParams.Add("ModerateMessageByUser", $ActionValue.Split(',').Trim())
                }
            }
            "SetHeaderName" {
                if (-not [string]::IsNullOrWhiteSpace($ActionValue)) {
                    $headerParts = $ActionValue.Split(':', 2)
                    if ($headerParts.Count -eq 2) {
                        $ruleParams.Add("SetHeaderName", $headerParts[0].Trim())
                        $ruleParams.Add("SetHeaderValue", $headerParts[1].Trim())
                    }
                }
            }
            "ApplyClassification" {
                if (-not [string]::IsNullOrWhiteSpace($ActionValue)) {
                    $ruleParams.Add("ApplyClassification", $ActionValue)
                }
            }
            "SetSCL" {
                if (-not [string]::IsNullOrWhiteSpace($ActionValue)) {
                    $ruleParams.Add("SetSCL", [int]$ActionValue)
                }
            }
            "Quarantine" {
                $ruleParams.Add("Quarantine", $true)
            }
        }
        
        # Transport Rule erstellen
        $newRule = New-TransportRule @ruleParams
        
        Write-Log "Transport Rule '$RuleName' erfolgreich erstellt" -Type "Success"
        Log-Action "Transport Rule erstellt: $RuleName (Modus: $Mode)"
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Erstellen der Transport Rule: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Erstellen der Transport Rule $RuleName`: $errorMsg"
        return $false
    }
}

function Test-MailFlowRuleAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RuleName,
        
        [Parameter(Mandatory = $true)]
        [string]$ConditionType,
        
        [Parameter(Mandatory = $false)]
        [string]$ConditionValue
    )
    
    try {
        Write-Log "Teste Transport Rule Konfiguration: $RuleName" -Type "Info"
        
        $testResults = @()
        $testResults += "=== Transport Rule Test Ergebnisse ==="
        $testResults += "Regel Name: $RuleName"
        $testResults += "Bedingung: $ConditionType"
        $testResults += "Wert: $ConditionValue"
        $testResults += ""
        
        # Validierung der Bedingungen
        switch ($ConditionType) {
            "FromAddressContainsWords" {
                if ([string]::IsNullOrWhiteSpace($ConditionValue)) {
                    $testResults += "❌ FEHLER: Keine Wörter für FromAddressContainsWords angegeben"
                } else {
                    $words = $ConditionValue.Split(',').Trim()
                    $testResults += "✅ OK: $($words.Count) Wort(e) für Absender-Filter konfiguriert"
                    foreach ($word in $words) {
                        $testResults += "   - '$word'"
                    }
                }
            }
            "SubjectContainsWords" {
                if ([string]::IsNullOrWhiteSpace($ConditionValue)) {
                    $testResults += "❌ FEHLER: Keine Wörter für SubjectContainsWords angegeben"
                } else {
                    $words = $ConditionValue.Split(',').Trim()
                    $testResults += "✅ OK: $($words.Count) Wort(e) für Betreff-Filter konfiguriert"
                    foreach ($word in $words) {
                        $testResults += "   - '$word'"
                    }
                }
            }
            "RecipientDomainIs" {
                if ([string]::IsNullOrWhiteSpace($ConditionValue)) {
                    $testResults += "❌ FEHLER: Keine Domain für RecipientDomainIs angegeben"
                } else {
                    $domains = $ConditionValue.Split(',').Trim()
                    $testResults += "✅ OK: $($domains.Count) Domain(s) für Empfänger-Filter konfiguriert"
                    foreach ($domain in $domains) {
                        if ($domain -match '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
                            $testResults += "   - ✅ '$domain' (gültiges Format)"
                        } else {
                            $testResults += "   - ❌ '$domain' (ungültiges Domain-Format)"
                        }
                    }
                }
            }
            "MessageSizeOver" {
                if ([string]::IsNullOrWhiteSpace($ConditionValue)) {
                    $testResults += "❌ FEHLER: Keine Größe für MessageSizeOver angegeben"
                } else {
                    if ($ConditionValue -match '^\d+$') {
                        $sizeKB = [int]$ConditionValue
                        $testResults += "✅ OK: Nachrichten über $sizeKB KB werden gefiltert"
                        $testResults += "   (Das entspricht ca. $([math]::Round($sizeKB/1024, 2)) MB)"
                    } else {
                        $testResults += "❌ FEHLER: '$ConditionValue' ist keine gültige Größenangabe (nur Zahlen erlaubt)"
                    }
                }
            }
            default {
                $testResults += "⚠️ WARNUNG: Unbekannter Bedingungstyp '$ConditionType'"
            }
        }
        
        $testResults += ""
        $testResults += "=== Empfehlungen ==="
        $testResults += "• Testen Sie die Regel zunächst im 'Test'-Modus"
        $testResults += "• Überwachen Sie die Regel-Performance nach der Aktivierung"
        $testResults += "• Dokumentieren Sie Änderungen für das Audit"
        
        $result = $testResults -join "`n"
        Write-Log "Transport Rule Test abgeschlossen für: $RuleName" -Type "Success"
        Log-Action "Transport Rule Test durchgeführt für: $RuleName"
        
        return $result
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Testen der Transport Rule: $errorMsg" -Type "Error"
        return "Fehler beim Testen der Regel: $errorMsg"
    }
}

function Get-MailFlowRulesAction {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Rufe Transport Rules ab..." -Type "Info"
        
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange Online verbunden."
        }
        
        # Status aktualisieren
        if ($null -ne $script:txtStatus) {
            $script:txtStatus.Text = "Lade Transport Rules..."
        }
        
        # Transport Rules abrufen
        $transportRules = Get-TransportRule | Select-Object Name, State, Mode, Priority, Description, 
            FromAddressContainsWords, SubjectContainsWords, RecipientDomainIs, SenderDomainIs,
            RedirectMessageTo, BlindCopyTo, RejectMessageReasonText, DeleteMessage
        
        # Daten für die Anzeige aufbereiten
        $rulesForGrid = @()
        foreach ($rule in $transportRules) {
            $conditions = [System.Collections.Generic.List[string]]::new()
            $actions = [System.Collections.Generic.List[string]]::new()
            
            # Bedingungen sammeln
            if ($rule.FromAddressContainsWords) {
                $conditions.Add("Absender enthält: $($rule.FromAddressContainsWords -join ', ')")
            }
            if ($rule.SubjectContainsWords) {
                $conditions.Add("Betreff enthält: $($rule.SubjectContainsWords -join ', ')")
            }
            if ($rule.RecipientDomainIs) {
                $conditions.Add("Empfänger-Domain: $($rule.RecipientDomainIs -join ', ')")
            }
            if ($rule.SenderDomainIs) {
                $conditions.Add("Absender-Domain: $($rule.SenderDomainIs -join ', ')")
            }
            
            # Aktionen sammeln
            if ($rule.RedirectMessageTo) {
                $actions.Add("Weiterleiten an: $($rule.RedirectMessageTo -join ', ')")
            }
            if ($rule.BlindCopyTo) {
                $actions.Add("BCC an: $($rule.BlindCopyTo -join ', ')")
            }
            if ($rule.RejectMessageReasonText) {
                $actions.Add("Ablehnen: $($rule.RejectMessageReasonText)")
            }
            if ($rule.DeleteMessage) {
                $actions.Add("Nachricht löschen")
            }
            
            $ruleObj = [PSCustomObject]@{
                Name = $rule.Name
                State = $rule.State
                Mode = $rule.Mode
                Priority = $rule.Priority
                Description = $rule.Description
                Conditions = $conditions -join '; '
                Actions = $actions -join '; '
            }
            
            $rulesForGrid += $ruleObj
        }
        
        # Daten in das DataGrid laden
        if ($null -ne $script:dgMailFlowRules) {
            $script:dgMailFlowRules.Dispatcher.Invoke([action]{
                $script:dgMailFlowRules.ItemsSource = $rulesForGrid
            }, "Normal")
        }
        
        Write-Log "Transport Rules erfolgreich geladen: $($rulesForGrid.Count) Regeln" -Type "Success"
        
        # Status aktualisieren
        if ($null -ne $script:txtStatus) {
            $script:txtStatus.Text = "Transport Rules geladen: $($rulesForGrid.Count) Regeln gefunden."
        }
        
        Log-Action "Transport Rules abgerufen: $($rulesForGrid.Count) Regeln"
        return $rulesForGrid
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Abrufen der Transport Rules: $errorMsg" -Type "Error"
        
        if ($null -ne $script:txtStatus) {
            $script:txtStatus.Text = "Fehler beim Laden der Transport Rules: $errorMsg"
        }
        
        Log-Action "Fehler beim Abrufen der Transport Rules: $errorMsg"
        return @()
    }
}

function Set-MailFlowRuleStateAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RuleName,
        
        [Parameter(Mandatory = $true)]
        [bool]$Enabled
    )
    
    try {
        $state = if ($Enabled) { "Enabled" } else { "Disabled" }
        Write-Log "Setze Transport Rule '$RuleName' auf Status: $state" -Type "Info"
        
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange Online verbunden."
        }
        
        # Transport Rule Status ändern - verwende Enable/Disable anstatt Set mit -State
        if ($Enabled) {
            Enable-TransportRule -Identity $RuleName -ErrorAction Stop
        }
        else {
            Disable-TransportRule -Identity $RuleName -ErrorAction Stop
        }
        
        $statusMsg = if ($Enabled) { "aktiviert" } else { "deaktiviert" }
        Write-Log "Transport Rule '$RuleName' erfolgreich $statusMsg" -Type "Success"
        Log-Action "Transport Rule '$RuleName' wurde $statusMsg"
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        $statusMsg = if ($Enabled) { "Aktivieren" } else { "Deaktivieren" }
        Write-Log "Fehler beim $statusMsg der Transport Rule '$RuleName': $errorMsg" -Type "Error"
        Log-Action "Fehler beim $statusMsg der Transport Rule '$RuleName': $errorMsg"
        return $false
    }
}

function Remove-MailFlowRuleAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RuleName
    )
    
    try {
        Write-Log "Lösche Transport Rule: $RuleName" -Type "Info"
        
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange Online verbunden."
        }
        
        # Transport Rule löschen
        Remove-TransportRule -Identity $RuleName -Confirm:$false -ErrorAction Stop
        
        Write-Log "Transport Rule '$RuleName' erfolgreich gelöscht" -Type "Success"
        Log-Action "Transport Rule '$RuleName' wurde gelöscht"
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Löschen der Transport Rule '$RuleName': $errorMsg" -Type "Error"
        Log-Action "Fehler beim Löschen der Transport Rule '$RuleName': $errorMsg"
        return $false
    }
}

function Export-MailFlowRulesAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        Write-Log "Exportiere Transport Rules nach: $FilePath" -Type "Info"
        
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange Online verbunden."
        }
        
        # Transport Rules abrufen
        $transportRules = Get-TransportRule | Select-Object Name, State, Mode, Priority, Description,
            FromAddressContainsWords, SubjectContainsWords, RecipientDomainIs, SenderDomainIs,
            RedirectMessageTo, BlindCopyTo, RejectMessageReasonText, DeleteMessage,
            SetHeaderName, SetHeaderValue, ApplyClassification, SetSCL, Quarantine
        
        # Bestimme Exportformat basierend auf Dateiendung
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        
        switch ($extension) {
            ".csv" {
                $transportRules | ConvertTo-SafeCsvObject | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8 -Delimiter ";"
            }
            ".xml" {
                $transportRules | Export-Clixml -Path $FilePath -Encoding UTF8
            }
            default {
                # Fallback zu CSV
                $transportRules | ConvertTo-SafeCsvObject | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8 -Delimiter ";"
            }
        }
        
        Write-Log "Transport Rules erfolgreich exportiert: $($transportRules.Count) Regeln" -Type "Success"
        Log-Action "Transport Rules exportiert nach: $FilePath ($($transportRules.Count) Regeln)"
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Exportieren der Transport Rules: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Exportieren der Transport Rules: $errorMsg"
        return $false
    }
}

function Import-MailFlowRulesAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        Write-Log "Importiere Transport Rules von: $FilePath" -Type "Info"
        
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange Online verbunden."
        }
        
        if (-not (Test-Path -Path $FilePath)) {
            throw "Datei nicht gefunden: $FilePath"
        }
        
        # Bestimme Importformat basierend auf Dateiendung
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        $importedRules = $null
        
        switch ($extension) {
            ".csv" {
                $importedRules = Import-Csv -Path $FilePath -Delimiter ";" -Encoding UTF8
            }
            ".xml" {
                $importedRules = Import-Clixml -Path $FilePath
            }
            default {
                # Fallback zu CSV
                $importedRules = Import-Csv -Path $FilePath -Delimiter ";" -Encoding UTF8
            }
        }
        
        if ($null -eq $importedRules -or $importedRules.Count -eq 0) {
            throw "Keine gültigen Transport Rules in der Datei gefunden."
        }
        
        $successCount = 0
        $errorCount = 0
        $errors = @()
        
        foreach ($rule in $importedRules) {
            try {
                # Überprüfe, ob Regel bereits existiert
                $existingRule = Get-TransportRule -Identity $rule.Name -ErrorAction SilentlyContinue
                if ($existingRule) {
                    Write-Log "Transport Rule '$($rule.Name)' existiert bereits - überspringe" -Type "Warning"
                    continue
                }
                
                # Parameter für Import vorbereiten
                $ruleParams = @{
                    Name = $rule.Name
                    State = $rule.State
                    Mode = $rule.Mode
                    Priority = if ($rule.Priority) { [int]$rule.Priority } else { 0 }
                    ErrorAction = "Stop"
                }
                
                if ($rule.Description) { $ruleParams.Add("Description", $rule.Description) }
                if ($rule.FromAddressContainsWords) { $ruleParams.Add("FromAddressContainsWords", $rule.FromAddressContainsWords.Split(',').Trim()) }
                if ($rule.SubjectContainsWords) { $ruleParams.Add("SubjectContainsWords", $rule.SubjectContainsWords.Split(',').Trim()) }
                if ($rule.RecipientDomainIs) { $ruleParams.Add("RecipientDomainIs", $rule.RecipientDomainIs.Split(',').Trim()) }
                if ($rule.SenderDomainIs) { $ruleParams.Add("SenderDomainIs", $rule.SenderDomainIs.Split(',').Trim()) }
                if ($rule.RedirectMessageTo) { $ruleParams.Add("RedirectMessageTo", $rule.RedirectMessageTo.Split(',').Trim()) }
                if ($rule.BlindCopyTo) { $ruleParams.Add("BlindCopyTo", $rule.BlindCopyTo.Split(',').Trim()) }
                if ($rule.RejectMessageReasonText) { $ruleParams.Add("RejectMessageReasonText", $rule.RejectMessageReasonText) }
                if ($rule.DeleteMessage -eq "True") { $ruleParams.Add("DeleteMessage", $true) }
                if ($rule.SetHeaderName) { $ruleParams.Add("SetHeaderName", $rule.SetHeaderName) }
                if ($rule.SetHeaderValue) { $ruleParams.Add("SetHeaderValue", $rule.SetHeaderValue) }
                if ($rule.ApplyClassification) { $ruleParams.Add("ApplyClassification", $rule.ApplyClassification) }
                if ($rule.SetSCL) { $ruleParams.Add("SetSCL", [int]$rule.SetSCL) }
                if ($rule.Quarantine -eq "True") { $ruleParams.Add("Quarantine", $true) }
                
                # Transport Rule erstellen
                New-TransportRule @ruleParams
                $successCount++
                
                Write-Log "Transport Rule '$($rule.Name)' erfolgreich importiert" -Type "Success"
            }
            catch {
                $errorCount++
                $errorMsg = $_.Exception.Message
                $errors += "Regel '$($rule.Name)': $errorMsg"
                Write-Log "Fehler beim Importieren der Transport Rule '$($rule.Name)': $errorMsg" -Type "Error"
            }
        }
        
        $resultMsg = "Import abgeschlossen: $successCount erfolgreich, $errorCount Fehler"
        Write-Log $resultMsg -Type "Info"
        
        if ($errors.Count -gt 0) {
            $errorSummary = "Fehler beim Import:`n" + ($errors -join "`n")
            Log-Action "Transport Rules Import: $resultMsg. Fehler: $errorSummary"
        } else {
            Log-Action "Transport Rules erfolgreich importiert: $successCount Regeln"
        }
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Importieren der Transport Rules: $errorMsg" -Type "Error"
        Log-Action "Fehler beim Importieren der Transport Rules: $errorMsg"
        return $false
    }
}

# Fehlende Hilfsfunktionen für die ComboBox-Initialisierung
function Initialize-MailFlowRuleConditionsComboBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ComboBox]$ComboBox
    )
    
    try {
        $ComboBox.Items.Clear()
        
        # Verfügbare Bedingungen definieren
        $conditions = @(
            @{ Display = "Absender-Adresse enthält Wörter"; Value = "FromAddressContainsWords" },
            @{ Display = "Betreff enthält Wörter"; Value = "SubjectContainsWords" },
            @{ Display = "Empfänger-Domain ist"; Value = "RecipientDomainIs" },
            @{ Display = "Absender-Domain ist"; Value = "SenderDomainIs" },
            @{ Display = "Dateianhang-Name entspricht Muster"; Value = "AttachmentNameMatchesPatterns" },
            @{ Display = "Nachrichtengröße größer als (KB)"; Value = "MessageSizeOver" }
        )
        
        foreach ($condition in $conditions) {
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Content = $condition.Display
            $item.Tag = $condition.Value
            $ComboBox.Items.Add($item)
        }
        
        if ($ComboBox.Items.Count -gt 0) {
            $ComboBox.SelectedIndex = 0
        }
        
        Write-Log "Mail Flow Bedingungen ComboBox initialisiert" -Type "Debug"
    }
    catch {
        Write-Log "Fehler beim Initialisieren der Bedingungen ComboBox: $($_.Exception.Message)" -Type "Error"
    }
}

function Initialize-MailFlowRuleActionsComboBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ComboBox]$ComboBox
    )
    
    try {
        $ComboBox.Items.Clear()
        
        # Verfügbare Aktionen definieren
        $actions = @(
            @{ Display = "Nachricht weiterleiten an"; Value = "RedirectMessageTo" },
            @{ Display = "Blindkopie (BCC) an"; Value = "BlindCopyTo" },
            @{ Display = "Nachricht ablehnen mit Text"; Value = "RejectMessageReasonText" },
            @{ Display = "Nachricht löschen"; Value = "DeleteMessage" },
            @{ Display = "Moderation durch Benutzer"; Value = "ModerateMessageByUser" },
            @{ Display = "Header setzen (Name:Wert)"; Value = "SetHeaderName" },
            @{ Display = "Klassifizierung anwenden"; Value = "ApplyClassification" },
            @{ Display = "SCL-Wert setzen"; Value = "SetSCL" },
            @{ Display = "In Quarantäne verschieben"; Value = "Quarantine" }
        )
        
        foreach ($action in $actions) {
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Content = $action.Display
            $item.Tag = $action.Value
            $ComboBox.Items.Add($item)
        }
        
        if ($ComboBox.Items.Count -gt 0) {
            $ComboBox.SelectedIndex = 0
        }
        
        Write-Log "Mail Flow Aktionen ComboBox initialisiert" -Type "Debug"
    }
    catch {
        Write-Log "Fehler beim Initialisieren der Aktionen ComboBox: $($_.Exception.Message)" -Type "Error"
    }
}

function Initialize-MailFlowRuleModeComboBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ComboBox]$ComboBox
    )
    
    try {
        $ComboBox.Items.Clear()
        
        # Verfügbare Modi definieren - nur gültige Werte für Exchange Online
        $modes = @(
            @{ Display = "Audit (Nur protokollieren)"; Value = "Audit" },
            @{ Display = "Audit und Benachrichtigen"; Value = "AuditAndNotify" },
            @{ Display = "Enforce (Regel aktiv)"; Value = "Enforce" }
        )
        
        foreach ($mode in $modes) {
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Content = $mode.Display
            $item.Tag = $mode.Value
            $ComboBox.Items.Add($item)
        }
        
        # Standardmäßig "Audit" auswählen
        if ($ComboBox.Items.Count -gt 0) {
            $ComboBox.SelectedIndex = 0
        }
        
        Write-Log "Mail Flow Modi ComboBox initialisiert" -Type "Debug"
    }
    catch {
        Write-Log "Fehler beim Initialisieren der Modi ComboBox: $($_.Exception.Message)" -Type "Error"
    }
}

function Initialize-MailFlowRulesTab {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Initialisiere Mail Flow Rules-Tab..." -Type "Info"

        # UI-Elemente referenzieren
        $txtRuleName = Get-XamlElement -ElementName "txtRuleName"
        $cmbCondition = Get-XamlElement -ElementName "cmbCondition"
        $txtConditionValue = Get-XamlElement -ElementName "txtConditionValue"
        $cmbAction = Get-XamlElement -ElementName "cmbAction"
        $txtActionValue = Get-XamlElement -ElementName "txtActionValue"
        $cmbRuleMode = Get-XamlElement -ElementName "cmbRuleMode"
        $btnCreateRule = Get-XamlElement -ElementName "btnCreateRule"
        $btnTestRule = Get-XamlElement -ElementName "btnTestRule"
        $dgMailFlowRules = Get-XamlElement -ElementName "dgMailFlowRules"
        $btnRefreshRules = Get-XamlElement -ElementName "btnRefreshRules"
        $btnEnableRule = Get-XamlElement -ElementName "btnEnableRule"
        $btnDisableRule = Get-XamlElement -ElementName "btnDisableRule"
        $btnDeleteRule = Get-XamlElement -ElementName "btnDeleteRule"
        $btnExportRules = Get-XamlElement -ElementName "btnExportRules"
        $btnImportRules = Get-XamlElement -ElementName "btnImportRules"

        # Globale Variablen setzen
        $script:txtRuleName = $txtRuleName
        $script:cmbCondition = $cmbCondition
        $script:txtConditionValue = $txtConditionValue
        $script:cmbAction = $cmbAction
        $script:txtActionValue = $txtActionValue
        $script:cmbRuleMode = $cmbRuleMode
        $script:dgMailFlowRules = $dgMailFlowRules

        # ComboBoxen initialisieren
        if ($null -ne $cmbCondition) {
            Initialize-MailFlowRuleConditionsComboBox -ComboBox $cmbCondition
        }
        
        if ($null -ne $cmbAction) {
            Initialize-MailFlowRuleActionsComboBox -ComboBox $cmbAction
        }
        
        if ($null -ne $cmbRuleMode) {
            Initialize-MailFlowRuleModeComboBox -ComboBox $cmbRuleMode
        }

        # Event-Handler für "Create Rule" Button
        Register-EventHandler -Control $btnCreateRule -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                # Eingabe validieren
                if ([string]::IsNullOrWhiteSpace($script:txtRuleName.Text)) {
                    Show-MessageBox -Message "Bitte geben Sie einen Namen für die Regel ein." -Title "Fehlende Angabe" -Type Warning
                    return
                }

                if ($null -eq $script:cmbCondition.SelectedItem) {
                    Show-MessageBox -Message "Bitte wählen Sie eine Bedingung aus." -Title "Fehlende Angabe" -Type Warning
                    return
                }

                if ($null -eq $script:cmbAction.SelectedItem) {
                    Show-MessageBox -Message "Bitte wählen Sie eine Aktion aus." -Title "Fehlende Angabe" -Type Warning
                    return
                }

                # Parameter sammeln
                $ruleName = $script:txtRuleName.Text.Trim()
                $conditionType = $script:cmbCondition.SelectedItem.Tag
                $conditionValue = $script:txtConditionValue.Text.Trim()
                $actionType = $script:cmbAction.SelectedItem.Tag
                $actionValue = $script:txtActionValue.Text.Trim()
                $ruleMode = if ($null -ne $script:cmbRuleMode.SelectedItem) { $script:cmbRuleMode.SelectedItem.Tag } else { "Test" }

                # Regel erstellen mit der MailFlow-Funktion
                $result = New-MailFlowRuleAction -RuleName $ruleName -ConditionType $conditionType -ConditionValue $conditionValue -ActionType $actionType -ActionValue $actionValue -Mode $ruleMode

                if ($result) {
                    $script:txtStatus.Text = "Transport Rule '$ruleName' erfolgreich erstellt."
                    # Felder zurücksetzen
                    $script:txtRuleName.Text = ""
                    $script:txtConditionValue.Text = ""
                    $script:txtActionValue.Text = ""
                    # Liste aktualisieren
                    Get-MailFlowRulesAction
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Erstellen der Transport Rule: $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnCreateRule"

        # Event-Handler für "Test Rule" Button
        Register-EventHandler -Control $btnTestRule -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                # Eingabe validieren
                if ([string]::IsNullOrWhiteSpace($script:txtRuleName.Text)) {
                    Show-MessageBox -Message "Bitte geben Sie einen Namen für die Regel ein." -Title "Fehlende Angabe" -Type Warning
                    return
                }

                if ($null -eq $script:cmbCondition.SelectedItem) {
                    Show-MessageBox -Message "Bitte wählen Sie eine Bedingung aus." -Title "Fehlende Angabe" -Type Warning
                    return
                }

                # Test-Regel mit der MailFlow-Funktion
                $result = Test-MailFlowRuleAction -RuleName $script:txtRuleName.Text.Trim() -ConditionType $script:cmbCondition.SelectedItem.Tag -ConditionValue $script:txtConditionValue.Text.Trim()

                Show-MessageBox -Message $result -Title "Regel-Test Ergebnis" -Type Info
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Testen der Transport Rule: $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnTestRule"

        # Event-Handler für "Refresh Rules" Button
        Register-EventHandler -Control $btnRefreshRules -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                Get-MailFlowRulesAction
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Aktualisieren der Transport Rules: $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnRefreshRules"

        # Event-Handler für "Enable Rule" Button
        Register-EventHandler -Control $btnEnableRule -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                $selectedRule = $script:dgMailFlowRules.SelectedItem
                if ($null -eq $selectedRule) {
                    Show-MessageBox -Message "Bitte wählen Sie eine Regel aus der Liste aus." -Title "Keine Auswahl" -Type Warning
                    return
                }

                $result = Set-MailFlowRuleStateAction -RuleName $selectedRule.Name -Enabled $true

                if ($result) {
                    $script:txtStatus.Text = "Transport Rule '$($selectedRule.Name)' wurde aktiviert."
                    Get-MailFlowRulesAction
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Aktivieren der Transport Rule: $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnEnableRule"

        # Event-Handler für "Disable Rule" Button
        Register-EventHandler -Control $btnDisableRule -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                $selectedRule = $script:dgMailFlowRules.SelectedItem
                if ($null -eq $selectedRule) {
                    Show-MessageBox -Message "Bitte wählen Sie eine Regel aus der Liste aus." -Title "Keine Auswahl" -Type Warning
                    return
                }

                $result = Set-MailFlowRuleStateAction -RuleName $selectedRule.Name -Enabled $false

                if ($result) {
                    $script:txtStatus.Text = "Transport Rule '$($selectedRule.Name)' wurde deaktiviert."
                    Get-MailFlowRulesAction
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Deaktivieren der Transport Rule: $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnDisableRule"

        # Event-Handler für "Delete Rule" Button
        Register-EventHandler -Control $btnDeleteRule -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                $selectedRule = $script:dgMailFlowRules.SelectedItem
                if ($null -eq $selectedRule) {
                    Show-MessageBox -Message "Bitte wählen Sie eine Regel aus der Liste aus." -Title "Keine Auswahl" -Type Warning
                    return
                }

                $confirmResult = Show-MessageBox -Message "Sind Sie sicher, dass Sie die Transport Rule '$($selectedRule.Name)' löschen möchten?" -Title "Löschen bestätigen" -Type Question

                if ($confirmResult -eq "Yes") {
                    $result = Remove-MailFlowRuleAction -RuleName $selectedRule.Name

                    if ($result) {
                        $script:txtStatus.Text = "Transport Rule '$($selectedRule.Name)' wurde gelöscht."
                        Get-MailFlowRulesAction
                    }
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Löschen der Transport Rule: $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnDeleteRule"

        # Event-Handler für "Export Rules" Button
        Register-EventHandler -Control $btnExportRules -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
                $saveFileDialog.Filter = "CSV-Dateien (*.csv)|*.csv|XML-Dateien (*.xml)|*.xml"
                $saveFileDialog.Title = "Transport Rules exportieren"
                $saveFileDialog.FileName = "TransportRules_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

                if ($saveFileDialog.ShowDialog() -eq $true) {
                    $result = Export-MailFlowRulesAction -FilePath $saveFileDialog.FileName

                    if ($result) {
                        $script:txtStatus.Text = "Transport Rules erfolgreich exportiert nach: $($saveFileDialog.FileName)"
                        Show-MessageBox -Message "Transport Rules wurden erfolgreich exportiert." -Title "Export erfolgreich" -Type Info
                    }
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Exportieren der Transport Rules: $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnExportRules"

        # Event-Handler für "Import Rules" Button
        Register-EventHandler -Control $btnImportRules -Handler {
            try {
                if (-not $script:isConnected) {
                    Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type Warning
                    return
                }

                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "CSV-Dateien (*.csv)|*.csv|XML-Dateien (*.xml)|*.xml"
                $openFileDialog.Title = "Transport Rules importieren"

                if ($openFileDialog.ShowDialog() -eq $true) {
                    $confirmResult = Show-MessageBox -Message "Sind Sie sicher, dass Sie Transport Rules aus der Datei '$($openFileDialog.FileName)' importieren möchten?" -Title "Import bestätigen" -Type Question

                    if ($confirmResult -eq "Yes") {
                        $result = Import-MailFlowRulesAction -FilePath $openFileDialog.FileName

                        if ($result) {
                            $script:txtStatus.Text = "Transport Rules erfolgreich importiert."
                            Get-MailFlowRulesAction
                            Show-MessageBox -Message "Transport Rules wurden erfolgreich importiert." -Title "Import erfolgreich" -Type Info
                        }
                    }
                }
            }
            catch {
                $errorMsg = $_.Exception.Message
                Write-Log "Fehler beim Importieren der Transport Rules: $errorMsg" -Type "Error"
                $script:txtStatus.Text = "Fehler: $errorMsg"
            }
        } -ControlName "btnImportRules"

        Write-Log "Mail Flow Rules-Tab erfolgreich initialisiert" -Type "Success"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Initialisieren des Mail Flow Rules-Tabs: $errorMsg" -Type "Error"
        return $false
    }
}
