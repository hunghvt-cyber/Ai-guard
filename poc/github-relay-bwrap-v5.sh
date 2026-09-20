#!/bin/bash
set -euo pipefail
KEY=${AI_GUARD_GITHUB_KEY:-/home/admin/.ssh/github_gemini_ngusidan}
BWRAP=$(command -v bwrap) || { echo "FAIL: bwrap not found"; exit 2; }
PYTHON=$(command -v python3) || { echo "FAIL: python3 not found"; exit 2; }
SSH=$(command -v ssh) || { echo "FAIL: ssh not found"; exit 2; }
test -r "$KEY" || { echo "FAIL: GitHub key not readable"; exit 2; }
T=$(mktemp -d /tmp/ai-guard-gh-poc.XXXXXX); SOCK="$T/github.sock"
cleanup(){ kill "${RELAY_PID:-}" 2>/dev/null || true; rm -rf "$T"; }; trap cleanup EXIT

cat >"$T/relay.py" <<'PY'
import socket,sys,threading
p=sys.argv[1]; s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM); s.bind(p); s.listen(8)
print("RELAY_READY",flush=True)
def pump(a,b):
    try:
        while True:
            d=a.recv(65536)
            if not d: break
            b.sendall(d)
    except Exception as e: pass
    finally:
        try:a.close()
        except:pass
        try:b.close()
        except:pass
def h(c):
    try:
        r=socket.create_connection(("github.com",22),10)
        print("RELAY_GITHUB_CONNECTED",flush=True)
    except Exception as e:
        print("RELAY_GITHUB_CONNECT_FAIL",repr(e),flush=True); c.close(); return
    threading.Thread(target=pump,args=(c,r),daemon=True).start()
    threading.Thread(target=pump,args=(r,c),daemon=True).start()
while True:
    c,_=s.accept(); print("RELAY_CLIENT_CONNECTED",flush=True)
    threading.Thread(target=h,args=(c,),daemon=True).start()
PY
"$PYTHON" "$T/relay.py" "$SOCK" >"$T/relay.log" 2>&1 & RELAY_PID=$!
for _ in $(seq 1 50); do [ -S "$SOCK" ] && break; sleep .1; done
test -S "$SOCK" || { echo "FAIL: relay socket"; cat "$T/relay.log"; exit 3; }
echo "RELAY: ready"

cat >"$T/github-proxy.py" <<'PY'
import socket,sys,threading
s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM); s.connect("/home/sandbox/github.sock")
def out():
    try:
        while True:
            d=s.recv(65536)
            if not d: break
            sys.stdout.buffer.write(d); sys.stdout.buffer.flush()
    except: pass
threading.Thread(target=out,daemon=True).start()
try:
    while True:
        d=sys.stdin.buffer.read(65536)
        if not d: break
        s.sendall(d)
except: pass
PY
cat >"$T/known_hosts" <<'EOF'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
EOF
cat >"$T/ssh_config" <<EOF
Host github.com
    HostName github.com
    User git
    IdentityFile /home/sandbox/github_key
    IdentitiesOnly yes
    ProxyCommand /usr/bin/python3 /home/sandbox/github-proxy.py
    StrictHostKeyChecking yes
    UserKnownHostsFile /home/sandbox/known_hosts
    ConnectTimeout 8
EOF
LIB64=(); [ -d /lib64 ] && LIB64=(--ro-bind /lib64 /lib64)

echo "SANDBOX: start"
set +e
timeout 20 "$BWRAP" \
 --unshare-user --unshare-net --unshare-pid --unshare-ipc --unshare-uts \
 --die-with-parent --new-session \
 --ro-bind /usr /usr --ro-bind /bin /bin --ro-bind /lib /lib "${LIB64[@]}" \
 --dev /dev --tmpfs /etc \
 --ro-bind /etc/passwd /etc/passwd --ro-bind /etc/group /etc/group --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf \
 --tmpfs /tmp --tmpfs /home --dir /home/sandbox \
 --ro-bind "$T/github-proxy.py" /home/sandbox/github-proxy.py \
 --ro-bind "$T/known_hosts" /home/sandbox/known_hosts \
 --ro-bind "$T/ssh_config" /home/sandbox/ssh_config \
 --ro-bind "$KEY" /home/sandbox/github_key --bind "$SOCK" /home/sandbox/github.sock \
 --chdir /home/sandbox --uid 1000 --gid 1000 \
 /bin/sh -c 'echo "SANDBOX: shell-ok"; test -c /dev/null && echo "SANDBOX: dev-null-ok"; test -x /usr/bin/ssh && echo "SANDBOX: ssh-ok"; exec /usr/bin/ssh -F /home/sandbox/ssh_config -T git@github.com'
RC=$?
set -e
echo "SANDBOX_EXIT=$RC"
echo "--- RELAY LOG ---"
cat "$T/relay.log" || true
echo "--- RESULT ---"
if grep -q RELAY_GITHUB_CONNECTED "$T/relay.log"; then echo "PASS: sandbox reached fixed GitHub relay"; else echo "FAIL: sandbox did not reach GitHub"; fi
