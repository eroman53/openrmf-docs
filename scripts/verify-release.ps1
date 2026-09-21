<#
  Fast, offline release checks for the checked-in deployment definition.
  Run this before pushing a compose or image-version change.
#>
param(
    [string]$EnvFile = '.env.example'
)

$ErrorActionPreference = 'Stop'
$compose = Join-Path $PSScriptRoot 'docker-compose.yml'
$production = Join-Path $PSScriptRoot 'docker-compose.production.yml'
$content = Get-Content -Raw $compose

$forbidden = @('openrmf\d{4,}!', 'MONGO_INITDB_ROOT_PASSWORD=(?!\$\{)', 'POSTGRES_PASSWORD=(?!\$\{)', ':latest')
foreach ($pattern in $forbidden) {
    if ($content -match $pattern) { throw "Release compose contains a forbidden credential or mutable image reference: $pattern" }
}

if (-not (Test-Path (Join-Path $PSScriptRoot $EnvFile))) {
    throw "Environment template not found: $EnvFile"
}

docker compose --env-file $EnvFile -f $compose -f $production config --quiet
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose configuration validation failed.' }

Write-Output 'Release compose checks passed: no known embedded credentials, no latest tags, and production overlay is valid.'
