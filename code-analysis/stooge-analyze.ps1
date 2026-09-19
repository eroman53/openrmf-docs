<#
    STOOGE static code analysis driver.
    Copyright (c) eroman53 2026.
    Licensed under the GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007.
    See the LICENSE file in the project root for full license information.

    Runs the Roslyn analyzers over the STOOGE service repos, merges the per-repo
    SARIF into one normalized SARIF 2.1.0 artifact, writes a human-readable
    report, and optionally uploads the artifact to STOOGE's scan history API
    (scanType=sarif) so static-analysis findings get the same delta tracking and
    trend history as Nessus and Trivy results.

    No extra tooling is required: the analyzers ship with the .NET SDK and SARIF
    comes straight from MSBuild's ErrorLog. Nothing to install, nothing to
    air-gap, nothing to keep patched.

    Usage:
      pwsh -File stooge-analyze.ps1
      pwsh -File stooge-analyze.ps1 -Repo openrmf-api-oscal -PreCommit
      pwsh -File stooge-analyze.ps1 -Upload -SystemGroupId <id> -Password '...'
#>
[CmdletBinding()]
param(
    # Repo(s) to analyze. Default: every entry in repos.txt.
    [string[]] $Repo,

    # Root holding the repo checkouts. Default: the parent of openrmf-docs.
    [string] $SourceRoot,

    # Where SARIF + report land. Default: <SourceRoot>/test-artifacts/code-analysis.
    [string] $OutputPath,

    # Hook mode: build only, fail on analyzer errors, no merge/report/upload.
    [switch] $PreCommit,

    # Skip the report (SARIF only).
    [switch] $NoReport,

    # Publish the merged SARIF to STOOGE scan history as scanType=sarif.
    [switch] $Upload,
    [string] $SystemGroupId,
    # Must be a URL the services accept as the token issuer. Keycloak stamps the
    # issuer with whatever host the token was requested through, and each service
    # validates it against ValidIssuers, so http://localhost:8080 authenticates
    # fine and is then rejected by every API with an issuer mismatch. Use the
    # address the stack is actually published on, or set STOOGE_BASEURL.
    [string] $BaseUrl   = $(if ($env:STOOGE_BASEURL) { $env:STOOGE_BASEURL } else { 'http://localhost:8080' }),
    [string] $Realm     = 'openrmf',
    [string] $ClientId  = 'openrmf',
    [string] $User      = 'testadmin',

    # Omit it and the script prompts. For unattended runs set STOOGE_UPLOAD_PASSWORD
    # in the environment rather than passing a literal, which would land the
    # credential in shell history and in any process listing.
    [SecureString] $Password,

    # Reuse existing obj/bin. Faster, but analyzers only re-run on projects that
    # actually recompile, so a full report should not use it.
    [switch] $Incremental
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $SourceRoot) { $SourceRoot = Split-Path -Parent (Split-Path -Parent $scriptDir) }
if (-not $OutputPath) { $OutputPath = Join-Path $SourceRoot 'test-artifacts/code-analysis' }

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Warn2($msg) { Write-Host "    $msg" -ForegroundColor Yellow }

# ---------------------------------------------------------------- repo set ---
if (-not $Repo -or $Repo.Count -eq 0) {
    $listFile = Join-Path $scriptDir 'repos.txt'
    if (-not (Test-Path $listFile)) { throw "repo list not found: $listFile" }
    $Repo = Get-Content $listFile |
            Where-Object { $_.Trim() -ne '' -and -not $_.TrimStart().StartsWith('#') } |
            ForEach-Object { $_.Trim() }
}

$runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$sarifDir = Join-Path $OutputPath 'sarif'
New-Item -ItemType Directory -Force -Path $sarifDir | Out-Null

# ------------------------------------------------------------------ build ----
$projects = @()
foreach ($r in $Repo) {
    $repoPath = Join-Path $SourceRoot $r
    if (-not (Test-Path $repoPath)) { Write-Warn2 "skipping $r (not checked out)"; continue }
    $found = Get-ChildItem -Path (Join-Path $repoPath 'src') -Filter '*.csproj' -ErrorAction SilentlyContinue
    if (-not $found) { Write-Warn2 "skipping $r (no src/*.csproj)"; continue }
    foreach ($p in $found) {
        $projects += [pscustomobject]@{ Repo = $r; RepoPath = $repoPath; Project = $p.FullName; Name = $p.BaseName }
    }
}
if ($projects.Count -eq 0) { throw 'no projects to analyze' }

