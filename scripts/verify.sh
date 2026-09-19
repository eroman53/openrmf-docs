#!/usr/bin/env bash
# Post-deploy verification for the STOOGE stack.
# Copyright (c) eroman53 2026. Licensed under the GNU GPL v3; see LICENSE.
#
#   ./verify.sh
#
# Checks containers, health routes, authentication, the authenticated APIs, the
# UI pages and theme assets, and whether each image is older than the last
# commit in its repo -- that last one catches "I rebuilt it" when the running
# stack never received the build.
#
# Kept in the repo rather than a scratch folder because the previous copy drifted
# out of step with the deployment: it was still checking the three merged
# listener services and three ":test" tags that no longer exist.
# STOOGE stack verification. Run after a rebuild + redeploy.
KEYIP=${1:-192.168.254.57}
B="http://$KEYIP:8080"
SYS=6a56de4bc215a09c8560dcf5
fail=0
note() { printf "%-46s %s\n" "$1" "$2"; }
check() { # label url expected
    code=$(curl -s -o /dev/null -w "%{http_code}" "$2")
    if [ "$code" = "${3:-200}" ]; then note "$1" "$code"; else note "$1" "$code  <-- expected ${3:-200}"; fail=1; fi
}
checkauth() {
    code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $T" "$2")
    if [ "$code" = "${3:-200}" ]; then note "$1" "$code"; else note "$1" "$code  <-- expected ${3:-200}"; fail=1; fi
}

echo "=================== containers ==================="
notup=$(docker ps -a --format '{{.Names}}\t{{.Status}}' | grep -viE "\bUp\b" | grep -v "openrmf-test-samba.*Exited" || true)
if [ -n "$notup" ]; then echo "$notup"; fail=1; else echo "all containers Up"; fi
restarting=$(docker ps --format '{{.Names}}\t{{.Status}}' | grep -i restarting || true)
[ -n "$restarting" ] && { echo "RESTARTING: $restarting"; fail=1; }
echo "count: $(docker ps -q | wc -l)"

echo
echo "=================== service health ==================="
for r in read poam scanhistory journal scanwatch conmon inventory ppsm oscal tasks trivyscan notify template scoring control audit report; do
    check "  /api/$r/healthz" "$B/api/$r/healthz"
done

