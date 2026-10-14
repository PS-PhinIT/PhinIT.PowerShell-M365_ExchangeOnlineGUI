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

# Zerlegt eine kommagetrennte Eingabe in eine Liste ohne leere Einträge
function ConvertTo-MailFlowRuleValueList {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
    return [string[]]@($Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

# Prüft Bedingung und Aktion einer neuen Transport Rule. Gibt eine Fehlermeldung oder $null zurück.
# Eine Regel ohne Bedingungswert würde für alle Nachrichten der Organisation gelten.
function Get-MailFlowRuleInputError {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConditionType,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$ConditionValue,

        [Parameter(Mandatory = $false)]
        [string]$ActionType,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$ActionValue
    )

    $listConditions = @("FromAddressContainsWords", "SubjectContainsWords", "RecipientDomainIs", "SenderDomainIs", "AttachmentNameMatchesPatterns")
    if ($ConditionType -in $listConditions) {
        if (@(ConvertTo-MailFlowRuleValueList -Value $ConditionValue).Count -eq 0) {
            return "Bitte geben Sie einen Wert für die Bedingung an (mehrere Werte durch Komma trennen). Ohne Wert würde die Regel für alle Nachrichten gelten."
        }
    }
    elseif ($ConditionType -eq "MessageSizeOver") {
        $sizeKB = 0
        if (-not [int]::TryParse(([string]$ConditionValue).Trim(), [ref]$sizeKB) -or $sizeKB -le 0) {
            return "Bitte geben Sie für die Nachrichtengröße eine positive ganze Zahl (KB) an."
        }
    }
    else {
        return "Unbekannte Bedingung: '$ConditionType'."
    }

    if ($ActionType -in @("RedirectMessageTo", "BlindCopyTo", "ModerateMessageByUser")) {
        if (@(ConvertTo-MailFlowRuleValueList -Value $ActionValue).Count -eq 0) {
            return "Bitte geben Sie für die Aktion mindestens eine Empfängeradresse an (mehrere durch Komma trennen)."
        }
    }
    elseif ($ActionType -in @("RejectMessageReasonText", "ApplyClassification")) {
        if ([string]::IsNullOrWhiteSpace($ActionValue)) {
            return "Bitte geben Sie einen Wert für die Aktion an."
        }
    }
    elseif ($ActionType -eq "SetHeaderName") {
        $headerParts = ([string]$ActionValue).Split(':', 2)
        if ($headerParts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($headerParts[0]) -or [string]::IsNullOrWhiteSpace($headerParts[1])) {
            return "Bitte geben Sie den Header im Format 'Name:Wert' an (z. B. X-Kennzeichnung:Extern)."
        }
    }
    elseif ($ActionType -eq "SetSCL") {
        $scl = 0
        if (-not [int]::TryParse(([string]$ActionValue).Trim(), [ref]$scl) -or $scl -lt -1 -or $scl -gt 9) {
            return "Bitte geben Sie einen SCL-Wert zwischen -1 und 9 an."
        }
    }
    elseif ($ActionType -notin @("DeleteMessage", "Quarantine")) {
        return "Unbekannte Aktion: '$ActionType'."
    }

    return $null
}

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
        
        # Gültige Werte für Exchange Online: Audit, AuditAndNotify, Enforce
        [Parameter(Mandatory = $false)]
        [ValidateSet("Audit", "AuditAndNotify", "Enforce")]
        [string]$Mode = "Audit"
    )
    
    try {
        Write-Log "Erstelle neue Transport Rule: $RuleName" -Type "Info"
        
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange Online verbunden."
        }

        $inputError = Get-MailFlowRuleInputError -ConditionType $ConditionType -ConditionValue $ConditionValue -ActionType $ActionType -ActionValue $ActionValue
        if ($inputError) {
            throw $inputError
        }
        
        # Parameter für die Regel aufbauen
        $ruleParams = @{
            Name = $RuleName
            Mode = $Mode
            ErrorAction = "Stop"
        }
        
        # Bedingungen setzen (Werte wurden oben geprüft)
        switch ($ConditionType) {
            "MessageSizeOver" {
                $ruleParams.Add("MessageSizeOver", "$($ConditionValue.Trim()) KB")
            }
            default {
                $ruleParams.Add($ConditionType, (ConvertTo-MailFlowRuleValueList -Value $ConditionValue))
            }
        }
        
        # Aktionen setzen
        switch ($ActionType) {
            "RedirectMessageTo" {
                $ruleParams.Add("RedirectMessageTo", (ConvertTo-MailFlowRuleValueList -Value $ActionValue))
            }
            "BlindCopyTo" {
                $ruleParams.Add("BlindCopyTo", (ConvertTo-MailFlowRuleValueList -Value $ActionValue))
            }
            "RejectMessageReasonText" {
                $ruleParams.Add("RejectMessageReasonText", $ActionValue.Trim())
            }
            "DeleteMessage" {
                $ruleParams.Add("DeleteMessage", $true)
            }
            "ModerateMessageByUser" {
                $ruleParams.Add("ModerateMessageByUser", (ConvertTo-MailFlowRuleValueList -Value $ActionValue))
            }
            "SetHeaderName" {
                $headerParts = $ActionValue.Split(':', 2)
                $ruleParams.Add("SetHeaderName", $headerParts[0].Trim())
                $ruleParams.Add("SetHeaderValue", $headerParts[1].Trim())
            }
            "ApplyClassification" {
                $ruleParams.Add("ApplyClassification", $ActionValue.Trim())
            }
            "SetSCL" {
                $ruleParams.Add("SetSCL", [int]$ActionValue.Trim())
            }
            "Quarantine" {
                $ruleParams.Add("Quarantine", $true)
            }
        }
        
        # Transport Rule erstellen
        $null = New-TransportRule @ruleParams
        
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
            { $_ -in @("RecipientDomainIs", "SenderDomainIs") } {
                $filterLabel = if ($ConditionType -eq "SenderDomainIs") { "Absender" } else { "Empfänger" }
                if ([string]::IsNullOrWhiteSpace($ConditionValue)) {
                    $testResults += "❌ FEHLER: Keine Domain für $ConditionType angegeben"
                } else {
                    $domains = $ConditionValue.Split(',').Trim()
                    $testResults += "✅ OK: $($domains.Count) Domain(s) für $filterLabel-Filter konfiguriert"
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
        $testResults += "• Testen Sie die Regel zunächst im Modus 'Audit' (nur protokollieren)"
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

# Eigenschaften für Export/Import von Transport Rules. Beim Import werden nur diese Eigenschaften
# übernommen; Listen werden in der CSV-Datei mit ", " verbunden und beim Import am Komma getrennt.
$script:MailFlowRuleExportProperties = @(
    "Name", "State", "Mode", "Priority", "Comments", "Description",
    "FromAddressContainsWords", "SubjectContainsWords", "RecipientDomainIs", "SenderDomainIs",
    "AttachmentNameMatchesPatterns", "MessageSizeOver",
    "RedirectMessageTo", "BlindCopyTo", "ModerateMessageByUser", "RejectMessageReasonText", "DeleteMessage",
    "SetHeaderName", "SetHeaderValue", "ApplyClassification", "SetSCL", "Quarantine"
)
$script:MailFlowRuleListProperties = @(
    "FromAddressContainsWords", "SubjectContainsWords", "RecipientDomainIs", "SenderDomainIs",
    "AttachmentNameMatchesPatterns", "RedirectMessageTo", "BlindCopyTo", "ModerateMessageByUser"
)
$script:MailFlowRuleConditionProperties = @(
    "FromAddressContainsWords", "SubjectContainsWords", "RecipientDomainIs", "SenderDomainIs",
    "AttachmentNameMatchesPatterns", "MessageSizeOver"
)
$script:MailFlowRuleIntProperties = @("Priority", "SetSCL")
$script:MailFlowRuleBoolProperties = @("DeleteMessage", "Quarantine")
$script:MailFlowRuleListSeparator = ", "

# Wandelt eine Transport Rule in ein Exportobjekt mit einfachen Typen um (string, bool, int, string[])
function ConvertTo-MailFlowRuleExportObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Rule
    )

    process {
        $exportObject = [ordered]@{}
        foreach ($propertyName in $script:MailFlowRuleExportProperties) {
            $value = $Rule.$propertyName
            if ($propertyName -in $script:MailFlowRuleListProperties) {
                $exportObject[$propertyName] = [string[]]@(@($value) | Where-Object { $null -ne $_ -and "$_" -ne "" } | ForEach-Object { "$_" })
            }
            elseif ($propertyName -in $script:MailFlowRuleBoolProperties) {
                $exportObject[$propertyName] = if ($value -is [bool]) { $value } else { "$value" -eq "True" }
            }
            elseif ($propertyName -in $script:MailFlowRuleIntProperties) {
                $number = 0
                $exportObject[$propertyName] = if ($null -ne $value -and [int]::TryParse("$value", [ref]$number)) { $number } else { $null }
            }
            else {
                $exportObject[$propertyName] = if ($null -eq $value) { $null } else { "$value" }
            }
        }
        [PSCustomObject]$exportObject
    }
}

