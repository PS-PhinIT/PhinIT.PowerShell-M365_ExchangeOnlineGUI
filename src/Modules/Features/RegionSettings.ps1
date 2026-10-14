# =====================================================================
# easyEXO - Modul: Sprache, Zeitzone, Datums- und Zeitformate von Postfächern
# Datei: src/Modules/Features/RegionSettings.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# Globale Variable für gültige Datumsformate pro Kultur für Exchange Online
$script:ExchangeValidDateFormats = @{
    "de-DE" = @( # Deutsch (Deutschland)
        @{ Display = "TT.MM.JJJJ (Standard)"; Value = "dd.MM.yyyy" },
        @{ Display = "T.M.JJJJ"; Value = "d.M.yyyy" },
        @{ Display = "TT.MM.JJ"; Value = "dd.MM.yy" },
        @{ Display = "T.M.JJ"; Value = "d.M.yy" },
        @{ Display = "JJJJ-MM-TT (ISO)"; Value = "yyyy-MM-dd" }
    );
    "de-AT" = @( # Deutsch (Österreich)
        @{ Display = "TT.MM.JJJJ (Standard)"; Value = "dd.MM.yyyy" },
        @{ Display = "T.M.JJJJ"; Value = "d.M.yyyy" },
        @{ Display = "JJJJ-MM-TT (ISO)"; Value = "yyyy-MM-dd" }
    );
    "de-CH" = @( # Deutsch (Schweiz)
        @{ Display = "TT.MM.JJJJ (Standard)"; Value = "dd.MM.yyyy" },
        @{ Display = "T.M.JJJJ"; Value = "d.M.yyyy" },
        @{ Display = "JJJJ-MM-TT (ISO)"; Value = "yyyy-MM-dd" }
    );
    "en-US" = @( # Englisch (USA)
        @{ Display = "MM/TT/JJJJ (Standard)"; Value = "MM/dd/yyyy" },
        @{ Display = "M/T/JJJJ"; Value = "M/d/yyyy" },
        @{ Display = "MM/TT/JJ"; Value = "MM/dd/yy" },
        @{ Display = "M/T/JJ"; Value = "M/d/yy" },
        @{ Display = "JJJJ-MM-TT (ISO)"; Value = "yyyy-MM-dd" }
    );
    "en-GB" = @( # Englisch (UK) - Gemäß Ihrer Fehlermeldung
        @{ Display = "TT/MM/JJJJ (Standard)"; Value = "dd/MM/yyyy" },
        @{ Display = "TT/MM/JJ"; Value = "dd/MM/yy" },
        @{ Display = "T/M/JJ"; Value = "d/M/yy" }, # Angepasst an Fehlermeldung (war d/M/yyyy)
        @{ Display = "T.M.JJ"; Value = "d.M.yy" },   # Hinzugefügt gemäß Fehlermeldung
        @{ Display = "JJJJ-MM-TT (ISO)"; Value = "yyyy-MM-dd" }
    );
    "fr-FR" = @( # Französisch (Frankreich)
        @{ Display = "TT/MM/JJJJ (Standard)"; Value = "dd/MM/yyyy" },
        @{ Display = "JJJJ-MM-TT (ISO)"; Value = "yyyy-MM-dd" }
    );
    "fr-CA" = @( # Französisch (Kanada) - Oft JJJJ-MM-TT bevorzugt
        @{ Display = "JJJJ-MM-TT (Standard)"; Value = "yyyy-MM-dd" },
        @{ Display = "TT/MM/JJJJ"; Value = "dd/MM/yyyy" }
    );
    "fr-CH" = @( # Französisch (Schweiz)
        @{ Display = "TT.MM.JJJJ (Standard)"; Value = "dd.MM.yyyy" }, # Punkte statt Schrägstriche
        @{ Display = "JJJJ-MM-TT (ISO)"; Value = "yyyy-MM-dd" }
    );
    "it-IT" = @( # Italienisch (Italien)
        @{ Display = "TT/MM/JJJJ (Standard)"; Value = "dd/MM/yyyy" },
        @{ Display = "JJJJ-MM-TT (ISO)"; Value = "yyyy-MM-dd" }
    );
    "it-CH" = @( # Italienisch (Schweiz)
        @{ Display = "TT.MM.JJJJ (Standard)"; Value = "dd.MM.yyyy" }, # Punkte statt Schrägstriche
        @{ Display = "JJJJ-MM-TT (ISO)"; Value = "yyyy-MM-dd" }
    );
    "pl-PL" = @( # Polnisch (Polen)
        @{ Display = "TT.MM.JJJJ (Standard)"; Value = "dd.MM.yyyy" }, # Punkte als Trennzeichen
        @{ Display = "JJJJ-MM-TT (ISO)"; Value = "yyyy-MM-dd" }
    );
    "es-ES" = @( # Spanisch (Spanien)
        @{ Display = "TT/MM/JJJJ (Standard)"; Value = "dd/MM/yyyy" },
        @{ Display = "JJJJ-MM-TT (ISO)"; Value = "yyyy-MM-dd" }
    );
    "es-MX" = @( # Spanisch (Mexiko) - Ähnlich wie Spanien
        @{ Display = "TT/MM/JJJJ (Standard)"; Value = "dd/MM/yyyy" },
        @{ Display = "JJJJ-MM-TT (ISO)"; Value = "yyyy-MM-dd" }
    );
    "nl-NL" = @( # Niederländisch (Niederlande)
        @{ Display = "T-M-JJJJ (Standard)"; Value = "d-M-yyyy" },
        @{ Display = "TT-MM-JJJJ"; Value = "dd-MM-yyyy" },
        @{ Display = "JJJJ-MM-TT (ISO)"; Value = "yyyy-MM-dd" }
    );
    "nl-BE" = @( # Niederländisch (Belgien)
        @{ Display = "T/M/JJJJ (Standard)"; Value = "d/M/yyyy" }, # Schrägstriche in Belgien
        @{ Display = "TT/MM/JJJJ"; Value = "dd/MM/yyyy" },
        @{ Display = "JJJJ-MM-TT (ISO)"; Value = "yyyy-MM-dd" }
    );
    # Fallback / Standard, falls eine Kultur nicht spezifisch abgedeckt ist
    "DEFAULT" = @(
        @{ Display = "Systemstandard (Keine explizite Auswahl)"; Value = "" }, # Leerer Value für keine Änderung
        @{ Display = "TT.MM.JJJJ"; Value = "dd.MM.yyyy" },
        @{ Display = "MM/TT/JJJJ"; Value = "MM/dd/yyyy" },
        @{ Display = "JJJJ-MM-TT (ISO)"; Value = "yyyy-MM-dd" }
    )
}

# Globale Variable für relevante Zeitformate pro Kultur für Exchange Online
$script:RelevantTimeFormatsPerCulture = @{
    "de-DE" = @( # Deutsch (Deutschland)
        @{ Display = "HH:mm (24h, Standard)"; Value = "HH:mm" },
        @{ Display = "H:mm (24h)"; Value = "H:mm" }
    );
    "de-AT" = @( # Deutsch (Österreich)
        @{ Display = "HH:mm (24h, Standard)"; Value = "HH:mm" },
        @{ Display = "H:mm (24h)"; Value = "H:mm" }
    );
    "de-CH" = @( # Deutsch (Schweiz) - Oft mit Punkt
        @{ Display = "HH.mm (24h, Standard)"; Value = "HH.mm" },
        @{ Display = "H.mm (24h)"; Value = "H.mm" }
    );
    "en-US" = @( # Englisch (USA)
        @{ Display = "h:mm tt (12h AM/PM, Standard)"; Value = "h:mm tt" },
        @{ Display = "hh:mm tt (12h AM/PM)"; Value = "hh:mm tt" },
        @{ Display = "H:mm (24h)"; Value = "H:mm" },
        @{ Display = "HH:mm (24h)"; Value = "HH:mm" }
    );
    "en-GB" = @( # Englisch (UK)
        @{ Display = "HH:mm (24h, Standard)"; Value = "HH:mm" },
        @{ Display = "H:mm (24h)"; Value = "H:mm" },
        @{ Display = "h:mm tt (12h AM/PM)"; Value = "h:mm tt" }
    );
    "fr-FR" = @( # Französisch (Frankreich)
        @{ Display = "HH:mm (24h, Standard)"; Value = "HH:mm" },
        @{ Display = "H:mm (24h)"; Value = "H:mm" }
    );
    "fr-CA" = @( # Französisch (Kanada)
        @{ Display = "HH:mm (24h, Standard)"; Value = "HH:mm" }, # Oft 24h bevorzugt
        @{ Display = "h:mm tt (12h AM/PM)"; Value = "h:mm tt" }
    );
    "fr-CH" = @( # Französisch (Schweiz) - Oft mit Punkt
        @{ Display = "HH.mm (24h, Standard)"; Value = "HH.mm" },
        @{ Display = "H.mm (24h)"; Value = "H.mm" }
    );
    "it-IT" = @( # Italienisch (Italien)
        @{ Display = "HH:mm (24h, Standard)"; Value = "HH:mm" },
        @{ Display = "H:mm (24h)"; Value = "H:mm" }
    );
    "it-CH" = @( # Italienisch (Schweiz) - Oft mit Punkt
        @{ Display = "HH.mm (24h, Standard)"; Value = "HH.mm" },
        @{ Display = "H.mm (24h)"; Value = "H.mm" }
    );
    "pl-PL" = @( # Polnisch (Polen)
        @{ Display = "HH:mm (24h, Standard)"; Value = "HH:mm" },
        @{ Display = "H:mm (24h)"; Value = "H:mm" }
    );
    "es-ES" = @( # Spanisch (Spanien)
        @{ Display = "H:mm (24h, Standard)"; Value = "H:mm" }, # Kann auch HH:mm sein
        @{ Display = "HH:mm (24h)"; Value = "HH:mm" }
    );
    "es-MX" = @( # Spanisch (Mexiko)
        @{ Display = "h:mm tt (12h AM/PM, Standard)"; Value = "h:mm tt" },
        @{ Display = "HH:mm (24h)"; Value = "HH:mm" }
    );
    "nl-NL" = @( # Niederländisch (Niederlande)
        @{ Display = "H:mm (24h, Standard)"; Value = "H:mm" }, # Oder HH:mm
        @{ Display = "HH:mm (24h)"; Value = "HH:mm" }
    );
    "nl-BE" = @( # Niederländisch (Belgien)
        @{ Display = "H:mm (24h, Standard)"; Value = "H:mm" }, # Oder HH:mm
        @{ Display = "HH:mm (24h)"; Value = "HH:mm" }
    );
    "DEFAULT" = @( # Allgemeine Fallbacks, wenn keine spezifische Kultur passt
        @{ Display = "Systemstandard (Keine explizite Auswahl)"; Value = "" },
        @{ Display = "HH:mm (24h)"; Value = "HH:mm" },
        @{ Display = "h:mm tt (12h AM/PM)"; Value = "h:mm tt" }
    )
}

