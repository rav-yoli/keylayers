# Run from PowerShell. This script publishes a release tag to origin.
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('\A[0-9]+\.[0-9]+\.[0-9]+[A-Za-z0-9-]*\z')]
    [string]$Version,

    [string]$RepoPath = (Get-Location).Path
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

    if ($updates.Count -eq 0) {
        throw "The version files already say $Version. Choose a new version."
    }

    foreach ($name in $updates.Keys) {
        [IO.File]::WriteAllText((Join-Path $root $name), $updates[$name], $utf8)
    }

    $changedFiles = @($updates.Keys)
    Invoke-Git -GitArguments (@('add', '--') + $changedFiles)
    Invoke-Git -GitArguments (@('commit', '-m', "Release KeyLayers $Version", '--') + $changedFiles)
    Invoke-Git -GitArguments @('tag', '-a', $tag, '-m', "KeyLayers $Version")
    Write-Host "Created commit and local tag $tag. Pushing main and the tag together..."
    Invoke-Git -GitArguments @('push', '--atomic', '--no-follow-tags', 'origin', 'refs/heads/main:refs/heads/main', "${tagRef}:${tagRef}")
    Write-Host "Pushed $tag. Check the Package KeyLayers workflow to confirm publication."
}
finally {
    Pop-Location
}
