#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GATE="$ROOT/ssh/clay-ssh-gate"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

mkdir -p "$TMP/tapo/sub" "$TMP/outside"
printf '%s\n' "SAFE" > "$TMP/tapo/sub/file.txt"
printf '%s\n' "SECRET" > "$TMP/outside/secret.txt"
ln -s "$TMP/outside/secret.txt" "$TMP/tapo/sub/link.txt"

TEST_GATE="$TMP/gate"
sed "s#^BASE=.*#BASE=\"$TMP/tapo\"#" "$GATE" > "$TEST_GATE"
chmod 0755 "$TEST_GATE"

run_ok() {
  SSH_ORIGINAL_COMMAND="$1" "$TEST_GATE" >/dev/null
}

run_denied() {
  if SSH_ORIGINAL_COMMAND="$1" "$TEST_GATE" >/dev/null 2>&1; then
    echo "expected denial: $1" >&2
    exit 1
  fi
}

run_ok "status"
run_ok "read $TMP/tapo/sub/file.txt"
run_ok "stat $TMP/tapo/sub/file.txt"
run_ok "list"

run_denied ""
run_denied "sh -c id"
run_denied "uptime; id"
run_denied "read $TMP/outside/secret.txt"
run_denied "read $TMP/tapo/sub/link.txt"
run_denied "read $TMP/tapo/../outside/secret.txt"
run_denied "systemctl-status 'bad unit'"

echo "CLAY_SSH_GATE_TEST_OK"