# Globale Variable für relevante Zeitzonen-IDs pro Kultur für Exchange Online
$script:RelevantTimezonesPerCulture = @{
    "de-DE" = @("W. Europe Standard Time", "Central European Standard Time"); # Berlin, Amsterdam, Paris, Rome
    "de-AT" = @("W. Europe Standard Time", "Central European Standard Time", "Romance Standard Time"); # Vienna
    "de-CH" = @("W. Europe Standard Time", "Central European Standard Time", "Romance Standard Time"); # Bern, Zurich
    "en-US" = @("Pacific Standard Time", "Mountain Standard Time", "Central Standard Time", "Eastern Standard Time", "Alaskan Standard Time", "Hawaiian Standard Time");
    "en-GB" = @("GMT Standard Time", "Greenwich Standard Time"); # London, Dublin
    "fr-FR" = @("Romance Standard Time", "Central European Standard Time"); # Paris
    "fr-CA" = @("Eastern Standard Time", "Central Standard Time", "Mountain Standard Time", "Pacific Standard Time", "Newfoundland Standard Time", "Atlantic Standard Time"); # Canada
    "fr-CH" = @("W. Europe Standard Time", "Central European Standard Time", "Romance Standard Time"); # Geneva
    "it-IT" = @("W. Europe Standard Time", "Central European Standard Time", "Romance Standard Time"); # Rome
    "it-CH" = @("W. Europe Standard Time", "Central European Standard Time", "Romance Standard Time"); # Italian-speaking Switzerland
    "pl-PL" = @("Central European Standard Time"); # Warsaw
    "es-ES" = @("Romance Standard Time", "Central European Standard Time"); # Madrid
    "es-MX" = @("Central Standard Time (Mexico)", "Mountain Standard Time (Mexico)", "Pacific Standard Time (Mexico)"); # Mexico City, Chihuahua, Tijuana
    "nl-NL" = @("W. Europe Standard Time", "Central European Standard Time", "Romance Standard Time"); # Amsterdam
    "nl-BE" = @("W. Europe Standard Time", "Central European Standard Time", "Romance Standard Time"); # Brussels
    # Fallback für nicht explizit gemappte Kulturen - hier könnten alle Zeitzonen geladen werden oder eine Auswahl häufiger
    "DEFAULT_ALL" = $true # Ein Flag, um alle Zeitzonen zu laden, wenn keine spezifische Kultur passt
    # Oder eine kleinere Default-Liste:
    # "DEFAULT" = @("UTC", "GMT Standard Time", "W. Europe Standard Time", "Central European Standard Time", "Eastern Standard Time", "Pacific Standard Time")
}

