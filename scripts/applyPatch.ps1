# Applies a downloaded KeyLayers patch archive.
[CmdletBinding()]
param(
    [string]$ZipPath,
    [string]$Destination,
    [string]$RepositoryPath = (Join-Path $PSScriptRoot "..")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ZipPath) {
    $defaultDownloads = Join-Path $env:USERPROFILE 'Downloads'
    $configuredDownloads = Get-ItemPropertyValue `
        -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' `
        -Name '{374DE290-123F-4565-9164-39C4925E467B}' -ErrorAction SilentlyContinue
    $downloadDirectories = @(
        if ($configuredDownloads) { [Environment]::ExpandEnvironmentVariables($configuredDownloads) }
        $defaultDownloads
    ) | Select-Object -Unique

    $candidates = foreach ($directory in $downloadDirectories) {
        if (Test-Path -LiteralPath $directory -PathType Container) {
            Get-ChildItem -LiteralPath $directory -File -Filter 'KeyLayers-*.zip' | ForEach-Object {
                if ($_.Name -match '^KeyLayers-2\.1\.(0|[1-9][0-9]{0,2})b-patch(?: \([0-9]+\))?\.zip$') {
                    [pscustomobject]@{ Rank = 1000 + [int]$Matches[1]; LastWriteTime = $_.LastWriteTime; FullName = $_.FullName }
                } elseif ($_.Name -match '^KeyLayers-2\.0\.0-beta([1-9][0-9]{0,2})-patch(?: \([0-9]+\))?\.zip$') {
                    [pscustomobject]@{ Rank = [int]$Matches[1]; LastWriteTime = $_.LastWriteTime; FullName = $_.FullName }
                }
            }
        }
    }
    $candidate = $candidates | Sort-Object Rank, LastWriteTime -Descending | Select-Object -First 1
    if (-not $candidate) {
        throw "No KeyLayers patch archive found in $($downloadDirectories -join ', '). Pass -ZipPath to select a ZIP."
    }
    $ZipPath = $candidate.FullName
}

$ZipPath = (Resolve-Path -LiteralPath $ZipPath).ProviderPath
$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).ProviderPath
$extractRoot = if ($Destination) { $Destination } else { [IO.Path]::GetTempPath() }
$patchDirectory = Join-Path $extractRoot ("KeyLayers-patch-" + [guid]::NewGuid())
Write-Host "Applying patch archive: $ZipPath"

try {
    [void][IO.Directory]::CreateDirectory($patchDirectory)
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $patchDirectory -Force

    $patchScripts = @(Get-ChildItem -LiteralPath $patchDirectory -File -Filter 'Apply-KeyLayers-*.ps1' -Recurse)
    if ($patchScripts.Count -ne 1) {
        throw "Expected one Apply-KeyLayers-*.ps1 script in $ZipPath. Found $($patchScripts.Count)."
    }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $patchScripts[0].FullName -RepositoryPath $RepositoryPath
    if ($LASTEXITCODE -ne 0) {
        throw "Patch script exited with code $LASTEXITCODE."
    }
}
finally {
    if (-not $Destination -and (Test-Path -LiteralPath $patchDirectory)) {
        Remove-Item -LiteralPath $patchDirectory -Recurse -Force
    }
}
