# STOOGE static code analysis

Pre-commit static analysis for the STOOGE service repositories, plus a report and
a SARIF artifact that uploads into STOOGE itself.

## What it is

The .NET SDK already ships the Roslyn analyzers, and MSBuild already emits SARIF
2.1.0 through its `ErrorLog` property. That is the whole engine. There is no
package to restore, no binary to air-gap, no scanner service to patch, and no
second copy of the rules to keep in sync with the build.

Five small pieces sit on top of it:

| Piece | What it does |
|---|---|
| `Directory.Build.props` | Turns the analyzers on for every project in a repo, with every rule off by default. |
| `stooge.editorconfig` | The ruleset. Names each rule we want, one line at a time. |
| `stooge-analyze.ps1` | Builds, merges the per-repo SARIF, writes the report, uploads the artifact. |
| `hooks/pre-commit` | Runs the driver against the repo being committed and blocks on error-tier findings. |
| `install-analysis.ps1` | Copies the config into every in-scope repo and installs the hook. |

`repos.txt` lists the repos in scope: the fourteen STOOGE services plus the two
upstream forks we have modified. The reference-only upstream clones and the
superseded pre-v1.8 split services are deliberately excluded, because analyzing
code we do not edit would report someone else's debt as ours.

## The ruleset, and why it is shaped this way

Turning the whole catalog on produces 3,146 findings across the fork, and the
large majority are advice that does not apply here. `CA2007`
(`ConfigureAwait(false)`) alone accounts for hundreds, and it is meaningless in
ASP.NET Core, which has no synchronization context to deadlock against.
`CA1062` wants null guards on parameters that dependency injection is contractually
required to populate. A ruleset that loud gets muted, and a muted ruleset catches
nothing.

So `AnalysisMode=None` turns every rule off, and the ruleset names each rule it
wants back, one line at a time, in two tiers.

That per-rule literalness is not a stylistic choice, and it is worth knowing why
before anyone tries to tidy it. The obvious way to write this is two lines:

```ini
dotnet_analyzer_diagnostic.severity = none
dotnet_analyzer_diagnostic.category-Security.severity = error
```

Both are valid EditorConfig, both parse without complaint, and both do nothing
at all. The SDK does not implement `AnalysisMode` by leaving rules at their
defaults. It injects a generated `.globalconfig` carrying an explicit
`dotnet_diagnostic.<rule>.severity` line for every rule in the catalog, and
Roslyn resolves an explicit per-rule entry ahead of any bulk or category-wide
entry, wherever each came from. The generated entries therefore win, silently.
This was measured rather than assumed: a config written the tidy way silenced
nothing and the full 3,146 findings came back looking exactly as though the file
were absent. Per-rule entries do override the generated ones, so per-rule is
what the ruleset uses, all ninety-four security rules spelled out.

**Error tier — blocks the build, therefore blocks the commit.** The analyzers'
entire Security category: hardcoded keys, weak and broken cryptography, disabled
certificate validation, unsafe deserialization, unsafe XML processing, the
injection taint rules, insecure randomness. The list is copied from the SDK's own
security rule set rather than assembled by hand, so it is the analyzers'
definition of security, not ours.

This tier was chosen by measurement, not taste. Every rule in it was verified
clean across all sixteen repos before it was switched on, so turning it on broke
nothing and any future hit is genuinely new. Two things came out of that survey
and are worth knowing:

- `CA5404` (disabled token validation) fires twelve times, once in each service's
  `Startup`, on `ValidateAudience = false`. That is deliberate, so it sits at
  warning instead. It is not suppressed, because a suppression would hide it;
  as a warning it appears in the security section of every report and keeps the
  decision visible.
- `CA3003` (file path injection) fires three times in the Trivy service, all
  false positives against guards the taint analyzer cannot see. Those carry
  in-source `SuppressMessage` attributes with written justifications, which is
  the documented mechanism and leaves the reasoning next to the code. The driver
  counts suppressed findings separately and never uploads them as open.

**Warning tier — reported, never blocks.** Correctness rules that have real hits
today: catch-all exception handlers, objects disposed late, logging templates
whose placeholders do not match their arguments, and the globalization family
(`CA1304`, `CA1305`, `CA1307`, `CA1310`, `CA1311`), which is the one that matters
most here. This fork parses DISA, NIST and Nessus files for a living, and
culture-sensitive parsing and comparison is exactly the bug class that makes a
parser behave differently on a differently configured host.