# Funktion zur Ausführung der Aktion "Regionaleinstellungen anwenden"
function Invoke-SetRegionSettingsAction {
    [CmdletBinding()]
    param()

    # Prüfen, ob verbunden
    if (-not (Confirm-ExchangeConnection)) {
        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Nicht verbunden"
        return
    }

    # Werte aus der GUI holen
    $mailboxInput = $script:txtRegionMailbox.Text.Trim()
    $selectedLanguageItem = $script:cmbRegionLanguage.SelectedItem
    $selectedTimezoneItem = $script:cmbRegionTimezone.SelectedItem
    $selectedDateFormatItem = $script:cmbRegionDateFormat.SelectedItem   # NEU
    $selectedTimeFormatItem = $script:cmbRegionTimeFormat.SelectedItem   # NEU
    $localizeFoldersState = $script:chkRegionDefaultFolderNameMatchingUserLanguage.IsChecked # NEU ($true, $false, oder $null)
    $statusTextBlock = $script:txtStatus

    # Postfach-Eingabe validieren
    if ([string]::IsNullOrWhiteSpace($mailboxInput)) {
        Show-MessageBox -Message "Bitte geben Sie mindestens eine Postfach-Identität an oder 'ALL'." -Title "Eingabe fehlt"
        return
    }

    # Parameter für Set-MailboxRegionalConfiguration zusammenstellen
    $params = @{}
    $displayParams = @{} # Für Bestätigungsdialog

    # Sprache prüfen
    if ($null -ne $selectedLanguageItem -and $null -ne $selectedLanguageItem.Tag -and $selectedLanguageItem.Tag -ne "") {
        $params.Add("Language", $selectedLanguageItem.Tag)
        $displayParams.Add("Sprache", "$($selectedLanguageItem.Content) ($($selectedLanguageItem.Tag))")
        Write-Log "Ausgewählte Sprache: $($selectedLanguageItem.Content) ($($selectedLanguageItem.Tag))" -Type Debug
    } else {
        $displayParams.Add("Sprache", "(Keine Änderung)")
        Write-Log "Keine Sprache zur Änderung ausgewählt." -Type Debug
    }

    # Zeitzone prüfen
    # Wichtig: Wenn cmbRegionTimezone IsEditable="True", kann SelectedItem null sein, auch wenn Text vorhanden ist.
    # Wir verlassen uns hier auf den Tag, wenn ein Item ausgewählt ist.
    # Wenn der Benutzer Text eingibt, der keinem Item entspricht, wird dieser nicht automatisch übernommen.
    # Eine robustere Lösung müsste den Text der ComboBox auswerten, wenn SelectedItem null ist.
    # Fürs Erste gehen wir davon aus, dass der Benutzer ein Item auswählt oder "Keine Änderung" belässt.
    if ($null -ne $selectedTimezoneItem -and $null -ne $selectedTimezoneItem.Tag -and $selectedTimezoneItem.Tag -ne "") {
        $params.Add("TimeZone", $selectedTimezoneItem.Tag)
        $displayParams.Add("Zeitzone", "$($selectedTimezoneItem.Content) ($($selectedTimezoneItem.Tag))")
        Write-Log "Ausgewählte Zeitzone: $($selectedTimezoneItem.Content) ($($selectedTimezoneItem.Tag))" -Type Debug
    } elseif (($null -eq $selectedTimezoneItem) -and (-not [string]::IsNullOrWhiteSpace($script:cmbRegionTimezone.Text)) -and ($script:cmbRegionTimezone.Text -ne "(Keine Änderung)")) {
        # Fall: Editierbare ComboBox mit Texteingabe, die keinem Item entspricht
        # Versuche, die Eingabe direkt als Zeitzonen-ID zu verwenden.
        # Get-TimeZone -ListAvailable könnte hier zur Validierung verwendet werden, ist aber aufwändig.
        # Wir übergeben es erstmal so, Set-MailboxRegionalConfiguration wird ggf. einen Fehler werfen.
        $timeZoneText = $script:cmbRegionTimezone.Text.Trim()
        if ($timeZoneText) { # Sicherstellen, dass es nicht nur Whitespace ist
            $params.Add("TimeZone", $timeZoneText)
            $displayParams.Add("Zeitzone", "$timeZoneText (Manuelle Eingabe)")
            Write-Log "Ausgewählte Zeitzone (manuelle Eingabe): $timeZoneText" -Type Debug
        } else {
            $displayParams.Add("Zeitzone", "(Keine Änderung)")
            Write-Log "Keine Zeitzone zur Änderung ausgewählt (manuelle Eingabe war leer oder nur Leerzeichen)." -Type Debug
        }
    } else {
        $displayParams.Add("Zeitzone", "(Keine Änderung)")
        Write-Log "Keine Zeitzone zur Änderung ausgewählt." -Type Debug
    }
    
    # Datumsformat prüfen
    if ($null -ne $selectedDateFormatItem -and $null -ne $selectedDateFormatItem.Tag -and $selectedDateFormatItem.Tag -ne "") {
        $params.Add("DateFormat", $selectedDateFormatItem.Tag)
        $displayParams.Add("Datumsformat", "$($selectedDateFormatItem.Content) ($($selectedDateFormatItem.Tag))")
        Write-Log "Ausgewähltes Datumsformat: $($selectedDateFormatItem.Content) ($($selectedDateFormatItem.Tag))" -Type Debug
    } else {
        $displayParams.Add("Datumsformat", "(Keine Änderung)")
        Write-Log "Kein Datumsformat zur Änderung ausgewählt." -Type Debug
    }

    # Zeitformat prüfen
    if ($null -ne $selectedTimeFormatItem -and $null -ne $selectedTimeFormatItem.Tag -and $selectedTimeFormatItem.Tag -ne "") {
        $params.Add("TimeFormat", $selectedTimeFormatItem.Tag)
        $displayParams.Add("Zeitformat", "$($selectedTimeFormatItem.Content) ($($selectedTimeFormatItem.Tag))")
        Write-Log "Ausgewähltes Zeitformat: $($selectedTimeFormatItem.Content) ($($selectedTimeFormatItem.Tag))" -Type Debug
    } else {
        $displayParams.Add("Zeitformat", "(Keine Änderung)")
        Write-Log "Kein Zeitformat zur Änderung ausgewählt." -Type Debug
    }

    # Standardordnernamen anpassen (LocalizeDefaultFolderName)
    if ($null -ne $localizeFoldersState) { # Nur wenn CheckBox nicht im unbestimmten Zustand ist
        $params.Add("LocalizeDefaultFolderName", $localizeFoldersState) # $true oder $false
        $localizeDisplayValue = if ($localizeFoldersState) { "Ja" } else { "Nein" }
        $displayParams.Add("Ordnernamen anpassen", $localizeDisplayValue)
        Write-Log "Ausgewählte Option für Ordnernamen anpassen: $localizeDisplayValue (Wert: $localizeFoldersState)" -Type Debug
    } else {
        $displayParams.Add("Ordnernamen anpassen", "(Keine Änderung)")
        Write-Log "Keine Änderung für 'Ordnernamen anpassen' ausgewählt." -Type Debug
    }

    # Prüfen, ob mindestens eine Einstellung geändert werden soll
    if ($params.Count -eq 0) {
        Show-MessageBox -Message "Bitte wählen Sie mindestens eine Einstellung (Sprache, Zeitzone, Datumsformat, Zeitformat, Ordnernamen anpassen) zur Änderung aus." -Title "Keine Auswahl"
        return
    }

    # Zusammenfassung der gewählten Einstellungen für die Bestätigung
    $settingsSummary = "Sprache: $($displayParams.Sprache)`n"
    $settingsSummary += "Zeitzone: $($displayParams.Zeitzone)`n"
    $settingsSummary += "Datumsformat: $($displayParams.Datumsformat)`n"
    $settingsSummary += "Zeitformat: $($displayParams.Zeitformat)`n"
    $settingsSummary += "Ordnernamen anpassen: $($displayParams.'Ordnernamen anpassen')"

    # Zielpostfächer ermitteln und die Änderung in jedem Fall bestätigen lassen
    $isAllMailboxes = $mailboxInput -eq 'ALL'
    $targetMailboxes = @()
    if ($isAllMailboxes) {
        $confirmMessage = "WARNUNG: Sie sind dabei, die regionalen Einstellungen für ALLE Benutzerpostfächer zu ändern.`n`n"
        $confirmMessage += "$settingsSummary`n"
        $confirmMessage += "`nDies kann sehr lange dauern und sollte mit Vorsicht verwendet werden.`n`n"
        $confirmMessage += "Möchten Sie wirklich fortfahren?"
        $confirmResult = Show-MessageBox -Message $confirmMessage -Title "Bestätigung erforderlich" -Type "Question" -Icon "Warning"
    } else {
        $targetMailboxes = @($mailboxInput -split ';' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($targetMailboxes.Count -eq 0) {
            $null = Show-MessageBox -Message "Keine gültigen Postfach-Identitäten angegeben oder gefunden." -Title "Keine Postfächer"
            Update-GuiText -TextElement $statusTextBlock -Message "Keine gültigen Postfächer zur Verarbeitung angegeben."
            Log-Action "Keine gültigen Postfächer zur Verarbeitung angegeben für '$mailboxInput'."
            return
        }

        $mailboxPreview = @($targetMailboxes | Select-Object -First 10)
        $mailboxListText = ($mailboxPreview | ForEach-Object { "  - $_" }) -join "`n"
        if ($targetMailboxes.Count -gt $mailboxPreview.Count) {
            $mailboxListText += "`n  ... und $($targetMailboxes.Count - $mailboxPreview.Count) weitere"
        }
        $confirmMessage = "Die regionalen Einstellungen werden für $($targetMailboxes.Count) Postfach/Postfächer geändert:`n$mailboxListText`n`n"
        $confirmMessage += "$settingsSummary`n`n"
        $confirmMessage += "Möchten Sie fortfahren?"
        $confirmResult = Show-MessageBox -Message $confirmMessage -Title "Bestätigung erforderlich" -Type "Question"
    }

    if ($confirmResult -ne 'Yes') {
        Update-GuiText -TextElement $statusTextBlock -Message "Vorgang abgebrochen."
        Log-Action "Anwendung der regionalen Einstellungen für '$mailboxInput' abgebrochen."
        return
    }

    if ($isAllMailboxes) {
        Update-GuiText -TextElement $statusTextBlock -Message "Rufe alle Benutzerpostfächer ab (kann dauern)..."
        Log-Action "Beginne Abruf aller Benutzerpostfächer für Regionaleinstellungen-Änderung."

        $retrievalError = $null
        $retrievalCancelled = $false
        Start-UIBusy -Message "Rufe alle Benutzerpostfächer ab (kann dauern)..." -Title "Regionaleinstellungen" -Cancelable
        try {
            # PrimarySmtpAddress ist eindeutig und wird von Set-MailboxRegionalConfiguration als Identity akzeptiert
            $targetMailboxes = @(Get-Mailbox -RecipientTypeDetails UserMailbox -ResultSize Unlimited -ErrorAction Stop |
                Step-UIProgress -Activity "Rufe Benutzerpostfächer ab" |
                ForEach-Object { [string]$_.PrimarySmtpAddress } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        } catch {
            $retrievalCancelled = $script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException]
            $retrievalError = $_
        } finally {
            Stop-UIBusy
        }

        if ($retrievalCancelled) {
            Update-GuiText -TextElement $statusTextBlock -Message "Abruf der Postfächer abgebrochen. Es wurden keine Einstellungen geändert."
            Log-Action "Abruf aller Benutzerpostfächer für Regionaleinstellungen abgebrochen."
            return
        }
        if ($null -ne $retrievalError) {
            $errorMsg = Get-FormattedError -ErrorRecord $retrievalError -DefaultText "Fehler beim Abrufen aller Postfächer."
            $null = Show-MessageBox -Message "Fehler beim Abrufen der Postfächer für 'ALL':`n$errorMsg" -Title "Fehler" -Type "Error"
            Update-GuiText -TextElement $statusTextBlock -Message "Fehler beim Abrufen der Postfächer."
            Log-Action "Fehler beim Abrufen aller Postfächer: $errorMsg"
            return
        }
        if ($targetMailboxes.Count -eq 0) {
            $null = Show-MessageBox -Message "Keine Benutzerpostfächer gefunden." -Title "Keine Postfächer"
            Update-GuiText -TextElement $statusTextBlock -Message "Keine Benutzerpostfächer für 'ALL' gefunden."
            Log-Action "Keine Benutzerpostfächer für 'ALL' gefunden."
            return
        }
        Update-GuiText -TextElement $statusTextBlock -Message "$($targetMailboxes.Count) Postfächer gefunden. Starte Änderungen..."
        Log-Action "$($targetMailboxes.Count) Postfächer für 'ALL' gefunden."
    }

    Update-GuiText -TextElement $statusTextBlock -Message "Starte Verarbeitung von $($targetMailboxes.Count) Postfach/Postfächern..."
    Log-Action "Starte Set-ExoMailboxRegionalSettings für $($targetMailboxes.Count) Postfächer mit Parametern: $($params.Keys -join ', ')"

    try {
        Start-UIBusy -Message "Wende Regionaleinstellungen an..." -Title "Regionaleinstellungen" -Cancelable
        try {
            $OperationResult = Set-ExoMailboxRegionalSettings -MailboxesToProcess $targetMailboxes -Parameters $params -StatusTextBlock $statusTextBlock
        } finally {
            Stop-UIBusy
        }

        $successCount = $OperationResult.Success.Count
        $failedCount = $OperationResult.Failed.Count
        $warningCount = $OperationResult.Warnings.Count
        $totalCount = $targetMailboxes.Count
        $notProcessedCount = $totalCount - $successCount - $failedCount

        $summaryMessage = "Regionaleinstellungen verarbeitet: $successCount erfolgreich, $failedCount fehlgeschlagen (von $totalCount)."
        if ($warningCount -gt 0) {
            $summaryMessage += " $warningCount Postfach/Postfächer mit Hinweisen von Exchange."
        }
        if ($OperationResult.Cancelled) {
            $summaryMessage += " Vorgang abgebrochen - $notProcessedCount Postfach/Postfächer nicht verarbeitet."
        }
        Update-GuiText -TextElement $statusTextBlock -Message $summaryMessage
        Log-Action $summaryMessage

        $errorDetailsString = Format-RegionSettingsResultDetail -Entries $OperationResult.Failed -TextProperty "Error"
        $warningDetailsString = Format-RegionSettingsResultDetail -Entries $OperationResult.Warnings -TextProperty "Warning"
        if ($warningCount -gt 0) {
            Log-Action "Hinweise Regionaleinstellungen: $($OperationResult.Warnings | ConvertTo-Json -Depth 3)"
        }

        if ($failedCount -gt 0) {
            $resultText = "$summaryMessage`n`nFehler bei Verarbeitung:`n$errorDetailsString"
            if ($warningCount -gt 0) { $resultText += "`n`nHinweise von Exchange:`n$warningDetailsString" }
            if ($null -ne $script:txtRegionResult) { $script:txtRegionResult.Text = $resultText }

            $null = Show-MessageBox -Message "Einige regionale Einstellungen konnten nicht angewendet werden:`n$errorDetailsString" -Title "Fehler bei Verarbeitung" -Type "Warning"
            Log-Action "Fehlerdetails Regionaleinstellungen: $($OperationResult.Failed | ConvertTo-Json -Depth 3)"
        } elseif ($successCount -gt 0) {
            $resultText = "$successCount Postfach/Postfächer erfolgreich aktualisiert."
            if ($OperationResult.Cancelled) { $resultText += "`nVorgang abgebrochen - $notProcessedCount Postfach/Postfächer nicht verarbeitet." }
            if ($warningCount -gt 0) { $resultText += "`n`nHinweise von Exchange:`n$warningDetailsString" }
            if ($null -ne $script:txtRegionResult) { $script:txtRegionResult.Text = $resultText }
            $null = Show-MessageBox -Message $resultText -Title "Erfolg"
        } else { # Weder Fehler noch Erfolg (z.B. sofort abgebrochen)
            $resultText = if ($OperationResult.Cancelled) { "Vorgang abgebrochen. Es wurden keine Einstellungen geändert." } else { "Keine Änderungen vorgenommen oder alle Operationen fehlgeschlagen/übersprungen." }
            if ($null -ne $script:txtRegionResult) { $script:txtRegionResult.Text = $resultText }
            $null = Show-MessageBox -Message $resultText -Title "Information"
        }
    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Schwerwiegender Fehler beim direkten Anwenden der regionalen Einstellungen."
        Update-GuiText -TextElement $statusTextBlock -Message "Fehler: $errorMsg"
        Log-Action "FEHLER beim direkten Anwenden der regionalen Einstellungen: $errorMsg"
        if ($null -ne $script:txtRegionResult) {
            $script:txtRegionResult.Text = "Fehler: $errorMsg"
        }
        $null = Show-MessageBox -Message "Ein schwerwiegender Fehler ist aufgetreten:`n$errorMsg" -Title "Fehler" -Type "Error"
    }
}

# Ende Invoke-SetRegionSettingsAction

# Fasst Fehler- bzw. Hinweiseinträge ("Postfach: Text") für Anzeige und Meldung zusammen (max. 10 Zeilen).
function Format-RegionSettingsResultDetail {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object[]]$Entries,

        [Parameter(Mandatory = $true)]
        [string]$TextProperty,

        [int]$MaxLines = 10
    )

    $lines = @($Entries | Where-Object { $null -ne $_ } | ForEach-Object { "  - $($_.Mailbox): $($_[$TextProperty])" })
    if ($lines.Count -eq 0) { return "" }
    $text = (@($lines | Select-Object -First $MaxLines)) -join "`n"
    if ($lines.Count -gt $MaxLines) {
        $text += "`n  ... (weitere Einträge im Log)"
    }
    return $text
}

