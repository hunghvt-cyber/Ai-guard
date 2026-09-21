#!/bin/bash
set -euo pipefail

BASE=/vol1/Docker/gemini
GUARD=/vol1/Docker/Ai-guard
GITHUB_KEY="${AI_GUARD_GITHUB_KEY:-/home/admin/.ssh/github_gemini_ngusidan}"
FNNAS_KEY="$BASE/home/.ssh/fnnas_gemini_ed25519"
TMP="$(mktemp -d /tmp/gemini-integration-poc.XXXXXX)"
GH_SOCK="$TMP/github.sock"
HOST_SOCK="$TMP/host.sock"
GH_RELAY="$TMP/github-relay.py"
HOST_RELAY="$TMP/host-relay.py"
GH_KNOWN="$TMP/github_known_hosts"
HOST_KNOWN="$TMP/host_known_hosts"
SSH_CONFIG="$TMP/ssh_config"
OVERRIDE="$TMP/compose.override.yml"

cleanup() {
  set +e
  [[ -n "${GH_PID:-}" ]] && kill "$GH_PID" 2>/dev/null
  [[ -n "${HOST_PID:-}" ]] && kill "$HOST_PID" 2>/dev/null
  [[ -n "${GH_PID:-}" ]] && wait "$GH_PID" 2>/dev/null
  [[ -n "${HOST_PID:-}" ]] && wait "$HOST_PID" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

[[ -f "$BASE/compose.yml" ]]
[[ -r "$GITHUB_KEY" ]] || { echo "GitHub key missing: $GITHUB_KEY"; exit 2; }
[[ -r "$FNNAS_KEY" ]] || { echo "FnNAS key missing: $FNNAS_KEY"; exit 2; }

cp "$GUARD/poc/gemini-docker-relay/host-relay.py" "$GH_RELAY"
cp "$GUARD/poc/gemini-docker-relay/host-relay.py" "$HOST_RELAY"
chmod 700 "$GH_RELAY" "$HOST_RELAY"

printf '%s\n' 'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl' > "$GH_KNOWN"
chmod 600 "$GH_KNOWN"

ssh-keyscan -T 5 -p 22 127.0.0.1 2>/dev/null |
  sed 's/^127\.0\.0\.1 /fnnas /' > "$HOST_KNOWN"
[[ -s "$HOST_KNOWN" ]] || { echo "FnNAS SSH host key unavailable"; exit 1; }
chmod 600 "$HOST_KNOWN"

RELAY_SOCKET="$GH_SOCK" RELAY_DEST_HOST=github.com RELAY_DEST_PORT=22 /usr/bin/python3 "$GH_RELAY" &
GH_PID=$!
RELAY_SOCKET="$HOST_SOCK" RELAY_DEST_HOST=127.0.0.1 RELAY_DEST_PORT=22 /usr/bin/python3 "$HOST_RELAY" &
HOST_PID=$!

for _ in $(seq 1 50); do
  [[ -S "$GH_SOCK" && -S "$HOST_SOCK" ]] && break
  sleep 0.1
done
[[ -S "$GH_SOCK" && -S "$HOST_SOCK" ]]

cat >"$SSH_CONFIG" <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile /run/ai-guard/github_key
  IdentitiesOnly yes
  UserKnownHostsFile /run/ai-guard/github_known_hosts
  StrictHostKeyChecking yes
  ProxyCommand /usr/local/bin/node /run/ai-guard/unix-proxy.js

Host fnnas
  HostName fnnas
  User admin
  IdentityFile /run/ai-guard/fnnas_key
  IdentitiesOnly yes
  UserKnownHostsFile /run/ai-guard/fnnas_known_hosts
  StrictHostKeyChecking yes
  HostKeyAlias fnnas
  ProxyCommand /usr/local/bin/node /run/ai-guard/unix-proxy.js
EOF
chmod 600 "$SSH_CONFIG"

cat >"$OVERRIDE" <<EOF
services:
  gemini:
    network_mode: none
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    volumes:
      - "$GH_SOCK:/run/ai-guard/github.sock:ro"
      - "$HOST_SOCK:/run/ai-guard/fnnas.sock:ro"
      - "$GUARD/poc/gemini-docker-relay/unix-proxy.js:/run/ai-guard/unix-proxy.js:ro"
      - "$GITHUB_KEY:/run/ai-guard/github_key:ro"
      - "$FNNAS_KEY:/run/ai-guard/fnnas_key:ro"
      - "$GH_KNOWN:/run/ai-guard/github_known_hosts:ro"
      - "$HOST_KNOWN:/run/ai-guard/fnnas_known_hosts:ro"
      - "$SSH_CONFIG:/run/ai-guard/ssh_config:ro"
EOF

cd "$BASE"
docker compose -f compose.yml -f "$OVERRIDE" config >/dev/null

echo "=== ACTUAL GEMINI ENTRYPOINT ==="
docker compose -f compose.yml -f "$OVERRIDE" run --rm --no-deps gemini --version

echo "=== ACTUAL GEMINI HELP ==="
docker compose -f compose.yml -f "$OVERRIDE" run --rm --no-deps gemini --help >/dev/null

echo "=== INTEGRATION POC PASS ==="
