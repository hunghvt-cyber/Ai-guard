#!/bin/bash
set -euo pipefail
KEY=${AI_GUARD_GITHUB_KEY:-/home/admin/.ssh/github_gemini_ngusidan}
BWRAP=$(command -v bwrap) || { echo "FAIL: bwrap not found"; exit 2; }
PYTHON=$(command -v python3) || { echo "FAIL: python3 not found"; exit 2; }
test -r "$KEY" || { echo "FAIL: GitHub key not readable"; exit 2; }

T=$(mktemp -d /tmp/ai-guard-gh-transport.XXXXXX)
SOCK="$T/github.sock"
cleanup(){ kill "${RELAY_PID:-}" 2>/dev/null || true; rm -rf "$T"; }
trap cleanup EXIT

cat >"$T/relay.py" <<'PY'
import socket,sys,threading
path=sys.argv[1]
srv=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
srv.bind(path); srv.listen(8)
print("RELAY_READY",flush=True)
def relay(c):
    try:
        r=socket.create_connection(("github.com",22),10)
        print("RELAY_GITHUB_CONNECTED",flush=True)
        def cp(a,b):
            try:
                while True:
                    d=a.recv(65536)
                    if not d: break
                    b.sendall(d)
            except: pass
            finally:
                try:b.shutdown(socket.SHUT_WR)
                except:pass
        t=threading.Thread(target=cp,args=(c,r)); t.start()
        cp(r,c); t.join()
    except Exception as e:
        print("RELAY_ERROR",repr(e),flush=True)
    finally:
        try:c.close()
        except:pass
        try:r.close()
        except:pass
while True:
    c,_=srv.accept()
    print("RELAY_CLIENT_CONNECTED",flush=True)
    threading.Thread(target=relay,args=(c,),daemon=True).start()
PY
"$PYTHON" "$T/relay.py" "$SOCK" >"$T/relay.log" 2>&1 &
RELAY_PID=$!
for _ in $(seq 1 50); do [ -S "$SOCK" ] && break; sleep .1; done
test -S "$SOCK" || { echo "FAIL: relay socket"; cat "$T/relay.log"; exit 3; }

cat >"$T/probe.py" <<'PY'
import socket
s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
s.settimeout(8)
s.connect("/home/sandbox/github.sock")
data=b""
while b"\n" not in data and len(data)<4096:
    x=s.recv(4096)
    if not x: break
    data+=x
print(data.decode("ascii","replace").rstrip())
PY

echo "=== Transport-only test: bwrap network=none -> fixed GitHub relay -> SSH banner ==="
set +e
timeout 15 "$BWRAP" \
 --unshare-user --unshare-net --unshare-pid --unshare-ipc --unshare-uts \
 --die-with-parent --new-session \
 --ro-bind /usr /usr --ro-bind /bin /bin --ro-bind /lib /lib \
 --dev /dev --tmpfs /etc \
 --ro-bind /etc/passwd /etc/passwd --ro-bind /etc/group /etc/group \
 --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf \
 --tmpfs /tmp --tmpfs /home --dir /home/sandbox \
 --ro-bind "$T/probe.py" /home/sandbox/probe.py \
 --bind "$SOCK" /home/sandbox/github.sock \
 --chdir /home/sandbox --uid 1000 --gid 1000 \
 /usr/bin/python3 /home/sandbox/probe.py
RC=$?
set -e
echo "PROBE_EXIT=$RC"
echo "--- RELAY LOG ---"
cat "$T/relay.log"
