#!/bin/bash
set -euo pipefail
KEY=${AI_GUARD_GITHUB_KEY:-/home/admin/.ssh/github_gemini_ngusidan}
BWRAP=$(command -v bwrap) || { echo "FAIL: bwrap not found"; exit 2; }
PYTHON=$(command -v python3) || { echo "FAIL: python3 not found"; exit 2; }
SSH=$(command -v ssh) || { echo "FAIL: ssh not found"; exit 2; }
test -r "$KEY" || { echo "FAIL: GitHub key not readable"; exit 2; }

T=$(mktemp -d /tmp/ai-guard-gh-ssh.XXXXXX); SOCK="$T/github.sock"
trap 'kill "${RELAY_PID:-}" 2>/dev/null || true; rm -rf "$T"' EXIT

cat >"$T/relay.py" <<'PY'
import socket,sys,threading
p=sys.argv[1]
s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM); s.bind(p); s.listen(8)
print("RELAY_READY",flush=True)
def copy(a,b):
    try:
        while True:
            d=a.recv(65536)
            if not d: break
            b.sendall(d)
    except: pass
    finally:
        try:b.shutdown(socket.SHUT_WR)
        except:pass
def handle(c):
    try:
        r=socket.create_connection(("github.com",22),10)
        print("RELAY_GITHUB_CONNECTED",flush=True)
        t=threading.Thread(target=copy,args=(c,r)); t.start()
        copy(r,c); t.join()
    except Exception as e:
        print("RELAY_ERROR",repr(e),flush=True)
    finally:
        try:c.close()
        except:pass
        try:r.close()
        except:pass
while True:
    c,_=s.accept(); print("RELAY_CLIENT_CONNECTED",flush=True)
    threading.Thread(target=handle,args=(c,),daemon=True).start()
PY

"$PYTHON" "$T/relay.py" "$SOCK" >"$T/relay.log" 2>&1 &
RELAY_PID=$!
for _ in $(seq 1 50); do [ -S "$SOCK" ] && break; sleep .1; done
test -S "$SOCK" || { echo "FAIL: relay socket"; cat "$T/relay.log"; exit 3; }

cat >"$T/proxy.py" <<'PY'
import os,select,socket,sys
s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
s.connect("/home/sandbox/github.sock")
fds=[sys.stdin.buffer,s]
while fds:
    r,_,_=select.select(fds,[],[])
    for x in r:
        try:
            d=x.read1(65536) if x is sys.stdin.buffer else x.recv(65536)
        except Exception:
            d=b""
        if not d:
            try:fds.remove(x)
            except ValueError:pass
            if x is sys.stdin.buffer:
                try:s.shutdown(socket.SHUT_WR)
                except:pass
            else:
                try:sys.stdout.buffer.close()
                except:pass
            continue
        if x is sys.stdin.buffer:
            s.sendall(d)
        else:
            sys.stdout.buffer.write(d)
            sys.stdout.buffer.flush()
PY

cat >"$T/ssh_config" <<EOF
Host github.com
    HostName github.com
    User git
    IdentityFile /home/sandbox/github_key
    IdentitiesOnly yes
    ProxyCommand /usr/bin/python3 /home/sandbox/proxy.py
    StrictHostKeyChecking yes
    UserKnownHostsFile /home/sandbox/known_hosts
    ConnectTimeout 8
EOF

cat >"$T/known_hosts" <<'EOF'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
EOF

echo "=== SSH authentication through fixed GitHub relay ==="
set +e
timeout 20 "$BWRAP" \
 --unshare-user --unshare-net --unshare-pid --unshare-ipc --unshare-uts \
 --die-with-parent --new-session \
 --ro-bind /usr /usr --ro-bind /bin /bin --ro-bind /lib /lib \
 --dev /dev --tmpfs /etc \
 --ro-bind /etc/passwd /etc/passwd --ro-bind /etc/group /etc/group \
 --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf \
 --tmpfs /tmp --tmpfs /home --dir /home/sandbox \
 --ro-bind "$T/proxy.py" /home/sandbox/proxy.py \
 --ro-bind "$T/ssh_config" /home/sandbox/ssh_config \
 --ro-bind "$T/known_hosts" /home/sandbox/known_hosts \
 --ro-bind "$KEY" /home/sandbox/github_key \
 --bind "$SOCK" /home/sandbox/github.sock \
 --chdir /home/sandbox --uid 1000 --gid 1000 \
 /bin/sh -c 'exec /usr/bin/ssh -vvv -F /home/sandbox/ssh_config -T git@github.com'
RC=$?
set -e
echo "SSH_EXIT=$RC"
echo "--- RELAY LOG ---"
cat "$T/relay.log"
