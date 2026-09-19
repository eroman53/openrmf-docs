#!/usr/bin/env bash
# Rebuild every STOOGE image from current source, shared base first.
# Copyright (c) eroman53 2026. Licensed under the GNU GPL v3; see LICENSE.
#
#   ./build-all.sh [logfile] [summaryfile]
#
# This lives in the repo rather than in a scratch folder on purpose. The
# previous copy drifted: it went on building the three ":test" images long
# after docker-compose.yml had moved to ":latest", and it still built the four
# listener services after they were merged into openrmf-msg-hub. A build script
# that disagrees with the compose file produces images nothing runs, and leaves
# the stack running something nobody rebuilt.
set -u
ROOT=${ROOT:-d:/OpenRMF_Build}
LOG=${1:-/tmp/build-all.log}
SUM=${2:-/tmp/build-all.summary}
: > "$LOG"; : > "$SUM"

# PATCH_EPOCH busts the cache on the OS-patching layer in the web and base
# images. Without it those layers cache forever and the images ship whatever
# packages the base had the day the layer was first built, however often they
# are "rebuilt". Measured live on 2026-09-17: 27 HIGH findings, every one of
# them already fixed upstream.
EPOCH=$(date +%Y%m%d)

run() {
  tag=$1; shift
  printf '=== %s  start %s ===\n' "$tag" "$(date +%H:%M:%S)" >> "$LOG"
  if docker build -q --build-arg PATCH_EPOCH="$EPOCH" -t "$tag" "$@" >> "$LOG" 2>&1; then
    echo "OK   $tag" >> "$SUM"
  else
    echo "FAIL $tag" >> "$SUM"
  fi
}

# 1) shared runtime base -- every fork .NET service derives from this, so it
#    has to be first or the services rebuild onto a stale base.
run eroman53/openrmf-base-ubi:8.10 \
    -f "$ROOT/openrmf-docs/base-container-image-ubi/Dockerfile" \
       "$ROOT/openrmf-docs/base-container-image"

# 2) our services, tagged exactly as scripts/docker-compose.yml references them
run eroman53/openrmf-api-scanhistory:latest "$ROOT/openrmf-api-scanhistory"
run eroman53/openrmf-api-poam:latest        "$ROOT/openrmf-api-poam"
run eroman53/openrmf-api-journal:latest     "$ROOT/openrmf-api-journal"
run eroman53/openrmf-api-tasks:latest       "$ROOT/openrmf-api-tasks"
run eroman53/openrmf-api-ppsm:latest        "$ROOT/openrmf-api-ppsm"
run eroman53/openrmf-api-oscal:latest       "$ROOT/openrmf-api-oscal"
run eroman53/openrmf-api-inventory:latest   "$ROOT/openrmf-api-inventory"
run eroman53/openrmf-api-conmon:latest      "$ROOT/openrmf-api-conmon"
run eroman53/openrmf-svc-notify:latest      "$ROOT/openrmf-svc-notify"
run eroman53/openrmf-svc-scanwatch:latest   "$ROOT/openrmf-svc-scanwatch"
run eroman53/openrmf-svc-trivy:latest       "$ROOT/openrmf-svc-trivy"

# One host for the inventory, journal, POA&M and report listeners. The four
# repos it replaced are superseded and deliberately not built here.
run eroman53/openrmf-msg-hub:latest         "$ROOT/openrmf-msg-hub"

# 3) the two upstream forks we modify. These are ":latest" now; they were
#    ":test" only because compose still named Cingulara's images and an overlay
#    pinned them back. Do not reintroduce a ":test" tag here.
run eroman53/openrmf-api-read:latest        "$ROOT/openrmf-api-read"
run eroman53/openrmf-web:latest             "$ROOT/openrmf-web"

# 4) Keycloak carries the STOOGE theme, so build it with everything else rather
#    than leaving the stack part-rebuilt.
run eroman53/keycloak-stooge:26.5.7         "$ROOT/openrmf-docs/keycloak-image"

printf '=== finished %s ===\n' "$(date +%H:%M:%S)" >> "$SUM"
cat "$SUM"
grep -q '^FAIL' "$SUM" && exit 1
exit 0
