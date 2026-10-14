# =====================================================================
# easyEXO - Modul: Berichte
# Datei: src/Modules/Features/Reports.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
#
# Die Berichte verwenden – sofern vorhanden – die REST-basierten EXO-V3-Cmdlets
# (Get-EXOMailbox, Get-EXOMailboxStatistics, Get-EXOMailboxPermission,
# Get-EXOMailboxFolderPermission). Statistiken werden per Pipeline im Block
# abgefragt statt einzeln pro Postfach. Alle Berichte zeigen Fortschritt an,
# lassen sich abbrechen und liefern bei Abbruch das bisherige Teilergebnis.
# =====================================================================

# Verfügbare Berichte (Anzeige in cmbReportType)
$script:ReportTypes = @(
    "Postfachgrößen",
    "Letzte Anmeldung",
    "Postfachberechtigungen (Vollzugriff)",
    "Kalenderberechtigungen",
    "Shared Mailbox-Berechtigungen",
    "Gruppenmitglieder (Verteilergruppen)"
)

function Test-ReportCommand {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

# Liefert eine eindeutige Identität eines Postfachs für Folgeabfragen
function Get-ReportMailboxIdentity {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        $Mailbox
    )

    foreach ($propertyName in @("ExchangeGuid", "UserPrincipalName", "PrimarySmtpAddress", "Identity")) {
        $value = [string]$Mailbox.$propertyName
        if (-not [string]::IsNullOrWhiteSpace($value) -and $value -ne "00000000-0000-0000-0000-000000000000") { return $value }
    }
    return [string]$Mailbox
}

# Wandelt TotalItemSize (ByteQuantifiedSize oder deserialisierte Zeichenfolge) in GB um
function ConvertTo-ReportSizeGB {
    [CmdletBinding()]
    param(
        $Size
    )

    if ($null -eq $Size) { return $null }
    try {
        if ($null -ne $Size.Value -and $null -ne $Size.Value.PSObject.Methods["ToBytes"]) {
            return [math]::Round($Size.Value.ToBytes() / 1GB, 2)
        }
    }
    catch {
        Write-Log "Postfachgröße konnte nicht direkt gelesen werden: $($_.Exception.Message)" -Type "Debug"
    }
    if ("$Size" -match '\(([\d\.,\s'']+) bytes\)') {
        $digits = $Matches[1] -replace '[^\d]', ''
        if (-not [string]::IsNullOrEmpty($digits)) { return [math]::Round([double]$digits / 1GB, 2) }
    }
    return $null
}

function Get-ReportMailboxes {
    [CmdletBinding()]
    param(
        [string]$RecipientTypeDetails
    )

    $params = @{ ResultSize = "Unlimited"; ErrorAction = "Stop" }
    if (-not [string]::IsNullOrWhiteSpace($RecipientTypeDetails)) { $params["RecipientTypeDetails"] = $RecipientTypeDetails }

    Update-UIBusy -Message "Lade Postfachliste..."
    if (Test-ReportCommand -Name "Get-EXOMailbox") {
        return @(Get-EXOMailbox @params | Step-UIProgress -Activity "Lade Postfachliste")
    }
    return @(Get-Mailbox @params | Step-UIProgress -Activity "Lade Postfachliste")
}

