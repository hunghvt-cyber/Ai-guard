#!/bin/bash
set -euo pipefail
WORKSPACE=""; REQUESTED_NETWORK=none; POLICY=""; DEBUG=0
PROGRAM_STAGE=""; SECRET_NAME=""; SECRET_FILE=""; SECRET_FILE_NAME=""; SETENV_FILE=""
while [[ $# -gt 0 ]]; do
 case "$1" in
  --workspace) WORKSPACE="$2"; shift 2;;
  --network) REQUESTED_NETWORK="$2"; shift 2;;
  --policy) POLICY="$2"; shift 2;;
  --program-stage) PROGRAM_STAGE="$2"; shift 2;;
  --secret-env) SECRET_NAME="$2"; SECRET_FILE="$3"; SECRET_FILE_NAME=""; shift 3;;
  --secret-file) SECRET_FILE_NAME="$2"; SECRET_FILE="$3"; shift 3;;
  --setenv-file) SETENV_FILE="$2"; shift 2;;
  --debug) DEBUG="$2"; shift 2;;
  --) shift; break;;
  *) echo "unknown backend option: $1" >&2; exit 2;;
 esac
done
[[ -d "$WORKSPACE" && -f "$POLICY" && $# -gt 0 ]] || { echo "invalid workspace, policy, or command" >&2; exit 2; }
source "$POLICY"
[[ "$WORKSPACE_MODE" == rw ]] || { echo "WORKSPACE_MODE must be rw" >&2; exit 2; }
[[ "$EXPOSE_SSH" == 0 && "$EXPOSE_DOCKER" == 0 && "$EXPOSE_VOL1" == 0 ]] || { echo "sensitive-path exposure is disabled" >&2; exit 2; }
B=(bwrap --ro-bind /usr /usr --ro-bind /bin /bin)
[[ -d /lib ]] && B+=(--ro-bind /lib /lib)
[[ -d /lib64 ]] && B+=(--ro-bind /lib64 /lib64)
B+=(--ro-bind /etc /etc --proc /proc --dev /dev --tmpfs /tmp --tmpfs /home --tmpfs /root --dir /home/sandbox --bind "$WORKSPACE" /workspace --chdir /workspace --cap-drop ALL --new-session)
if [[ -n "$PROGRAM_STAGE" ]]; then
 [[ -d "$PROGRAM_STAGE" ]] || { echo "program staging directory missing" >&2; exit 2; }
 B+=(--ro-bind "$PROGRAM_STAGE" /opt/ai-guard)
fi
SECRET_DEST=""
SECRET_FILE_DEST=""
if [[ -n "$SECRET_NAME" ]]; then
 [[ -f "$SECRET_FILE" ]] || { echo "secret file missing" >&2; exit 2; }
 exec {SECRET_FD}<"$SECRET_FILE"
 B+=(--dir /run --dir /run/secrets --ro-bind-data "$SECRET_FD" "/run/secrets/$SECRET_NAME")
 SECRET_DEST="/run/secrets/$SECRET_NAME"
fi
if [[ -n "$SECRET_FILE_NAME" ]]; then
 [[ -f "$SECRET_FILE" ]] || { echo "secret file missing" >&2; exit 2; }
 exec {SECRET_FILE_FD}<"$SECRET_FILE"
 B+=(--dir /run --dir /run/secrets --ro-bind-data "$SECRET_FILE_FD" "/run/secrets/$SECRET_FILE_NAME")
 SECRET_FILE_DEST="/run/secrets/$SECRET_FILE_NAME"
fi
[[ "$PID_NAMESPACE" == 1 ]] && B+=(--unshare-pid)
[[ "$IPC_NAMESPACE" == 1 ]] && B+=(--unshare-ipc)
[[ "$UTS_NAMESPACE" == 1 ]] && B+=(--unshare-uts)
[[ "$REQUESTED_NETWORK" == none ]] && B+=(--unshare-net)
[[ "$DIE_WITH_PARENT" == 1 ]] && B+=(--die-with-parent)
B+=(--clearenv --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin --setenv HOME /home/sandbox --setenv USER sandbox --setenv LOGNAME sandbox)
if [[ -n "$SETENV_FILE" ]]; then
  [[ -f "$SETENV_FILE" ]] || { echo "setenv file missing" >&2; exit 2; }
  while IFS= read -r ENV_NAME && IFS= read -r ENV_VALUE; do
    [[ "$ENV_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { echo "invalid environment name" >&2; exit 2; }
    B+=(--setenv "$ENV_NAME" "$ENV_VALUE")
  done < "$SETENV_FILE"
fi
B+=(--)
CMD=("$@")
if [[ -n "$PROGRAM_STAGE" ]]; then CMD=(/opt/ai-guard/program "${CMD[@]}"); fi
if [[ -n "$SECRET_NAME" ]]; then
 SCRIPT='secret=$(cat "$1"); export "$2=$secret"; shift 2; exec "$@"'
 CMD=(/bin/sh -c "$SCRIPT" /run/secrets/entry "$SECRET_DEST" "$SECRET_NAME" "${CMD[@]}")
fi
if [[ "$DEBUG" == 1 ]]; then printf '%q ' "${B[@]}" >&2; printf '\n' >&2; fi
exec "${B[@]}" "${CMD[@]}"
