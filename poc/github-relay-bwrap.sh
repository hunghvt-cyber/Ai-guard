#!/bin/bash
set -euo pipefail

KEY=${AI_GUARD_GITHUB_KEY:-/home/admin/.ssh/github_gemini_ngusidan}
command -v bwrap >/dev/null || { echo "FAIL: bwrap not found" >&2; exit 2; }
command -v python3 >/dev/null || { echo "FAIL: python3 not found" >&2; exit 2; }
command -v ssh >/dev/null || { echo "FAIL: ssh not found" >&2; exit 2; }
command -v node >/dev/null || { echo "FAIL: node not found on host" >&2; exit 2; }
test -r "$KEY" || { echo "FAIL: GitHub key not readable: $KEY" >&2; exit 2; }

T=$(mktemp -d /tmp/ai-guard-gh-poc.XXXXXX)
SOCK="$T/github.sock"
RELAY_LOG="$T/relay.log"
cleanup() {
  [ -n "${RELAY_PID:-}" ] && kill "$RELAY_PID" 2>/dev/null || true
  rm -rf "$T"
}
trap cleanup EXIT

cat >"$T/relay.py" <<'PY'
import os, socket, sys, threading

path = sys.argv[1]
target = ("github.com", 22)

try:
    os.unlink(path)
except FileNotFoundError:
    pass

srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
srv.bind(path)
os.chmod(path, 0o600)
srv.listen(8)

def forward(src, dst):
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        for s in (src, dst):
            try:
                s.shutdown(socket.SHUT_RDWR)
            except Exception:
                pass

def handle(client):
    try:
        remote = socket.create_connection(target, 10)
    except Exception:
        client.close()
        return
    threading.Thread(target=forward, args=(client, remote), daemon=True).start()
    threading.Thread(target=forward, args=(remote, client), daemon=True).start()

print("RELAY_READY", flush=True)
while True:
    c, _ = srv.accept()
    threading.Thread(target=handle, args=(c,), daemon=True).start()
PY

python3 "$T/relay.py" "$SOCK" >"$RELAY_LOG" 2>&1 &
RELAY_PID=$!

for _ in $(seq 1 50); do
  [ -S "$SOCK" ] && break
  sleep 0.1
done
test -S "$SOCK" || { cat "$RELAY_LOG" >&2; exit 3; }

cat >"$T/github-proxy.js" <<'JS'
const net = require("net");
const s = net.createConnection("/home/sandbox/github.sock");
s.on("connect", () => {
  process.stdin.pipe(s);
  s.pipe(process.stdout);
});
s.on("error", () => process.exit(1));
JS

cat >"$T/known_hosts" <<'EOF'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
EOF

cat >"$T/ssh_config" <<'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile /home/sandbox/github_key
    IdentitiesOnly yes
    ProxyCommand /usr/bin/node /home/sandbox/github-proxy.js
    StrictHostKeyChecking yes
    UserKnownHostsFile /home/sandbox/known_hosts
EOF

BIND_LIB64=()
[ -d /lib64 ] && BIND_LIB64=(--ro-bind /lib64 /lib64)

echo "=== relay: PASS ==="
echo "=== bwrap + GitHub SSH ==="

bwrap \
  --unshare-user --unshare-net --unshare-pid --unshare-ipc --unshare-uts \
  --die-with-parent --new-session \
  --ro-bind /usr /usr \
  --ro-bind /bin /bin \
  --ro-bind /lib /lib \
  "${BIND_LIB64[@]}" \
  --tmpfs /etc \
  --ro-bind /etc/passwd /etc/passwd \
  --ro-bind /etc/group /etc/group \
  --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf \
  --tmpfs /tmp \
  --tmpfs /home \
  --dir /home/sandbox \
  --ro-bind "$T/github-proxy.js" /home/sandbox/github-proxy.js \
  --ro-bind "$T/known_hosts" /home/sandbox/known_hosts \
  --ro-bind "$T/ssh_config" /home/sandbox/ssh_config \
  --ro-bind "$KEY" /home/sandbox/github_key \
  --bind "$SOCK" /home/sandbox/github.sock \
  --chdir /home/sandbox \
  --uid 1000 --gid 1000 \
  /bin/sh -c 'exec /usr/bin/ssh -F /home/sandbox/ssh_config -T git@github.com'

rc=$?
echo "=== SSH exit code: $rc ==="
exit "$rc"