# Postfachgrößen / letzte Anmeldung: Statistiken werden per Pipeline (gebündelt) abgefragt
function Add-ReportMailboxStatistics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Mailboxes,

        [ValidateSet("Size", "Logon")]
        [string]$Mode = "Size",

        [Nullable[datetime]]$StartDate,

        [Nullable[datetime]]$EndDate
    )

    $mailboxLookup = @{}
    foreach ($mbx in $Mailboxes) {
        if ($null -ne $mbx.ExchangeGuid) { $mailboxLookup[[string]$mbx.ExchangeGuid] = $mbx }
    }
    $total = $Mailboxes.Count

    $addRow = {
        param($stat)
        $mailbox = $null
        if ($null -ne $stat.MailboxGuid) { $mailbox = $mailboxLookup[[string]$stat.MailboxGuid] }
        $address = if ($null -ne $mailbox) { [string]$mailbox.PrimarySmtpAddress } else { "" }
        $lastLogon = $stat.LastLogonTime

        if ($Mode -eq "Logon") {
            if ($null -ne $StartDate -or $null -ne $EndDate) {
                if ($null -eq $lastLogon) { return }
                $logonDate = [datetime]$lastLogon
                if ($null -ne $StartDate -and $logonDate -lt $StartDate.Date) { return }
                if ($null -ne $EndDate -and $logonDate -ge $EndDate.Date.AddDays(1)) { return }
            }
            $Results.Add([PSCustomObject]@{
                DisplayName        = $stat.DisplayName
                PrimarySmtpAddress = $address
                LastLogonTime      = $lastLogon
                ItemCount          = $stat.ItemCount
            })
        }
        else {
            $Results.Add([PSCustomObject]@{
                DisplayName        = $stat.DisplayName
                PrimarySmtpAddress = $address
                TotalItemSize      = [string]$stat.TotalItemSize
                TotalSizeGB        = ConvertTo-ReportSizeGB -Size $stat.TotalItemSize
                ItemCount          = $stat.ItemCount
                LastLogonTime      = $lastLogon
            })
        }
    }

    if ($total -eq 0) { return }

    if (Test-ReportCommand -Name "Get-EXOMailboxStatistics") {
        $Mailboxes |
            Get-EXOMailboxStatistics -Properties LastLogonTime -ErrorAction SilentlyContinue |
            Step-UIProgress -Activity "Lese Postfachstatistiken" -Total $total |
            ForEach-Object { & $addRow $_ }
    }
    else {
        $Mailboxes |
            ForEach-Object { Get-MailboxStatistics -Identity (Get-ReportMailboxIdentity -Mailbox $_) -ErrorAction SilentlyContinue } |
            Step-UIProgress -Activity "Lese Postfachstatistiken" -Total $total |
            ForEach-Object { & $addRow $_ }
    }
}

# Vollzugriffs-Berechtigungen (nicht geerbt, ohne Systemkonten)
function Add-ReportMailboxPermissions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Mailboxes
    )

    $useRest = Test-ReportCommand -Name "Get-EXOMailboxPermission"
    $total = $Mailboxes.Count
    $index = 0
    foreach ($mailbox in $Mailboxes) {
        $index++
        Update-UIBusy -Message "Lese Postfachberechtigungen" -Current $index -Total $total
        Assert-UINotCancelled

        $identity = Get-ReportMailboxIdentity -Mailbox $mailbox
        try {
            $permissions = if ($useRest) {
                Get-EXOMailboxPermission -Identity $identity -ErrorAction Stop
            }
            else {
                Get-MailboxPermission -Identity $identity -ErrorAction Stop
            }
        }
        catch {
            Write-Log "Berechtigungen für '$($mailbox.DisplayName)' konnten nicht gelesen werden: $($_.Exception.Message)" -Type "Warning"
            continue
        }

        foreach ($perm in $permissions) {
            $user = [string]$perm.User
            if ($perm.IsInherited -eq $true -or $user -like "NT AUTHORITY\*" -or $user -like "S-1-5-*") { continue }
            $Results.Add([PSCustomObject]@{
                Mailbox      = $mailbox.DisplayName
                MailboxEmail = [string]$mailbox.PrimarySmtpAddress
                User         = $user
                AccessRights = ($perm.AccessRights -join ", ")
            })
        }
    }
}

