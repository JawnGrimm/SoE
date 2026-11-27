param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$version = "v1.8.1"
$assetName = "limboai+v1.8.1.godot-4.7.2.editor.windows.x86_64.zip"
$assetUrl = "https://github.com/limbonaut/limboai/releases/download/$version/limboai%2Bv1.8.1.godot-4.7.2.editor.windows.x86_64.zip"
$expectedSha256 = "c6e4516c59eed72de5dd798d78ff8da53b36a2dffabcf5f8aa01467ba88f6c0c"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("soe-limboai-" + [guid]::NewGuid().ToString("N"))
$zipPath = Join-Path $tempRoot $assetName
$extractPath = Join-Path $tempRoot "extract"
$destination = Join-Path $ProjectRoot "addons/limboai"
$backup = Join-Path $ProjectRoot ("addons/limboai.backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

try {
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    Write-Host "Downloading LimboAI $version for Godot 4.7.2..."
    Invoke-WebRequest -Uri $assetUrl -OutFile $zipPath
    $actualSha256 = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualSha256 -ne $expectedSha256) {
        throw "LimboAI archive checksum mismatch. Expected $expectedSha256; got $actualSha256."
    }

    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    $descriptor = Get-ChildItem -Path $extractPath -Filter "limboai.gdextension" -File -Recurse | Select-Object -First 1
    if ($null -eq $descriptor) {
        throw "The verified LimboAI archive does not contain limboai.gdextension."
    }
    $source = $descriptor.Directory.FullName
    $windowsLibrary = Get-ChildItem -Path (Join-Path $source "bin") -Filter "*windows.editor.x86_64.dll" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $windowsLibrary) {
        throw "The LimboAI archive is missing its Windows x86_64 editor library."
    }

    if (Test-Path $destination) {
        Move-Item -Path $destination -Destination $backup
        Write-Host "Existing addon moved to $backup"
    }
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
        Copy-Item -Path $source -Destination $destination -Recurse
    } catch {
        if (Test-Path $destination) { Remove-Item -Path $destination -Recurse -Force }
        if (Test-Path $backup) { Move-Item -Path $backup -Destination $destination }
        throw
    }
    Write-Host "LimboAI $version installed and checksum verified at $destination"
} finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