echo
echo "=================== authentication ==================="
T=$(curl -s -X POST "$B/auth/realms/openrmf/protocol/openid-connect/token" \
      -d client_id=openrmf -d username=testadmin -d "password=TestAdmin12!!" -d grant_type=password \
    | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
if [ -z "$T" ]; then note "  password grant" "FAILED"; fail=1; else note "  password grant" "ok (${#T} chars)"; fi

echo
echo "=================== authenticated API ==================="
checkauth "  read: systems"            "$B/api/read/artifact/systems"
checkauth "  read: search"             "$B/api/read/search?q=test"
checkauth "  tasks: mine"              "$B/api/tasks/tasks/mine"
checkauth "  tasks: by system"         "$B/api/tasks/tasks/system/$SYS"
checkauth "  poam: by system"          "$B/api/poam/poam/system/$SYS"
checkauth "  ppsm: by system"          "$B/api/ppsm/ppsm/system/$SYS"
checkauth "  scanhistory: trend"       "$B/api/scanhistory/scan/$SYS/trend"
checkauth "  journal: by system"       "$B/api/journal/journal/system/$SYS"
checkauth "  conmon: posture"          "$B/api/conmon/conmon/posture"
checkauth "  conmon: system posture"   "$B/api/conmon/conmon/system/$SYS/posture"
checkauth "  inventory: mappings"      "$B/api/inventory/inventory/mappings"
checkauth "  inventory: assets"        "$B/api/inventory/inventory/system/$SYS/assets"
checkauth "  trivy: config"            "$B/api/trivyscan/config"
checkauth "  trivy: runs"              "$B/api/trivyscan/runs?limit=5"
checkauth "  notify: config"           "$B/api/notify/config"
checkauth "  scanwatch: config"        "$B/api/scanwatch/config"

echo
echo "=================== 800-53 catalog and assessment ==================="
checkauth "  oscal: status"             "$B/api/oscal/status"
checkauth "  oscal: controls (moderate)" "$B/api/oscal/controls?baseline=moderate"
checkauth "  oscal: one control + CCIs"  "$B/api/oscal/controls/ac-17.4"
checkauth "  oscal: profile"            "$B/api/oscal/profile/system/$SYS"
checkauth "  oscal: applicable controls" "$B/api/oscal/profile/system/$SYS/controls"
checkauth "  oscal: assessment"         "$B/api/oscal/assessment/system/$SYS"
checkauth "  oscal: due for review"     "$B/api/oscal/assessment/system/$SYS/due"
checkauth "  oscal: report (xlsx)"      "$B/api/oscal/assessment/system/$SYS/report"

# the catalog has to actually hold data, not just answer
counts=$(curl -s -H "Authorization: Bearer $T" "$B/api/oscal/status")
ctl=$(echo "$counts" | grep -oE '"controls":[0-9]+' | cut -d: -f2)
cci=$(echo "$counts" | grep -oE '"cciItems":[0-9]+' | cut -d: -f2)
if [ "${ctl:-0}" -gt 300 ] && [ "${cci:-0}" -gt 5000 ]; then
    note "  catalog loaded" "$ctl controls, $cci CCIs"
else
    note "  catalog loaded" "ctl=${ctl:-0} cci=${cci:-0}  <-- expected a full catalog"; fail=1
fi

# conmon must be able to see the assessment, or the dashboard silently
# reports "not tracked" while looking healthy
ca=$(curl -s -H "Authorization: Bearer $T" "$B/api/conmon/conmon/system/$SYS/posture" | grep -oE '"controlAssessment":{"configured":(true|false)')
if echo "$ca" | grep -q "configured\":true"; then
    note "  conmon sees the catalog DB" "configured"
else
    note "  conmon sees the catalog DB" "NOT configured  <-- OSCALDBCONNECTION missing"; fail=1
fi

echo
echo "=================== UI pages ==================="
for p in index.html systems.html checklists.html conmon.html containers.html inventory.html \
         ppsm.html tasks.html poam.html trends.html notifications.html scanwatch.html \
         search.html templates.html upload.html authorization.html compliance.html audit.html \
         reports/index.html reports/nessus.html reports/vulnerability.html; do
    check "  /$p" "$B/$p"
done

echo
echo "=================== UI theme assets ==================="
check "  assets/css/stooge-theme.css" "$B/assets/css/stooge-theme.css"
check "  js/stooge-theme.js"          "$B/js/stooge-theme.js"
n=$(curl -s "$B/includes/navbar.html" | grep -c "stoogeThemeToggle")
[ "$n" -ge 1 ] && note "  navbar: appearance switch" "present" || { note "  navbar: appearance switch" "MISSING"; fail=1; }
n=$(curl -s "$B/conmon.html" | grep -c "stooge-theme")
[ "$n" = "2" ] && note "  page wiring (conmon.html)" "css+js" || { note "  page wiring (conmon.html)" "$n refs <-- expected 2"; fail=1; }

echo
echo "=================== keycloak theme ==================="
LOGIN="$B/auth/realms/openrmf/protocol/openid-connect/auth?client_id=openrmf&redirect_uri=http%3A%2F%2F$KEYIP%3A8080%2F&response_type=code&scope=openid"
check "  login page" "$LOGIN"
RP=$(curl -s "$LOGIN" | grep -o 'resources/[a-z0-9]*/login/stooge' | head -1)
note "  theme resource path" "${RP:-NOT FOUND}"
[ -z "$RP" ] && fail=1
title=$(curl -s "$LOGIN" | grep -o '<title>[^<]*</title>')
note "  page title" "$title"
for f in css/stooge.css js/stooge-theme-toggle.js img/cyber-topology.svg \
         img/stooge-logo-horizontal.svg img/stooge-logo-horizontal-darkbg.svg img/favicon.ico; do
    check "  $f" "$B/auth/$RP/$f"
done
check "  account console" "$B/auth/realms/openrmf/account/"
# the admin CLI session lives in the container and is wiped when it is
# recreated, so log in before asking rather than reporting a blank line
MSYS_NO_PATHCONV=1 docker exec openrmf-keycloak /opt/keycloak/bin/kcadm.sh config credentials \
    --server "http://localhost:8080/auth" --realm master --user admin --password admin >/dev/null 2>&1
themes=$(MSYS_NO_PATHCONV=1 docker exec openrmf-keycloak /opt/keycloak/bin/kcadm.sh get realms/openrmf --fields loginTheme,accountTheme,adminTheme 2>/dev/null | tr -d " 
\"")
note "  realm themes" "$themes"

echo
echo "=================== image freshness ==================="
stale=0
while read -r repo img; do
    [ -d "d:/OpenRMF_Build/$repo/.git" ] || continue
    ct=$(git -C "d:/OpenRMF_Build/$repo" log -1 --format=%ct)
    it=$(docker image inspect "$img" --format '{{.Created}}' 2>/dev/null)
    [ -z "$it" ] && { note "  $img" "MISSING"; fail=1; continue; }
    is=$(date -d "$it" +%s 2>/dev/null)
    if [ -n "$is" ] && [ "$is" -ge "$ct" ]; then
        note "  $repo" "image newer than last commit"
    else
        note "  $repo" "IMAGE OLDER THAN COMMIT"; stale=1; fail=1
    fi
done <<ROWS
openrmf-api-scanhistory eroman53/openrmf-api-scanhistory:latest
openrmf-api-poam eroman53/openrmf-api-poam:latest
openrmf-api-journal eroman53/openrmf-api-journal:latest
openrmf-api-tasks eroman53/openrmf-api-tasks:latest
openrmf-api-ppsm eroman53/openrmf-api-ppsm:latest
openrmf-api-inventory eroman53/openrmf-api-inventory:latest
openrmf-api-conmon eroman53/openrmf-api-conmon:latest
openrmf-msg-hub eroman53/openrmf-msg-hub:latest
openrmf-svc-notify eroman53/openrmf-svc-notify:latest
openrmf-svc-scanwatch eroman53/openrmf-svc-scanwatch:latest
openrmf-svc-trivy eroman53/openrmf-svc-trivy:latest
openrmf-api-read eroman53/openrmf-api-read:latest
openrmf-web eroman53/openrmf-web:latest
openrmf-api-oscal eroman53/openrmf-api-oscal:latest
ROWS

echo
[ "$fail" = "0" ] && echo "RESULT: PASS" || echo "RESULT: ISSUES FOUND (see lines marked <--)"

# The keycloak image is checked by CONTENT, not by timestamp: its build context
# rarely changes, so Docker returns the cached image and .Created keeps the
# original build time, which can predate a later commit of the same files.
echo
echo "=================== keycloak theme content ==================="
cd d:/OpenRMF_Build/openrmf-docs/keycloak-image/themes/stooge || exit 1
for f in login/resources/css/stooge.css login/resources/js/stooge-theme-toggle.js \
         login/resources/img/cyber-topology.svg login/theme.properties; do
    repo=$(md5sum "$f" | cut -c1-12)
    img=$(MSYS_NO_PATHCONV=1 docker exec openrmf-keycloak md5sum "/opt/keycloak/themes/stooge/$f" 2>/dev/null | cut -c1-12)
    if [ "$repo" = "$img" ]; then note "  $(basename "$f")" "matches repo"; else note "  $(basename "$f")" "DIFFERS"; fi
done
