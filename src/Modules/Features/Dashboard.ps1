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
# Namen der Statistikfelder (TextBlocks) im Dashboard
$script:DashboardStatElementNames = @("txtStatTotalMailboxes", "txtStatSharedMailboxes", "txtStatGroups", "txtStatResources", "txtStatDomains")

# Zeigt einen Wert in einem Dashboard-Statistikfeld an (Zugriff im UI-Thread)
function Show-DashboardStatText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ElementName,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        $Value
    )

    $element = Get-XamlElement -ElementName $ElementName
    if ($null -eq $element) {
        Write-Log "Dashboard-Statistikfeld nicht gefunden: $ElementName" -Type "Debug"
        return
    }
    $text = if ($null -eq $Value) { "-" } else { [string]$Value }
    if ($element.Dispatcher.CheckAccess()) {
        $element.Text = $text
    }
    else {
        $element.Dispatcher.Invoke([Action]{ $element.Text = $text })
    }
}

function Reset-DashboardStatistics {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Setze Dashboard-Statistiken zurück..." -Type "Info"
        Update-StatusBar -Message "Setze Dashboard-Statistiken zurück..." -Type "Info"

        # Statistikfelder auf den Platzhalter "-" setzen
        foreach ($statName in $script:DashboardStatElementNames) {
            Show-DashboardStatText -ElementName $statName -Value "-"
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

        # Performance: Alle Empfängertypen mit EINER Abfrage laden und während des Empfangs zählen
        # (keine Zwischenspeicherung aller Objekte, Fortschrittsanzeige, abbrechbar).
        Start-UIBusy -Message "Lade Dashboard-Statistiken..." -Title "Dashboard" -Cancelable
        try {
            Write-Log "Rufe Empfängerstatistik ab..." -Type "Debug"
            $recipientTypes = @(
                'UserMailbox', 'SharedMailbox', 'RoomMailbox', 'EquipmentMailbox',
                'MailUniversalDistributionGroup', 'MailUniversalSecurityGroup', 'MailNonUniversalGroup',
                'RoomList', 'GroupMailbox'
            )
            $countByType = @{}
            $countRecipient = {
                process {
                    $typeName = [string]$_.RecipientTypeDetails
                    if ($countByType.ContainsKey($typeName)) { $countByType[$typeName]++ } else { $countByType[$typeName] = 1 }
                }
            }
            if (Get-Command -Name Get-EXORecipient -ErrorAction SilentlyContinue) {
                Get-EXORecipient -RecipientTypeDetails $recipientTypes -ResultSize Unlimited -PropertySets Minimum -ErrorAction Stop |
                    Step-UIProgress -Activity "Zähle Empfänger" | & $countRecipient
            }
            else {
                Get-Recipient -RecipientTypeDetails $recipientTypes -ResultSize Unlimited -ErrorAction Stop |
                    Step-UIProgress -Activity "Zähle Empfänger" | & $countRecipient
            }

            $getCount = { param([string[]]$Types) ($Types | ForEach-Object { if ($countByType.ContainsKey($_)) { $countByType[$_] } else { 0 } } | Measure-Object -Sum).Sum }

            Show-DashboardStatText -ElementName "txtStatTotalMailboxes" -Value (& $getCount @('UserMailbox'))
            Show-DashboardStatText -ElementName "txtStatSharedMailboxes" -Value (& $getCount @('SharedMailbox'))
            Show-DashboardStatText -ElementName "txtStatGroups" -Value (& $getCount @('MailUniversalDistributionGroup', 'MailUniversalSecurityGroup', 'MailNonUniversalGroup', 'RoomList', 'GroupMailbox'))
            Show-DashboardStatText -ElementName "txtStatResources" -Value (& $getCount @('RoomMailbox', 'EquipmentMailbox'))
        } catch {
            $statText = if ($script:UICancelRequested) { "Abgebrochen" } else { "Fehler" }
            Write-Log "Empfängerstatistik nicht vollständig abgerufen ($statText): $($_.Exception.Message)" -Type "Warning"
            foreach ($statName in @("txtStatTotalMailboxes", "txtStatSharedMailboxes", "txtStatGroups", "txtStatResources")) {
                Show-DashboardStatText -ElementName $statName -Value $statText
            }
        } finally {
            Stop-UIBusy
        }

        # Domänen abrufen
        try {
            Write-Log "Rufe Domänen ab..." -Type "Debug"
            $count = (Get-AcceptedDomain -ErrorAction Stop | Measure-Object).Count
            Show-DashboardStatText -ElementName "txtStatDomains" -Value $count
        } catch {
            Write-Log "Fehler beim Abrufen der Domänen: $($_.Exception.Message)" -Type "Warning"
            Show-DashboardStatText -ElementName "txtStatDomains" -Value "Fehler"
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
