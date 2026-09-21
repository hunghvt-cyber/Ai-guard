#!/bin/bash
set -euo pipefail

BASE=/vol1/Docker/gemini
GUARD=/vol1/Docker/Ai-guard
KEY="${AI_GUARD_GITHUB_KEY:-}"
TMP="$(mktemp -d /tmp/gemini-docker-relay-poc.XXXXXX)"
SOCK="$TMP/github.sock"
RELAY="$TMP/relay.py"
KNOWN="$TMP/known_hosts"
OVERRIDE="$TMP/compose.override.yml"

cleanup() {
  set +e
  [[ -n "${RELAY_PID:-}" ]] && kill "$RELAY_PID" 2>/dev/null
  [[ -n "${RELAY_PID:-}" ]] && wait "$RELAY_PID" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

[[ -f "$BASE/compose.yml" ]]
[[ -r "$KEY" ]] || { echo "AI_GUARD_GITHUB_KEY is required"; exit 2; }

cp "$GUARD/poc/gemini-docker-relay/host-relay.py" "$RELAY"
chmod 700 "$RELAY"

printf '%s\n' 'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl' > "$KNOWN"
chmod 600 "$KNOWN"

RELAY_SOCKET="$SOCK" RELAY_DEST_HOST=github.com RELAY_DEST_PORT=22 \
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
    entrypoint:
      - /bin/sh
      - -lc
    network_mode: none
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    volumes:
      - "$SOCK:/run/ai-guard/github.sock:ro"
      - "$GUARD/poc/gemini-docker-relay/unix-proxy.js:/run/ai-guard/unix-proxy.js:ro"
      - "$KEY:/run/ai-guard/github_key:ro"
      - "$KNOWN:/run/ai-guard/known_hosts:ro"
EOF

cd "$BASE"
docker compose -f compose.yml -f "$OVERRIDE" config >/dev/null

echo "=== NETWORK DENY ==="
NETWORK_TEST="/usr/local/bin/node -e 'require(\"dns\").lookup(\"github.com\",e=>process.exit(e?0:1))'"
if docker compose -f compose.yml -f "$OVERRIDE" run --rm --no-deps gemini "$NETWORK_TEST"; then
  echo "NETWORK_DENY=FAIL"
  exit 1
else
  echo "NETWORK_DENY=PASS"
fi

echo "=== GITHUB RELAY ==="
RELAY_SOCKET=/run/ai-guard/github.sock
CMD='ssh -i /run/ai-guard/github_key -o BatchMode=yes -o ProxyCommand="/usr/local/bin/node /run/ai-guard/unix-proxy.js" -o UserKnownHostsFile=/run/ai-guard/known_hosts -o StrictHostKeyChecking=yes git@github.com'

if docker compose -f compose.yml -f "$OVERRIDE" run --rm --no-deps \
  -e RELAY_SOCKET="$RELAY_SOCKET" gemini "$CMD 2>&1 | grep -F 'Hi hunghvt-cyber!'"; then
  echo "GITHUB_RELAY=PASS"
else
  echo "GITHUB_RELAY=FAIL"
  exit 1
fi

echo "POC_PASS"
