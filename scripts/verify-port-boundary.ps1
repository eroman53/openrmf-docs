param([string]$Project = 'scripts', [int]$WebPort = 8080)
$ErrorActionPreference = 'Stop'
$ids = @(docker ps -q --filter "label=com.docker.compose.project=$Project")
if ($LASTEXITCODE -ne 0 -or $ids.Count -eq 0) { throw 'Deployment not found' }
$items = docker inspect $ids | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Container inspection failed' }
$webFound = $false
foreach ($item in $items) {
    $service = $item.Config.Labels.'com.docker.compose.service'
    foreach ($property in $item.NetworkSettings.Ports.PSObject.Properties) {
        foreach ($binding in @($property.Value)) {
            if ($null -eq $binding) { continue }
            if ($service -ne 'openrmf-web' -or $property.Name -ne '8080/tcp' -or [int]$binding.HostPort -ne $WebPort) {
                throw "Unexpected published port: $service $($property.Name) -> $($binding.HostIp):$($binding.HostPort)"
            }
            $webFound = $true
        }
    }
}
if (-not $webFound) { throw 'Expected web entry was not published' }
Write-Output "PASS: $Project publishes only web port $WebPort across $($items.Count) running containers."