# Funktion zur Ausführung der Aktion "Aktuelle Einstellungen abrufen"
function Invoke-GetRegionSettingsAction {
    [CmdletBinding()]
    param()

    if (-not (Confirm-ExchangeConnection)) {
        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Nicht verbunden"
        return
    }

    # KORREKTUR: Richtige Referenz auf das XAML-Element txtGetRegionMailbox
    $mailboxId = $script:txtGetRegionMailbox.Text.Trim()
    $statusTextBlock = $script:txtStatus
    $resultTextBlock = $script:txtRegionResult
    
    $languageComboBox = $script:cmbRegionLanguage
    $timezoneComboBox = $script:cmbRegionTimezone
    $dateFormatComboBox = $script:cmbRegionDateFormat
    $timeFormatComboBox = $script:cmbRegionTimeFormat
    $localizeFoldersCheckBox = $script:chkRegionDefaultFolderNameMatchingUserLanguage

    # Validierung der Postfach-Eingabe
    if ([string]::IsNullOrWhiteSpace($mailboxId)) {
        Show-MessageBox -Message "Bitte geben Sie die E-Mail-Adresse des Postfachs an, dessen Einstellungen abgerufen werden sollen." -Title "Eingabe fehlt"
        return
    }
    if ($mailboxId -eq 'ALL') {
        Show-MessageBox -Message "Bitte geben Sie eine einzelne Postfach-Identität zum Abrufen an (nicht 'ALL')." -Title "Ungültige Eingabe"
        return
    }

    Update-GuiText -TextElement $statusTextBlock -Message "Rufe regionale Einstellungen für '$mailboxId' ab..."
    Log-Action "Starte Get-ExoMailboxRegionalSettings für '$mailboxId'."

    if ($null -ne $resultTextBlock) {
        $resultTextBlock.Dispatcher.Invoke({ $resultTextBlock.Text = "" }) | Out-Null
    }

    try {
        $OperationResult = Get-ExoMailboxRegionalSettings -MailboxIdentity $mailboxId
        
        Write-Log ("Get-ExoMailboxRegionalSettings OperationResult für '$mailboxId': " + ($OperationResult | ConvertTo-Json -Depth 4)) -Type Debug

        if ($OperationResult.Success) {
            $regionalSettings = $OperationResult.Result 
            
            if ($null -eq $regionalSettings) {
                $noDataMessage = "Abruf für '$mailboxId' erfolgreich, aber keine Einstellungsdaten (regionalSettings ist null) zurückgegeben."
                Update-GuiText -TextElement $statusTextBlock -Message $noDataMessage
                Log-Action $noDataMessage
                if ($null -ne $resultTextBlock) {
                    $resultTextBlock.Dispatcher.Invoke({ $resultTextBlock.Text = "Keine Einstellungsdaten für '$mailboxId' empfangen." }) | Out-Null
                }
                
                # UI-Reset bei Null-Ergebnis
                try {
                    if ($null -ne $languageComboBox) { 
                        $languageComboBox.Dispatcher.Invoke({ 
                            $languageComboBox.SelectedItem = ($languageComboBox.Items | Where-Object {$_.Tag -eq ""} | Select-Object -First 1) 
                        }) | Out-Null 
                    }
                    Populate-DateFormatComboBox -ComboBox $dateFormatComboBox -CultureName "" 
                    Populate-TimeFormatComboBox -ComboBox $timeFormatComboBox -CultureName ""
                    Populate-TimezoneComboBox -ComboBox $timezoneComboBox -CultureName "DEFAULT_ALL" 
                    if ($null -ne $localizeFoldersCheckBox) { 
                        $localizeFoldersCheckBox.Dispatcher.Invoke({ $localizeFoldersCheckBox.IsChecked = $null }) | Out-Null 
                    }
                } catch { 
                    Write-Log "Fehler beim Zurücksetzen der UI nach Null-Ergebnis (GetRegion): $($_.Exception.Message)" -Type Warning 
                }

            } else {
                $retrievedIdentity = $mailboxId 
                if ($regionalSettings.PSObject.Properties['Identity'] -and $null -ne $regionalSettings.Identity) {
                    $retrievedIdentity = $regionalSettings.Identity.ToString() 
                } elseif ($regionalSettings.PSObject.Properties['DistinguishedName'] -and $null -ne $regionalSettings.DistinguishedName) {
                    $retrievedIdentity = $regionalSettings.DistinguishedName.ToString()
                }
                
                $statusMsg = "Regionale Einstellungen für '$retrievedIdentity' erfolgreich abgerufen."
                Update-GuiText -TextElement $statusTextBlock -Message "Abruf erfolgreich. Aktualisiere UI..." 
                Log-Action $statusMsg

                $currentCultureForUI = ""

                # Sprache setzen
                if ($null -ne $regionalSettings.Language) {
                    $langCodeToSelect = $regionalSettings.Language.ToString()
                    $langItem = $languageComboBox.Items | Where-Object { $_.Tag -eq $langCodeToSelect } | Select-Object -First 1
                    if ($null -ne $langItem) {
                        $languageComboBox.Dispatcher.Invoke({ $languageComboBox.SelectedItem = $langItem }) | Out-Null
                        $currentCultureForUI = $langCodeToSelect 
                    } else {
                        $languageComboBox.Dispatcher.Invoke({ 
                            $languageComboBox.SelectedItem = ($languageComboBox.Items | Where-Object {$_.Tag -eq ""} | Select-Object -First 1) 
                        }) | Out-Null
                    }
                } else {
                     $languageComboBox.Dispatcher.Invoke({ 
                         $languageComboBox.SelectedItem = ($languageComboBox.Items | Where-Object {$_.Tag -eq ""} | Select-Object -First 1) 
                     }) | Out-Null
                }
                
                # Formate und Zeitzonen basierend auf der gesetzten Sprache laden
                Populate-DateFormatComboBox -ComboBox $dateFormatComboBox -CultureName $currentCultureForUI
                Populate-TimeFormatComboBox -ComboBox $timeFormatComboBox -CultureName $currentCultureForUI
                Populate-TimezoneComboBox -ComboBox $timezoneComboBox -CultureName $currentCultureForUI 
                
                # Datumsformat setzen
                if ($null -ne $regionalSettings.DateFormat) {
                    $dateFormatToSelect = $regionalSettings.DateFormat.ToString()
                    $dateItem = $dateFormatComboBox.Items | Where-Object { $_.Tag -eq $dateFormatToSelect } | Select-Object -First 1
                    if ($null -ne $dateItem) {
                        $dateFormatComboBox.Dispatcher.Invoke({ $dateFormatComboBox.SelectedItem = $dateItem }) | Out-Null
                    } else {
                        $dateFormatComboBox.Dispatcher.Invoke({ 
                            $dateFormatComboBox.SelectedItem = ($dateFormatComboBox.Items | Where-Object {$_.Tag -eq ""} | Select-Object -First 1) 
                        }) | Out-Null
                    }
                } else {
                     $dateFormatComboBox.Dispatcher.Invoke({ 
                         $dateFormatComboBox.SelectedItem = ($dateFormatComboBox.Items | Where-Object {$_.Tag -eq ""} | Select-Object -First 1) 
                     }) | Out-Null
                }
                
                # Zeitformat setzen
                if ($null -ne $regionalSettings.TimeFormat) {
                    $timeFormatToSelect = $regionalSettings.TimeFormat.ToString()
                    $timeItem = $timeFormatComboBox.Items | Where-Object { $_.Tag -eq $timeFormatToSelect } | Select-Object -First 1
                    if ($null -ne $timeItem) {
                        $timeFormatComboBox.Dispatcher.Invoke({ $timeFormatComboBox.SelectedItem = $timeItem }) | Out-Null
                        Write-Log "Zeitformat '$timeFormatToSelect' in UI ausgewählt." -Type Debug
                    } else {
                        Write-Log "Abgerufenes Zeitformat '$timeFormatToSelect' nicht in UI-Liste für Kultur '$currentCultureForUI'. (Keine Änderung) bleibt." -Type Warning
                        $timeFormatComboBox.Dispatcher.Invoke({ 
                            $timeFormatComboBox.SelectedItem = ($timeFormatComboBox.Items | Where-Object {$_.Tag -eq ""} | Select-Object -First 1) 
                        }) | Out-Null
                    }
                } else {
                     Write-Log "Kein Zeitformat von Exchange empfangen. UI bleibt auf (Keine Änderung)." -Type Debug
                     $timeFormatComboBox.Dispatcher.Invoke({ 
                         $timeFormatComboBox.SelectedItem = ($timeFormatComboBox.Items | Where-Object {$_.Tag -eq ""} | Select-Object -First 1) 
                     }) | Out-Null
                }

                # Zeitzone setzen
                if ($null -ne $regionalSettings.TimeZone) {
                    $timeZoneToSelect = $regionalSettings.TimeZone.ToString()
                    $tzItem = $timezoneComboBox.Items | Where-Object { $_.Tag -eq $timeZoneToSelect } | Select-Object -First 1
                    if ($null -ne $tzItem) {
                        $timezoneComboBox.Dispatcher.Invoke({ $timezoneComboBox.SelectedItem = $tzItem }) | Out-Null
                    } else {
                         $timezoneComboBox.Dispatcher.Invoke({ 
                             $timezoneComboBox.SelectedItem = ($timezoneComboBox.Items | Where-Object {$_.Tag -eq ""} | Select-Object -First 1) 
                         }) | Out-Null
                    }
                } else {
                     $timezoneComboBox.Dispatcher.Invoke({ 
                         $timezoneComboBox.SelectedItem = ($timezoneComboBox.Items | Where-Object {$_.Tag -eq ""} | Select-Object -First 1) 
                     }) | Out-Null
                }
                
                # Ordnernamen-Status setzen (Get-MailboxRegionalConfiguration liefert DefaultFolderNameMatchingUserLanguage)
                if (($regionalSettings.PSObject.Properties.Name -contains "DefaultFolderNameMatchingUserLanguage") -and 
                    $null -ne $regionalSettings.DefaultFolderNameMatchingUserLanguage) {
                    $localizeValue = $regionalSettings.DefaultFolderNameMatchingUserLanguage
                    if ($localizeValue -is [bool]) {
                        $localizeFoldersCheckBox.Dispatcher.Invoke({ $localizeFoldersCheckBox.IsChecked = $localizeValue }) | Out-Null
                    } else {
                        $localizeFoldersCheckBox.Dispatcher.Invoke({ $localizeFoldersCheckBox.IsChecked = $null }) | Out-Null 
                    }
                } else {
                    $localizeFoldersCheckBox.Dispatcher.Invoke({ $localizeFoldersCheckBox.IsChecked = $null }) | Out-Null
                }

                # Verbesserte Ergebnis-Anzeige in der ResultBox
                if ($null -ne $resultTextBlock) {
                    $resultOutput = "Aktuelle regionale Einstellungen für: $retrievedIdentity`n"
                    $resultOutput += "=" * 60 + "`n`n"
                    
                    # Strukturierte Darstellung der Einstellungen
                    $resultOutput += "SPRACH- UND REGIONALE EINSTELLUNGEN:`n"
                    $resultOutput += "-" * 40 + "`n"
                    
                    # Sprache
                    if ($null -ne $regionalSettings.Language) {
                        $languageDisplay = $regionalSettings.Language.ToString()
                        # Versuche, den Anzeigenamen der Sprache zu finden
                        try {
                            $culture = [System.Globalization.CultureInfo]::new($regionalSettings.Language.ToString())
                            $languageDisplay = "$($culture.DisplayName) ($($regionalSettings.Language))"
                        } catch {
                            $languageDisplay = $regionalSettings.Language.ToString()
                        }
                        $resultOutput += "Sprache:        $languageDisplay`n"
                    } else {
                        $resultOutput += "Sprache:        (Nicht festgelegt)`n"
                    }
                    
                    # Zeitzone
                    if ($null -ne $regionalSettings.TimeZone) {
                        $timezoneDisplay = $regionalSettings.TimeZone.ToString()
                        # Versuche, zusätzliche Timezone-Info zu bekommen
                        try {
                            $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById($regionalSettings.TimeZone.ToString())
                            $timezoneDisplay = "$($tz.DisplayName) ($($regionalSettings.TimeZone))"
                        } catch {
                            $timezoneDisplay = $regionalSettings.TimeZone.ToString()
                        }
                        $resultOutput += "Zeitzone:       $timezoneDisplay`n"
                    } else {
                        $resultOutput += "Zeitzone:       (Nicht festgelegt)`n"
                    }
                    
                    # Datumsformat
                    if ($null -ne $regionalSettings.DateFormat) {
                        $resultOutput += "Datumsformat:   $($regionalSettings.DateFormat)`n"
                    } else {
                        $resultOutput += "Datumsformat:   (Nicht festgelegt)`n"
                    }
                    
                    # Zeitformat
                    if ($null -ne $regionalSettings.TimeFormat) {
                        $resultOutput += "Zeitformat:     $($regionalSettings.TimeFormat)`n"
                    } else {
                        $resultOutput += "Zeitformat:     (Nicht festgelegt)`n"
                    }
                    
                    # Ordnernamen in Benutzersprache (DefaultFolderNameMatchingUserLanguage)
                    $localizeDisplay = "Unbekannt"
                    if (($regionalSettings.PSObject.Properties.Name -contains "DefaultFolderNameMatchingUserLanguage") -and 
                        $null -ne $regionalSettings.DefaultFolderNameMatchingUserLanguage) {
                        $localizeDisplay = if ($regionalSettings.DefaultFolderNameMatchingUserLanguage -eq $true) { "Ja" } else { "Nein" }
                    } else {
                        $localizeDisplay = "(Nicht ermittelbar)"
                    }
                    $resultOutput += "Ordnernamen in Benutzersprache: $localizeDisplay`n"
                    
                    $resultOutput += "`n" + "=" * 60 + "`n"
                    $resultOutput += "TECHNISCHE DETAILS:`n"
                    $resultOutput += "-" * 20 + "`n"
                    
                    # Weitere technische Eigenschaften anzeigen
                    $technicalProps = @("Identity", "DistinguishedName", "Guid", "ObjectCategory", "WhenCreated", "WhenChanged")
                    foreach ($prop in $technicalProps) {
                        if ($regionalSettings.PSObject.Properties.Name -contains $prop -and $null -ne $regionalSettings.$prop) {
                            $resultOutput += "${prop}: $($regionalSettings.$prop)`n"
                        }
                    }
                    
                    # Den zusammengestellten Text in die TextBox schreiben
                    $resultTextBlock.Dispatcher.Invoke({ $resultTextBlock.Text = $resultOutput }) | Out-Null
                }
                Update-GuiText -TextElement $statusTextBlock -Message $statusMsg
            }
        } else {
            $errorMsg = $OperationResult.Error
            Update-GuiText -TextElement $statusTextBlock -Message "Fehler beim Abrufen der Einstellungen."
            Log-Action "Fehler bei Get-ExoMailboxRegionalSettings für '$mailboxId': $errorMsg"
            if ($null -ne $resultTextBlock) {
                $resultTextBlock.Dispatcher.Invoke({ $resultTextBlock.Text = "Fehler: $errorMsg" }) | Out-Null
            }
            Show-MessageBox -Message "Fehler beim Abrufen der regionalen Einstellungen:`n$errorMsg" -Title "Fehler"
        }
    } catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Schwerwiegender Fehler beim Abrufen der regionalen Einstellungen."
        Update-GuiText -TextElement $statusTextBlock -Message "Fehler: $errorMsg"
        Log-Action "FEHLER bei Get-ExoMailboxRegionalSettings für '$mailboxId': $errorMsg"
        if ($null -ne $resultTextBlock) {
            $resultTextBlock.Dispatcher.Invoke({ $resultTextBlock.Text = "Fehler: $errorMsg" }) | Out-Null
        }
        Show-MessageBox -Message "Ein schwerwiegender Fehler ist aufgetreten:`n$errorMsg" -Title "Fehler"
    }
}