$buildFailures = @()
$sarifFiles    = @()
foreach ($p in $projects) {
    Write-Step "analyzing $($p.Repo)"
    $sarif = Join-Path $sarifDir "$($p.Name).sarif"
    # MSBuild wants the SARIF version appended to ErrorLog after a semicolon;
    # the semicolon has to be %3B-escaped or MSBuild reads it as a list break.
    $buildArgs = @('build', $p.Project, '-v', 'q', '--nologo', "-p:ErrorLog=$sarif%3Bversion=2.1")
    if (-not $Incremental) { $buildArgs += '--no-incremental' }
    $log = & dotnet @buildArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        $buildFailures += [pscustomobject]@{ Repo = $p.Repo; Output = ($log -join [Environment]::NewLine) }
        Write-Host ($log -join [Environment]::NewLine) -ForegroundColor Red
    }
    if (Test-Path $sarif) { $sarifFiles += [pscustomobject]@{ Repo = $p.Repo; Path = $sarif } }
}

if ($buildFailures.Count -gt 0) {
    Write-Host ''
    Write-Host "BUILD FAILED in: $(($buildFailures.Repo | Sort-Object -Unique) -join ', ')" -ForegroundColor Red
    Write-Host 'Analyzer rules in the "error" tier (see .editorconfig) break the build by design.' -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------ read results ---
# Normalize every result into one flat shape. The important transform is the
# path: Roslyn writes absolute file:/// URIs, which would make the same finding
# look different on another machine and read as gibberish in the UI. Rewritten
# to "<repo>/src/Dir/File.cs", findings key stably across machines and the scan
# history "host" column reads as the file the finding lives in.
$rulesById = @{}
$results   = @()
$suppressedCount = 0
foreach ($s in $sarifFiles) {
    $json = Get-Content $s.Path -Raw | ConvertFrom-Json
    foreach ($run in $json.runs) {
        foreach ($rule in $run.tool.driver.rules) {
            if (-not $rulesById.ContainsKey($rule.id)) {
                $cat = $null
                if ($rule.PSObject.Properties.Name -contains 'properties' -and $rule.properties) {
                    if ($rule.properties.PSObject.Properties.Name -contains 'category') { $cat = $rule.properties.category }
                }
                $rulesById[$rule.id] = [pscustomobject]@{
                    id       = $rule.id
                    name     = $rule.shortDescription.text
                    full     = $rule.fullDescription.text
                    helpUri  = $rule.helpUri
                    category = $cat
                }
            }
        }
        foreach ($res in $run.results) {
            # Roslyn writes in-source suppressions into the ErrorLog as ordinary
            # results carrying a "suppressions" array, not as omissions. Counting
            # them would report findings that a reviewer already dispositioned
            # with a written justification, and would upload them to STOOGE as if
            # they were open. Count them separately and move on.
            if ($res.PSObject.Properties.Name -contains 'suppressions' -and @($res.suppressions).Count -gt 0) {
                $script:suppressedCount++
                continue
            }
            $uri  = $null; $line = 0
            $loc  = @($res.locations)[0]
            if ($loc -and $loc.physicalLocation) {
                $uri = $loc.physicalLocation.artifactLocation.uri
                if ($loc.physicalLocation.region) { $line = [int]$loc.physicalLocation.region.startLine }
            }
            $rel = '(project)'
            if ($uri) {
                $decoded = [Uri]::UnescapeDataString(($uri -replace '^file:///', ''))
                $decoded = $decoded -replace '\\', '/'
                $marker  = '/' + $s.Repo + '/'
                $ix = $decoded.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase)
                if ($ix -ge 0) { $rel = $decoded.Substring($ix + 1) }
                else { $rel = $s.Repo + '/' + (Split-Path -Leaf $decoded) }
            }
            $lvl = 'warning'
            if ($res.PSObject.Properties.Name -contains 'level' -and $res.level) { $lvl = $res.level }
            $results += [pscustomobject]@{
                repo    = $s.Repo
                ruleId  = $res.ruleId
                level   = $lvl
                message = $res.message.text
                file    = $rel
                line    = $line
            }
        }
    }
}

# Deduplicate: a file compiled into more than one project reports more than once.
$results = @($results | Sort-Object repo, file, line, ruleId |
           Group-Object { "$($_.repo)|$($_.file)|$($_.line)|$($_.ruleId)" } |
           ForEach-Object { $_.Group[0] })

