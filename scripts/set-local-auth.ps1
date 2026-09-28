<#
Synchronize a local STOOGE deployment's API issuers and Keycloak browser URLs.
Run against an initialized, running stack, then run docker compose up -d.
Existing non-local URLs are preserved. No credentials or tokens are printed.
#>
param(
    [string[]]$Origins = @('http://localhost:8080', 'http://127.0.0.1:8080'),
    [string]$EnvFile = (Join-Path $PSScriptRoot '.env')
)
$ErrorActionPreference = 'Stop'
$originsNormalized = @($Origins | ForEach-Object {
    $uri = [uri]$_
    if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notin @('http', 'https') -or
        $uri.AbsolutePath -ne '/' -or $uri.Query -or $uri.Fragment -or $uri.UserInfo) {
        throw "Expected an HTTP(S) origin without a path: $_"
    }
    $uri.GetLeftPart([UriPartial]::Authority)
} | Select-Object -Unique)
$content = [IO.File]::ReadAllText($EnvFile)
$match = [regex]::Match($content, '(?m)^JWTAUTHORITY=([^\r\n]*)')
if (-not $match.Success) { throw 'JWTAUTHORITY is missing from the environment file.' }
$issuers = @($match.Groups[1].Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$issuers += @($originsNormalized | ForEach-Object { "$_/auth/realms/openrmf" })
$issuers = @($issuers | Select-Object -Unique)

# Authenticate inside the container so its existing credentials stay there.
docker exec openrmf-keycloak sh -c '/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user "$KEYCLOAK_ADMIN" --password "$KEYCLOAK_ADMIN_PASSWORD" >/dev/null'
if ($LASTEXITCODE -ne 0) { throw 'Keycloak administrator login failed.' }
$clientJson = docker exec openrmf-keycloak /opt/keycloak/bin/kcadm.sh get clients -r openrmf -q clientId=openrmf --fields id,redirectUris,webOrigins
if ($LASTEXITCODE -ne 0) { throw 'Could not read the OpenRMF client.' }
$clients = @((($clientJson -join "`n") | ConvertFrom-Json))
if ($clients.Count -ne 1) { throw 'Expected exactly one OpenRMF client.' }
$client = $clients[0]
$redirects = @(@($client.redirectUris) + @($originsNormalized | ForEach-Object { "$_/*" }) | Select-Object -Unique)
$webOrigins = @(@($client.webOrigins) + $originsNormalized | Select-Object -Unique)
$redirectJson = ConvertTo-Json -InputObject $redirects -Compress
$originJson = ConvertTo-Json -InputObject $webOrigins -Compress
docker exec openrmf-keycloak /opt/keycloak/bin/kcadm.sh update "clients/$($client.id)" -r openrmf -s "redirectUris=$redirectJson" -s "webOrigins=$originJson"
if ($LASTEXITCODE -ne 0) { throw 'Could not update the OpenRMF client.' }

$content = $content.Replace($match.Value, ('JWTAUTHORITY=' + ($issuers -join ',')))
# Same-origin browser requests need no CORS exception, but keep an explicit
# CORS allowlist consistent when this deployment has configured one.
$cors = [regex]::Match($content, '(?m)^CORSORIGINS=([^\r\n]*)')
if ($cors.Success) {
    $allowed = @(@($cors.Groups[1].Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) + $originsNormalized | Select-Object -Unique)
    $content = $content.Replace($cors.Value, ('CORSORIGINS=' + ($allowed -join ',')))
}
[IO.File]::WriteAllText($EnvFile, $content, [Text.UTF8Encoding]::new($false))
Write-Output ('Configured browser origins: ' + ($originsNormalized -join ', '))
Write-Output 'Run docker compose up -d to recreate APIs with the updated issuer allowlist. A plain restart does not reload .env.'