# Hilfsfunktion zum Befüllen der Zeitformat-ComboBox basierend auf Kultur
function Populate-TimeFormatComboBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Controls.ComboBox]$ComboBox,
        [Parameter(Mandatory=$false)]
        [string]$CultureName # z.B. "de-DE"
    )
    try {
        Write-Log "Befülle Zeitformat-ComboBox für Kultur '$CultureName'..." -Type Debug
        
        $currentValue = $null
        if ($null -ne $ComboBox.SelectedItem -and $null -ne $ComboBox.SelectedItem.Tag) {
            $currentValue = $ComboBox.SelectedItem.Tag
        } elseif (-not [string]::IsNullOrEmpty($ComboBox.Text) -and $ComboBox.Text -ne "(Keine Änderung)") {
             $currentValue = $ComboBox.Text
        }

        $ComboBox.Items.Clear()

        $noChangeItem = New-Object System.Windows.Controls.ComboBoxItem
        $noChangeItem.Content = "(Keine Änderung)"
        $noChangeItem.Tag = "" 
        [void]$ComboBox.Items.Add($noChangeItem)

        $formatsToUse = $null
        if (-not [string]::IsNullOrEmpty($CultureName) -and $script:RelevantTimeFormatsPerCulture.ContainsKey($CultureName)) {
            $formatsToUse = $script:RelevantTimeFormatsPerCulture[$CultureName]
        } else {
            Write-Log "Kultur '$CultureName' nicht in RelevantTimeFormatsPerCulture gefunden oder leer, verwende DEFAULT Zeitformate." -Type Debug
            $formatsToUse = $script:RelevantTimeFormatsPerCulture["DEFAULT"]
        }

        if ($null -ne $formatsToUse) {
            foreach ($formatInfo in $formatsToUse) {
                $item = New-Object System.Windows.Controls.ComboBoxItem
                $item.Content = $formatInfo.Display 
                $item.Tag = $formatInfo.Value     
                [void]$ComboBox.Items.Add($item)
            }
        }
        
        $itemToSelectAfterPopulation = $ComboBox.Items | Where-Object { $_.Tag -eq $currentValue } | Select-Object -First 1
        if ($null -ne $itemToSelectAfterPopulation) {
            $ComboBox.SelectedItem = $itemToSelectAfterPopulation
        } else {
            $ComboBox.SelectedItem = $noChangeItem # Auf "(Keine Änderung)" zurückfallen
        }

        Write-Log "Zeitformat-ComboBox erfolgreich befüllt. Ausgewählt: '$($ComboBox.SelectedItem.Content)' (Tag: '$($ComboBox.SelectedItem.Tag)')" -Type Debug
        return $true
    } catch {
        Write-Log "Fehler beim Befüllen der Zeitformat-ComboBox: $($_.Exception.Message)" -Type Error
        Log-Action "Fehler beim Befüllen der Zeitformat-ComboBox: $($_.Exception.Message)"
        if ($ComboBox.Items.Count -gt 0) { $ComboBox.SelectedIndex = 0 } # Auf "(Keine Änderung)" zurückfallen
        return $false
    }
}