$errCount = @($results | Where-Object { $_.level -eq 'error' }).Count
$warnCount = @($results | Where-Object { $_.level -eq 'warning' }).Count
$security = @($results | Where-Object { $rulesById.ContainsKey($_.ruleId) -and $rulesById[$_.ruleId].category -eq 'Security' })
$repoCount = @($projects.Repo | Sort-Object -Unique).Count

Write-Host ''
$supNote = ''
if ($suppressedCount -gt 0) { $supNote = "  ($suppressedCount suppressed in source)" }
Write-Step "$($results.Count) findings across $repoCount repos  [$errCount error / $warnCount warning / $($security.Count) security]$supNote"

if ($PreCommit) {
    # The commit has already passed if the build succeeded. Print the local
    # warning count so the committer sees their debt without being blocked.
    exit 0
}

# ------------------------------------------------------- merged artifact -----
# One SARIF run carrying every repo -- this is what gets uploaded.
# security-severity is stamped onto Security-category rules so STOOGE's SARIF
# importer scores them HIGH instead of inferring MEDIUM from the "warning" level.
$sdkVersion = (& dotnet --version).Trim()
# Only rules that actually fired. Roslyn's ErrorLog describes the entire rule
# catalog whether or not it produced a result, which would make most of the
# uploaded artifact metadata for rules nothing tripped.
$firedRuleIds = @{}
foreach ($f in $results) { $firedRuleIds[$f.ruleId] = $true }
$mergedRules = @()
foreach ($r in ($rulesById.Values | Where-Object { $firedRuleIds.ContainsKey($_.id) } | Sort-Object id)) {
    $props = @{ category = "$($r.category)" }
    if ($r.category -eq 'Security') { $props['security-severity'] = '7.5' }
    $rule = [ordered]@{
        id               = $r.id
        shortDescription = @{ text = "$($r.name)" }
        properties       = $props
    }
    if ($r.full)    { $rule['fullDescription'] = @{ text = "$($r.full)" } }
    if ($r.helpUri) { $rule['helpUri']         = "$($r.helpUri)" }
    $mergedRules += $rule
}
$mergedResults = @()
foreach ($f in $results) {
    $mergedResults += [ordered]@{
        ruleId    = $f.ruleId
        level     = $f.level
        message   = @{ text = "$($f.message)" }
        locations = @(@{ physicalLocation = @{
            artifactLocation = @{ uri = $f.file }
            region           = @{ startLine = [Math]::Max(1, $f.line) }
        } })
    }
}
$merged = [ordered]@{
    'version' = '2.1.0'
    '$schema' = 'https://json.schemastore.org/sarif-2.1.0.json'
    'runs'    = @([ordered]@{
        tool = @{ driver = [ordered]@{
            name            = 'STOOGE Static Analysis'
            fullName        = 'STOOGE Static Analysis (.NET Roslyn analyzers)'
            informationUri  = 'https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview'
            semanticVersion = $sdkVersion
            rules           = $mergedRules
        } }
        results = $mergedResults
    })
}
$mergedPath = Join-Path $OutputPath "stooge-code-analysis-$runStamp.sarif"
$merged | ConvertTo-Json -Depth 20 | Set-Content -Path $mergedPath -Encoding utf8
Write-Step "artifact: $mergedPath"

