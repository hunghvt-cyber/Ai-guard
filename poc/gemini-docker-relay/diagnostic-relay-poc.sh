#!/bin/bash
# Diagnostic-only wrapper for Gemini API relay POC.
# Generated 2026-09-21 to diagnose empty docker logs after container startup.
# Does NOT modify the production POC script.
#
# Usage:
#   bash poc/gemini-docker-relay/diagnostic-relay-poc.sh
#
# The script copies the first 91 lines of the current POC script, starts the
# container, then keeps it alive long enough to inspect state, logs, proxy log,
# processes, and host relay state. Cleanup is intentionally NOT performed here
# so the caller can inspect the container after this diagnostic if needed.

set -euo pipefail

BASE=/vol1/Docker/gemini
GUARD=/vol1/Docker/Ai-guard
GITHUB_KEY="${AI_GUARD_GITHUB_KEY:-/home/admin/.ssh/github_gemini_ngusidan}"
TMP="$(mktemp -d /tmp/gemini-api-relay-debug.XXXXXX)"
SOCK="$TMP/gemini-api.sock"
RELAY="$TMP/relay.py"
PROXY="$TMP/tcp-unix-proxy.js"
TLS_TEST="$TMP/tls-test.js"
OVERRIDE="$TMP/compose.override.yml"
CONTAINER=gemini-api-relay-poc

[[ -f "$BASE/compose.yml" ]]
[[ -r "$GITHUB_KEY" ]] || { echo "GitHub key missing"; exit 2; }

cp "$GUARD/poc/gemini-docker-relay/host-relay.py" "$RELAY"
cp "$GUARD/poc/gemini-docker-relay/tcp-unix-proxy.js" "$PROXY"
chmod 700 "$RELAY" "$PROXY"

cat >"$TLS_TEST" <<'NODE'
const tls = require("tls");

const s = tls.connect({
  host: "generativelanguage.googleapis.com",
  port: 443,
  servername: "generativelanguage.googleapis.com",
  rejectUnauthorized: true
}, () => {
  console.log("GEMINI_API_TLS=PASS");
  s.end();
});

s.setTimeout(8000, () => {
  console.log("GEMINI_API_TLS=FAIL");
  process.exit(1);
});

s.on("error", () => {
  console.log("GEMINI_API_TLS=FAIL");
  process.exit(1);
});
NODE

RELAY_SOCKET="$SOCK" RELAY_DEST_HOST=generativelanguage.googleapis.com RELAY_DEST_PORT=443 \
  /usr/bin/python3 "$RELAY" &
RELAY_PID=$!

for _ in $(seq 1 50); do
  [[ -S "$SOCK" ]] && break
  sleep 0.1
done
[[ -S "$SOCK" ]]

cat >"$OVERRIDE" <<EOF
services:
  gemini:
    network_mode: none
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    extra_hosts:
      - "generativelanguage.googleapis.com:127.0.0.1"
    volumes:
      - "$SOCK:/run/ai-guard/gemini-api.sock:ro"
      - "$PROXY:/run/ai-guard/tcp-unix-proxy.js:ro"
      - "$TLS_TEST:/run/ai-guard/tls-test.js:ro"
EOF

cd "$BASE"
docker compose -f compose.yml -f "$OVERRIDE" config >/dev/null

echo '=== DEBUG: START CONTAINER ==='
docker compose -f compose.yml -f "$OVERRIDE" run --rm --no-deps \
  -d --name "$CONTAINER" \
  -e RELAY_SOCKET=/run/ai-guard/gemini-api.sock \
  gemini \
  /bin/sh -lc '/usr/local/bin/node /run/ai-guard/tcp-unix-proxy.js >/tmp/api-proxy.log 2>&1 & exec /usr/local/bin/node /run/ai-guard/tls-test.js'

echo '=== DEBUG: AFTER CONTAINER START ==='
echo '--- docker inspect ---'
docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} Error={{.State.Error}} StartedAt={{.State.StartedAt}} FinishedAt={{.State.FinishedAt}}' "$CONTAINER" || true
echo '--- docker logs ---'
docker logs "$CONTAINER" 2>&1 || true
echo '--- proxy log ---'
docker exec "$CONTAINER" /bin/sh -lc 'cat /tmp/api-proxy.log 2>&1 || true'
echo '--- processes ---'
docker exec "$CONTAINER" /bin/sh -lc 'ps aux 2>&1 || true'
echo '--- host relay process ---'
ps -fp "$RELAY_PID" || true
echo '--- host unix socket ---'
ls -l "$SOCK" 2>&1 || true

echo '=== DEBUG: WAIT 5s ==='
sleep 5

echo '--- docker inspect after 5s ---'
docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} Error={{.State.Error}} StartedAt={{.State.StartedAt}} FinishedAt={{.State.FinishedAt}}' "$CONTAINER" || true
echo '--- docker logs after 5s ---'
docker logs "$CONTAINER" 2>&1 || true
echo '--- proxy log after 5s ---'
docker exec "$CONTAINER" /bin/sh -lc 'cat /tmp/api-proxy.log 2>&1 || true'
echo '--- processes after 5s ---'
docker exec "$CONTAINER" /bin/sh -lc 'ps aux 2>&1 || true'
echo '--- host relay process after 5s ---'
ps -fp "$RELAY_PID" || true
echo '=== DEBUG END ==='

echo
echo "Container left in place for inspection: $CONTAINER"
echo "Temporary files: $TMP"