# Hilfsfunktion zum Befüllen der Sprachen-ComboBox
function Populate-LanguageComboBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Controls.ComboBox]$ComboBox
    )
    try {
        Write-Log "Befülle Sprachen-ComboBox mit gefilterter Sprachliste..." -Type Debug

        $currentValue = $null
        if ($null -ne $ComboBox.SelectedItem -and $null -ne $ComboBox.SelectedItem.Tag) {
            $currentValue = $ComboBox.SelectedItem.Tag
        } elseif (-not [string]::IsNullOrEmpty($ComboBox.Text)) {
             $currentValue = $ComboBox.Text
        }

        $ComboBox.Items.Clear()

        $noChangeItem = New-Object System.Windows.Controls.ComboBoxItem
        $noChangeItem.Content = "(Keine Änderung)"
        $noChangeItem.Tag = "" # Leerer Tag für "Keine Änderung"
        $noChangeItem.IsSelected = $true
        [void]$ComboBox.Items.Add($noChangeItem)

        # Gewünschte spezifische Kultur-Codes
        $desiredSpecificCultures = @(
            "de-DE", "de-AT", "de-CH", # Deutsch
            "en-US", "en-GB",         # Englisch
            "fr-FR", "fr-CA", "fr-CH", "fr-BE", "fr-LU", # Französisch
            "it-IT", "it-CH",         # Italienisch
            "pl-PL",                  # Polnisch
            "es-ES", "es-MX", # Spanisch (Spanien, Mexiko)
            "nl-NL", "nl-BE"          # Niederländisch
        )

        $allCultures = [System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::SpecificCultures)
        $filteredCultures = [System.Collections.Generic.List[System.Globalization.CultureInfo]]::new()

        foreach ($culture in $allCultures) {
            if ($desiredSpecificCultures -contains $culture.Name) {
                $filteredCultures.Add($culture)
            }
        }
        
        # Sortieren der gefilterten Kulturen nach Anzeigenamen
        $sortedFilteredCultures = $filteredCultures | Sort-Object -Property DisplayName

        foreach ($culture in $sortedFilteredCultures) {
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Content = $culture.DisplayName # z.B. "Deutsch (Deutschland)"
            $item.Tag = $culture.Name          # z.B. "de-DE"
            [void]$ComboBox.Items.Add($item)
        }

        if (-not [string]::IsNullOrEmpty($currentValue)) {
            $itemToSelect = $ComboBox.Items | Where-Object { $_.Tag -eq $currentValue -or $_.Content -eq $currentValue } | Select-Object -First 1
            if ($null -ne $itemToSelect) {
                $ComboBox.SelectedItem = $itemToSelect
            } elseif ($ComboBox.IsEditable -and $currentValue -ne "(Keine Änderung)") {
                 $ComboBox.Text = $currentValue
            } else {
                 $ComboBox.SelectedItem = $noChangeItem
            }
        } else {
             $ComboBox.SelectedItem = $noChangeItem
        }
        Write-Log "Sprachen-ComboBox erfolgreich mit gefilterter Liste befüllt." -Type Debug
        return $true
    } catch {
        Write-Log "Fehler beim Befüllen der Sprachen-ComboBox (gefiltert): $($_.Exception.Message)" -Type Warning
        Log-Action "Warnung: Sprachen konnten nicht dynamisch gefiltert geladen werden."
        return $false
    }
}

# Hilfsfunktion zum Befüllen der Datumsformat-ComboBox basierend auf Kultur
function Populate-DateFormatComboBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Controls.ComboBox]$ComboBox,
        [Parameter(Mandatory=$false)]
        [string]$CultureName # z.B. "de-DE"
    )
    try {
        Write-Log "Befülle Datumsformat-ComboBox für Kultur '$CultureName'..." -Type Debug
        
        # Aktuelle Auswahl merken (Tag oder Text)
        $currentValue = $null
        if ($null -ne $ComboBox.SelectedItem -and $null -ne $ComboBox.SelectedItem.Tag) {
            $currentValue = $ComboBox.SelectedItem.Tag
        } elseif (-not [string]::IsNullOrEmpty($ComboBox.Text) -and $ComboBox.Text -ne "(Keine Änderung)") {
             $currentValue = $ComboBox.Text # Fallback auf Text, wenn manuell editiert
        }

        $ComboBox.Items.Clear()

        $noChangeItem = New-Object System.Windows.Controls.ComboBoxItem
        $noChangeItem.Content = "(Keine Änderung)"
        $noChangeItem.Tag = "" # Leerer Tag für "Keine Änderung"
        [void]$ComboBox.Items.Add($noChangeItem)

        $formatsToUse = $null
        if (-not [string]::IsNullOrEmpty($CultureName) -and $script:ExchangeValidDateFormats.ContainsKey($CultureName)) {
            $formatsToUse = $script:ExchangeValidDateFormats[$CultureName]
        } else {
            Write-Log "Kultur '$CultureName' nicht in ExchangeValidDateFormats gefunden oder leer, verwende DEFAULT Datumsformate." -Type Debug
            $formatsToUse = $script:ExchangeValidDateFormats["DEFAULT"]
        }

        if ($null -ne $formatsToUse) {
            foreach ($formatInfo in $formatsToUse) {
                $item = New-Object System.Windows.Controls.ComboBoxItem
                $item.Content = $formatInfo.Display # z.B. "TT.MM.JJJJ (Standard)"
                $item.Tag = $formatInfo.Value     # z.B. "dd.MM.yyyy"
                [void]$ComboBox.Items.Add($item)
            }
        }
        
        # Versuche vorherige Auswahl wiederherzustellen oder "(Keine Änderung)" zu wählen
        $itemToSelectAfterPopulation = $ComboBox.Items | Where-Object { $_.Tag -eq $currentValue } | Select-Object -First 1
        if ($null -ne $itemToSelectAfterPopulation) {
            $ComboBox.SelectedItem = $itemToSelectAfterPopulation
        } else {
            # Wenn der alte Wert nicht mehr gültig ist (oder keiner war), setze auf "(Keine Änderung)"
            $ComboBox.SelectedItem = $noChangeItem
        }

        Write-Log "Datumsformat-ComboBox erfolgreich befüllt. Ausgewählt: '$($ComboBox.SelectedItem.Content)' (Tag: '$($ComboBox.SelectedItem.Tag)')" -Type Debug
        return $true
    } catch {
        Write-Log "Fehler beim Befüllen der Datumsformat-ComboBox: $($_.Exception.Message)" -Type Error
        Log-Action "Fehler beim Befüllen der Datumsformat-ComboBox: $($_.Exception.Message)"
        # Im Fehlerfall "(Keine Änderung)" auswählen
        if ($ComboBox.Items.Count -gt 0) { $ComboBox.SelectedIndex = 0 }
        return $false
    }
}

# Hilfsfunktion zum Befüllen der Zeitzonen-ComboBox
function Populate-TimezoneComboBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Controls.ComboBox]$ComboBox,
        [Parameter(Mandatory=$false)]
        [string]$CultureName # z.B. "de-DE", leer für alle/default
    )
    try {
        Write-Log "Befülle Zeitzonen-ComboBox für Kultur '$CultureName'..." -Type Debug

        $currentValue = $null
        if ($null -ne $ComboBox.SelectedItem -and $null -ne $ComboBox.SelectedItem.Tag) {
            $currentValue = $ComboBox.SelectedItem.Tag
        } elseif (-not [string]::IsNullOrEmpty($ComboBox.Text) -and $ComboBox.Text -ne "(Keine Änderung)") {
            $currentValue = $ComboBox.Text
        }

        $ComboBox.Items.Clear()

        $noChangeItem = New-Object System.Windows.Controls.ComboBoxItem
        $noChangeItem.Content = "(Keine Änderung)"
        $noChangeItem.Tag = ""
        [void]$ComboBox.Items.Add($noChangeItem)

        $allSystemTimezones = [System.TimeZoneInfo]::GetSystemTimeZones()
        $timezonesToDisplay = [System.Collections.Generic.List[System.TimeZoneInfo]]::new()

        $specificTimezoneIDs = $null
        if (-not [string]::IsNullOrEmpty($CultureName) -and $script:RelevantTimezonesPerCulture.ContainsKey($CultureName)) {
            $mappedValue = $script:RelevantTimezonesPerCulture[$CultureName]
            if ($mappedValue -is [array]) {
                $specificTimezoneIDs = $mappedValue
                Write-Log "Kultur '$CultureName' gefunden. Lade spezifische Zeitzonen-IDs: $($specificTimezoneIDs -join ', ')" -Type Debug
            } elseif ($mappedValue -is [bool] -and $mappedValue -eq $true -and $CultureName -eq "DEFAULT_ALL") {
                # Spezialfall für DEFAULT_ALL, lade alle
                $specificTimezoneIDs = $null # Signalisiert, alle zu nehmen
                Write-Log "Kultur '$CultureName' ist DEFAULT_ALL. Lade alle Systemzeitzonen." -Type Debug
            }
        } elseif ($script:RelevantTimezonesPerCulture.ContainsKey("DEFAULT_ALL") -and $script:RelevantTimezonesPerCulture["DEFAULT_ALL"] -eq $true) {
             Write-Log "Keine spezifische Kultur '$CultureName' oder kein Mapping. Fallback auf DEFAULT_ALL: Lade alle Systemzeitzonen." -Type Debug
             $specificTimezoneIDs = $null # Signalisiert, alle zu nehmen
        }


        if ($null -ne $specificTimezoneIDs) {
            foreach ($tzID in $specificTimezoneIDs) {
                $foundTz = $allSystemTimezones | Where-Object { $_.Id -eq $tzID } | Select-Object -First 1
                if ($null -ne $foundTz -and -not $timezonesToDisplay.Contains($foundTz)) {
                    $timezonesToDisplay.Add($foundTz)
                } else {
                    Write-Log "Zeitzonen-ID '$tzID' für Kultur '$CultureName' nicht im System gefunden oder bereits hinzugefügt." -Type Warning
                }
            }
        } else { # Lade alle Systemzeitzonen
            $timezonesToDisplay.AddRange($allSystemTimezones)
        }
        
        # Sortiere die anzuzeigenden Zeitzonen
        $sortedTimezonesToDisplay = $timezonesToDisplay | Sort-Object @{Expression={$_.BaseUtcOffset.TotalHours}}, @{Expression={$_.DisplayName}}
        
        foreach ($tz in $sortedTimezonesToDisplay) {
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $offsetHours = $tz.BaseUtcOffset.TotalHours
            $offsetString = ""
            if ($offsetHours -lt 0) {
                $offsetString = "UTC$($tz.BaseUtcOffset.ToString('hh\:mm'))"
            } elseif ($offsetHours -gt 0) {
                $offsetString = "UTC+$($tz.BaseUtcOffset.ToString('hh\:mm'))"
            } else {
                $offsetString = "UTC"
            }
            $item.Content = "($offsetString) $($tz.DisplayName)"
            $item.Tag = $tz.Id
            [void]$ComboBox.Items.Add($item)
        }

        $itemToSelectAfterPopulation = $ComboBox.Items | Where-Object { $_.Tag -eq $currentValue } | Select-Object -First 1
        if ($null -ne $itemToSelectAfterPopulation) {
            $ComboBox.SelectedItem = $itemToSelectAfterPopulation
        } else {
            $ComboBox.SelectedItem = $noChangeItem
        }
        Write-Log "Zeitzonen-ComboBox erfolgreich befüllt für Kultur '$CultureName'. Ausgewählt: '$($ComboBox.SelectedItem.Content)' (Tag: '$($ComboBox.SelectedItem.Tag)')" -Type Debug
        return $true
    } catch {
        Write-Log "Fehler beim Befüllen der Zeitzonen-ComboBox für Kultur '$CultureName': $($_.Exception.Message)" -Type Error
        Log-Action "Fehler beim Befüllen der Zeitzonen-ComboBox: $($_.Exception.Message)"
        if ($ComboBox.Items.Count -gt 0) { $ComboBox.SelectedIndex = 0 }
        return $false
    }
}

