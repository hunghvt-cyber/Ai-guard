#!/bin/bash
set -euo pipefail

BASE=/vol1/Docker/gemini
GUARD=/vol1/Docker/Ai-guard
GITHUB_KEY="${AI_GUARD_GITHUB_KEY:-/home/admin/.ssh/github_gemini_ngusidan}"
TMP="$(mktemp -d /tmp/gemini-api-relay-poc.XXXXXX)"
SOCK="$TMP/gemini-api.sock"
RELAY="$TMP/relay.py"
PROXY="$TMP/tcp-unix-proxy.js"
TLS_TEST="$TMP/tls-test.js"
OVERRIDE="$TMP/compose.override.yml"
CONTAINER=gemini-api-relay-poc

cleanup() {
  set +e
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  [[ -n "${RELAY_PID:-}" ]] && kill "$RELAY_PID" 2>/dev/null
  [[ -n "${RELAY_PID:-}" ]] && wait "$RELAY_PID" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

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
      - "$TLS_TEST:/run/ai-guard/tls-test.js:ro"
EOF

cd "$BASE"
docker compose -f compose.yml -f "$OVERRIDE" config >/dev/null

# Bridge 127.0.0.1:443 inside the container to the fixed Unix relay.
docker compose -f compose.yml -f "$OVERRIDE" run --rm --no-deps \
  --entrypoint /bin/sh \
  -d --name "$CONTAINER" \
  -e RELAY_SOCKET=/run/ai-guard/gemini-api.sock \
  gemini \
  -c '/usr/local/bin/node /run/ai-guard/tcp-unix-proxy.js >/tmp/api-proxy.log 2>&1 & exec /usr/local/bin/node /run/ai-guard/tls-test.js'

EXIT_CODE="$(docker wait "$CONTAINER")"
LOGS="$(docker logs "$CONTAINER" 2>&1 || true)"

printf '%s\n' "$LOGS"

if [[ "$EXIT_CODE" -eq 0 ]] && grep -q '^GEMINI_API_TLS=PASS$' <<<"$LOGS"; then
  echo "=== GEMINI API RELAY POC PASS ==="
else
  echo "=== GEMINI API RELAY POC FAIL ==="
  echo "Container exit code: $EXIT_CODE"
  exit 1
fi
