#Requires -Version 7.4
<#
.SYNOPSIS
    Clones Prowlarr at a branch and merges one pull request into it.
.DESCRIPTION
    Writes step outputs for the workflow: tag (image tag), version (assembly version),
    base_sha and pr_sha. Fails if the pull request doesn't merge cleanly.
    -Patch applies an extra patch from this repo (patches/<name>.patch) on top, for testing
    proposed fixes to the pull request; the image tag then carries the patch name.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidatePattern('^[0-9]{1,6}$')] [string] $Pr,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Za-z0-9._/-]{1,100}$')] [string] $Base,
    [Parameter(Mandatory)] [string] $Path,
    [ValidatePattern('^$|^[A-Za-z0-9._-]{1,80}$')] [string] $Patch = ''
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$patchFile = $null
if ($Patch) {
    $patchFile = Join-Path $PSScriptRoot '..' 'patches' "$Patch.patch" | Resolve-Path
}

git clone --quiet --filter=blob:none --branch $Base https://github.com/Prowlarr/Prowlarr.git $Path
Push-Location $Path
try {
    git fetch --quiet origin "pull/$Pr/head:pr-$Pr"
    $baseSha = git rev-parse HEAD
    $prSha = git rev-parse "pr-$Pr"
    git -c user.name=prowlarr-pr-builds -c user.email=prowlarr-pr-builds@users.noreply.github.com `
        merge --quiet --no-ff --no-edit "pr-$Pr"
    if ($patchFile) {
        git apply --check $patchFile
        git apply $patchFile
        Write-Output "Applied patch $Patch"
    }

    # Same major/minor as Prowlarr's own CI; the build part is this workflow's run number.
    $major = Select-String -Path azure-pipelines.yml -Pattern "majorVersion:\s*'([0-9.]+)'" |
        Select-Object -First 1 | ForEach-Object { $_.Matches[0].Groups[1].Value }
    if (-not $major) { throw 'majorVersion not found in azure-pipelines.yml' }
    $version = "$major.$($env:GITHUB_RUN_NUMBER ?? '0')"
    # The run number keeps every build's tag unique (a tag is never moved to another image).
    $tag = "pr$Pr-$($prSha.Substring(0, 7))-$($Base -replace '[^A-Za-z0-9]', '')-$($baseSha.Substring(0, 7))"
    if ($Patch) { $tag += "-$Patch" }
    $tag += "-r$($env:GITHUB_RUN_NUMBER ?? '0')"

    Write-Output "Base $Base at $baseSha, PR #$Pr at $prSha, version $version, tag $tag"
    if ($env:GITHUB_OUTPUT) {
        @("tag=$tag", "version=$version", "base_sha=$baseSha", "pr_sha=$prSha") |
            Add-Content -Path $env:GITHUB_OUTPUT
    }
}
finally {
    Pop-Location
}
