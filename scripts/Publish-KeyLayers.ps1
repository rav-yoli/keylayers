# Run from PowerShell. This script publishes a release tag to origin.
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('\A[0-9]+\.[0-9]+\.[0-9]+[A-Za-z0-9-]*\z')]
    [string]$Version,

    [string]$RepoPath = (Join-Path $PSScriptRoot '..')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param([string[]]$GitArguments)
    & git @GitArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git exited with code ${LASTEXITCODE}: git $($GitArguments -join ' ')"
    }
}

$tag = "v$Version"
$tagRef = "refs/tags/$tag"
$toc = 'KeyLayers by Rav Yoli.toc'
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Get-VersionParts {
    param([string]$Name)

    if ($Name -match '^v([0-9]+)\.([0-9]+)\.([0-9]+)([A-Za-z0-9-]*)\.md$') {
        return [PSCustomObject]@{
            Major = [int]$Matches[1]
            Minor = [int]$Matches[2]
            Patch = [int]$Matches[3]
            Suffix = $Matches[4]
        }
    }
    return $null
}

function Build-AggregatedChangelog {
    param(
        [string]$Root,
        [string]$Version,
        [AllowNull()][string]$PreviousTag
    )

    $releaseDirectory = Join-Path $Root 'docs\releases'
    $currentPath = Join-Path $releaseDirectory "v$Version.md"
    if (-not (Test-Path -LiteralPath $currentPath -PathType Leaf)) {
        throw "Missing changelog for v$Version."
    }

    $currentText = [IO.File]::ReadAllText($currentPath).Trim()
    if (-not $currentText) {
        throw "Changelog v$Version is empty."
    }

    if ($PreviousTag) {
        $previousPath = Join-Path $releaseDirectory "$PreviousTag.md"
        if (Test-Path -LiteralPath $previousPath -PathType Leaf) {
            $previousText = [IO.File]::ReadAllText($previousPath).Trim()
            if ($previousText -and $previousText -ne $currentText) {
                return "$currentText`n`n$previousText"
            }
        }
    }

    $fallbackNotes = @(
        Get-ChildItem -LiteralPath $releaseDirectory -Filter 'v*.md' -File |
            Sort-Object Name -Descending |
            ForEach-Object { [IO.File]::ReadAllText($_.FullName).Trim() } |
            Where-Object { $_ }
    )
    if ($fallbackNotes.Count -eq 0) {
        throw 'No release changelogs found.'
    }
    return ($fallbackNotes -join "`n`n")
}

Push-Location -LiteralPath $RepoPath
try {
    $root = Invoke-Git -GitArguments @('rev-parse', '--show-toplevel')
    Set-Location -LiteralPath $root

    $branch = Invoke-Git -GitArguments @('branch', '--show-current')
    if ($branch -cne 'main') {
        throw 'Switch to main before publishing.'
    }

    $status = Invoke-Git -GitArguments @('status', '--porcelain=v1', '--untracked-files=normal')
    if ($status) {
        $status | Out-Host
        throw 'Commit or stash the changes listed above before publishing.'
    }

    Invoke-Git -GitArguments @('fetch', '--no-tags', 'origin', 'refs/heads/main')
    $remoteMain = Invoke-Git -GitArguments @('rev-parse', 'FETCH_HEAD')
    $common = Invoke-Git -GitArguments @('merge-base', 'HEAD', $remoteMain)
    if ($common -ne $remoteMain) {
        throw 'Local main is behind or has diverged from origin/main. Sync it first.'
    }

    $localTag = Invoke-Git -GitArguments @('tag', '--list', $tag)
    $remoteTag = Invoke-Git -GitArguments @('ls-remote', '--tags', 'origin', $tagRef)
    if ($localTag -or $remoteTag) {
        throw "Tag $tag already exists. Use another version or finish the pending release."
    }

    $previousTag = & git describe --tags --abbrev=0 2>$null
    if ($LASTEXITCODE -ne 0) {
        $previousTag = $null
    }
    $aggregatedChangelog = Build-AggregatedChangelog -Root $root -Version $Version -PreviousTag $previousTag
    $releaseNotePath = Join-Path $root "docs\releases\$tag.md"

    $versionPattern = '[0-9]+\.[0-9]+\.[0-9]+[A-Za-z0-9-]*'
    $files = @(
        @{ Name = $toc; Pattern = "(?m)^(##[ \t]+Version:[ \t]*)$versionPattern(?=[ \t]*\r?$)"; Required = $true }
        @{ Name = 'Core.lua'; Pattern = '(?m)^(addon\.version[ \t]*=[^\r\n]*\bor[ \t]+")' + $versionPattern + '(")'; Required = $true }
        @{ Name = 'README.md'; Pattern = "(?m)^(#[ \t]+KeyLayers by Rav Yoli[ \t]+)$versionPattern(?=[ \t]*\r?$)"; Required = $false }
    )

    $updates = [ordered]@{}
    foreach ($file in $files) {
        $path = Join-Path $root $file.Name
        $original = [IO.File]::ReadAllText($path)
        $pattern = [regex]$file.Pattern
        $matchesFound = $pattern.Matches($original)
        if ($matchesFound.Count -eq 0 -and -not $file.Required) {
            continue
        }
        if ($matchesFound.Count -ne 1) {
            throw "Expected exactly one version field in $($file.Name)."
        }

        $replacement = '${1}' + $Version
        if ($file.Name -eq 'Core.lua') {
            $replacement += '${2}'
        }
        $updated = $pattern.Replace($original, $replacement, 1)
        if ($updated -cne $original) {
            $updates[$file.Name] = $updated
        }
    }

    $releaseNoteName = "docs/releases/$tag.md"
    $releaseNoteOriginal = if (Test-Path -LiteralPath $releaseNotePath -PathType Leaf) {
        [IO.File]::ReadAllText($releaseNotePath)
    } else {
        ''
    }
    if ($aggregatedChangelog -cne $releaseNoteOriginal) {
        $updates[$releaseNoteName] = $aggregatedChangelog
    }

    if ($updates.Count -gt 0) {
        foreach ($name in $updates.Keys) {
            [IO.File]::WriteAllText((Join-Path $root $name), $updates[$name], $utf8)
        }

        $changedFiles = @($updates.Keys)
        Invoke-Git -GitArguments (@('add', '--') + $changedFiles)
        Invoke-Git -GitArguments (@('commit', '-m', "Release KeyLayers $Version", '--') + $changedFiles)
    }
    Invoke-Git -GitArguments @('tag', '-a', $tag, '-m', "KeyLayers $Version")
    Write-Host "Created local tag $tag. Pushing main and the tag together..."
    Invoke-Git -GitArguments @('push', '--atomic', '--no-follow-tags', 'origin', 'refs/heads/main:refs/heads/main', "${tagRef}:${tagRef}")
    Write-Host "Pushed $tag. Check the Package KeyLayers workflow to confirm publication."
}
finally {
    Pop-Location
}
