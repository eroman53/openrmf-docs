# STOOGE — Developer Onboarding

Welcome. **STOOGE** (STIG Tracking, Oversight & Organizational Governance Engine)
is a long-term fork of [OpenRMF OSS](https://github.com/Cingulara) (GPL-3.0) that
adds advanced RMF capabilities — scan history & vulnerability trends, a live
POA&M, SP 800-137 continuous monitoring, an asset inventory, review-task
tracking, container (Trivy) scanning, automated scan ingest, package-level RBAC,
and journaling/evidence. All new logic is independently implemented (no code from
OpenRMF Professional) and every fork service runs on a UBI8 (RHEL 8.10) base.

This doc gets you from a clean machine to a running stack.

---

## 1. Prerequisites

- **Docker Desktop** (Linux containers; give it ~8 GB RAM — the stack is ~34 containers)
- **.NET SDK 8.0** (services are net8.0, self-contained `linux-x64` publishes)
- **git** and, optionally, the **GitHub CLI** (`gh`) for cloning private repos
- A machine with a **stable LAN IP** — Keycloak/JWT validation is pinned to it
- Windows notes: the project was built on Windows 11; PowerShell examples below.
  On Linux/macOS the Docker + dotnet commands are identical.

You'll need **read access** to the 15 GitHub repos under `eroman53` (ask the owner
to add you as a collaborator, or accept the org invite).

---

## 2. Repo map & active branches

Clone all repos into **one parent folder** (paths below assume `D:\OpenRMF_Build`).
**Work is on feature branches, not `master`** for the forked repos — check out the
branch listed here.

**Forked from Cingulara** (`origin` = eroman53, `upstream` = cingulara):

| Repo | Branch | Purpose |
|---|---|---|
| `openrmf-web` | `feature/history-trends-live-poam` | UI — STOOGE pages & branding |
| `openrmf-docs` | `feature/nessus-scanhistory-gridfs` | compose stack, nginx, docs, diagrams |
| `openrmf-api-read` | `feature/nessus-scanhistory-gridfs` | save/upload/read API (Nessus → GridFS) |
| `openrmf-msg-reports` | `feature/nessus-scanhistory-gridfs` | report listener (reads scans from GridFS) |

**New fork services** (branch `master`):

| Repo | Port | Purpose |
|---|---|---|
| `openrmf-api-scanhistory` | 8100 | GridFS scan storage + delta/trend engine (Nessus + Trivy) |
| `openrmf-api-poam` | 8102 | live POA&M CRUD, merge rule, XLSX export |
| `openrmf-msg-poam` | — | POA&M reconciliation NATS listener |
| `openrmf-api-journal` | 8104 | change journal, notes, GridFS evidence |
| `openrmf-msg-journal` | — | journal NATS listener |
| `openrmf-svc-scanwatch` | 8106 | SMB/folder watch-folder scan ingest |
| `openrmf-api-conmon` | 8108 | SP 800-137 continuous-monitoring posture |
| `openrmf-api-inventory` | 8110 | asset inventory + OS classification |
| `openrmf-msg-inventory` | — | inventory NATS listener |
| `openrmf-api-tasks` | 8112 | review task assignment/tracking |
| `openrmf-svc-trivy` | 8114 | live Trivy container scanning |

### Clone everything

```powershell
$parent = "D:\OpenRMF_Build"; New-Item -ItemType Directory -Force $parent | Out-Null; cd $parent
$repos = @{
  'openrmf-web'='feature/history-trends-live-poam';
  'openrmf-docs'='feature/nessus-scanhistory-gridfs';
  'openrmf-api-read'='feature/nessus-scanhistory-gridfs';
  'openrmf-msg-reports'='feature/nessus-scanhistory-gridfs';
  'openrmf-api-scanhistory'='master'; 'openrmf-api-poam'='master'; 'openrmf-msg-poam'='master';
  'openrmf-api-journal'='master'; 'openrmf-msg-journal'='master'; 'openrmf-svc-scanwatch'='master';
  'openrmf-api-conmon'='master'; 'openrmf-api-inventory'='master'; 'openrmf-msg-inventory'='master';
  'openrmf-api-tasks'='master'; 'openrmf-svc-trivy'='master'
}
foreach ($r in $repos.Keys) { gh repo clone "eroman53/$r" -- -b $repos[$r]; }
```

