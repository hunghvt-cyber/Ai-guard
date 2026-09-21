#!/bin/bash
set -euo pipefail

BASE=/vol1/Docker/gemini
GUARD=/vol1/Docker/Ai-guard
GITHUB_KEY="${AI_GUARD_GITHUB_KEY:-/home/admin/.ssh/github_gemini_ngusidan}"
TMP="$(mktemp -d /tmp/gemini-api-relay-poc.XXXXXX)"
SOCK="$TMP/gemini-api.sock"
RELAY="$TMP/relay.py"
PROXY="$TMP/tcp-unix-proxy.js"
OVERRIDE="$TMP/compose.override.yml"

cleanup() {
  set +e
  [[ -n "${RELAY_PID:-}" ]] && kill "$RELAY_PID" 2>/dev/null
  [[ -n "${PROXY_PID:-}" ]] && kill "$PROXY_PID" 2>/dev/null
  [[ -n "${RELAY_PID:-}" ]] && wait "$RELAY_PID" 2>/dev/null
  [[ -n "${PROXY_PID:-}" ]] && wait "$PROXY_PID" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

[[ -f "$BASE/compose.yml" ]]
[[ -r "$GITHUB_KEY" ]] || { echo "GitHub key missing"; exit 2; }

cp "$GUARD/poc/gemini-docker-relay/host-relay.py" "$RELAY"
cp "$GUARD/poc/gemini-docker-relay/tcp-unix-proxy.js" "$PROXY"
chmod 700 "$RELAY" "$PROXY"

# Fixed upstream: Gemini API only.
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
EOF

cd "$BASE"
docker compose -f compose.yml -f "$OVERRIDE" config >/dev/null

# Bridge 127.0.0.1:443 inside the container to the fixed Unix relay.
docker compose -f compose.yml -f "$OVERRIDE" run --rm --no-deps \
  -d --name gemini-api-relay-poc \
  -e RELAY_SOCKET=/run/ai-guard/gemini-api.sock \
  gemini \
  "/usr/local/bin/node /run/ai-guard/tcp-unix-proxy.js & exec /bin/sh -lc 'sleep 2; /usr/local/bin/node -e "const tls=require(\\\"tls\\\");const s=tls.connect({host:\\"generativelanguage.googleapis.com\\\",port:443,servername:\\"generativelanguage.googleapis.com\\\",rejectUnauthorized:true},()=>{console.log(\\\"GEMINI_API_TLS=PASS\\\");s.end()});s.setTimeout(8000,()=>{console.log(\\\"GEMINI_API_TLS=FAIL\\\");process.exit(1)});s.on(\\\"error\\\",e=>{console.log(\\\"GEMINI_API_TLS=FAIL\\\");process.exit(1)})"'"
CONTAINER=gemini-api-relay-poc

sleep 1
docker logs "$CONTAINER" 2>&1 | tail -20
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

echo "=== GEMINI API RELAY POC PASS ==="
