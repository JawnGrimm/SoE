[CmdletBinding()]
param(
    [string]$Version = "1.8.1"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$addonsPath = Join-Path $projectRoot "addons"
$installPath = Join-Path $addonsPath "limboai"
$projectFile = Join-Path $projectRoot "project.godot"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("soe-limboai-" + [guid]::NewGuid().ToString("N"))
$archivePath = Join-Path $tempRoot "limboai-gdextension.zip"

$expectedHash = "0910411f8dbc0da8920f6c8bbbb6397c347cd9f2f193942468a702dfb11d5f0e"
$downloadUrl = "https://github.com/limbonaut/limboai/releases/download/v$Version/limboai%2Bv$Version.gdextension-4.6.zip"

try {
    if (-not (Test-Path $projectFile)) {
        throw "Could not find project.godot. Run this script from a Scribe of Eras checkout."
    }
    if ($Version -ne "1.8.1") {
        throw "This installer is pinned and checksum-verified for LimboAI 1.8.1. Update the expected hash before using another version."
    }

    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $addonsPath -Force | Out-Null

    Write-Host "Downloading LimboAI $Version GDExtension..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath

    $actualHash = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        throw "LimboAI archive checksum mismatch. Expected $expectedHash, got $actualHash. Nothing was installed."
    }

    $extractPath = Join-Path $tempRoot "extracted"
    Expand-Archive -Path $archivePath -DestinationPath $extractPath -Force

    $pluginConfig = Get-ChildItem -Path $extractPath -Filter "plugin.cfg" -File -Recurse |
        Where-Object { $_.FullName -match '[\\/]addons[\\/]limboai[\\/]plugin\.cfg$' } |
        Select-Object -First 1

    if ($null -eq $pluginConfig) {
        throw "The verified archive did not contain addons/limboai/plugin.cfg. Nothing was installed."
    }

    $sourceAddonPath = $pluginConfig.Directory.FullName
    $extensionFile = Get-ChildItem -Path $sourceAddonPath -Filter "*.gdextension" -File -Recurse |
        Select-Object -First 1

    if ($null -eq $extensionFile) {
        throw "The LimboAI plugin folder did not contain a .gdextension descriptor. Nothing was installed."
    }

    if (Test-Path $installPath) {
        $backupPath = Join-Path $addonsPath ("limboai.backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
        Move-Item -Path $installPath -Destination $backupPath
        Write-Host "Existing addons/limboai moved to $backupPath"
    }

    Copy-Item -Path $sourceAddonPath -Destination $installPath -Recurse

    $installedConfig = Join-Path $installPath "plugin.cfg"
    if (-not (Test-Path $installedConfig)) {
        throw "Installation copy is missing plugin.cfg."
    }

    $projectText = [System.IO.File]::ReadAllText($projectFile)
    $pluginEntry = '"res://addons/limboai/plugin.cfg"'

    if ($projectText -notmatch [regex]::Escape($pluginEntry)) {
        $enabledPattern = '(?m)^(enabled=PackedStringArray\()([^\r\n]*)(\))$'
        if ($projectText -notmatch $enabledPattern) {
            throw "Could not locate editor_plugins.enabled in project.godot. Plugin files were installed, but automatic enablement was skipped."
        }

        $projectText = [regex]::Replace(
            $projectText,
            $enabledPattern,
            [System.Text.RegularExpressions.MatchEvaluator]{
                param($match)
                return $match.Groups[1].Value + $match.Groups[2].Value + ', ' + $pluginEntry + $match.Groups[3].Value
            },
            1
        )
        [System.IO.File]::WriteAllText($projectFile, $projectText, [System.Text.UTF8Encoding]::new($false))
    }

    Write-Host ""
    Write-Host "LimboAI $Version installed at res://addons/limboai/"
    Write-Host "The editor plugin is enabled in project.godot."
    Write-Host "Open the SoE project in Godot 4.7.2 and allow the filesystem scan to finish."
    Write-Host "If the editor was already open, restart it once."
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
