# Applies a downloaded KeyLayers patch archive.
[CmdletBinding()]
param(
    [string]$ZipPath,
    [string]$Destination
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ZipPath) {
    $downloads = Join-Path $env:USERPROFILE 'Downloads'
    $candidate = Get-ChildItem -LiteralPath $downloads -File -Filter 'KeyLayers-*patch.zip' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $candidate) {
        throw "No KeyLayers patch archive found in $downloads."
    }
    $ZipPath = $candidate.FullName
}

$ZipPath = (Resolve-Path -LiteralPath $ZipPath).ProviderPath
$patchDirectory = $Destination
$createdDestination = $false
if (-not $patchDirectory) {
    $patchDirectory = Join-Path ([IO.Path]::GetTempPath()) ("KeyLayers-patch-" + [guid]::NewGuid())
    $createdDestination = $true
}

try {
    [void][IO.Directory]::CreateDirectory($patchDirectory)
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $patchDirectory -Force

    $patchScripts = @(Get-ChildItem -LiteralPath $patchDirectory -File -Filter 'Apply-KeyLayers-*.ps1' -Recurse)
    if ($patchScripts.Count -ne 1) {
        throw "Expected one Apply-KeyLayers-*.ps1 script in $ZipPath; found $($patchScripts.Count)."
    }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $patchScripts[0].FullName
    if ($LASTEXITCODE -ne 0) {
        throw "Patch script exited with code $LASTEXITCODE."
    }
}
finally {
    if ($createdDestination -and (Test-Path -LiteralPath $patchDirectory)) {
        Remove-Item -LiteralPath $patchDirectory -Recurse -Force
    }
}