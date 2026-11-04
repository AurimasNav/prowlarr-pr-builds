#Requires -Version 7.4
<#
.SYNOPSIS
    Builds the test image from the packaged Prowlarr (prowlarr.tar.gz), checks that it starts
    and offers the pull request's indexer, then pushes it to GHCR.
.DESCRIPTION
    Reads TAG, VERSION, BASE_SHA, PR_SHA, PR, INDEXER and REGISTRY_TOKEN from the environment.
    Prints the pushed digest and writes it to the job summary.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

foreach ($name in 'TAG', 'VERSION', 'BASE_SHA', 'PR_SHA', 'PR', 'INDEXER', 'REGISTRY_TOKEN') {
    if (-not [Environment]::GetEnvironmentVariable($name)) { throw "$name is not set" }
}
$owner = $env:GITHUB_REPOSITORY_OWNER.ToLowerInvariant()
$image = "ghcr.io/$owner/prowlarr-pr-builds"
$context = Join-Path $env:RUNNER_TEMP 'image'

New-Item -ItemType Directory -Force -Path $context | Out-Null
tar -xzf prowlarr.tar.gz -C $context
Copy-Item Dockerfile $context

docker build --pull `
    --label "org.opencontainers.image.source=https://github.com/$env:GITHUB_REPOSITORY" `
    --label "org.opencontainers.image.version=$env:VERSION" `
    --label "org.opencontainers.image.revision=$env:PR_SHA" `
    --label "io.github.prowlarr.pr=$env:PR" `
    --label "io.github.prowlarr.base-revision=$env:BASE_SHA" `
    --tag "${image}:$env:TAG" $context

# Smoke test: the container starts, reports the expected version and lists the indexer.
$apiKey = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(16)).ToLowerInvariant()
docker run --detach --name smoke --publish 127.0.0.1:9696:9696 `
    --env PUID=1000 --env PGID=1000 --env "PROWLARR__AUTH__APIKEY=$apiKey" "${image}:$env:TAG" | Out-Null
try {
    $headers = @{ 'X-Api-Key' = $apiKey }
    $deadline = (Get-Date).AddSeconds(180)
    $status = $null
    while (-not $status -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        try { $status = Invoke-RestMethod -Uri 'http://127.0.0.1:9696/api/v1/system/status' -Headers $headers }
        catch { Write-Verbose "not up yet: $($_.Exception.Message)" }
    }
    if (-not $status) { throw 'Prowlarr did not answer within 180 s' }
    if ($status.version -ne $env:VERSION) { throw "version is $($status.version), expected $env:VERSION" }
    $schema = Invoke-RestMethod -Uri 'http://127.0.0.1:9696/api/v1/indexer/schema' -Headers $headers
    $found = @($schema | Where-Object { $_.implementation -eq $env:INDEXER })
    if ($found.Count -eq 0) { throw "indexer $env:INDEXER is not in /api/v1/indexer/schema" }
    Write-Output "Smoke test OK: Prowlarr $($status.version) on .NET $($status.runtimeVersion), indexer $env:INDEXER present"
}
finally {
    docker logs smoke 2>&1 | Select-Object -Last 40
    docker rm --force smoke | Out-Null
}

$env:REGISTRY_TOKEN | docker login ghcr.io --username $env:GITHUB_ACTOR --password-stdin
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
        "- Prowlarr version: $env:VERSION (started and listed indexer $env:INDEXER)",
        "- PR head: $env:PR_SHA, base: $env:BASE_SHA"
    ) | Add-Content -Path $env:GITHUB_STEP_SUMMARY
}
