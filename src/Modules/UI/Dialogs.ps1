# =====================================================================
# easyEXO - Modul: Dialoge (MessageBox, Hilfe, Einstellungen)
# Datei: src/Modules/UI/Dialogs.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# MessageBox-Funktion
function Show-MessageBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Title = "Information",
        
        # "YesNo" wird als Bestätigungsdialog (Ja/Nein) behandelt - identisch zu "Question"
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error", "Question", "YesNo")]
        [string]$Type = "Info",

        # Optionales Symbol, überschreibt das aus -Type abgeleitete Symbol
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error", "Question")]
        [string]$Icon
    )
    
    $isConfirmation = $Type -in @("Question", "YesNo")
    try {
        $iconName = if ($PSBoundParameters.ContainsKey('Icon')) { $Icon } elseif ($Type -eq "YesNo") { "Question" } else { $Type }
        $iconValue = switch ($iconName) {
            "Info" { [System.Windows.MessageBoxImage]::Information }
            "Warning" { [System.Windows.MessageBoxImage]::Warning }
            "Error" { [System.Windows.MessageBoxImage]::Error }
            "Question" { [System.Windows.MessageBoxImage]::Question }
        }
        
        $buttons = if ($isConfirmation) { 
            [System.Windows.MessageBoxButton]::YesNo 
        } else { 
            [System.Windows.MessageBoxButton]::OK 
        }
        
        $result = [System.Windows.MessageBox]::Show($Message, $Title, $buttons, $iconValue)
        
        Write-LogEntry -Message "$Title - $Type - $Message - Ergebnis: $result" -Type "Info"
        
        # Ergebnis zurückgeben (wichtig für Ja/Nein-Fragen)
        return $result
    }
    catch {
        Write-LogEntry -Message "Fehler beim Anzeigen der MessageBox '$Title': $($_.Exception.Message)" -Type "Error"
        # Sicherer Fallback: Bestätigungen gelten im Fehlerfall als abgelehnt
        if ($isConfirmation) {
            return [System.Windows.MessageBoxResult]::No
        }
    }
}