# Funktion zum Abrufen der regionalen Einstellungen eines Postfachs
function Get-ExoMailboxRegionalSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MailboxIdentity
    )

    # Prüfen, ob eine Verbindung besteht
    if (-not (Confirm-ExchangeConnection)) {
        Write-Log "Get-ExoMailboxRegionalSettings: Keine Verbindung zu Exchange Online." -Type Warning
        # Rückgabe eines Fehlerobjekts oder einer Nachricht
        return [PSCustomObject]@{
            Success = $false
            Error   = "Keine Verbindung zu Exchange Online hergestellt."
            Result  = $null
        }
    }

    # Eingabe validieren
    if ([string]::IsNullOrWhiteSpace($MailboxIdentity)) {
        Write-Log "Get-ExoMailboxRegionalSettings: Keine Postfach-Identität angegeben." -Type Warning
        return [PSCustomObject]@{
            Success = $false
            Error   = "Keine Postfach-Identität angegeben."
            Result  = $null
        }
    }

    try {
        # Use ${} for clarity
        Write-Log "Rufe regionale Einstellungen für ${MailboxIdentity} ab..." -Type Debug
        # Use ${} for clarity
        Log-Action "Versuche, regionale Einstellungen für ${MailboxIdentity} abzurufen."

        # Regionale Einstellungen abrufen
        # -VerifyDefaultFolderNameLanguage ist nötig, sonst ist DefaultFolderNameMatchingUserLanguage immer $false
        $regionalSettings = Get-MailboxRegionalConfiguration -Identity $MailboxIdentity -VerifyDefaultFolderNameLanguage -ErrorAction Stop

        # Erfolgreiches Ergebnis zurückgeben
        # Use ${} for clarity
        Write-Log "Regionale Einstellungen für ${MailboxIdentity} erfolgreich abgerufen." -Type Success
        # Use $() for expressions, ${} for clarity
        Log-Action "Regionale Einstellungen für ${MailboxIdentity} erfolgreich abgerufen: Sprache=$($regionalSettings.Language), Zeitzone=$($regionalSettings.TimeZone)"

        return [PSCustomObject]@{
            Success = $true
            Error   = $null
            Result  = $regionalSettings # Das gesamte Objekt zurückgeben für Flexibilität
        }

    } catch {
        # Fehler behandeln und zurückgeben
        # Use ${} for clarity in default text
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Abrufen der regionalen Einstellungen für ${MailboxIdentity}."
        Write-Log $errorMsg -Type Error
        # Use ${} for clarity
        Log-Action "FEHLER: Get-ExoMailboxRegionalSettings - ${errorMsg}"

        return [PSCustomObject]@{
            Success = $false
            Error   = $errorMsg
            Result  = $null
        }
    }
}

# Funktion zum Setzen der regionalen Einstellungen für ein oder mehrere Postfächer
function Set-ExoMailboxRegionalSettings {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[string]]$MailboxesToProcess,

        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters, # Enthält Schlüssel wie Language, TimeZone, DateFormat, TimeFormat, LocalizeDefaultFolderName

        [Parameter(Mandatory = $false)]
        [System.Windows.Controls.TextBlock]$StatusTextBlock
    )

    $results = @{
        Success   = [System.Collections.Generic.List[string]]::new()
        Failed    = [System.Collections.Generic.List[object]]::new()
        Warnings  = [System.Collections.Generic.List[object]]::new()
        Cancelled = $false
    }
    $total = $MailboxesToProcess.Count
    $processed = 0

    foreach ($mailbox in $MailboxesToProcess) {
        # Abbruch über die Arbeitsanzeige ("Abbrechen")
        if (Test-UICancelRequested) {
            $results.Cancelled = $true
            Log-Action "Anwendung der regionalen Einstellungen nach $processed von $total Postfächern abgebrochen."
            break
        }

        $processed++
        $progress = [int](($processed / $total) * 100)

        # Läuft im UI-Thread: Fortschritt direkt anzeigen (kein Dispatcher-Aufruf nötig)
        Update-UIBusy -Message "Verarbeite ${mailbox}" -Current $processed -Total $total
        if ($null -ne $StatusTextBlock) {
            $StatusTextBlock.Text = "Verarbeite ${mailbox} (${processed}/${total})... [${progress}%]"
        }
        else {
            Write-Verbose "Verarbeite ${mailbox} (${processed}/${total})... [${progress}%]"
        }

        try {
            $cmdletParams = $Parameters.Clone()

            if ($cmdletParams.ContainsKey("LocalizeDefaultFolderName")) {
                $localizeValue = $cmdletParams["LocalizeDefaultFolderName"]
                $cmdletParams.Remove("LocalizeDefaultFolderName")
                if ($localizeValue -eq $true) {
                    $cmdletParams.Add("LocalizeDefaultFolderName", $true)
                } elseif ($localizeValue -eq $false) {
                    $cmdletParams.Add("LocalizeDefaultFolderName", $false)
                }
            }

            Write-Log "Setze regionale Einstellungen für ${mailbox} mit cmdletParams: $($cmdletParams | Out-String)" -Type Debug
            Log-Action "Versuche Set-MailboxRegionalConfiguration für ${mailbox} mit Parametern: $($cmdletParams.Keys -join ', ')"

            $warningMessages = New-Object System.Collections.Generic.List[string]
            $originalWarningPreference = $WarningPreference
            $WarningPreference = "SilentlyContinue" # Um Warnungen im Skript abzufangen

            try {
                if ($PSCmdlet.ShouldProcess($mailbox, "Regionale Einstellungen anwenden (Sprache/Zeitzone/Datumsformate/Ordnernamen)")) {
                    Set-MailboxRegionalConfiguration -Identity $mailbox @cmdletParams -Confirm:$false -ErrorAction Stop -WarningVariable +tempWarnings
                    
                    if ($null -ne $tempWarnings -and $tempWarnings.Count -gt 0) {
                        foreach($warn in $tempWarnings){
                            $formattedWarning = $warn.Message
                            Write-Log "Exchange WARNUNG für Postfach ${mailbox}: ${formattedWarning}" -Type Warning
                            Log-Action "Exchange WARNUNG für Postfach ${mailbox}: ${formattedWarning}"
                            $warningMessages.Add($formattedWarning)
                        }
                    }
                    $tempWarnings = $null 
                }
            }
            finally {
                $WarningPreference = $originalWarningPreference
            }

            if ($warningMessages.Count -gt 0) {
                # Warnungen (z.B. "keine Einstellungen geändert") sind kein Fehler: Postfach zählt als erfolgreich
                $results.Success.Add($mailbox)
                $results.Warnings.Add(@{ Mailbox = $mailbox; Warning = ($warningMessages -join "`n") })
            } else {
                 $results.Success.Add($mailbox)
                 Log-Action "Regionale Einstellungen für ${mailbox} erfolgreich gesetzt (oder ohne Fehler/Warnungen abgeschlossen)."
            }
        }
        catch {
            $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Setzen der Einstellungen für ${mailbox}."
            $results.Failed.Add(@{ Mailbox = $mailbox; Error = $errorMsg })
            Log-Action "FEHLER beim Setzen der regionalen Einstellungen für ${mailbox}: ${errorMsg}"
            Write-Warning "Fehler bei Postfach ${mailbox}: ${errorMsg}"
        }
    }
    return $results
}