---

## 3. Build the images

The fork's container images are **built locally** (not published to a registry).
Upstream `cingulara/*` images pull from Docker Hub automatically.

**Build the UBI base image FIRST** — every fork .NET service is `FROM` it:

```powershell
cd D:\OpenRMF_Build
docker build -f openrmf-docs\base-container-image-ubi\Dockerfile `
  -t eroman53/openrmf-base-ubi:8.10 openrmf-docs\base-container-image
```

Then build the service images:

```powershell
# new services -> :latest (tags the compose expects)
$svc = 'openrmf-api-scanhistory','openrmf-api-poam','openrmf-msg-poam','openrmf-api-journal',
       'openrmf-msg-journal','openrmf-svc-scanwatch','openrmf-api-conmon','openrmf-api-inventory',
       'openrmf-msg-inventory','openrmf-api-tasks','openrmf-svc-trivy'
foreach ($s in $svc) { docker build -t "eroman53/$s`:latest" "D:\OpenRMF_Build\$s" }
# forked services -> :test (the fork override points at these)
docker build -t eroman53/openrmf-web:test D:\OpenRMF_Build\openrmf-web
docker build -t eroman53/openrmf-api-read:test D:\OpenRMF_Build\openrmf-api-read
docker build -t eroman53/openrmf-msg-reports:test D:\OpenRMF_Build\openrmf-msg-reports
```

---

## 4. Configure the stack

Create `openrmf-docs\scripts\.env` (this file is intentionally **not committed** —
it holds machine-specific settings and a secret):

```
COMPOSE_IGNORE_ORPHANS=True
JWTAUTHORITY=http://YOUR.LAN.IP:8080/auth/realms/openrmf
JWTCLIENT=openrmf
SCANWATCH_CLIENTSECRET=set-after-keycloak-setup
```

Replace `YOUR.LAN.IP` with your machine's actual LAN IPv4 (not 127.0.0.1 — the
browser and the containers must reach Keycloak at the same address).

The base compose ships upstream images for web/read/msg-reports; to run the
**fork** versions, add a small override at `openrmf-docs\scripts\compose-fork.yml`:

```yaml
services:
  openrmf-web:
    image: eroman53/openrmf-web:test
  openrmfapi-read:
    image: eroman53/openrmf-api-read:test
  openrmfmsg-reports:
    image: eroman53/openrmf-msg-reports:test
```

---

## 5. Bring up the stack

```powershell
docker compose -f openrmf-docs\scripts\docker-compose.yml `
  -f openrmf-docs\scripts\compose-fork.yml `
  --project-directory openrmf-docs\scripts up -d
```

Data lives in one consolidated `mongodb` container (13 logical databases, one per
service). First start seeds all users/collections via `initializeAll.js`.

---

## 6. Keycloak realm setup (one time)

Wait 2–3 minutes for Keycloak to finish starting, then create the realm. The
upstream helper does the base setup (realm, 5 roles, `openrmf` client, first admin):

```
openrmf-docs\scripts\keycloak\setup-realm-windows.cmd
```

Then apply the **fork-specific** additions (needed for RBAC + automated scanning):

1. **Groups mapper** — add a `groups` protocol-mapper to the `openrmf` client so
   team membership rides in the JWT (drives package-level RBAC).
2. **Service account** — create a confidential client `openrmf-scanwatch`
   (service accounts enabled, Editor + Reader roles, `roles` mapper). Copy its
   client secret into `SCANWATCH_CLIENTSECRET` in `.env`, then restart the
   scanwatch and trivy services.
3. **Teams & users** — create Keycloak groups (e.g. `team-alpha`, `team-bravo`)
   for testing package RBAC, and at least one admin user.

> The exact `kcadm` commands and mapper JSON used to set this up live with the
> project owner (ask for the Keycloak setup helpers). Restart Keycloak-dependent
> services after changing `.env`: `docker compose ... up -d --force-recreate`
> (note this restarts Keycloak too — it 401s for ~2 min while it comes back).

---

## 7. Verify

```powershell
"http://YOUR.LAN.IP:8080/api/scanhistory/healthz","/api/poam/healthz","/api/conmon/healthz",
"/api/inventory/healthz","/api/tasks/healthz","/api/journal/healthz","/api/scanwatch/healthz",
"/api/trivyscan/healthz" | ForEach-Object { }
```

Browse to `http://YOUR.LAN.IP:8080`, log in through Keycloak, and confirm the
STOOGE lighthouse logo appears top-left with the new sidebar items (ConMon,
Inventory, Tasks, Container Security, Scan Watch). The **Testing Quick Reference**
(`docs/STOOGE-Testing-Quick-Reference.md` / `.pdf`) walks through exercising each
feature.

