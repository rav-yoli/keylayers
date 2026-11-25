# Installs the test ZIP matching the KeyLayers checkout, building it if needed.
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [string]$ZipPath,

    [string]$RepoPath,

    [string]$AddOnsPath = 'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$addonName = 'KeyLayers by Rav Yoli'

$tocName = "$addonName.toc"
$versionPattern = '(?m)^##[ \t]+Version:[ \t]*([^ \t\r\n]+)'
$sourceVersion = $null
$builder = $null
if ($ZipPath) {
    $archive = Get-Item -LiteralPath $ZipPath
    if ($archive.PSIsContainer -or $archive.Extension -ne '.zip') {
        throw "Expected a ZIP archive: $ZipPath"
    }
    $operation = "Install $($archive.Name)"
}
else {
    if (-not $RepoPath) {
        $RepoPath = $PSScriptRoot
        if (-not (Test-Path -LiteralPath (Join-Path $RepoPath $tocName) -PathType Leaf)) {
            $RepoPath = Split-Path -Parent $PSScriptRoot
        }
    }
    $repo = (Resolve-Path -LiteralPath $RepoPath).ProviderPath
    $sourceToc = Join-Path $repo $tocName
    if (-not (Test-Path -LiteralPath $sourceToc -PathType Leaf)) {
        throw "KeyLayers repository not found at $repo. Place this script in the repository or pass -RepoPath."
    }

    $sourceVersion = [regex]::Match([IO.File]::ReadAllText($sourceToc), $versionPattern).Groups[1].Value
    if ($sourceVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+[A-Za-z0-9-]*$') {
        throw "Invalid or missing version in $sourceToc"
    }

    $testZipName = "KeyLayers-by-Rav-Yoli-$sourceVersion-test.zip"
    $distArchive = Join-Path (Join-Path $repo 'dist') $testZipName
    if (Test-Path -LiteralPath $distArchive -PathType Leaf) {
        $archive = Get-Item -LiteralPath $distArchive
        $operation = "Install $distArchive"
    }
    else {
        $builderName = 'Build-KeyLayersTestZip.ps1'
        $builder = Join-Path (Join-Path $repo 'scripts') $builderName
        if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) {
            $builder = Join-Path $repo $builderName
        }
        if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) {
            throw "Missing $distArchive and could not find $builderName in the repository."
        }
        $operation = "Build and install KeyLayers $sourceVersion from $repo"
    }
}

$addons = Get-Item -LiteralPath $AddOnsPath
if (-not $addons.PSIsContainer) {
    throw "Expected the WoW Forever AddOns directory: $AddOnsPath"
}

$destination = Join-Path $addons.FullName $addonName
if (-not $PSCmdlet.ShouldProcess($destination, $operation)) {
    return
}

$stage = Join-Path $addons.Parent.FullName ('.keylayers-install-' + [guid]::NewGuid().ToString('N'))
$backup = $null
try {
    [void][IO.Directory]::CreateDirectory($stage)
    if ($builder) {
        $buildOutput = Join-Path $stage 'build'
        & $builder -RepoPath $repo -Version $sourceVersion -OutputDirectory $buildOutput | Out-Null
        $archive = Get-Item -LiteralPath (Join-Path $buildOutput $testZipName)
    }

    $extracted = Join-Path $stage 'extracted'
    Expand-Archive -LiteralPath $archive.FullName -DestinationPath $extracted
    $package = Join-Path $extracted $addonName
    $toc = Join-Path $package $tocName
    if (-not (Test-Path -LiteralPath $toc -PathType Leaf)) {
        throw "Invalid test ZIP. Expected '$addonName\$addonName.toc' in the archive."
    }

    $installedVersion = [regex]::Match([IO.File]::ReadAllText($toc), $versionPattern).Groups[1].Value
    if (-not $installedVersion) {
        throw "Invalid test ZIP. Missing version in $tocName."
    }
    if ($sourceVersion -and $sourceVersion -ne $installedVersion) {
        throw "The ZIP contains version $installedVersion, expected $sourceVersion."
    }

    if (Test-Path -LiteralPath $destination) {
        if (-not (Test-Path -LiteralPath $destination -PathType Container)) {
            throw "The destination exists but is not an addon directory: $destination"
        }
        $backupDirectory = Join-Path $addons.Parent.FullName 'KeyLayersTestBackups'
        [void][IO.Directory]::CreateDirectory($backupDirectory)
        $backupName = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), [guid]::NewGuid().ToString('N')
        $backup = Join-Path $backupDirectory $backupName
        [IO.Directory]::Move($destination, $backup)
    }

    try {
        [IO.Directory]::Move($package, $destination)
    }
    catch {
        if ($backup) {
            try {
                [IO.Directory]::Move($backup, $destination)
            }
            catch {
                Write-Warning "Restore failed. The previous addon is available at: $backup"
            }
        }
        throw
    }

    Write-Host "Installed KeyLayers $installedVersion in $destination"
    if ($backup) {
        Write-Host "Previous version: $backup"
    }
}
finally {
    if (Test-Path -LiteralPath $stage -PathType Container) {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction Continue
    }
}
