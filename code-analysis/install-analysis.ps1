<#
    Installs the STOOGE static analysis config into every in-scope repo.
    Copyright (c) eroman53 2026.
    Licensed under the GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007.
    See the LICENSE file in the project root for full license information.

    Copies the canonical Directory.Build.props and stooge.editorconfig (as
    .editorconfig) to each repo root, ignores the analysis output folder, and
    installs the pre-commit hook into each repo's .git/hooks.

    The config files are COPIED, not symlinked, so each repo stays independently
    buildable and the ruleset travels in its own history. Re-run this after
    editing the canonical copies; -Check reports drift without writing.

    Usage:
      pwsh -File install-analysis.ps1            # install or refresh everything
      pwsh -File install-analysis.ps1 -Check     # report drift, change nothing
      pwsh -File install-analysis.ps1 -HooksOnly # only (re)install git hooks
#>
[CmdletBinding()]
param(
    [string] $SourceRoot,
    [string[]] $Repo,
    [switch] $Check,
    [switch] $HooksOnly,
    [switch] $NoHooks
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $SourceRoot) { $SourceRoot = Split-Path -Parent (Split-Path -Parent $scriptDir) }

if (-not $Repo -or $Repo.Count -eq 0) {
    $Repo = Get-Content (Join-Path $scriptDir 'repos.txt') |
            Where-Object { $_.Trim() -ne '' -and -not $_.TrimStart().StartsWith('#') } |
            ForEach-Object { $_.Trim() }
}

$propsSrc  = Join-Path $scriptDir 'Directory.Build.props'
$editorSrc = Join-Path $scriptDir 'stooge.editorconfig'
$hookSrc   = Join-Path $scriptDir 'hooks/pre-commit'
foreach ($f in @($propsSrc, $editorSrc, $hookSrc)) {
    if (-not (Test-Path $f)) { throw "missing canonical file: $f" }
}

function Same-Content($a, $b) {
    if (-not (Test-Path $b)) { return $false }
    return ((Get-FileHash $a).Hash -eq (Get-FileHash $b).Hash)
}

$drift = 0
foreach ($r in $Repo) {
    $repoPath = Join-Path $SourceRoot $r
    if (-not (Test-Path $repoPath)) { Write-Host "skip   $r (not checked out)" -ForegroundColor Yellow; continue }

    if (-not $HooksOnly) {
        foreach ($pair in @(
            @{ src = $propsSrc;  dst = (Join-Path $repoPath 'Directory.Build.props') },
            @{ src = $editorSrc; dst = (Join-Path $repoPath '.editorconfig') })) {

            if (Same-Content $pair.src $pair.dst) {
                Write-Host "ok     $r/$(Split-Path -Leaf $pair.dst)" -ForegroundColor DarkGray
            } elseif ($Check) {
                Write-Host "DRIFT  $r/$(Split-Path -Leaf $pair.dst)" -ForegroundColor Yellow
                $drift++
            } else {
                Copy-Item $pair.src $pair.dst -Force
                Write-Host "wrote  $r/$(Split-Path -Leaf $pair.dst)" -ForegroundColor Green
            }
        }

        # Nothing to add to .gitignore. SARIF and reports are written to
        # test-artifacts/code-analysis, outside every repo, and the analyzers'
        # own intermediates land in obj/, which is already ignored.
    }

    if (-not $NoHooks) {
        $hookDir = Join-Path $repoPath '.git/hooks'
        if (-not (Test-Path $hookDir)) { Write-Host "skip   $r hooks (no .git/hooks)" -ForegroundColor Yellow; continue }
        $hookDst = Join-Path $hookDir 'pre-commit'
        if (Same-Content $hookSrc $hookDst) {
            Write-Host "ok     $r/.git/hooks/pre-commit" -ForegroundColor DarkGray
        } elseif ($Check) {
            Write-Host "DRIFT  $r/.git/hooks/pre-commit" -ForegroundColor Yellow
            $drift++
        } else {
            if ((Test-Path $hookDst) -and -not (Select-String -Path $hookDst -Pattern 'STOOGE pre-commit' -Quiet)) {
                Copy-Item $hookDst "$hookDst.bak" -Force
                Write-Host "       existing non-STOOGE hook backed up to pre-commit.bak" -ForegroundColor Yellow
            }
            Copy-Item $hookSrc $hookDst -Force
            Write-Host "wrote  $r/.git/hooks/pre-commit" -ForegroundColor Green
        }
    }
}

if ($Check) {
    if ($drift -gt 0) { Write-Host "`n$drift file(s) drifted from the canonical copies; re-run without -Check." -ForegroundColor Yellow; exit 1 }
    Write-Host "`nAll in-scope repos match the canonical analysis config." -ForegroundColor Green
}
exit 0