# Entfernt das von ConvertTo-SafeCsvObject vorangestellte Hochkomma (Schutz vor CSV-Injection)
function ConvertFrom-MailFlowRuleCsvText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Value,

        [switch]$FromCsv
    )

    if ($FromCsv -and $Value -match "^'[=+\-@\t\r]") {
        return $Value.Substring(1)
    }
    return $Value
}

# Prüft ein importiertes Objekt (CSV oder XML) und gibt eine Hashtable mit den erlaubten Eigenschaften zurück.
# Unbekannte Eigenschaften werden ignoriert, Eigenschaften mit unerwartetem Typ führen zu einem Fehler.
function ConvertTo-MailFlowRuleImportObject {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $InputObject,

        [switch]$FromCsv
    )

    if ($null -eq $InputObject -or $InputObject -is [string] -or $InputObject -is [System.ValueType] -or
        $InputObject -is [System.Collections.IDictionary] -or $InputObject -is [System.Collections.IEnumerable]) {
        throw "Der Eintrag ist kein gültiges Regelobjekt."
    }

    $rule = @{}
    foreach ($property in $InputObject.PSObject.Properties) {
        $propertyName = $property.Name
        $value = $property.Value
        if ($propertyName -notin $script:MailFlowRuleExportProperties -or $null -eq $value) { continue }

        if ($propertyName -in $script:MailFlowRuleListProperties) {
            if ($value -is [string]) {
                $text = ConvertFrom-MailFlowRuleCsvText -Value $value -FromCsv:$FromCsv
                $items = if ($FromCsv) { @(ConvertTo-MailFlowRuleValueList -Value $text) } else { @($text.Trim()) }
            }
            elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [System.Collections.IDictionary]) {
                $items = @(foreach ($item in $value) {
                    if ($null -eq $item) { continue }
                    if ($item -isnot [string]) {
                        throw "Eigenschaft '$propertyName' enthält einen ungültigen Typ ($($item.GetType().FullName))."
                    }
                    $item.Trim()
                })
            }
            else {
                throw "Eigenschaft '$propertyName' hat einen ungültigen Typ ($($value.GetType().FullName))."
            }
            $items = @($items | Where-Object { $_ })
            if ($items.Count -gt 0) { $rule[$propertyName] = [string[]]$items }
        }
        elseif ($propertyName -in $script:MailFlowRuleBoolProperties) {
            if ($value -is [bool]) {
                $rule[$propertyName] = $value
            }
            elseif ($value -is [string]) {
                $text = $value.Trim()
                if ($text -eq "") { continue }
                if ($text -notin @("True", "False")) {
                    throw "Eigenschaft '$propertyName' hat einen ungültigen Wert ('$text')."
                }
                $rule[$propertyName] = ($text -eq "True")
            }
            else {
                throw "Eigenschaft '$propertyName' hat einen ungültigen Typ ($($value.GetType().FullName))."
            }
        }
        elseif ($propertyName -in $script:MailFlowRuleIntProperties) {
            $number = 0
            if ($value -is [int]) {
                $rule[$propertyName] = $value
            }
            elseif ($value -is [string]) {
                $text = (ConvertFrom-MailFlowRuleCsvText -Value $value -FromCsv:$FromCsv).Trim()
                if ($text -eq "") { continue }
                if (-not [int]::TryParse($text, [ref]$number)) {
                    throw "Eigenschaft '$propertyName' hat einen ungültigen Wert ('$text')."
                }
                $rule[$propertyName] = $number
            }
            else {
                throw "Eigenschaft '$propertyName' hat einen ungültigen Typ ($($value.GetType().FullName))."
            }
        }
        else {
            if ($value -isnot [string]) {
                throw "Eigenschaft '$propertyName' hat einen ungültigen Typ ($($value.GetType().FullName))."
            }
            $text = (ConvertFrom-MailFlowRuleCsvText -Value $value -FromCsv:$FromCsv).Trim()
            if ($text -ne "") { $rule[$propertyName] = $text }
        }
    }

    if ([string]::IsNullOrWhiteSpace($rule["Name"])) {
        throw "Der Eintrag hat keinen Regelnamen."
    }
    return $rule
}