---

## 8. Working conventions

- **Feature branches only** on the forked repos — never commit to `master` there
  (`master` tracks upstream for clean rebases). New-service repos use `master`.
- **After changes:** `dotnet build` must pass; for integration, run the compose
  stack and exercise the real NATS/Mongo path.
- **Security scan before pushing images:** Trivy v0.72.0 lives in
  `tools\trivy\`; run `test-artifacts\trivy-scan.ps1` and keep images clean at
  CRITICAL/HIGH. `Snappier` is pinned ≥1.3.1 in every csproj (a transitive CVE).
- **New service?** Copy the nearest existing service's layout (Dockerfile,
  nlog.config, Startup) — they follow one pattern (UBI8 base, `linux-x64`
  publish, shadow-utils user, per-service Mongo database + Keycloak JWT).

---

## 9. Gotchas (things that will otherwise cost you an afternoon)

- **`JWTAUTHORITY` must equal your current LAN IP.** DHCP changed it? Tokens fail
  issuer validation until you update `.env` and recreate.
- **nginx caches upstream IPs.** After recreating any API container, restart
  `openrmf-web` or you'll get 502/404 error pages.
- **UBI publish RID is `linux-x64`** (glibc), not `linux-musl-x64` — the base is
  RHEL, not Alpine. User creation uses `groupadd`/`useradd`.
- **Do NOT reload `nlog.config` in `Startup`** — `Program.Main` already loaded it;
  reloading wipes the log-level variable and silences all logging.
- **RBAC cold-start:** a just-restarted service can 403 on its first request
  before its checklist-DB read warms — retry once. Admins & service accounts
  always bypass package RBAC.
- **Browser cache:** after a UI change, hard-refresh once (`Ctrl-Shift-R`).

---

## 10. Where things live

- `openrmf-docs/scripts/` — `docker-compose.yml`, `nginx.conf`, `initializeAll.js`
- `openrmf-docs/diagrams/` — architecture + ports/protocols diagram (PNG/PDF/HTML)
- `openrmf-docs/docs/` — this guide + the Testing Quick Reference
- `openrmf-docs/base-container-image-ubi/` — the UBI8 base image
- `test-artifacts/` (project owner's machine) — e2e scripts, synthetic scan
  samples, the Keycloak setup helpers, and Mongo migration dumps

---

## Roadmap snapshot

**Built:** scan history/trends, live POA&M + reconciliation, journal + evidence,
scan-watch ingest (SMB/NFS), ConMon (800-137), asset inventory, review tasks,
Trivy container scanning, package RBAC, STOOGE rebrand, UBI8 rebase, Mongo
consolidation.

**Next up (dependency-ordered):** team notifications (`openrmf-msg-notify`),
full-text search, bulk edit + locking, team subpackages; then automated PPSM and
generic scan importers (SARIF/Checkov); then the 800-53/OSCAL compliance engine;
then document generation (SSP/SAR/RAR). CIS support is explicitly out of scope.
