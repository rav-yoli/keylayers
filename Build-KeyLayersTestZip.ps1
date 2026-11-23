# Builds an installable KeyLayers test archive from local repository files.
[CmdletBinding()]
param(
    [string]$RepoPath = (Get-Location).Path,
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+[A-Za-z0-9-]*$')]
    [string]$Version,
    [string]$OutputDirectory = [IO.Path]::GetTempPath()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$addonName = 'KeyLayers by Rav Yoli'
$tocName = "$addonName.toc"
$repo = (Resolve-Path -LiteralPath $RepoPath).ProviderPath
$tocPath = Join-Path $repo $tocName
$tocText = [IO.File]::ReadAllText($tocPath)
$versionLine = [regex]'(?m)^(##[ \t]+Version:[ \t]*)([^ \t\r\n]+)'
$tocVersion = $versionLine.Match($tocText)
if (-not $tocVersion.Success) {
    throw "Missing ## Version in $tocName."
}
if (-not $Version) {
    $Version = $tocVersion.Groups[2].Value
}
if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+[A-Za-z0-9-]*$') {
    throw "Invalid ZIP version: $Version"
}

$required = @('Core.lua', 'Bindings.xml', $tocName, 'Media\Minimap.tga')
$required += @(($tocText -split '\r?\n') | ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and $_ -notmatch '^#' })
foreach ($name in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $repo $name) -PathType Leaf)) {
        throw "Missing add-on file: $name"
    }
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
[void][IO.Directory]::CreateDirectory($output)
$archiveName = "KeyLayers-by-Rav-Yoli-$Version-test.zip"
$destination = Join-Path $output $archiveName
$staging = Join-Path ([IO.Path]::GetTempPath()) ("KeyLayers-" + [guid]::NewGuid())

try {
    $addon = Join-Path $staging $addonName
    [void][IO.Directory]::CreateDirectory($addon)

    foreach ($name in ($required | Where-Object { $_ -notmatch '^Media[\\/]' } | Select-Object -Unique)) {
        $target = Join-Path $addon $name
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
        Copy-Item -LiteralPath (Join-Path $repo $name) -Destination $target
    }
    Copy-Item -LiteralPath (Join-Path $repo 'Media') -Destination $addon -Recurse
    foreach ($name in @('README.md', 'LICENSE', 'NOTICE')) {
        $source = Join-Path $repo $name
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $addon $name)
        }
    }

    $utf8 = [System.Text.UTF8Encoding]::new($false)
    $stagedToc = Join-Path $addon $tocName
    [IO.File]::WriteAllText($stagedToc, $versionLine.Replace($tocText, ('${1}' + $Version), 1), $utf8)

    $corePath = Join-Path $addon 'Core.lua'
    $coreText = [IO.File]::ReadAllText($corePath)
    $fallback = [regex]'(?m)^(addon\.version[ \t]*=[^\r\n]*\bor[ \t]+")[^"\r\n]+(")'
    if (-not $fallback.IsMatch($coreText)) {
        throw 'Could not locate the fallback version in Core.lua.'
    }
    [IO.File]::WriteAllText($corePath, $fallback.Replace($coreText, ('${1}' + $Version + '${2}'), 1), $utf8)

    $readme = Join-Path $addon 'README.md'
    if (Test-Path -LiteralPath $readme -PathType Leaf) {
        $readmeText = [IO.File]::ReadAllText($readme)
        $heading = [regex]'(?m)^(#[ \t]+KeyLayers by Rav Yoli[ \t]+)\S+(?=[ \t]*\r?$)'
        if ($heading.IsMatch($readmeText)) {
            [IO.File]::WriteAllText($readme, $heading.Replace($readmeText, ('${1}' + $Version), 1), $utf8)
        }
    }

    $archive = Join-Path $staging $archiveName
    [IO.Compression.ZipFile]::CreateFromDirectory($addon, $archive, [IO.Compression.CompressionLevel]::Optimal, $true)
    Copy-Item -LiteralPath $archive -Destination $destination -Force
    Get-Item -LiteralPath $destination
}
finally {
    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
}
