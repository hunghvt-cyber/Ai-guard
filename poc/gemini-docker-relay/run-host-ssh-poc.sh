#!/bin/bash
set -euo pipefail

BASE=/vol1/Docker/gemini
GUARD=/vol1/Docker/Ai-guard
KEY="$BASE/home/.ssh/fnnas_gemini_ed25519"
TMP="$(mktemp -d /tmp/gemini-host-ssh-relay-poc.XXXXXX)"
SOCK="$TMP/host.sock"
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
[[ -r "$KEY" ]] || { echo "FNNAS SSH key missing: $KEY"; exit 2; }

cp "$GUARD/poc/gemini-docker-relay/host-relay.py" "$RELAY"
chmod 700 "$RELAY"

# Resolve and pin the FnNAS host SSH host key from the host side only.
ssh-keyscan -T 5 -p 22 127.0.0.1 2>/dev/null |
  sed 's/^127\.0\.0\.1 /fnnas /' > "$KNOWN"
[[ -s "$KNOWN" ]] || { echo "FnNAS SSH host key not available on 127.0.0.1:22"; exit 1; }
chmod 600 "$KNOWN"

# Fixed destination: host loopback SSH only.
RELAY_SOCKET="$SOCK" RELAY_DEST_HOST=127.0.0.1 RELAY_DEST_PORT=22 \
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
      - "$SOCK:/run/ai-guard/host.sock:ro"
      - "$GUARD/poc/gemini-docker-relay/unix-proxy.js:/run/ai-guard/unix-proxy.js:ro"
      - "$KEY:/run/ai-guard/fnnas_key:ro"
      - "$KNOWN:/run/ai-guard/known_hosts:ro"
EOF

cd "$BASE"
docker compose -f compose.yml -f "$OVERRIDE" config >/dev/null

echo "=== NETWORK DENY ==="
NETWORK_TEST="/usr/local/bin/node -e 'const net=require(\"net\");const s=net.createConnection({host:\"192.168.1.12\",port:22});s.setTimeout(3000);s.on(\"connect\",()=>process.exit(0));s.on(\"error\",()=>process.exit(1));s.on(\"timeout\",()=>process.exit(1))'"
if docker compose -f compose.yml -f "$OVERRIDE" run --rm --no-deps gemini "$NETWORK_TEST"; then
  echo "NETWORK_DENY=FAIL"
  exit 1
else
  echo "NETWORK_DENY=PASS"
fi

echo "=== HOST SSH RELAY ==="
RELAY_SOCKET=/run/ai-guard/host.sock
CMD='ssh -i /run/ai-guard/fnnas_key -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/run/ai-guard/known_hosts -o HostKeyAlias=fnnas -o ProxyCommand="/usr/local/bin/node /run/ai-guard/unix-proxy.js" admin@fnnas "printf HOST_SSH_RELAY=PASS"'

if docker compose -f compose.yml -f "$OVERRIDE" run --rm --no-deps \
  -e RELAY_SOCKET="$RELAY_SOCKET" gemini "$CMD"; then
  echo "HOST_SSH_RELAY=PASS"
else
  echo "HOST_SSH_RELAY=FAIL"
  exit 1
fi

echo "POC_PASS"
