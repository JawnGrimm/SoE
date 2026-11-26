[CmdletBinding()]
param([string]$Version = "1.8.1")

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$addonsPath = Join-Path $projectRoot "addons"
$installPath = Join-Path $addonsPath "limboai"
$projectFile = Join-Path $projectRoot "project.godot"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("soe-limboai-" + [guid]::NewGuid().ToString("N"))
$archivePath = Join-Path $tempRoot "limboai-gdextension.zip"

# SHA-256 for the upstream v1.8.1 Godot 4.6+ GDExtension archive.
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
    Write-Host "Archive checksum verified."

    $extractPath = Join-Path $tempRoot "extracted"
    Expand-Archive -Path $archivePath -DestinationPath $extractPath -Force

    # GDExtensions use a .gdextension descriptor; LimboAI has no plugin.cfg.
    $extensionFile = Get-ChildItem -Path $extractPath -Filter "limboai.gdextension" -File -Recurse |
        Select-Object -First 1
    if ($null -eq $extensionFile) {
        throw "The verified archive did not contain limboai.gdextension. Nothing was installed."
    }

    $sourceAddonPath = $extensionFile.Directory.FullName
    $windowsEditorLibrary = Join-Path $sourceAddonPath "bin\liblimboai.windows.editor.x86_64.dll"
    if (-not (Test-Path $windowsEditorLibrary)) {
        throw "The archive contains limboai.gdextension but is missing the Windows x86_64 editor library. Nothing was installed."
    }

    $backupPath = $null
    if (Test-Path $installPath) {
        $backupPath = Join-Path $addonsPath ("limboai.backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
        Move-Item -Path $installPath -Destination $backupPath
        Write-Host "Existing addons/limboai moved to $backupPath"
    }

    try {
        Copy-Item -Path $sourceAddonPath -Destination $installPath -Recurse
        if (-not (Test-Path (Join-Path $installPath "limboai.gdextension")) -or
            -not (Test-Path (Join-Path $installPath "bin\liblimboai.windows.editor.x86_64.dll"))) {
            throw "The installed LimboAI folder failed its post-copy validation."
        }
    }
    catch {
        if (Test-Path $installPath) {
            Remove-Item -Path $installPath -Recurse -Force
        }
        if ($backupPath -and (Test-Path $backupPath)) {
            Move-Item -Path $backupPath -Destination $installPath
        }
        throw
    }

    Write-Host ""
    Write-Host "LimboAI $Version GDExtension installed at res://addons/limboai/"
    Write-Host "Godot loads GDExtensions from their .gdextension descriptor; no editor plugin toggle is required."
    Write-Host "Open the SoE project in Godot 4.7.2 and allow the filesystem scan to finish."
    Write-Host "If the editor was already open, restart it once."
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
