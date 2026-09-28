<# Verify browser redirects, issuer discovery, and authenticated API access. #>
param(
    [string[]]$Origins = @('http://localhost:8080', 'http://127.0.0.1:8080'),
    [string]$EnvFile = (Join-Path $PSScriptRoot '.env')
)
$ErrorActionPreference = 'Stop'
$settings = @{}
Get-Content -LiteralPath $EnvFile | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$') { $settings[$matches[1]] = $matches[2] }
}
$username = $env:STOOGE_VERIFY_USERNAME
$password = $env:STOOGE_VERIFY_PASSWORD
if (-not $username) { $username = $settings['STOOGE_INITIAL_ADMIN_USERNAME'] }
if (-not $password) { $password = $settings['STOOGE_INITIAL_ADMIN_PASSWORD'] }
if (-not $username -or -not $password) { throw 'Set STOOGE_VERIFY_USERNAME and STOOGE_VERIFY_PASSWORD for authenticated checks.' }
$healthServices = @('read','poam','scanhistory','journal','scanwatch','conmon','inventory','ppsm','oscal','tasks','trivyscan','notify','template','scoring','control','audit','report')
foreach ($origin in $Origins) {
    $base = $origin.TrimEnd('/')
    $issuer = "$base/auth/realms/openrmf"
    $discovery = Invoke-RestMethod "$issuer/.well-known/openid-configuration" -TimeoutSec 20
    if ($discovery.issuer -cne $issuer) { throw "Issuer mismatch for $base" }
    $redirect = [uri]::EscapeDataString("$base/")
    $login = Invoke-WebRequest -UseBasicParsing "$issuer/protocol/openid-connect/auth?client_id=openrmf&redirect_uri=$redirect&response_type=code&scope=openid" -TimeoutSec 20
    if ($login.StatusCode -ne 200 -or $login.Content -notmatch 'kc-form-login') { throw "Login form missing for $base" }
    $token = Invoke-RestMethod "$issuer/protocol/openid-connect/token" -Method Post -Body @{
        client_id = 'openrmf'; username = $username; password = $password; grant_type = 'password'
    } -TimeoutSec 20
    $headers = @{ Authorization = "Bearer $($token.access_token)" }
    foreach ($route in @('/api/read/artifact/systems','/api/tasks/tasks/mine','/api/conmon/conmon/posture','/api/oscal/status','/api/inventory/inventory/mappings')) {
        $response = Invoke-WebRequest -UseBasicParsing "$base$route" -Headers $headers -TimeoutSec 30
        if ($response.StatusCode -ne 200) { throw "Authenticated API failed: $base$route" }
    }
    $unauthorized = Invoke-WebRequest -UseBasicParsing "$base/api/read/artifact/systems" -SkipHttpErrorCheck -TimeoutSec 20
    if ($unauthorized.StatusCode -ne 401) { throw "Unauthenticated API request was not rejected for $base" }
    foreach ($service in $healthServices) {
        $health = Invoke-WebRequest -UseBasicParsing "$base/api/$service/healthz" -TimeoutSec 20
        if ($health.StatusCode -ne 200) { throw "Health check failed: $service at $base" }
    }
    Write-Output "PASS $base : issuer, login form, five authenticated APIs, unauthenticated rejection, 17 health routes"
}
