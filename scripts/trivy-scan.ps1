<#
    Trivy security scan for the STOOGE stack: our repositories and the images
    built from them.
    Copyright (c) eroman53 2026.
    Licensed under the GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007.
    See the LICENSE file in the project root for full license information.

        .\trivy-scan.ps1              full tables, repos then images
        .\trivy-scan.ps1 -Summary     one CRITICAL/HIGH line per image
        .\trivy-scan.ps1 -Json        also write JSON reports

    The image list is DERIVED FROM docker-compose.yml rather than written out
    here. The previous copy of this script kept its own list, and that list went
    stale: it was still scanning three ":test" tags compose had stopped using
    and four listener repositories that had been merged into openrmf-msg-hub. A
    scan of images nothing runs does not fail. It reports clean, which is worse
    than not scanning, because it looks like evidence.
#>
param(
    [switch]$Json,
    [switch]$Summary,
    [string]$Root = 'd:\OpenRMF_Build'
)

$ErrorActionPreference = 'Stop'
$trivy = Join-Path $Root 'tools\trivy\trivy.exe'
if (-not (Test-Path $trivy)) { throw "trivy not found at $trivy" }
$out = Join-Path $PSScriptRoot 'trivy-reports'
New-Item -ItemType Directory -Force $out | Out-Null

# --- the image set, straight from the compose file the stack actually runs ---
$composePath = Join-Path $PSScriptRoot 'docker-compose.yml'
$images = @(Select-String -Path $composePath -Pattern '^\s*image:\s*(eroman53/\S+)' |
            ForEach-Object { $_.Matches[0].Groups[1].Value } | Sort-Object -Unique)
if ($images.Count -eq 0) { throw "no eroman53 images found in $composePath" }

# The shared runtime base is a build dependency rather than a running service,
# so it is not in compose. Every .NET service inherits its findings, which is
# why they all report the same count.
$base = 'eroman53/openrmf-base-ubi:8.10'
if ($images -notcontains $base) { $images += $base }

# Repos to filesystem-scan: the checkout matching each service image, where one
# exists. Keycloak and the base image are built from folders inside openrmf-docs.
$repos = @($images |
    ForEach-Object { ($_ -replace '^eroman53/', '') -replace ':.*$', '' } |
    Where-Object { Test-Path (Join-Path $Root $_) } | Sort-Object -Unique)

Write-Output "=== scanning $($repos.Count) repo(s) and $($images.Count) image(s) ==="

if ($Summary) {
    Write-Output ''
    Write-Output '=== CRITICAL/HIGH per image ==='
    $worst = 0
    foreach ($i in $images) {
        # NOT $json: PowerShell variable names are case-insensitive, so that
        # would overwrite the -Json switch parameter with a report object.
        $report = & $trivy image --severity CRITICAL,HIGH --quiet --format json $i 2>$null | ConvertFrom-Json
        $c = 0; $h = 0
        foreach ($r in $report.Results) {
            foreach ($v in $r.Vulnerabilities) {
                if ($v.Severity -eq 'CRITICAL') { $c++ } elseif ($v.Severity -eq 'HIGH') { $h++ }
            }
        }
        if ($c -gt 0) { $worst = 1 }
        Write-Output ("{0,-48} CRIT={1,-4} HIGH={2}" -f $i, $c, $h)
    }
    Write-Output ''
    if ($worst -eq 0) { Write-Output 'No CRITICAL findings.' }
    else { Write-Output 'CRITICAL findings present -- do not push.' }
    exit $worst
}

Write-Output ''
Write-Output '=== filesystem scans (vuln + secret + misconfig, CRITICAL/HIGH/MEDIUM) ==='
foreach ($r in $repos) {
    Write-Output "--- $r"
    & $trivy fs --scanners vuln,secret,misconfig --severity CRITICAL,HIGH,MEDIUM --quiet (Join-Path $Root $r)
    if ($Json) {
        & $trivy fs --scanners vuln,secret,misconfig --severity CRITICAL,HIGH,MEDIUM --quiet `
                 --format json --output (Join-Path $out "$r.json") (Join-Path $Root $r)
    }
}

Write-Output ''
Write-Output '=== image scans (CRITICAL/HIGH) ==='
foreach ($i in $images) {
    Write-Output "--- $i"
    & $trivy image --severity CRITICAL,HIGH --quiet $i
    if ($Json) {
        $safe = ($i -replace '[/:]', '_')
        & $trivy image --severity CRITICAL,HIGH --quiet --format json --output (Join-Path $out "image-$safe.json") $i
    }
}
