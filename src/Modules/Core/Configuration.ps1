# =====================================================================
# easyEXO - Modul: Konfiguration (Registry HKCU:\Software\easyIT\easyEXO)
# Datei: src/Modules/Core/Configuration.ps1
#
# Wird von src/easyEXO.ps1 per Dot-Sourcing geladen (gemeinsamer Script-Scope,
# damit $script:-Variablen und WPF-Event-Handler unverändert funktionieren).
# Nicht direkt ausführen.
# =====================================================================

# Lade Konfiguration aus Registry
function Get-RegistryConfig {
    [CmdletBinding()]
    param()
    
    try {
        $config = @{
            "General" = @{}
            "Paths" = @{}
            "UI" = @{}
        }
        
        # Lese alle Registry-Werte
        $regValues = Get-ItemProperty -Path $script:registryPath -ErrorAction SilentlyContinue
        
        if ($regValues) {
            # Debug-Einstellung
            if ($null -ne $regValues.Debug) {
                $config["General"]["Debug"] = $regValues.Debug.ToString()
            }
            
            # AppName
            if ($null -ne $regValues.AppName) {
                $config["General"]["AppName"] = $regValues.AppName
            }
            
            # Version
            if ($null -ne $regValues.Version) {
                $config["General"]["Version"] = $regValues.Version
            }
            
            # DefaultUser
            if ($null -ne $regValues.DefaultUser) {
                $config["General"]["DefaultUser"] = $regValues.DefaultUser
            }
            
            # LogPath
            if ($null -ne $regValues.LogPath) {
                $config["Paths"]["LogPath"] = $regValues.LogPath
            }

        }
        
        return $config
    }
    catch {
        # Fallback zu Standardwerten bei Fehlern
        return @{
            "General" = @{
                "Debug" = "0"
                "AppName" = "easyEXO | Exchange Online Management Tool"
                "Version" = $script:AppVersion
            }
            "Paths" = @{
                "LogPath" = "$script:AppRoot\Logs"
            }
            "UI" = @{}
        }
    }
}
