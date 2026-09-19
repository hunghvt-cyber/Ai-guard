#!/bin/bash
set -euo pipefail

WORKSPACE=""
NETWORK="none"
POLICY=""
DEBUG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --network) NETWORK="$2"; shift 2 ;;
    --policy) POLICY="$2"; shift 2 ;;
    --debug) DEBUG="$2"; shift 2 ;;
    --) shift; break ;;
    *) echo "unknown backend option: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$WORKSPACE" ]] || { echo "invalid workspace" >&2; exit 2; }
[[ -f "$POLICY" ]] || { echo "invalid policy" >&2; exit 2; }
[[ $# -gt 0 ]] || { echo "no command" >&2; exit 2; }
source "$POLICY"

[[ "$WORKSPACE_MODE" == "rw" ]] || { echo "WORKSPACE_MODE must be rw" >&2; exit 2; }
[[ "$EXPOSE_SSH" == "0" && "$EXPOSE_DOCKER" == "0" && "$EXPOSE_VOL1" == "0" ]] || {
  echo "default-sensitive paths cannot be enabled by this prototype" >&2; exit 2;
}

B=(bwrap
  --ro-bind /usr /usr
  --ro-bind /bin /bin
)
[[ -d /lib ]] && B+=(--ro-bind /lib /lib)
[[ -d /lib64 ]] && B+=(--ro-bind /lib64 /lib64)
B+=(--ro-bind /etc /etc
    --proc /proc
    --dev /dev
    --tmpfs /tmp
    --tmpfs /home
    --tmpfs /root
    --bind "$WORKSPACE" /workspace
    --chdir /workspace)

[[ "$PID_NAMESPACE" == "1" ]] && B+=(--unshare-pid)
[[ "$IPC_NAMESPACE" == "1" ]] && B+=(--unshare-ipc)
[[ "$UTS_NAMESPACE" == "1" ]] && B+=(--unshare-uts)
[[ "$NETWORK" == "none" ]] && B+=(--unshare-net)
[[ "$DIE_WITH_PARENT" == "1" ]] && B+=(--die-with-parent)

B+=(--clearenv
    --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    --setenv HOME /home/sandbox
    --setenv USER sandbox
    --setenv LOGNAME sandbox
    --)

if [[ "$DEBUG" == "1" ]]; then
  printf '%q ' "${B[@]}" >&2
  printf '\n' >&2
fi

exec "${B[@]}" "$@"