# Kalenderberechtigungen; der lokalisierte Ordnername (Kalender/Calendar/...) wird gemerkt,
# damit nicht für jedes Postfach zuerst ein Fehlversuch nötig ist.
function Add-ReportCalendarPermissions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Mailboxes
    )

    $useRest = Test-ReportCommand -Name "Get-EXOMailboxFolderPermission"
    $folderNames = New-Object 'System.Collections.Generic.List[string]'
    foreach ($name in @("Kalender", "Calendar", "Calendrier", "Calendario", "Agenda")) { $folderNames.Add($name) }

    $total = $Mailboxes.Count
    $index = 0
    foreach ($mailbox in $Mailboxes) {
        $index++
        Update-UIBusy -Message "Lese Kalenderberechtigungen" -Current $index -Total $total
        Assert-UINotCancelled

        $address = [string]$mailbox.PrimarySmtpAddress
        if ([string]::IsNullOrWhiteSpace($address)) { $address = Get-ReportMailboxIdentity -Mailbox $mailbox }

        $permissions = $null
        foreach ($folderName in @($folderNames)) {
            try {
                $folderIdentity = "${address}:\$folderName"
                $permissions = if ($useRest) {
                    Get-EXOMailboxFolderPermission -Identity $folderIdentity -ErrorAction Stop
                }
                else {
                    Get-MailboxFolderPermission -Identity $folderIdentity -ErrorAction Stop
                }
                if ($folderNames[0] -ne $folderName) {
                    [void]$folderNames.Remove($folderName)
                    $folderNames.Insert(0, $folderName)
                }
                break
            }
            catch {
                $permissions = $null
            }
        }

        if ($null -eq $permissions) {
            Write-Log "Kalenderordner von '$($mailbox.DisplayName)' nicht gefunden oder nicht lesbar." -Type "Debug"
            continue
        }

        foreach ($perm in $permissions) {
            $user = [string]$perm.User
            if ($user -eq "Anonymous" -or $user -eq "Default" -or $user -eq "Standard" -or $user -eq "Anonym") { continue }
            $Results.Add([PSCustomObject]@{
                Mailbox      = $mailbox.DisplayName
                MailboxEmail = [string]$mailbox.PrimarySmtpAddress
                User         = $user
                AccessRights = ($perm.AccessRights -join ", ")
            })
        }
    }
}

function Add-ReportGroupMembers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Results
    )

    Update-UIBusy -Message "Lade Verteilergruppen..."
    $groups = @(Get-DistributionGroup -ResultSize Unlimited -ErrorAction Stop | Step-UIProgress -Activity "Lade Verteilergruppen")
    $total = $groups.Count
    $index = 0
    foreach ($group in $groups) {
        $index++
        Update-UIBusy -Message "Lese Gruppenmitglieder" -Current $index -Total $total
        Assert-UINotCancelled

        $groupIdentity = if (-not [string]::IsNullOrWhiteSpace([string]$group.DistinguishedName)) { [string]$group.DistinguishedName } else { [string]$group.Identity }
        try {
            $members = Get-DistributionGroupMember -Identity $groupIdentity -ResultSize Unlimited -ErrorAction Stop
        }
        catch {
            Write-Log "Mitglieder von '$($group.DisplayName)' konnten nicht gelesen werden: $($_.Exception.Message)" -Type "Warning"
            continue
        }

        foreach ($member in $members) {
            $Results.Add([PSCustomObject]@{
                Gruppe        = $group.DisplayName
                GruppenEmail  = [string]$group.PrimarySmtpAddress
                Mitglied      = $member.DisplayName
                MitgliedEmail = [string]$member.PrimarySmtpAddress
                MitgliedTyp   = [string]$member.RecipientType
            })
        }
    }
}

