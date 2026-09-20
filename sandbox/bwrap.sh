#!/bin/bash
set -euo pipefail

WORKSPACE=""; REQUESTED_NETWORK=none; CAPABILITY=none; POLICY=""; DEBUG=0
while [[ $# -gt 0 ]]; do
 case "$1" in
  --workspace) WORKSPACE="$2"; shift 2;;
  --network) REQUESTED_NETWORK="$2"; shift 2;;
  --capability) CAPABILITY="$2"; shift 2;;
  --policy) POLICY="$2"; shift 2;;
  --debug) DEBUG="$2"; shift 2;;
  --) shift; break;;
  *) echo "unknown backend option: $1" >&2; exit 2;;
 esac
done

[[ -d "$WORKSPACE" && -f "$POLICY" && $# -gt 0 ]] || { echo "invalid workspace, policy, or command" >&2; exit 2; }
source "$POLICY"
[[ "$WORKSPACE_MODE" == rw ]] || { echo "WORKSPACE_MODE must be rw" >&2; exit 2; }
[[ "$EXPOSE_SSH" == 0 && "$EXPOSE_DOCKER" == 0 && "$EXPOSE_VOL1" == 0 ]] || { echo "sensitive-path exposure is disabled" >&2; exit 2; }
[[ "$REQUESTED_NETWORK" == none && "$NETWORK" == none ]] || { echo "network mode is disabled by policy" >&2; exit 2; }
[[ "$CAPABILITY" == none || "$CAPABILITY" == github-ssh ]] || { echo "unsupported capability: $CAPABILITY" >&2; exit 2; }

if [[ "$CAPABILITY" == github-ssh ]]; then
  : "${AI_GUARD_GITHUB_KEY:?AI_GUARD_GITHUB_KEY must name the GitHub SSH key}"
  GITHUB_KEY=$(readlink -f "$AI_GUARD_GITHUB_KEY")
  [[ -r "$GITHUB_KEY" && -f "$GITHUB_KEY" ]] || { echo "GitHub key is not readable" >&2; exit 2; }
  command -v python3 >/dev/null 2>&1 || { echo "python3 not found" >&2; exit 127; }
  RELAY_DIR=$(mktemp -d /tmp/ai-guard-gh-ssh.XXXXXX)
  SOCK="$RELAY_DIR/github.sock"
  trap 'kill "${RELAY_PID:-}" 2>/dev/null || true; rm -rf "$RELAY_DIR"' EXIT
  python3 - "$SOCK" >"$RELAY_DIR/relay.log" 2>&1 <<'PY' &
import os,socket,sys,threading
s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
s.bind(sys.argv[1]); os.chmod(sys.argv[1],0o600); s.listen(8)
def cp(a,b):
    try:
        while True:
            d=a.recv(65536)
            if not d: break
            b.sendall(d)
    except OSError: pass
    finally:
        try: b.shutdown(socket.SHUT_WR)
        except OSError: pass
while True:
    c,_=s.accept(); r=None
    try:
        r=socket.create_connection(("github.com",22),10)
        t=threading.Thread(target=cp,args=(c,r)); t.start(); cp(r,c); t.join()
    except Exception:
        pass
    finally:
        try: c.close()
        except OSError: pass
        if r:
            try: r.close()
            except OSError: pass
PY
  RELAY_PID=$!
  for _ in $(seq 1 50); do [[ -S "$SOCK" ]] && break; sleep .1; done
  [[ -S "$SOCK" ]] || { echo "GitHub relay failed to start" >&2; exit 3; }
  cat >"$RELAY_DIR/proxy.py" <<'PY'
import select,socket,sys
s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM); s.connect("/home/sandbox/github.sock")
xs=[sys.stdin.buffer,s]
while xs:
    rs,_,_=select.select(xs,[],[])
    for x in rs:
        try: d=x.read1(65536) if x is sys.stdin.buffer else x.recv(65536)
        except OSError: d=b""
        if not d:
            xs.remove(x)
            if x is sys.stdin.buffer:
                try: s.shutdown(socket.SHUT_WR)
                except OSError: pass
            continue
        if x is sys.stdin.buffer: s.sendall(d)
        else: sys.stdout.buffer.write(d); sys.stdout.buffer.flush()
PY
  cat >"$RELAY_DIR/ssh_config" <<'EOF'
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
  cat >"$RELAY_DIR/known_hosts" <<'EOF'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
EOF
fi

B=(bwrap
   --unshare-user
   --disable-userns
   --ro-bind /usr /usr
   --ro-bind /bin /bin)
[[ -d /lib ]] && B+=(--ro-bind /lib /lib)
[[ -d /lib64 ]] && B+=(--ro-bind /lib64 /lib64)

# Do not expose the host /etc wholesale. Keep only non-sensitive identity
# files needed by common CLI tools; network/DNS configuration is intentionally
# absent because networking is disabled.
B+=(
  --tmpfs /etc
  --ro-bind /etc/passwd /etc/passwd
  --ro-bind /etc/group /etc/group
  --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf
  --proc /proc
  --dev /dev
  --tmpfs /tmp
  --tmpfs /home
  --tmpfs /root
  --dir /home/sandbox
  --bind "$WORKSPACE" /workspace
  --chdir /workspace
  --cap-drop ALL
  --new-session
)

[[ "$PID_NAMESPACE" == 1 ]] && B+=(--unshare-pid)
[[ "$IPC_NAMESPACE" == 1 ]] && B+=(--unshare-ipc)
[[ "$UTS_NAMESPACE" == 1 ]] && B+=(--unshare-uts)
[[ "$DIE_WITH_PARENT" == 1 ]] && B+=(--die-with-parent)

if [[ "$CAPABILITY" == github-ssh ]]; then
  B+=(
    --dir /home/sandbox/.ssh
    --ro-bind "$RELAY_DIR/ssh_config" /home/sandbox/.ssh/config
    --ro-bind "$RELAY_DIR/known_hosts" /home/sandbox/known_hosts
    --ro-bind "$RELAY_DIR/proxy.py" /home/sandbox/proxy.py
    --ro-bind "$GITHUB_KEY" /home/sandbox/github_key
    --bind "$SOCK" /home/sandbox/github.sock
  )
fi

B+=(
  --clearenv
  --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  --setenv HOME /home/sandbox
  --setenv USER sandbox
  --setenv LOGNAME sandbox
  --
)

if [[ "$DEBUG" == 1 ]]; then
  printf '%q ' "${B[@]}" >&2
  printf '\n' >&2
fi

exec "${B[@]}" "$@"
