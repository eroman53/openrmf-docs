param([string]$BaseUrl='http://localhost:8080')
$ErrorActionPreference='Stop'
$settings=@{}
Get-Content (Join-Path $PSScriptRoot '.env') | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$') { $settings[$matches[1]]=$matches[2] }
}
$routes=@('read','poam','scanhistory','journal','scanwatch','conmon','inventory','ppsm','oscal','tasks','trivyscan','notify','template','scoring','control','audit','report')
foreach($route in $routes){
    $response=Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 "$BaseUrl/api/$route/healthz"
    if($response.StatusCode -ne 200){throw "Health failed: $route"}
}
$token=Invoke-RestMethod "$BaseUrl/auth/realms/openrmf/protocol/openid-connect/token" -Method Post -Body @{client_id='openrmf';grant_type='password';username=$settings.STOOGE_INITIAL_ADMIN_USERNAME;password=$settings.STOOGE_INITIAL_ADMIN_PASSWORD}
if(-not $token.access_token){throw 'Authentication failed'}
$headers=@{Authorization="Bearer $($token.access_token)"}
$systems=Invoke-RestMethod "$BaseUrl/api/read/artifact/systems" -Headers $headers -TimeoutSec 30
Write-Output "PASS: 17 health routes, authentication and authenticated systems read at $BaseUrl."
