#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
T=$(mktemp -d /tmp/ai-guard-test.XXXXXX)
trap 'rm -rf "$T"' EXIT
W="$T/workspace"
mkdir -p "$W"
printf 'ok\n' > "$W/input"

guard() { "$BASE/bin/ai-guard" --workspace "$W" --network none -- "$@"; }

echo "== filesystem =="
guard /bin/sh -c '
  test -f /workspace/input
  touch /workspace/write-ok
  test -f /workspace/write-ok
  ! touch /etc/ai-guard-write-test 2>/dev/null
  ! test -e /vol1
  ! test -e /home/admin/.ssh
  ! test -e /root/.ssh
'
echo "PASS"

echo "== docker sockets =="
guard /bin/sh -c '
  test ! -S /var/run/docker.sock
  test ! -S /run/docker.sock
  test ! -S /var/run/containerd/containerd.sock
'
echo "PASS"

echo "== pid namespace =="
PID=$(guard /bin/sh -c 'echo $$')
case "$PID" in 1|2|3|4|5|6|7|8|9) ;; *) echo "unexpected PID: $PID" >&2; exit 20 ;; esac
echo "PASS"

echo "== network namespace =="
guard /bin/sh -c 'test "$(ls /sys/class/net 2>/dev/null | tr "\n" " ")" = "lo "'
echo "PASS"

echo "== symlink escape =="
ln -s /etc "$W/escape"
if guard /bin/sh -c 'echo bad > /workspace/escape/ai-guard-test' 2>/dev/null; then
  echo "symlink escape succeeded" >&2
  exit 30
fi
echo "PASS"

echo "ALL TESTS PASSED"