# Erstellt den in cmbReportType gewählten Bericht und zeigt ihn in lstReportResults an
function Invoke-ReportGeneration {
    [CmdletBinding()]
    param()

    if (-not $script:isConnected) {
        Show-MessageBox -Message "Bitte stellen Sie zuerst eine Verbindung zu Exchange Online her." -Title "Keine Verbindung" -Type "Warning"
        return
    }

    $reportType = $script:cmbReportType.SelectedItem
    if ($null -eq $reportType) {
        Show-MessageBox -Message "Bitte wählen Sie einen Berichtstyp aus." -Title "Keine Auswahl" -Type "Warning"
        return
    }
    $reportName = if ($reportType -is [System.Windows.Controls.ComboBoxItem]) { [string]$reportType.Content } else { [string]$reportType }

    $startDate = $null
    $endDate = $null
    if ($null -ne $script:dpReportStartDate -and $null -ne $script:dpReportStartDate.SelectedDate) { $startDate = $script:dpReportStartDate.SelectedDate }
    if ($null -ne $script:dpReportEndDate -and $null -ne $script:dpReportEndDate.SelectedDate) { $endDate = $script:dpReportEndDate.SelectedDate }
    if ($null -ne $startDate -and $null -ne $endDate -and $startDate -gt $endDate) {
        Show-MessageBox -Message "Das Startdatum liegt nach dem Enddatum." -Title "Ungültiger Zeitraum" -Type "Warning"
        return
    }

    $results = New-Object 'System.Collections.Generic.List[object]'
    $cancelled = $false
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Update-StatusBar -Message "Generiere Bericht: $reportName..." -Type Info
    Write-Log "Generiere Bericht '$reportName'" -Type "Info"

    try {
        Start-UIBusy -Message "Generiere Bericht '$reportName'..." -Title "Bericht wird erstellt" -Cancelable
        try {
            switch -Wildcard ($reportName) {
                "*Postfachgrößen*" {
                    $mailboxes = Get-ReportMailboxes
                    Add-ReportMailboxStatistics -Results $results -Mailboxes $mailboxes -Mode Size
                }
                "*Letzte Anmeldung*" {
                    $mailboxes = Get-ReportMailboxes
                    Add-ReportMailboxStatistics -Results $results -Mailboxes $mailboxes -Mode Logon -StartDate $startDate -EndDate $endDate
                }
                "*Postfachberechtigungen*" {
                    $mailboxes = Get-ReportMailboxes
                    Add-ReportMailboxPermissions -Results $results -Mailboxes $mailboxes
                }
                "*Kalenderberechtigungen*" {
                    $mailboxes = Get-ReportMailboxes
                    Add-ReportCalendarPermissions -Results $results -Mailboxes $mailboxes
                }
                "*Shared Mailbox*" {
                    $mailboxes = Get-ReportMailboxes -RecipientTypeDetails "SharedMailbox"
                    Add-ReportMailboxPermissions -Results $results -Mailboxes $mailboxes
                }
                "*Gruppenmitglieder*" {
                    Add-ReportGroupMembers -Results $results
                }
                default {
                    Show-MessageBox -Message "Der gewählte Berichtstyp wird derzeit nicht unterstützt." -Title "Nicht unterstützt" -Type "Warning"
                    return
                }
            }
        }
        catch {
            # Abbruch durch den Benutzer: Teilergebnis anzeigen (EXO-Cmdlets verpacken die Ausnahme ggf.)
            if ($script:UICancelRequested -or $_.Exception -is [System.OperationCanceledException]) {
                $cancelled = $true
            }
            else {
                throw
            }
        }
        finally {
            Stop-UIBusy
        }

        $displayData = $results.ToArray()
        if ($reportName -like "*Postfachgrößen*") {
            $displayData = @($displayData | Sort-Object -Property TotalSizeGB -Descending)
        }
        $script:lstReportResults.ItemsSource = $displayData

        $duration = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
        if ($cancelled) {
            $statusMessage = "Bericht '$reportName' abgebrochen - Teilergebnis: $($results.Count) Datensätze ($duration s)."
            Write-Log $statusMessage -Type "Warning"
            Update-StatusBar -Message $statusMessage -Type Warning
        }
        else {
            $statusMessage = "Bericht '$reportName' generiert: $($results.Count) Datensätze ($duration s)."
            Write-Log $statusMessage -Type "Success"
            Update-StatusBar -Message $statusMessage -Type Success
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Generieren des Berichts: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Fehler: $errorMsg" -Type Error
        Show-MessageBox -Message "Fehler beim Generieren des Berichts: $errorMsg" -Title "Fehler" -Type "Error"
    }
}

function Export-ReportResults {
    [CmdletBinding()]
    param()

    try {
        $data = @($script:lstReportResults.ItemsSource)
        if ($data.Count -eq 0) {
            Show-MessageBox -Message "Es sind keine Daten zum Exportieren vorhanden. Bitte generieren Sie zuerst einen Bericht." -Title "Keine Daten" -Type "Warning"
            return
        }

        $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveFileDialog.Filter = "CSV-Dateien (*.csv)|*.csv"
        $saveFileDialog.Title = "Bericht exportieren"
        $saveFileDialog.FileName = "Exchange_Bericht_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

        if ($saveFileDialog.ShowDialog() -eq $true) {
            $data | ConvertTo-SafeCsvObject | Export-Csv -Path $saveFileDialog.FileName -NoTypeInformation -Encoding UTF8 -Delimiter ";"
            Update-StatusBar -Message "Bericht wurde erfolgreich exportiert: $($saveFileDialog.FileName)" -Type Success
            Show-MessageBox -Message "Der Bericht wurde erfolgreich exportiert: $($saveFileDialog.FileName)" -Title "Export erfolgreich" -Type "Info"
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler beim Exportieren des Berichts: $errorMsg" -Type "Error"
        Update-StatusBar -Message "Fehler: $errorMsg" -Type Error
        Show-MessageBox -Message "Fehler beim Exportieren des Berichts: $errorMsg" -Title "Fehler" -Type "Error"
    }
}

function Initialize-ReportsTab {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log  "Initialisiere Berichte-Tab" -Type "Info"
        
        # UI-Elemente referenzieren
        $script:cmbReportType = Get-XamlElement -ElementName "cmbReportType"
        $script:dpReportStartDate = Get-XamlElement -ElementName "dpReportStartDate"
        $script:dpReportEndDate = Get-XamlElement -ElementName "dpReportEndDate"
        $script:lstReportResults = Get-XamlElement -ElementName "lstReportResults"
        $btnGenerateReport = Get-XamlElement -ElementName "btnGenerateReport"
        $btnExportReport = Get-XamlElement -ElementName "btnExportReport"
        $helpLinkReports = Get-XamlElement -ElementName "helpLinkReports"

        # Berichtstypen eintragen (die ComboBox ist in der XAML leer)
        if ($null -ne $script:cmbReportType -and $script:cmbReportType.Items.Count -eq 0) {
            foreach ($reportTypeName in $script:ReportTypes) {
                [void]$script:cmbReportType.Items.Add($reportTypeName)
            }
            $script:cmbReportType.SelectedIndex = 0
        }
        if ($null -ne $script:lstReportResults) {
            $script:lstReportResults.IsReadOnly = $true
        }
        
        # Event-Handler registrieren
        Register-EventHandler -Control $btnGenerateReport -Handler { Invoke-ReportGeneration } -ControlName "btnGenerateReport"
        Register-EventHandler -Control $btnExportReport -Handler { Export-ReportResults } -ControlName "btnExportReport"
        
        # Hilfe-Link initialisieren, falls vorhanden
        if ($null -ne $helpLinkReports) {
            $helpLinkReports.Add_MouseLeftButtonDown({
                Show-HelpDialog -Topic "Reports"
            })
            
            $helpLinkReports.Add_MouseEnter({
                $this.TextDecorations = [System.Windows.TextDecorations]::Underline
                $this.Cursor = [System.Windows.Input.Cursors]::Hand
            })
            
            $helpLinkReports.Add_MouseLeave({
                $this.TextDecorations = $null
                $this.Cursor = [System.Windows.Input.Cursors]::Arrow
            })
        }
        
        Write-Log  "Berichte-Tab erfolgreich initialisiert" -Type "Success"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log  "Fehler beim Initialisieren des Berichte-Tabs: $errorMsg" -Type "Error"
        return $false
    }
}
