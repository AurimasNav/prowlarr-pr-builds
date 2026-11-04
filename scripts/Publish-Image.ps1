#Requires -Version 7.4
<#
.SYNOPSIS
    Builds the test image from the packaged Prowlarr (prowlarr.tar.gz) and pushes it to GHCR.
.DESCRIPTION
    Reads TAG, VERSION, BASE_SHA, PR_SHA, PR and REGISTRY_TOKEN from the environment.
    Prints the pushed digest and writes it to the job summary.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

foreach ($name in 'TAG', 'VERSION', 'BASE_SHA', 'PR_SHA', 'PR', 'REGISTRY_TOKEN') {
    if (-not [Environment]::GetEnvironmentVariable($name)) { throw "$name is not set" }
}
$owner = $env:GITHUB_REPOSITORY_OWNER.ToLowerInvariant()
$image = "ghcr.io/$owner/prowlarr-pr-builds"
$context = Join-Path $env:RUNNER_TEMP 'image'

New-Item -ItemType Directory -Force -Path $context | Out-Null
tar -xzf prowlarr.tar.gz -C $context
Copy-Item Dockerfile $context

$env:REGISTRY_TOKEN | docker login ghcr.io --username $env:GITHUB_ACTOR --password-stdin
docker build --pull `
    --label "org.opencontainers.image.source=https://github.com/$env:GITHUB_REPOSITORY" `
    --label "org.opencontainers.image.version=$env:VERSION" `
    --label "org.opencontainers.image.revision=$env:PR_SHA" `
    --label "io.github.prowlarr.pr=$env:PR" `
    --label "io.github.prowlarr.base-revision=$env:BASE_SHA" `
    --tag "${image}:$env:TAG" $context
docker push "${image}:$env:TAG"
$digest = docker inspect --format '{{index .RepoDigests 0}}' "${image}:$env:TAG"
docker logout ghcr.io

Write-Output "Pushed $digest"
if ($env:GITHUB_STEP_SUMMARY) {
    @(
        "### Prowlarr PR #$env:PR test image",
        '',
        "- Image: ``${image}:$env:TAG``",
        "- Digest: ``$digest``",
        "- Prowlarr version: $env:VERSION",
        "- PR head: $env:PR_SHA, base: $env:BASE_SHA"
    ) | Add-Content -Path $env:GITHUB_STEP_SUMMARY
}