**Off.** Style, naming, API-surface design and micro-performance. They are not
wrong, they are just not what this tool is for.

Ratchet, do not gate. The warning tier exists to be driven down over time. If it
were turned into errors today, nothing would build.

## Daily use

Install once, on a fresh checkout or after changing the canonical config:

```powershell
pwsh -File openrmf-docs/code-analysis/install-analysis.ps1
```

After that the hook runs itself. Committing C# in an in-scope repo builds that
repo with the analyzers and blocks only on the error tier:

```
stooge: running static analysis on openrmf-api-oscal ...
==> analyzing openrmf-api-oscal
==> 34 findings across 1 repos  [0 error / 33 warning / 1 security]
```

Escape hatches, for when the hook is in the way rather than doing its job:

```bash
STOOGE_SKIP_ANALYSIS=1 git commit ...   # skip this hook
git commit --no-verify ...              # skip all hooks
```

If the repos are not siblings of `openrmf-docs`, point the hook at the tooling
with `STOOGE_ANALYSIS_HOME`.

Two caveats that come with any build-based hook. It analyzes the working tree,
not the staged index, so partially staged changes are analyzed as they sit on
disk. And it builds, so the first run after a clean is slow; the hook passes
`-Incremental` to keep the rest fast.

## The report

A full run analyzes every in-scope repo and writes both outputs to
`test-artifacts/code-analysis/`:

```powershell
pwsh -File openrmf-docs/code-analysis/stooge-analyze.ps1
```

- `stooge-code-analysis-<stamp>.md` — the human-readable report: totals, a
  security section, findings by rule, by repository, by file, then the full list.
- `stooge-code-analysis-<stamp>.sarif` — the machine-readable artifact.

## The artifact in STOOGE

The merged SARIF uploads to the scan history API as `scanType=sarif`, which is
the generic static-analysis importer that already exists for Checkov, CodeQL and
Semgrep output:

```powershell
pwsh -File openrmf-docs/code-analysis/stooge-analyze.ps1 `
     -Upload -SystemGroupId <system package id> `
     -BaseUrl http://<host>:8080 -User testadmin
```

It files under a system package like any other scan. The platform's own source
has one, `STOOGE Platform Source`, created so these findings sit next to the
scans of the things STOOGE monitors without being mixed into them.

Give `-BaseUrl` the address the stack is actually published on, not
`http://localhost:8080`, or set `STOOGE_BASEURL` once. Keycloak stamps a token's
issuer with whatever host it was requested through, and every service validates
that issuer against a fixed list. A localhost token authenticates perfectly well
and is then rejected by each API, which surfaces as a truncated response rather
than a clear authorization error. Omit `-Password` and the script prompts;
`STOOGE_UPLOAD_PASSWORD` covers unattended runs without putting the credential
in shell history.

From there it is an ordinary STOOGE scan. It gets a stored immutable snapshot,
delta computation against the previous run (new, resolved and persisting findings
with `firstSeen`/`lastSeen`), trend history, and a place on the Container Security
and scan history views next to the Nessus and Trivy results.

Two details make that work properly rather than just technically:

**Paths are rewritten before upload.** Roslyn emits absolute `file:///D:/...`
URIs. The importer keys a finding on its location, so raw absolute paths would
make the same finding look new on a different machine and would read as noise in
the UI. The driver rewrites them to `<repo>/src/Dir/File.cs`, which is stable
across machines and reads as the file the finding lives in.

**Security findings are scored, not inferred.** SARIF has no severity, only a
`level`, and the importer would map every analyzer warning to MEDIUM. The driver
stamps `security-severity` onto Security-category rules so they arrive as HIGH.

One thing this deliberately does not do: `openrmf-msg-poam` filters on
`scanType=nessus`, so static-analysis findings never reach POA&M reconciliation.
Source code defects are not system vulnerabilities and should not open POA&M
items automatically.

## Changing the ruleset

Edit the canonical copies in this folder, then re-run the installer to push them
out. `install-analysis.ps1 -Check` reports which repos have drifted without
writing anything, which is the one to run if a build behaves differently in one
repo than another.

Every rule change is a one-line edit in `stooge.editorconfig` with a comment
saying why. Before promoting anything into the error tier, run a full analysis and
confirm the count is zero, or the promotion stops everyone's build instead of
preventing the next defect.
