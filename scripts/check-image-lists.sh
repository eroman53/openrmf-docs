#!/usr/bin/env bash
# Assert that every script naming STOOGE images agrees with docker-compose.yml.
# Copyright (c) eroman53 2026. Licensed under the GNU GPL v3; see LICENSE.
#
#   ./check-image-lists.sh        exits non-zero on any disagreement
#
# Why this exists. Three separate scripts carried their own hand-written list of
# images, and all three drifted from the compose file at once: they went on
# naming the ":test" tags after compose moved to ":latest", and the four
# listener services after they were merged into openrmf-msg-hub. Each failure
# mode is quiet and each is worse than an error:
#
#   build-all.sh   builds images nothing runs, so a fix never reaches the stack
#   verify.sh      checks services that no longer exist, so it verifies nothing
#   trivy-scan.ps1 scans images nothing runs, and reports CLEAN
#
# The compose file is the source of truth, because it is the only one of the
# four that the running stack actually obeys. trivy-scan.ps1 now derives its
# list from it directly and is checked here only for the absence of a
# hand-written one.
set -u
cd "$(dirname "$0")"
fail=0
note() { printf '  %-34s %s\n' "$1" "$2"; }

compose=$(grep -oE '^\s*image:\s*eroman53/\S+' docker-compose.yml \
          | sed 's/.*image:[[:space:]]*//' | sort -u)
[ -z "$compose" ] && { echo "FAIL: no eroman53 images in docker-compose.yml"; exit 1; }
echo "docker-compose.yml names $(echo "$compose" | wc -l) of our images"

echo
echo "=== build-all.sh ==="
# The base image is a build dependency, not a running service, so it is
# expected here and absent from compose.
built=$(grep -oE '^run eroman53/\S+' build-all.sh | sed 's/^run //' | sort -u)
missing=$(comm -23 <(echo "$compose") <(echo "$built"))
extra=$(comm -13 <(echo "$compose") <(echo "$built") | grep -v '^eroman53/openrmf-base-ubi:' || true)
[ -n "$missing" ] && { note "compose wants, not built" "$(echo "$missing" | tr '\n' ' ')"; fail=1; }
[ -n "$extra" ] && { note "built, compose never runs" "$(echo "$extra" | tr '\n' ' ')"; fail=1; }
[ -z "$missing$extra" ] && note "image set" "matches compose"
# Only real code: both files explain in comments why ':test' must not return.
grep -vE '^[[:space:]]*#' build-all.sh | grep -q ':test' && { note "':test' tag present" "REMOVE IT"; fail=1; }

echo
echo "=== verify.sh ==="
# verify.sh checks image freshness from a "<repo> <image>" table.
checked=$(grep -oE '^openrmf-\S+ eroman53/\S+' verify.sh | awk '{print $2}' | sort -u)
missing=$(comm -23 <(echo "$compose") <(echo "$checked") | grep -v 'keycloak-stooge' || true)
extra=$(comm -13 <(echo "$compose") <(echo "$checked"))
# Keycloak is verified by content rather than timestamp; see verify.sh.
[ -n "$missing" ] && { note "compose runs, not checked" "$(echo "$missing" | tr '\n' ' ')"; fail=1; }
[ -n "$extra" ] && { note "checked, compose never runs" "$(echo "$extra" | tr '\n' ' ')"; fail=1; }
[ -z "$missing$extra" ] && note "image set" "matches compose"
grep -qE 'eroman53/\S+:test' verify.sh && { note "':test' tag present" "REMOVE IT"; fail=1; }

echo
echo "=== trivy-scan.ps1 ==="
if grep -q 'Select-String -Path \$composePath' trivy-scan.ps1; then
    note "image set" "derived from compose"
else
    note "image set" "HAND-WRITTEN -- derive it from compose"; fail=1
fi
grep -qE "eroman53/\S+:test" trivy-scan.ps1 && { note "':test' tag present" "REMOVE IT"; fail=1; }

echo
if [ "$fail" = "0" ]; then echo "RESULT: PASS -- every script agrees with docker-compose.yml"; else
    echo "RESULT: DRIFT -- fix the lines above before building or scanning"; fi
exit $fail
