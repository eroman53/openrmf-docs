# STOOGE material moved out of this fork

This repository is a fork of `Cingulara/openrmf-docs` and is rebased against
upstream. To keep those rebases small, everything STOOGE-specific was moved to
a separate repo on 2026-09-20:

**https://github.com/eroman53/STOOGE-docs** (private)

That is where to find the architecture diagram, the user and testing quick
references, developer onboarding, the Roslyn static-analysis tooling, the UBI
base image Dockerfile, and `build-all.sh` / `verify.sh` / `trivy-scan.ps1` /
`check-image-lists.sh`.

## What deliberately stayed here

| File | Why it could not move |
|---|---|
| `scripts/docker-compose.yml` | A modified upstream file. It is also the source of truth the build/verify/scan scripts are checked against. |
| `scripts/nginx.conf` | Mounted by compose at `./nginx.conf`. |
| `scripts/initializeAll.js` | Mounted by compose at `./initializeAll.js` as the Mongo init script. |
| `keycloak-image/` | Upstream directory; the STOOGE theme lives inside it and `verify.sh` checks it here by absolute path. Only `tools/` moved. |
| `base-container-image/` | Upstream build context. The STOOGE UBI Dockerfile moved but still builds against this directory. |

## The two repos expect to be siblings

```
d:/OpenRMF_Build/
├── STOOGE-docs/     <- scripts, docs, diagrams, code-analysis
└── openrmf-docs/    <- this fork: compose, nginx.conf, initializeAll.js
```

`check-image-lists.sh` and `trivy-scan.ps1` read this repo's
`scripts/docker-compose.yml` across that boundary, resolving it as
`../../openrmf-docs/scripts/docker-compose.yml` with a `STOOGE_COMPOSE`
override. Both fail hard if they cannot find it — a drift guard that passes
because it lost its reference is worse than none.
