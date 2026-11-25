# Deploy already-built, already-scanned local images. Does not pull or publish.
param(
    [string]$Project='scripts',
    [string[]]$ExtraComposeFiles=@(),
    [string]$BaseUrl='http://localhost:8080',
    [int]$WebPort=8080,
    [switch]$Metrics
)
$ErrorActionPreference='Stop'
$argsList=@('compose','-p',$Project,'-f',(Join-Path $PSScriptRoot 'docker-compose.yml'))
foreach($file in $ExtraComposeFiles){$argsList+=@('-f',$file)}
$argsList+=@('-f',(Join-Path $PSScriptRoot 'docker-compose.hardened-local.yml'),'-f',(Join-Path $PSScriptRoot 'docker-compose.beta-hardened-local.yml'))
if($Metrics){$argsList+=@('--profile','metrics')}
& docker @argsList config --quiet
if($LASTEXITCODE -ne 0){throw 'Invalid Compose configuration'}
& docker @argsList up -d --pull never
if($LASTEXITCODE -ne 0){throw 'Deployment failed; inspect service status before retrying'}
$web=& docker @argsList ps -q openrmf-web
if($LASTEXITCODE -ne 0 -or -not $web){throw 'Web container unavailable'}
# NGINX 1.20 caches upstream addresses; refresh after API container recreation.
docker exec $web nginx -t
if($LASTEXITCODE -ne 0){throw 'NGINX configuration invalid'}
docker exec $web nginx -s reload
if($LASTEXITCODE -ne 0){throw 'NGINX reload failed'}
& (Join-Path $PSScriptRoot 'verify-port-boundary.ps1') -Project $Project -WebPort $WebPort
& (Join-Path $PSScriptRoot 'verify-hardened-http.ps1') -BaseUrl $BaseUrl