# Wandelt die exportierte Nachrichtengröße (z. B. "10 MB (10,485,760 bytes)") in einen gültigen Wert um
function ConvertTo-MailFlowRuleSizeValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $text = $Value.Trim()
    if ($text -match '\(([\d.,\s]+)\s*bytes\)') {
        $bytes = $Matches[1] -replace '[^\d]', ''
        if ($bytes) { return "$bytes B" }
    }
    if ($text -match '^\d+(\.\d+)?\s*(B|KB|MB|GB|TB)?$') {
        return $text
    }
    throw "Ungültige Nachrichtengröße: '$Value'."
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
        
        # Transport Rules abrufen und auf einfache Typen reduzieren (Import-kompatibel)
        $transportRules = @(Get-TransportRule -ErrorAction Stop | ConvertTo-MailFlowRuleExportObject)
        
        # Bestimme Exportformat basierend auf Dateiendung
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        
        switch ($extension) {
            ".xml" {
                $transportRules | Export-Clixml -Path $FilePath -Encoding UTF8
            }
            default {
                # CSV (auch als Fallback); Listen werden mit ", " verbunden
                $transportRules | ConvertTo-SafeCsvObject -ListSeparator $script:MailFlowRuleListSeparator | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8 -Delimiter ";"
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

# Importiert Transport Rules aus CSV/XML. Gibt eine Zusammenfassung zurück
# (Success ist nur $true, wenn kein Fehler aufgetreten ist und der Import nicht abgebrochen wurde).
function Import-MailFlowRulesAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    $messages = [System.Collections.Generic.List[string]]::new()
    $importedCount = 0
    $skippedCount = 0
    $failedCount = 0
    $cancelled = $false
    $generalError = $null

    Start-UIBusy -Message "Importiere Transport Rules..." -Title "Transport Rules importieren" -Cancelable
    try {
        Write-Log "Importiere Transport Rules von: $FilePath" -Type "Info"
        
        if (-not $script:isConnected) {
            throw "Nicht mit Exchange Online verbunden."
        }
        
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
            throw "Datei nicht gefunden: $FilePath"
        }
        
        # Bestimme Importformat basierend auf Dateiendung
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        $fromCsv = $extension -ne ".xml"
        $importedRules = if ($fromCsv) {
            @(Import-Csv -LiteralPath $FilePath -Delimiter ";" -Encoding UTF8)
        }
        else {
            @(Import-Clixml -LiteralPath $FilePath)
        }
        
        if ($importedRules.Count -eq 0) {
            throw "Keine gültigen Transport Rules in der Datei gefunden."
        }

        # Vorhandene Regelnamen einmalig laden (statt Get-TransportRule pro Regel)
        Update-UIBusy -Message "Lade vorhandene Transport Rules..."
        $existingNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($existingRule in @(Get-TransportRule -ErrorAction Stop)) {
            [void]$existingNames.Add([string]$existingRule.Name)
        }
        $ruleCount = $existingNames.Count
        $validModes = @("Audit", "AuditAndNotify", "Enforce")
        
        $index = 0
        foreach ($importedRule in $importedRules) {
            $index++
            if (Test-UICancelRequested) {
                $cancelled = $true
                break
            }
            Update-UIBusy -Message "Importiere Transport Rules" -Current $index -Total $importedRules.Count

            $ruleLabel = "Eintrag $index"
            try {
                $rule = ConvertTo-MailFlowRuleImportObject -InputObject $importedRule -FromCsv:$fromCsv
                $ruleName = $rule["Name"]
                $ruleLabel = "Regel '$ruleName'"

                if ($existingNames.Contains($ruleName)) {
                    $skippedCount++
                    $messages.Add("$($ruleLabel): existiert bereits - übersprungen")
                    Write-Log "Transport Rule '$ruleName' existiert bereits - überspringe" -Type "Warning"
                    continue
                }
                
                # Parameter für Import vorbereiten
                $ruleParams = @{
                    Name = $ruleName
                    ErrorAction = "Stop"
                }

                $mode = "Audit"
                if ($rule.ContainsKey("Mode")) {
                    if ($rule["Mode"] -in $validModes) {
                        $mode = $rule["Mode"]
                    }
                    else {
                        $messages.Add("$($ruleLabel): ungültiger Modus '$($rule["Mode"])' - Modus 'Audit' verwendet")
                    }
                }
                $ruleParams.Mode = $mode

                if ($rule.ContainsKey("State")) {
                    $ruleParams.Enabled = ($rule["State"] -eq "Enabled")
                }
                if ($rule.ContainsKey("Priority") -and $rule["Priority"] -ge 0 -and $rule["Priority"] -le $ruleCount) {
                    $ruleParams.Priority = $rule["Priority"]
                }
                if ($rule.ContainsKey("Comments")) {
                    $ruleParams.Comments = $rule["Comments"]
                }

                # Bedingungen - ohne Bedingung würde die Regel für alle Nachrichten gelten
                $hasCondition = $false
                foreach ($conditionName in $script:MailFlowRuleConditionProperties) {
                    if (-not $rule.ContainsKey($conditionName)) { continue }
                    if ($conditionName -eq "MessageSizeOver") {
                        $ruleParams.MessageSizeOver = ConvertTo-MailFlowRuleSizeValue -Value $rule["MessageSizeOver"]
                    }
                    else {
                        $ruleParams[$conditionName] = $rule[$conditionName]
                    }
                    $hasCondition = $true
                }
                if (-not $hasCondition) {
                    $skippedCount++
                    $messages.Add("$($ruleLabel): keine unterstützte Bedingung (die Regel würde für alle Nachrichten gelten) - übersprungen")
                    Write-Log "Transport Rule '$ruleName' ohne unterstützte Bedingung - überspringe" -Type "Warning"
                    continue
                }

                # Aktionen
                $hasAction = $false
                foreach ($actionName in @("RedirectMessageTo", "BlindCopyTo", "ModerateMessageByUser", "RejectMessageReasonText", "ApplyClassification")) {
                    if ($rule.ContainsKey($actionName)) {
                        $ruleParams[$actionName] = $rule[$actionName]
                        $hasAction = $true
                    }
                }
                if ($rule["DeleteMessage"] -eq $true) {
                    $ruleParams.DeleteMessage = $true
                    $hasAction = $true
                }
                if ($rule["Quarantine"] -eq $true) {
                    $ruleParams.Quarantine = $true
                    $hasAction = $true
                }
                if ($rule.ContainsKey("SetSCL")) {
                    if ($rule["SetSCL"] -lt -1 -or $rule["SetSCL"] -gt 9) {
                        throw "Ungültiger SCL-Wert: $($rule["SetSCL"])"
                    }
                    $ruleParams.SetSCL = $rule["SetSCL"]
                    $hasAction = $true
                }
                if ($rule.ContainsKey("SetHeaderName") -or $rule.ContainsKey("SetHeaderValue")) {
                    if (-not ($rule.ContainsKey("SetHeaderName") -and $rule.ContainsKey("SetHeaderValue"))) {
                        throw "SetHeaderName und SetHeaderValue müssen gemeinsam angegeben werden."
                    }
                    $ruleParams.SetHeaderName = $rule["SetHeaderName"]
                    $ruleParams.SetHeaderValue = $rule["SetHeaderValue"]
                    $hasAction = $true
                }
                if (-not $hasAction) {
                    $skippedCount++
                    $messages.Add("$($ruleLabel): keine unterstützte Aktion - übersprungen")
                    Write-Log "Transport Rule '$ruleName' ohne unterstützte Aktion - überspringe" -Type "Warning"
                    continue
                }
                
                # Transport Rule erstellen
                $null = New-TransportRule @ruleParams
                [void]$existingNames.Add($ruleName)
                $ruleCount++
                $importedCount++
                
                Write-Log "Transport Rule '$ruleName' erfolgreich importiert" -Type "Success"
            }
            catch {
                $failedCount++
                $errorMsg = $_.Exception.Message
                $messages.Add("$($ruleLabel): $errorMsg")
                Write-Log "Fehler beim Importieren ($ruleLabel): $errorMsg" -Type "Error"
            }
        }
    }
    catch {
        $generalError = $_.Exception.Message
        $messages.Add("Import fehlgeschlagen: $generalError")
        Write-Log "Fehler beim Importieren der Transport Rules: $generalError" -Type "Error"
        Log-Action "Fehler beim Importieren der Transport Rules: $generalError"
    }
    finally {
        Stop-UIBusy
    }

    $resultMsg = "Import abgeschlossen: $importedCount importiert, $skippedCount übersprungen, $failedCount fehlgeschlagen"
    if ($cancelled) { $resultMsg += " (abgebrochen)" }
    if ($null -eq $generalError) {
        Write-Log $resultMsg -Type $(if ($failedCount -gt 0 -or $cancelled) { "Warning" } else { "Info" })
        Log-Action "Transport Rules Import aus $($FilePath): $resultMsg"
    }

    return [PSCustomObject]@{
        Success   = ($null -eq $generalError -and $failedCount -eq 0 -and -not $cancelled)
        Imported  = $importedCount
        Skipped   = $skippedCount
        Failed    = $failedCount
        Cancelled = $cancelled
        Messages  = $messages.ToArray()
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