function Show-HelpDialog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Topic
    )

    try {
        $helpTitle = "Hilfe: $Topic"
        $helpMessage = ""

        switch ($Topic) {
            "Calendar" {
                $helpMessage = "Hier finden Sie Hilfe zum Verwalten von Kalenderberechtigungen.`n`n"
                $helpMessage += "Funktionen:`n"
                $helpMessage += "- Postfach angeben: Geben Sie die E-Mail-Adresse des Postfachs ein, dessen Kalenderberechtigungen Sie verwalten möchten.`n"
                $helpMessage += "- Anzeigen: Zeigt die aktuellen Kalenderberechtigungen für das angegebene Postfach an.`n"
                $helpMessage += "- Benutzer und Zugriffsebene auswählen/eingeben: Wählen Sie einen Benutzer aus der Liste oder geben Sie dessen E-Mail-Adresse ein. Wählen Sie die gewünschte Zugriffsebene (z.B. Editor, Reviewer).`n"
                $helpMessage += "- Hinzufügen: Fügt dem angegebenen Benutzer die ausgewählte Berechtigungsstufe für den Kalender hinzu.`n"
                $helpMessage += "- Ändern: Modifiziert die vorhandene Berechtigungsstufe des ausgewählten Benutzers auf die neu ausgewählte Zugriffsebene.`n"
                $helpMessage += "- Entfernen: Löscht die Kalenderberechtigungen des ausgewählten Benutzers.`n"
                $helpMessage += "- Alle setzen: Ermöglicht das Setzen einer Standardberechtigung (z.B. Verfügbarkeit) für alle Benutzer (außer 'Default' und 'Anonymous'). Bestehende spezifische Berechtigungen bleiben erhalten oder können optional überschrieben werden.`n"
                $helpMessage += "- Exportieren: Exportiert die aktuell angezeigten Kalenderberechtigungen in eine CSV-Datei.`n`n"
                $helpMessage += "Hinweis: 'Default' bezieht sich auf alle authentifizierten Benutzer in Ihrer Organisation. 'Anonymous' bezieht sich auf externe, nicht authentifizierte Benutzer."
            }
            "Mailbox" {
                $helpMessage = "Hier finden Sie Hilfe zum Verwalten von Postfachberechtigungen (Vollzugriff), 'Senden als'-Rechten und 'Senden im Auftrag von'-Rechten.`n`n"
                $helpMessage += "Eingabefelder:`n"
                $helpMessage += "- Ziel-Postfach: Das Postfach, für das Berechtigungen erteilt oder angezeigt werden sollen.`n"
                $helpMessage += "- Benutzer-Postfach: Das Postfach des Benutzers, der die Berechtigungen erhalten oder dem sie entzogen werden sollen.`n`n"
                $helpMessage += "Postfachberechtigungen (Vollzugriff):`n"
                $helpMessage += "- Hinzufügen: Gewährt dem 'Benutzer-Postfach' Vollzugriff auf das 'Ziel-Postfach'.`n"
                $helpMessage += "- Entfernen: Entzieht dem 'Benutzer-Postfach' den Vollzugriff auf das 'Ziel-Postfach'.`n"
                $helpMessage += "- Anzeigen: Listet alle Benutzer auf, die Vollzugriff auf das 'Ziel-Postfach' haben.`n`n"
                $helpMessage += "'Senden als'-Rechte:`n"
                $helpMessage += "- Hinzufügen: Erlaubt dem 'Benutzer-Postfach', E-Mails so zu senden, als kämen sie direkt vom 'Ziel-Postfach'.`n"
                $helpMessage += "- Entfernen: Entzieht dem 'Benutzer-Postfach' die 'Senden als'-Rechte für das 'Ziel-Postfach'.`n"
                $helpMessage += "- Anzeigen: Listet alle Benutzer auf, die 'Senden als'-Rechte für das 'Ziel-Postfach' haben.`n`n"
                $helpMessage += "'Senden im Auftrag von'-Rechte:`n"
                $helpMessage += "- Hinzufügen: Erlaubt dem 'Benutzer-Postfach', E-Mails im Auftrag des 'Ziel-Postfachs' zu senden (Empfänger sehen 'Benutzer A im Auftrag von Benutzer B').`n"
                $helpMessage += "- Entfernen: Entzieht dem 'Benutzer-Postfach' die 'Senden im Auftrag von'-Rechte für das 'Ziel-Postfach'.`n"
                $helpMessage += "- Anzeigen: Listet alle Benutzer auf, die 'Senden im Auftrag von'-Rechte für das 'Ziel-Postfach' haben."
            }
            "Contacts" {
                $helpMessage = "Hier finden Sie Hilfe zum Verwalten von externen Kontakten (MailContacts) und E-Mail-aktivierten Benutzern (MailUsers).`n`n"
                $helpMessage += "Funktionen:`n"
                $helpMessage += "- Neuer Kontakt:`n"
                $helpMessage += "  - Name: Der Anzeigename des Kontakts.`n"
                $helpMessage += "  - E-Mail: Die externe E-Mail-Adresse des Kontakts.`n"
                $helpMessage += "  - Erstellen: Legt einen neuen externen Kontakt (MailContact) an.`n`n"
                $helpMessage += "- Anzeigen (MailContacts): Listet alle externen Kontakte in Ihrer Organisation auf.`n"
                $helpMessage += "- Anzeigen (MailUsers): Listet alle E-Mail-aktivierten Benutzer auf (Benutzer mit Postfächern in Ihrer lokalen Active Directory-Umgebung, die mit Exchange Online synchronisiert werden, aber kein Exchange Online-Postfach haben).`n"
                $helpMessage += "- Ausgewählten Kontakt/MailUser entfernen: Löscht den in der Liste ausgewählten Kontakt oder MailUser. Eine Bestätigung ist erforderlich.`n"
                $helpMessage += "- Kontakte exportieren: Exportiert die aktuell in der Liste angezeigten Kontakte oder MailUser in eine CSV-Datei."
            }
            "Resources" {
                $helpMessage = "Hier finden Sie Hilfe zum Verwalten von Ressourceneinstellungen für Raum- und Gerätepostfächer.`n`n"
                $helpMessage += "Funktionen:`n"
                $helpMessage += "- Raum-Postfächer anzeigen: Listet alle konfigurierten Raumpostfächer auf.`n"
                $helpMessage += "- Geräte-Postfächer anzeigen: Listet alle konfigurierten Gerätepostfächer auf.`n"
                $helpMessage += "- Ausgewählte Ressource bearbeiten: Öffnet einen Dialog zur Anpassung spezifischer Einstellungen für die in der Liste ausgewählte Ressource. Dazu gehören unter anderem:`n"
                $helpMessage += "  - Anzeigename, Kapazität, Standort`n"
                $helpMessage += "  - Automatische Annahme/Ablehnung von Besprechungsanfragen`n"
                $helpMessage += "  - Zulassen von Konflikten und Serienbesprechungen`n"
                $helpMessage += "  - Buchungsfenster (wie weit im Voraus gebucht werden kann)`n"
                $helpMessage += "  - Maximale Besprechungsdauer`n"
                $helpMessage += "  - Verarbeitung von Anfragen außerhalb der Arbeitszeiten`n"
                $helpMessage += "  - Löschen von Kommentaren, Betreffzeilen oder privaten Kennzeichnungen`n"
                $helpMessage += "  - Hinzufügen des Organisators zum Betreff."
            }
            "Groups" {
                $helpMessage = "Hier finden Sie Hilfe zum Verwalten von Verteilergruppen und Microsoft 365-Gruppen.`n`n"
                $helpMessage += "Verteilergruppen:`n"
                $helpMessage += "- Anzeigen: Listet alle Verteilergruppen auf.`n"
                $helpMessage += "- Neu: Erstellt eine neue Verteilergruppe.`n"
                $helpMessage += "  - Name, Alias, Primäre SMTP-Adresse, Typ (Distribution/Security), Beitritts-/Verlassensoptionen.`n"
                $helpMessage += "- Bearbeiten: Ändert Eigenschaften der ausgewählten Verteilergruppe.`n"
                $helpMessage += "- Mitglieder verwalten: Hinzufügen/Entfernen von Mitgliedern.`n"
                $helpMessage += "- Besitzer verwalten: Hinzufügen/Entfernen von Besitzern.`n"
                $helpMessage += "- Löschen: Entfernt die ausgewählte Verteilergruppe.`n`n"
                $helpMessage += "Microsoft 365-Gruppen:`n"
                $helpMessage += "- Anzeigen: Listet alle Microsoft 365-Gruppen auf.`n"
                $helpMessage += "- Neu: Erstellt eine neue Microsoft 365-Gruppe.`n"
                $helpMessage += "  - Name, Alias, Beschreibung, Datenschutz (Öffentlich/Privat), Sprache, Besitzer, Mitglieder.`n"
                $helpMessage += "- Bearbeiten: Ändert Eigenschaften der ausgewählten Microsoft 365-Gruppe.`n"
                $helpMessage += "- Mitglieder verwalten: Hinzufügen/Entfernen von Mitgliedern.`n"
                $helpMessage += "- Besitzer verwalten: Hinzufügen/Entfernen von Besitzern.`n"
                $helpMessage += "- Löschen: Entfernt die ausgewählte Microsoft 365-Gruppe.`n`n"
                $helpMessage += "Exportieren: Exportiert die angezeigte Liste der Gruppen in eine CSV-Datei."
            }
            "Rules" {
                $helpMessage = "Hier finden Sie Hilfe zum Verwalten von Posteingangsregeln für Benutzerpostfächer.`n`n"
                $helpMessage += "Funktionen:`n"
                $helpMessage += "- Postfach auswählen: Geben Sie die E-Mail-Adresse des Postfachs ein, dessen Regeln Sie verwalten möchten.`n"
                $helpMessage += "- Regeln anzeigen: Listet alle aktiven Posteingangsregeln für das ausgewählte Postfach auf.`n"
                $helpMessage += "- Regel aktivieren/deaktivieren: Schaltet die ausgewählte Regel ein oder aus, ohne sie zu löschen.`n"
                $helpMessage += "- Regel löschen: Entfernt die ausgewählte Regel vollständig aus dem Postfach.`n"
                $helpMessage += "- Regel bearbeiten: Öffnet einen Dialog zur Bearbeitung der Regelkriterien und -aktionen.`n"
                $helpMessage += "- Neue Regel erstellen: Erstellt eine neue Posteingangsregel mit benutzerdefinierten Bedingungen und Aktionen.`n"
                $helpMessage += "- Regeln exportieren: Exportiert alle Regeln des ausgewählten Postfachs in eine CSV-Datei.`n`n"
                $helpMessage += "Regeltypen:`n"
                $helpMessage += "- Bedingungen: Absender, Betreff, Empfänger, Größe, Wichtigkeit, etc.`n"
                $helpMessage += "- Aktionen: Verschieben in Ordner, Weiterleiten, Löschen, Markieren, etc.`n"
                $helpMessage += "- Ausnahmen: Spezielle Bedingungen, die die Regel außer Kraft setzen."
            }
            "Transport" {
                $helpMessage = "Hier finden Sie Hilfe zum Verwalten von Transportregeln (Mail Flow Rules) in Exchange Online.`n`n"
                $helpMessage += "Funktionen:`n"
                $helpMessage += "- Transportregeln anzeigen: Listet alle konfigurierten Transportregeln in Ihrer Organisation auf.`n"
                $helpMessage += "- Regel aktivieren/deaktivieren: Schaltet die ausgewählte Transportregel ein oder aus.`n"
                $helpMessage += "- Regel löschen: Entfernt die ausgewählte Transportregel vollständig.`n"
                $helpMessage += "- Regel bearbeiten: Öffnet einen Dialog zur Bearbeitung der Regelbedingungen und -aktionen.`n"
                $helpMessage += "- Neue Regel erstellen: Erstellt eine neue Transportregel mit benutzerdefinierten Kriterien.`n"
                $helpMessage += "- Regeln exportieren: Exportiert alle Transportregeln in eine CSV-Datei.`n`n"
                $helpMessage += "Regelkomponenten:`n"
                $helpMessage += "- Bedingungen: Absender, Empfänger, Betreff, Anhänge, Nachrichtengröße, etc.`n"
                $helpMessage += "- Aktionen: Blockieren, Umleiten, Disclaimer hinzufügen, Verschlüsseln, etc.`n"
                $helpMessage += "- Ausnahmen: Spezielle Bedingungen, die die Regel umgehen.`n"
                $helpMessage += "- Priorität: Reihenfolge der Regelverarbeitung (niedrigere Zahlen = höhere Priorität).`n`n"
                $helpMessage += "Hinweis: Transportregeln wirken sich auf den gesamten E-Mail-Verkehr Ihrer Organisation aus. Seien Sie vorsichtig bei Änderungen."
            }
            "Quarantine" {
                $helpMessage = "Hier finden Sie Hilfe zum Verwalten von Quarantäne-Nachrichten in Exchange Online.`n`n"
                $helpMessage += "Funktionen:`n"
                $helpMessage += "- Quarantäne-Nachrichten anzeigen: Listet alle aktuell in Quarantäne befindlichen Nachrichten auf.`n"
                $helpMessage += "- Nach Empfänger filtern: Zeigt nur Quarantäne-Nachrichten für einen bestimmten Empfänger an.`n"
                $helpMessage += "- Nach Absender filtern: Zeigt nur Quarantäne-Nachrichten von einem bestimmten Absender an.`n"
                $helpMessage += "- Nachricht freigeben: Gibt die ausgewählte Nachricht frei und stellt sie dem Empfänger zu.`n"
                $helpMessage += "- Nachricht löschen: Entfernt die ausgewählte Nachricht dauerhaft aus der Quarantäne.`n"
                $helpMessage += "- Absender zur Whitelist hinzufügen: Fügt den Absender der ausgewählten Nachricht zur Whitelist hinzu.`n"
                $helpMessage += "- Massenaktionen: Führt Aktionen für mehrere ausgewählte Nachrichten gleichzeitig aus.`n"
                $helpMessage += "- Quarantäne exportieren: Exportiert die Quarantäne-Liste in eine CSV-Datei.`n`n"
                $helpMessage += "Quarantäne-Gründe:`n"
                $helpMessage += "- Spam: Als Spam identifizierte Nachrichten`n"
                $helpMessage += "- Malware: Nachrichten mit schädlichen Anhängen oder Links`n"
                $helpMessage += "- Phishing: Verdächtige Phishing-Versuche`n"
                $helpMessage += "- Transportregel: Durch Transportregeln blockierte Nachrichten`n"
                $helpMessage += "- Richtlinie: Durch Sicherheitsrichtlinien blockierte Nachrichten"
            }
            "Audit" {
                $helpMessage = "Hier finden Sie Hilfe zum Verwalten und Anzeigen von Audit-Logs in Exchange Online.`n`n"
                $helpMessage += "Funktionen:`n"
                $helpMessage += "- Postfach-Audit-Logs anzeigen: Zeigt Audit-Einträge für Postfachzugriffe und -aktionen an.`n"
                $helpMessage += "- Administrator-Audit-Logs anzeigen: Zeigt Audit-Einträge für administrative Aktionen an.`n"
                $helpMessage += "- Zeitraum festlegen: Definiert den Zeitraum für die Audit-Log-Suche (Standard: letzte 7 Tage).`n"
                $helpMessage += "- Nach Benutzer filtern: Filtert Audit-Logs nach einem bestimmten Benutzer oder Administrator.`n"
                $helpMessage += "- Nach Aktion filtern: Filtert nach spezifischen Aktionen (z.B. Anmeldung, E-Mail-Zugriff, Konfigurationsänderungen).`n"
                $helpMessage += "- Detailansicht: Zeigt detaillierte Informationen zu einem ausgewählten Audit-Eintrag an.`n"
                $helpMessage += "- Audit-Logs exportieren: Exportiert die gefilterten Audit-Logs in eine CSV-Datei.`n`n"
                $helpMessage += "Audit-Kategorien:`n"
                $helpMessage += "- Postfachzugriff: Anmeldungen, E-Mail-Zugriffe, Ordneraktionen`n"
                $helpMessage += "- Administrative Aktionen: Konfigurationsänderungen, Berechtigungsänderungen`n"
                $helpMessage += "- Sicherheitsereignisse: Verdächtige Aktivitäten, Anmeldefehler`n"
                $helpMessage += "- Compliance-Ereignisse: eDiscovery-Aktionen, Aufbewahrungsrichtlinien`n`n"
                $helpMessage += "Hinweis: Audit-Logs werden standardmäßig 90 Tage aufbewahrt. Für längere Aufbewahrung sind spezielle Lizenzen erforderlich."
            }
            "General" {
                 $helpTitle = "Allgemeine Hilfe zu easyEXO"
                 $helpMessage = "Willkommen bei easyEXO! Dieses Tool wurde entwickelt, um die Verwaltung gängiger Aufgaben in Exchange Online über eine grafische Benutzeroberfläche zu vereinfachen.`n`n"
                 $helpMessage += "Hauptfunktionen und Tabs:`n"
                 $helpMessage += "- Verbindung: Bevor Sie Aktionen ausführen können, müssen Sie eine Verbindung zu Ihrem Exchange Online Tenant herstellen. Klicken Sie auf 'Verbinden' und geben Sie Ihre Administrator-Anmeldeinformationen ein.`n"
                 $helpMessage += "- Postfächer: Verwalten Sie Vollzugriffsberechtigungen, 'Senden als'-Rechte und 'Senden im Auftrag von'-Rechte für Benutzerpostfächer.`n"
                 $helpMessage += "- Kalender: Verwalten Sie die Freigabeberechtigungen für Benutzerkalender.`n"
                 $helpMessage += "- Kontakte: Erstellen und verwalten Sie externe Kontakte (MailContacts) und E-Mail-aktivierte Benutzer (MailUsers).`n"
                 $helpMessage += "- Ressourcen: Zeigen Sie Raum- und Gerätepostfächer an und bearbeiten Sie deren spezifische Buchungseinstellungen.`n"
                 $helpMessage += "- Gruppen: Verwalten Sie Verteilergruppen und Microsoft 365-Gruppen, deren Mitglieder und Besitzer.`n"
                 $helpMessage += "- Regeln: Verwalten Sie Posteingangsregeln für einzelne Benutzerpostfächer.`n"
                 $helpMessage += "- Transport: Verwalten Sie organisationsweite Transportregeln (Mail Flow Rules).`n"
                 $helpMessage += "- Quarantäne: Verwalten Sie in Quarantäne befindliche E-Mail-Nachrichten.`n"
                 $helpMessage += "- Audit: Zeigen Sie Audit-Logs für Postfach- und administrative Aktionen an.`n`n"
                 $helpMessage += "Bedienung:`n"
                 $helpMessage += "- Verwenden Sie die jeweiligen Tabs, um auf die spezifischen Verwaltungsfunktionen zuzugreifen.`n"
                 $helpMessage += "- Statusmeldungen und detaillierte Log-Informationen werden im unteren Bereich der Anwendung angezeigt.`n"
                 $helpMessage += "- Viele Listen können durch Klicken auf die Spaltenüberschriften sortiert werden.`n"
                 $helpMessage += "- Exportfunktionen sind oft verfügbar, um Daten als CSV-Datei zu sichern.`n"
                 $helpMessage += "- Hilfe-Symbole (?) in den Tabs bieten kontextspezifische Unterstützung.`n`n"
                 $helpMessage += "Stellen Sie sicher, dass die erforderlichen PowerShell-Module (insbesondere 'ExchangeOnlineManagement') installiert sind. Das Tool versucht, diese bei Bedarf zu installieren."
            }
            default {
                $helpMessage = "Kein spezifisches Hilfethema für '$Topic' gefunden.`n`n"
                $helpMessage += "Verfügbare Hilfethemen sind: General, Mailbox, Calendar, Contacts, Resources, Groups, Rules, Transport, Quarantine, Audit.`n"
                $helpMessage += "Bitte klicken Sie auf ein Hilfe-Symbol in einem der Tabs, um spezifische Informationen zu erhalten, oder wählen Sie 'General' für einen Überblick."
                $helpTitle = "Hilfe: Unbekanntes Thema"
            }
        }

        [System.Windows.MessageBox]::Show($helpMessage, $helpTitle, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    }
    catch {
        $errorMsg = $_.Exception.Message
        # Versuchen, Write-Log aufzurufen, falls es definiert ist
        try {
            Write-Log -Message "Fehler im Show-HelpDialog für Topic '$Topic': $errorMsg" -Type "Error"
        } catch {}
        [System.Windows.MessageBox]::Show("Fehler beim Anzeigen der Hilfe für '$Topic': $errorMsg", "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
    }
}

# Funktion zum Anzeigen und Verwalten des Einstellungsfensters
function Show-SettingsWindow {
    [CmdletBinding()]
    param()

    # WPF-Framework laden
    Add-Type -AssemblyName PresentationFramework

    # WinForms für FolderBrowserDialog
    Add-Type -AssemblyName System.Windows.Forms

    Write-Log "Show-SettingsWindow: Öffne Einstellungsfenster." -Type Info
    Update-StatusBar -Message "Öffne Einstellungen..." -Type Info

    try {
        # XAML für das Einstellungsfenster
        $xamlSettings = @"
        <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                Title="Einstellungen - easyEXO" Height="275" Width="500" 
                WindowStartupLocation="CenterOwner" ShowInTaskbar="False" ResizeMode="NoResize"
                Background="#f9f9f9">
            <Window.Resources>
                <Style TargetType="Button">
                    <Setter Property="Background" Value="#f0f0f0"/>
                    <Setter Property="Foreground" Value="#202020"/>
                    <Setter Property="BorderBrush" Value="#e0e0e0"/>
                    <Setter Property="BorderThickness" Value="1"/>
                    <Setter Property="Padding" Value="10,6"/>
                    <Setter Property="MinHeight" Value="30"/>
                    <Setter Property="MinWidth" Value="80"/>
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="Button">
                                <Border Background="{TemplateBinding Background}" 
                                        BorderBrush="{TemplateBinding BorderBrush}" 
                                        BorderThickness="{TemplateBinding BorderThickness}"
                                        CornerRadius="2">
                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                                </Border>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                    <Style.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter Property="Background" Value="#e5e5e5"/>
                            <Setter Property="BorderBrush" Value="#d0d0d0"/>
                        </Trigger>
                        <Trigger Property="IsPressed" Value="True">
                            <Setter Property="Background" Value="#d0d0d0"/>
                        </Trigger>
                    </Style.Triggers>
                </Style>
                <Style TargetType="TextBox">
                    <Setter Property="BorderBrush" Value="#d4d4d4"/>
                    <Setter Property="BorderThickness" Value="1"/>
                    <Setter Property="Padding" Value="8,2"/>
                    <Setter Property="Height" Value="30"/>
                    <Setter Property="VerticalContentAlignment" Value="Center"/>
                </Style>
                <Style TargetType="CheckBox">
                    <Setter Property="VerticalAlignment" Value="Center"/>
                </Style>
                <Style TargetType="TextBlock">
                    <Setter Property="VerticalAlignment" Value="Center"/>
                    <Setter Property="Margin" Value="0,0,10,0"/>
                </Style>
            </Window.Resources>
            
            <Grid Margin="15">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <TextBlock Grid.Row="0" Grid.Column="0" Text="Standard-Benutzer (optional):" ToolTip="Benutzerprinzipalname (UPN), der beim Verbinden vorgeschlagen wird."/>
                <TextBox Grid.Row="0" Grid.Column="1" Grid.ColumnSpan="2" x:Name="txtDefaultUser" Margin="0,0,0,10"/>

                <TextBlock Grid.Row="1" Grid.Column="0" Text="Debugging aktivieren:" ToolTip="Schreibt ausführliche Informationen in die Log-Datei."/>
                <CheckBox Grid.Row="1" Grid.Column="1" x:Name="chkEnableDebug" Margin="0,0,0,10"/>
                
                <TextBlock Grid.Row="2" Grid.Column="0" Text="Log-Verzeichnis:" ToolTip="Pfad zum Ordner, in dem Log-Dateien gespeichert werden."/>
                <TextBox Grid.Row="2" Grid.Column="1" x:Name="txtLogPath" Margin="0,0,5,10" IsReadOnly="True" Background="#eeeeee"/>
                <Button Grid.Row="2" Grid.Column="2" x:Name="btnBrowseLogPath" Content="..." Width="40" ToolTip="Log-Verzeichnis auswählen"/>

                <StackPanel Grid.Row="5" Grid.Column="0" Grid.ColumnSpan="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,15,0,0">
                    <Button x:Name="btnSaveSettings" Content="Speichern" IsDefault="True" Margin="0,0,10,0" Background="#0078D7" Foreground="White" BorderBrush="#005BA1" FontWeight="SemiBold"/>
                    <Button x:Name="btnCancelSettings" Content="Abbrechen" IsCancel="True"/>
                </StackPanel>
            </Grid>
        </Window> 
"@

        # XAML laden
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xamlSettings)
        $settingsWindow = [Windows.Markup.XamlReader]::Load($reader)
        $settingsWindow.Owner = $script:Form

        # UI-Elemente finden
        $txtDefaultUser = $settingsWindow.FindName("txtDefaultUser")
        $chkEnableDebug = $settingsWindow.FindName("chkEnableDebug")
        $txtLogPath = $settingsWindow.FindName("txtLogPath")
        $btnBrowseLogPath = $settingsWindow.FindName("btnBrowseLogPath")
        $btnSaveSettings = $settingsWindow.FindName("btnSaveSettings")
        $btnCancelSettings = $settingsWindow.FindName("btnCancelSettings")

        # Aktuelle Einstellungen laden und in der GUI anzeigen
        $currentConfig = Get-RegistryConfig
        $txtDefaultUser.Text = $currentConfig.General.DefaultUser
        $chkEnableDebug.IsChecked = [bool]($currentConfig.General.Debug -eq "1")
        $txtLogPath.Text = $currentConfig.General.LogPath

        # Event-Handler für "Durchsuchen"
        $btnBrowseLogPath.Add_Click({
            $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
            $folderBrowser.Description = "Bitte wählen Sie das Verzeichnis für die Log-Dateien aus."
            $folderBrowser.SelectedPath = $txtLogPath.Text
            if ($folderBrowser.ShowDialog() -eq "OK") {
                $txtLogPath.Text = $folderBrowser.SelectedPath
            }
        })

        # Event-Handler für "Abbrechen"
        $btnCancelSettings.Add_Click({
            $settingsWindow.Close()
        })

        # Event-Handler für "Speichern"
        $btnSaveSettings.Add_Click({
            try {
                if (-not (Test-Path -Path $script:registryPath)) {
                    New-Item -Path $script:registryPath -Force | Out-Null
                }
                Set-ItemProperty -Path $script:registryPath -Name "DefaultUser" -Value $txtDefaultUser.Text -ErrorAction Stop
                $debugValue = if ($chkEnableDebug.IsChecked) { "1" } else { "0" }
                Set-ItemProperty -Path $script:registryPath -Name "Debug" -Value $debugValue -ErrorAction Stop
                Set-ItemProperty -Path $script:registryPath -Name "LogPath" -Value $txtLogPath.Text -ErrorAction Stop

                Write-Log "Einstellungen erfolgreich in der Registry gespeichert." -Type Success
                Show-MessageBox -Message "Die Einstellungen wurden gespeichert. Einige Änderungen erfordern einen Neustart der Anwendung." -Title "Gespeichert" -Type Info
                
                # Globale Konfiguration aktualisieren
                $script:config = Get-RegistryConfig
                # Debug-Modus direkt anpassen
                $script:debugMode = $script:config.General.Debug -eq "1"

                $settingsWindow.Close()
            }
            catch {
                $errorMsg = "Fehler beim Speichern der Einstellungen in der Registry: $($_.Exception.Message)"
                Write-Log $errorMsg -Type Error
                Show-MessageBox -Message $errorMsg -Title "Fehler" -Type Error
            }
        })

        $settingsWindow.ShowDialog() | Out-Null
        Write-Log "Show-SettingsWindow: Einstellungsfenster geschlossen." -Type Success
        Update-StatusBar -Message "Einstellungen angezeigt." -Type Success
    } catch {
        Write-Log "Show-SettingsWindow: Fehler beim Anzeigen der Einstellungen: $($_.Exception.Message)" -Type Error
        Show-MessageBox -Message "Fehler beim Anzeigen der Einstellungen: $($_.Exception.Message)" -Title "Fehler" -Type Error
        Update-StatusBar -Message "Fehler beim Anzeigen der Einstellungen." -Type Error
    }
}