# Funktion zum Initialisieren des Regionaleinstellungen-Tabs
function Initialize-RegionSettingsTab {
    [CmdletBinding()]
    param()

    try {
        Write-Log "Initialisiere Regionaleinstellungen-Tab..." -Type Info

        # GUI-Elemente finden gemäß XAML-Definition
        $script:txtRegionMailbox = $script:Form.FindName("txtRegionMailbox")
        $script:cmbRegionLanguage = $script:Form.FindName("cmbRegionLanguage")
        $script:cmbRegionTimezone = $script:Form.FindName("cmbRegionTimezone")
        $script:btnSetRegionSettings = $script:Form.FindName("btnSetRegionSettings")
        $script:txtGetRegionMailbox = $script:Form.FindName("txtGetRegionMailbox")
        $script:btnGetRegionSettings = $script:Form.FindName("btnGetRegionSettings")
        $script:txtRegionResult = $script:Form.FindName("txtRegionResult")
        $script:helpLinkRegionSettings = $script:Form.FindName("helpLinkRegionSettings")
        $script:cmbRegionDateFormat = $script:Form.FindName("cmbRegionDateFormat")
        $script:cmbRegionTimeFormat = $script:Form.FindName("cmbRegionTimeFormat")
        $script:chkRegionDefaultFolderNameMatchingUserLanguage = $script:Form.FindName("chkRegionDefaultFolderNameMatchingUserLanguage")
        # HINZUGEFÜGT: Export-Button aus XAML
        $script:btnExportRegionSettings = $script:Form.FindName("btnExportRegionSettings")
        
        $requiredControlsMap = @{
            "txtRegionMailbox"     = $script:txtRegionMailbox
            "cmbRegionLanguage"    = $script:cmbRegionLanguage
            "cmbRegionTimezone"    = $script:cmbRegionTimezone
            "btnSetRegionSettings" = $script:btnSetRegionSettings
            "txtGetRegionMailbox"  = $script:txtGetRegionMailbox
            "btnGetRegionSettings" = $script:btnGetRegionSettings
            "txtRegionResult"      = $script:txtRegionResult
            "cmbRegionDateFormat" = $script:cmbRegionDateFormat
            "cmbRegionTimeFormat" = $script:cmbRegionTimeFormat
            "chkRegionDefaultFolderNameMatchingUserLanguage" = $script:chkRegionDefaultFolderNameMatchingUserLanguage
            "btnExportRegionSettings" = $script:btnExportRegionSettings
        }

        $missingControls = [System.Collections.Generic.List[string]]::new()
        foreach ($controlNameInMap in $requiredControlsMap.Keys) {
            if ($null -eq $requiredControlsMap[$controlNameInMap]) {
                $missingControls.Add($controlNameInMap)
            }
        }

        if ($missingControls.Count -gt 0) {
            $missingControlsListString = $missingControls -join ", "
            $logMessage = "Ein oder mehrere erforderliche Steuerelemente im Regionaleinstellungen-Tab nicht gefunden: $missingControlsListString. Bitte XAML 'x:Name' Attribute prüfen."
            Write-Log $logMessage -Type Error
            Log-Action "Fehler: Wichtige Steuerelemente für Regionaleinstellungen ($missingControlsListString) nicht gefunden. XAML-Namen prüfen!"
            Show-MessageBox -Message $logMessage -Title "Initialisierungsfehler"
            return $false
        }

        # ComboBoxen befüllen
        try {
            Populate-LanguageComboBox -ComboBox $script:cmbRegionLanguage
        } catch {
            Write-Log "FEHLER beim initialen Befüllen der Sprachen-ComboBox: $($_.Exception.Message)" -Type Error
        }

        try {
            Populate-TimezoneComboBox -ComboBox $script:cmbRegionTimezone -CultureName "DEFAULT_ALL"
        } catch {
            Write-Log "FEHLER beim initialen Befüllen der Zeitzonen-ComboBox: $($_.Exception.Message)" -Type Error
        }
        
        try {
            Populate-DateFormatComboBox -ComboBox $script:cmbRegionDateFormat -CultureName "" 
        } catch {
            Write-Log "FEHLER beim initialen Befüllen der Datumsformat-ComboBox: $($_.Exception.Message)" -Type Error
        }
        
        # Zeitformat-ComboBox initial mit DEFAULT befüllen
        try {
            Populate-TimeFormatComboBox -ComboBox $script:cmbRegionTimeFormat -CultureName ""
        } catch {
            Write-Log "FEHLER beim initialen Befüllen der Zeitformat-ComboBox: $($_.Exception.Message)" -Type Error
        }
        
        # Drei-Zustand-CheckBox auf unbestimmt setzen
        $script:chkRegionDefaultFolderNameMatchingUserLanguage.IsChecked = $null 
        Write-Log "chkRegionDefaultFolderNameMatchingUserLanguage.IsChecked auf \$null (unbestimmt) gesetzt." -Type Debug
        
        # Event-Handler für Sprachauswahl-Änderung
        $script:cmbRegionLanguage.Add_SelectionChanged({
            param($eventSender)
            try {
                $selectedLanguageItem = $eventSender.SelectedItem
                $cultureNameForFormats = "" 
                $cultureNameForTimezones = "DEFAULT_ALL" 

                if ($null -ne $selectedLanguageItem -and $null -ne $selectedLanguageItem.Tag -and $selectedLanguageItem.Tag -ne "") {
                    $selectedCultureTag = $selectedLanguageItem.Tag.ToString()
                    $cultureNameForFormats = $selectedCultureTag
                    $cultureNameForTimezones = $selectedCultureTag 
                }
                
                Write-Log "Sprachauswahl geändert. Kultur für Formate: '$cultureNameForFormats', Kultur für Zeitzonen: '$cultureNameForTimezones'. Aktualisiere abhängige ComboBoxen." -Type Debug
                Populate-DateFormatComboBox -ComboBox $script:cmbRegionDateFormat -CultureName $cultureNameForFormats
                Populate-TimeFormatComboBox -ComboBox $script:cmbRegionTimeFormat -CultureName $cultureNameForFormats
                Populate-TimezoneComboBox -ComboBox $script:cmbRegionTimezone -CultureName $cultureNameForTimezones
            } catch {
                $errorMsgSelChange = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler im SelectionChanged Event der Sprach-ComboBox."
                Write-Log "FEHLER im cmbRegionLanguage.SelectionChanged: $errorMsgSelChange" -Type Error
            }
        })
        Write-Log "Event-Handler für cmbRegionLanguage.SelectionChanged registriert (inkl. Datums-, Zeitformat- und Zeitzonen-Update)." -Type Debug
        
        # Event-Handler für "Einstellungen abrufen" Button
        if ($null -ne $script:btnGetRegionSettings) {
            $null = Register-EventHandler -Control $script:btnGetRegionSettings -ControlName "btnGetRegionSettings" -Handler {
                try {
                    Invoke-GetRegionSettingsAction
                } catch {
                    $errorMsgAction = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Abrufen der Regionaleinstellungen."
                    Write-Log $errorMsgAction -Type Error
                    Log-Action "FEHLER bei Aktion 'Einstellungen abrufen' ($($script:btnGetRegionSettings.Name)): $errorMsgAction"
                    Show-MessageBox -Message "Ein Fehler ist beim Abrufen der Einstellungen aufgetreten: $($_.Exception.Message)" -Title "Aktionsfehler"
                }
            }
            Write-Log "Event-Handler für '$($script:btnGetRegionSettings.Name)' registriert." -Type Debug
        }

        # Event-Handler für "Einstellungen anwenden" Button
        if ($null -ne $script:btnSetRegionSettings) {
            $null = Register-EventHandler -Control $script:btnSetRegionSettings -ControlName "btnSetRegionSettings" -Handler {
                try {
                    Invoke-SetRegionSettingsAction
                } catch {
                    $errorMsgAction = Get-FormattedError -ErrorRecord $_ -DefaultText "Fehler beim Anwenden der Regionaleinstellungen."
                    Write-Log $errorMsgAction -Type Error
                    Log-Action "FEHLER bei Aktion 'Einstellungen anwenden' ($($script:btnSetRegionSettings.Name)): $errorMsgAction"
                    Show-MessageBox -Message "Ein Fehler ist beim Anwenden der Einstellungen aufgetreten: $($_.Exception.Message)" -Title "Aktionsfehler"
                }
            }
            Write-Log "Event-Handler für '$($script:btnSetRegionSettings.Name)' registriert." -Type Debug
        }

        # Event-Handler für Export-Button
        if ($null -ne $script:btnExportRegionSettings) {
            $null = Register-EventHandler -Control $script:btnExportRegionSettings -ControlName "btnExportRegionSettings" -Handler {
                # Prüfen ob Daten zum Exportieren vorhanden sind
                if ([string]::IsNullOrWhiteSpace($script:txtRegionResult.Text)) {
                    Show-MessageBox -Message "Keine Daten zum Exportieren vorhanden. Bitte rufen Sie zuerst die Einstellungen ab." -Title "Keine Daten" -Type Warning
                    return
                }

                # Freitext wird als Textdatei gespeichert (kein CSV: Inhalte könnten in Tabellenprogrammen als Formeln ausgeführt werden)
                Export-TextContent -Text $script:txtRegionResult.Text -DefaultFileName "Regionaleinstellungen"
            }
            Write-Log "Event-Handler für '$($script:btnExportRegionSettings.Name)' registriert." -Type Debug
        }

        # Event-Handler für Hilfe-Link
        if ($null -ne $script:helpLinkRegionSettings) {
            $script:helpLinkRegionSettings.Add_MouseLeftButtonDown({ 
                try {
                    if (Test-Path Function:\Show-HelpDialog) {
                        Show-HelpDialog -Topic "RegionSettings"
                    } else {
                        Write-Log "Hilfefunktion Show-HelpDialog nicht gefunden." -Type Warning
                    }
                } catch {
                    Write-Log "Fehler beim Öffnen des Hilfe-Dialogs: $($_.Exception.Message)" -Type Error
                }
            }) 
            $script:helpLinkRegionSettings.Add_MouseEnter({ 
                $this.Cursor = [System.Windows.Input.Cursors]::Hand
                $this.TextDecorations = [System.Windows.TextDecorations]::Underline 
            })
            $script:helpLinkRegionSettings.Add_MouseLeave({ 
                $this.TextDecorations = $null
                $this.Cursor = [System.Windows.Input.Cursors]::Arrow 
            })
            Write-Log "Event-Handler für '$($script:helpLinkRegionSettings.Name)' registriert." -Type Debug
        }

        Write-Log "Regionaleinstellungen-Tab erfolgreich initialisiert." -Type Success
        Log-Action "Regionaleinstellungen-Tab initialisiert."
        return $true
    }
    catch {
        $errorMsg = Get-FormattedError -ErrorRecord $_ -DefaultText "Schwerwiegender Fehler beim Initialisieren des Regionaleinstellungen-Tabs."
        Write-Log $errorMsg -Type Error
        Log-Action "FEHLER: Schwerwiegender Fehler beim Initialisieren des Regionaleinstellungen-Tabs: ${errorMsg}"
        Show-MessageBox -Message "Ein unerwarteter schwerwiegender Fehler ist beim Initialisieren des Regionaleinstellungen-Tabs aufgetreten: `n$($_.Exception.Message)`nBitte überprüfen Sie die Logs und die XAML-Definition." -Title "Schwerer Initialisierungsfehler" -Type Error
        return $false
    }
}
