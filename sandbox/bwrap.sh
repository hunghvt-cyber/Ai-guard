#!/bin/bash
set -euo pipefail

BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BASE=$(readlink -f "$BASE")

WORKSPACE=""; REQUESTED_NETWORK=none; POLICY=""; DEBUG=0; OPENCODE=0; SSH=0
while [[ $# -gt 0 ]]; do
 case "$1" in
  --workspace) WORKSPACE="$2"; shift 2;;
  --network) REQUESTED_NETWORK="$2"; shift 2;;
  --policy) POLICY="$2"; shift 2;;
  --opencode) OPENCODE="$2"; shift 2;;
  --ssh) SSH="$2"; shift 2;;
  --debug) DEBUG="$2"; shift 2;;
  --) shift; break;;
  *) echo "unknown backend option: $1" >&2; exit 2 ;;
 esac
done

[[ -d "$WORKSPACE" && -f "$POLICY" && $# -gt 0 ]] || { echo "invalid workspace, policy, or command" >&2; exit 2; }
source "$POLICY"
[[ "$WORKSPACE_MODE" == rw ]] || { echo "WORKSPACE_MODE must be rw" >&2; exit 2; }
[[ "$EXPOSE_SSH" == 0 && "$EXPOSE_DOCKER" == 0 && "$EXPOSE_VOL1" == 0 ]] || { echo "sensitive-path exposure is disabled" >&2; exit 2; }

B=(bwrap
   --ro-bind /usr /usr
   --ro-bind /bin /bin)
[[ -d /lib ]] && B+=(--ro-bind /lib /lib)
[[ -d /lib64 ]] && B+=(--ro-bind /lib64 /lib64)
B+=(
  --ro-bind /etc /etc
  --ro-bind /vol1 /vol1
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

if [[ "$WORKSPACE" == /vol1/* ]]; then
  B+=(--bind "$WORKSPACE" "$WORKSPACE")
fi

[[ "$PID_NAMESPACE" == 1 ]] && B+=(--unshare-pid)
[[ "$IPC_NAMESPACE" == 1 ]] && B+=(--unshare-ipc)
[[ "$UTS_NAMESPACE" == 1 ]] && B+=(--unshare-uts)
[[ "$REQUESTED_NETWORK" == none ]] && B+=(--unshare-net)
[[ "$USER_NAMESPACE" == 1 ]] && B+=(--unshare-user)
[[ "$DIE_WITH_PARENT" == 1 ]] && B+=(--die-with-parent)

if [[ "$SSH" == 1 ]]; then
  SSH_KEY=/vol1/Docker/gemini/home/.ssh/id_ed25519_gemini
  SSH_KNOWN_HOSTS=/vol1/Docker/gemini/home/.ssh/known_hosts
  SSH_CONFIG="$BASE/adapters/opencode/ssh/config"

  [[ -f "$SSH_KEY" && -r "$SSH_KEY" ]] || {
    echo "SSH private key not found or not readable: $SSH_KEY" >&2
    exit 2
  }

  [[ -f "$SSH_KNOWN_HOSTS" && -r "$SSH_KNOWN_HOSTS" ]] || {
    echo "SSH known_hosts not found or not readable: $SSH_KNOWN_HOSTS" >&2
    exit 2
  }

  [[ -f "$SSH_CONFIG" && -r "$SSH_CONFIG" ]] || {
    echo "SSH config not found or not readable: $SSH_CONFIG" >&2
    exit 2
  }

  B+=(
    --dir /home/admin/.ssh
    --ro-bind "$SSH_CONFIG" /home/admin/.ssh/config
    --ro-bind "$SSH_KEY" /home/admin/.ssh/id_ed25519_gemini
    --ro-bind "$SSH_KNOWN_HOSTS" /home/admin/.ssh/known_hosts
  )
fi

if [[ "$OPENCODE" == 1 ]]; then
  OPENCODE_BIN=/home/admin/.opencode/bin/opencode
  OPENCODE_CONFIG=/home/admin/.config/opencode/opencode.jsonc
  OPENCODE_AUTH=/home/admin/.local/share/opencode/auth.json

  [[ -f "$OPENCODE_BIN" && -x "$OPENCODE_BIN" ]] || {
    echo "OpenCode binary not found or not executable: $OPENCODE_BIN" >&2
    exit 2
  }

  [[ -f "$OPENCODE_CONFIG" ]] || {
    echo "OpenCode config not found: $OPENCODE_CONFIG" >&2
    exit 2
  }

  [[ -f "$OPENCODE_AUTH" ]] || {
    echo "OpenCode auth not found: $OPENCODE_AUTH" >&2
    exit 2
  }

  B+=(
    --dir /opencode
    --ro-bind "$OPENCODE_BIN" /opencode/opencode
    --dir /home/sandbox/.config/opencode
    --ro-bind "$OPENCODE_CONFIG" /home/sandbox/.config/opencode/opencode.jsonc
    --dir /home/sandbox/.local
    --dir /home/sandbox/.local/share
    --dir /home/sandbox/.local/share/opencode
    --ro-bind "$OPENCODE_AUTH" /home/sandbox/.local/share/opencode/auth.json
  )
fi

B+=(
  --clearenv
  --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  --setenv HOME /home/sandbox
  --setenv USER sandbox
  --setenv LOGNAME sandbox
)

# Explicit credential handoff: selector -> Guard -> sandbox.
# Do not inherit the host environment wholesale.
if [[ -n "${GOOGLE_GENERATIVE_AI_API_KEY:-}" ]]; then
  B+=(--setenv GOOGLE_GENERATIVE_AI_API_KEY "$GOOGLE_GENERATIVE_AI_API_KEY")
fi

B+=(--)

if [[ "$DEBUG" == 1 ]]; then
  printf '%q ' "${B[@]}" >&2
  printf '\n' >&2
fi

exec "${B[@]}" "$@"