# --------------------------------------------------------------- report ------
$reportPath = $null
if (-not $NoReport) {
    $byRule = $results | Group-Object ruleId | Sort-Object Count -Descending
    $byRepo = $results | Group-Object repo   | Sort-Object Count -Descending
    $byFile = $results | Group-Object file   | Sort-Object Count -Descending

    $md = [System.Collections.Generic.List[string]]::new()
    $md.Add('# STOOGE static code analysis')
    $md.Add('')
    $md.Add("Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') by stooge-analyze.ps1 using the .NET $sdkVersion Roslyn analyzers.")
    $md.Add('Ruleset: code-analysis/.editorconfig. Security category breaks the build, a curated correctness set warns, style and design noise is off.')
    $md.Add('')
    $md.Add('| Measure | Count |')
    $md.Add('|---|---|')
    $md.Add("| Repositories analyzed | $repoCount |")
    $md.Add("| Total findings | $($results.Count) |")
    $md.Add("| Build-breaking (error) | $errCount |")
    $md.Add("| Warnings | $warnCount |")
    $md.Add("| Security category | $($security.Count) |")
    $md.Add("| Distinct rules triggered | $($byRule.Count) |")
    $md.Add("| Suppressed in source with a written justification | $suppressedCount |")
    $md.Add('')

    $md.Add('## Security findings')
    $md.Add('')
    if ($security.Count -eq 0) {
        $md.Add("None. Every rule in the analyzers' Security category is clean.")
    } else {
        $md.Add('These carry the Security category and upload to STOOGE at HIGH severity.')
        $md.Add('')
        $md.Add('| Rule | What it means | Where |')
        $md.Add('|---|---|---|')
        foreach ($g in ($security | Group-Object ruleId | Sort-Object Count -Descending)) {
            $desc  = $rulesById[$g.Name].name
            $where = (($g.Group | ForEach-Object { "$($_.file):$($_.line)" } | Select-Object -First 6) -join '<br>')
            if ($g.Count -gt 6) { $where += "<br>...and $($g.Count - 6) more" }
            $md.Add("| $($g.Name) ($($g.Count)) | $desc | $where |")
        }
    }
    $md.Add('')

    $md.Add('## Findings by rule')
    $md.Add('')
    $md.Add('| Rule | Count | Description |')
    $md.Add('|---|---|---|')
    foreach ($g in $byRule) {
        $d = ''
        if ($rulesById.ContainsKey($g.Name)) { $d = $rulesById[$g.Name].name }
        $md.Add("| $($g.Name) | $($g.Count) | $d |")
    }
    $md.Add('')

    $md.Add('## Findings by repository')
    $md.Add('')
    $md.Add('| Repository | Findings | Top rule |')
    $md.Add('|---|---|---|')
    foreach ($g in $byRepo) {
        $top = ($g.Group | Group-Object ruleId | Sort-Object Count -Descending | Select-Object -First 1)
        $md.Add("| $($g.Name) | $($g.Count) | $($top.Name) ($($top.Count)) |")
    }
    $md.Add('')

    $md.Add('## Files with the most findings')
    $md.Add('')
    $md.Add('| File | Findings |')
    $md.Add('|---|---|')
    foreach ($g in ($byFile | Select-Object -First 20)) { $md.Add("| $($g.Name) | $($g.Count) |") }
    $md.Add('')

    $md.Add('## Full finding list')
    $md.Add('')
    $md.Add('| File | Line | Rule | Level | Message |')
    $md.Add('|---|---|---|---|---|')
    foreach ($f in ($results | Sort-Object file, line)) {
        $msg = ($f.message -replace '\|', '\|') -replace '[\r\n]+', ' '
        if ($msg.Length -gt 180) { $msg = $msg.Substring(0, 180) + '...' }
        $md.Add("| $($f.file) | $($f.line) | $($f.ruleId) | $($f.level) | $msg |")
    }

    $reportPath = Join-Path $OutputPath "stooge-code-analysis-$runStamp.md"
    $md -join [Environment]::NewLine | Set-Content -Path $reportPath -Encoding utf8
    Write-Step "report:   $reportPath"
}

# --------------------------------------------------------------- upload ------
if ($Upload) {
    if (-not $SystemGroupId) { throw '-Upload requires -SystemGroupId (the STOOGE system package to file the scan under)' }
    if (-not $Password) {
        if ($env:STOOGE_UPLOAD_PASSWORD) {
            $Password = ConvertTo-SecureString $env:STOOGE_UPLOAD_PASSWORD -AsPlainText -Force
        } else {
            $Password = Read-Host -AsSecureString "Keycloak password for $User"
        }
    }
    Write-Step "uploading to $BaseUrl (system $SystemGroupId)"
    # Keycloak's token endpoint takes a form post, so the secret has to be plain
    # text for exactly the length of this call. Held in a local and cleared after.
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                 [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
    $tokenUri = "$BaseUrl/auth/realms/$Realm/protocol/openid-connect/token"
    try {
        $token = (Invoke-RestMethod -Method Post -Uri $tokenUri -Body @{
            grant_type = 'password'; client_id = $ClientId; username = $User; password = $plain
        }).access_token
    } finally {
        $plain = $null
    }
    if (-not $token) { throw 'authentication failed: no access_token returned' }

    $uploadUri = "$BaseUrl/api/scanhistory/scan/$SystemGroupId"
    $resp = Invoke-RestMethod -Method Post -Uri $uploadUri `
                -Headers @{ Authorization = "Bearer $token" } `
                -Form @{ scanType = 'sarif'; scanFile = Get-Item $mergedPath }
    Write-Step "stored as scan $($resp.id): $($resp.newFindings) new, $($resp.resolvedFindings) resolved, $($resp.persistingFindings) persisting"
}

exit 0
