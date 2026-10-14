# =====================================================================
# easyEXO - Modul: Dashboard-Statistiken
# Datei: src/Modules/Features/Dashboard.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

#endregion

#region Dashboard Statistics
function Reset-DashboardStatistics {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Setze Dashboard-Statistiken zurück..." -Type "Info"
        Update-StatusBar -Message "Setze Dashboard-Statistiken zurück..." -Type "Info"

        # Platzhalterwert für die Statistikfelder
        $placeholder = "-"

        # Hilfsfunktion für das Setzen des Textes
        function Set-StatText($element, $value) {
            if ($null -ne $element) {
                $element.Text = $value
            }
        }

        # UI-Updates im Dispatcher-Thread ausführen
        if ($null -ne $script:Form -and $script:Form.Dispatcher) {
            $script:Form.Dispatcher.Invoke([Action]{
                Set-StatText $script:txtStatTotalMailboxes $placeholder
                Set-StatText $script:txtStatSharedMailboxes $placeholder
                Set-StatText $script:txtStatGroups $placeholder
                Set-StatText $script:txtStatResources $placeholder
                Set-StatText $script:txtStatDomains $placeholder
            }, "Normal")
        } else {
            # Fallback, falls Dispatcher nicht verfügbar
            Set-StatText $script:txtStatTotalMailboxes $placeholder
            Set-StatText $script:txtStatSharedMailboxes $placeholder
            Set-StatText $script:txtStatGroups $placeholder
            Set-StatText $script:txtStatResources $placeholder
            Set-StatText $script:txtStatDomains $placeholder
        }

        Update-StatusBar -Message "Dashboard-Statistiken zurückgesetzt." -Type "Success"
        Write-Log "Dashboard-Statistiken erfolgreich zurückgesetzt." -Type "Success"
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Zurücksetzen der Dashboard-Statistiken."
        Write-Log $errorMsg -Type "Error"
        Update-StatusBar -Message "Fehler beim Zurücksetzen der Statistiken." -Type "Error"
    }
}

function Refresh-DashboardStatistics {
    [CmdletBinding()]
    param()
    
    try {
        if (-not $script:isConnected) {
            Write-Log "Nicht mit Exchange Online verbunden. Dashboard-Statistiken können noch nicht aktualisiert werden." -Type "Warning"
            Reset-DashboardStatistics # Setzt die Felder auf "-" zurück
            return
        }

        Write-Log "Aktualisiere Dashboard-Statistiken..." -Type "Info"
        Update-StatusBar -Message "Lade Dashboard-Statistiken..." -Type "Info"

        # Hilfsfunktion, um UI-Updates sicher im UI-Thread auszuführen
        function Set-StatText($elementName, $value) {
            $element = Get-XamlElement -ElementName $elementName
            if ($null -ne $element) {
                $script:Form.Dispatcher.Invoke([Action]{
                    $element.Text = $value.ToString()
                }) | Out-Null
            }
        }

        # Performance: Alle Empfängertypen mit EINER Abfrage laden und clientseitig gruppieren
        # (statt sechs separater Get-Mailbox/Get-*Group -ResultSize Unlimited Aufrufe).
        try {
            Write-Log "Rufe Empfängerstatistik ab..." -Type "Debug"
            $recipientTypes = @(
                'UserMailbox', 'SharedMailbox', 'RoomMailbox', 'EquipmentMailbox',
                'MailUniversalDistributionGroup', 'MailUniversalSecurityGroup', 'MailNonUniversalGroup',
                'RoomList', 'GroupMailbox'
            )
            if (Get-Command -Name Get-EXORecipient -ErrorAction SilentlyContinue) {
                $recipients = Get-EXORecipient -RecipientTypeDetails $recipientTypes -ResultSize Unlimited -PropertySets Minimum -ErrorAction Stop
            }
            else {
                $recipients = Get-Recipient -RecipientTypeDetails $recipientTypes -ResultSize Unlimited -ErrorAction Stop
            }

            $countByType = @{}
            foreach ($typeGroup in @($recipients | Group-Object -Property RecipientTypeDetails)) {
                $countByType[[string]$typeGroup.Name] = $typeGroup.Count
            }
            $getCount = { param([string[]]$Types) ($Types | ForEach-Object { if ($countByType.ContainsKey($_)) { $countByType[$_] } else { 0 } } | Measure-Object -Sum).Sum }

            Set-StatText "txtStatTotalMailboxes" (& $getCount @('UserMailbox'))
            Set-StatText "txtStatSharedMailboxes" (& $getCount @('SharedMailbox'))
            Set-StatText "txtStatGroups" (& $getCount @('MailUniversalDistributionGroup', 'MailUniversalSecurityGroup', 'MailNonUniversalGroup', 'RoomList', 'GroupMailbox'))
            Set-StatText "txtStatResources" (& $getCount @('RoomMailbox', 'EquipmentMailbox'))
        } catch {
            Write-Log "Fehler beim Abrufen der Empfängerstatistik: $($_.Exception.Message)" -Type "Warning"
            foreach ($statName in @("txtStatTotalMailboxes", "txtStatSharedMailboxes", "txtStatGroups", "txtStatResources")) {
                Set-StatText $statName "Fehler"
            }
        }

        # Domänen abrufen
        try {
            Write-Log "Rufe Domänen ab..." -Type "Debug"
            $count = (Get-AcceptedDomain | Measure-Object).Count
            Set-StatText "txtStatDomains" $count
        } catch {
            Write-Log "Fehler beim Abrufen der Domänen: $($_.Exception.Message)" -Type "Warning"
            Set-StatText "txtStatDomains" "Fehler"
        }

        Update-StatusBar -Message "Dashboard-Statistiken erfolgreich aktualisiert." -Type "Success"
        Write-Log "Dashboard-Statistiken erfolgreich aktualisiert." -Type "Success"

    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_
        Write-Log "Fehler beim Aktualisieren der Dashboard-Statistiken: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Fehler beim Laden der Dashboard-Statistiken." -Type "Error"
        Reset-DashboardStatistics
    }
}
