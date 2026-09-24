#!/bin/sh
set -eu

BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
T=$(mktemp -d /tmp/ai-guard-test.XXXXXX)
trap 'rm -rf "$T"' EXIT
W="$T/workspace"
mkdir -p "$W"
printf 'ok\n' > "$W/input"

guard(){ "$BASE/bin/ai-guard" --workspace "$W" --network none -- "$@"; }

echo "== guarded program =="
"$BASE/bin/ai-guard" --workspace "$W" --program /bin/sh --network none -- -c 'test "$PWD" = /workspace; touch /workspace/program-ok; test -f /workspace/program-ok'
echo PASS

echo "== secret environment =="
printf 'SECRET_OK' > "$T/secret"
"$BASE/bin/ai-guard" --workspace "$W" --program /bin/sh --secret-env TEST_SECRET "$T/secret" -- -c 'test "$TEST_SECRET" = SECRET_OK'
echo PASS
echo "== filesystem =="
guard /bin/sh -c 'test -f /workspace/input; touch /workspace/write-ok; test -f /workspace/write-ok; ! touch /etc/ai-guard-write-test 2>/dev/null; ! test -e /vol1; ! test -e /home/admin/.ssh; ! test -e /root/.ssh'
echo PASS

echo "== workspace guard =="
if "$BASE/bin/ai-guard" --workspace "$BASE" -- /bin/true 2>/dev/null; then exit 10; fi
if "$BASE/bin/ai-guard" --workspace "$BASE/sandbox" -- /bin/true 2>/dev/null; then exit 11; fi
if "$BASE/bin/ai-guard" --workspace "$(dirname "$BASE")" -- /bin/true 2>/dev/null; then exit 12; fi
if "$BASE/bin/ai-guard" --workspace "$HOME" -- /bin/true 2>/dev/null; then exit 13; fi
if "$BASE/bin/ai-guard" --workspace /etc -- /bin/true 2>/dev/null; then exit 14; fi
echo PASS

echo "== policy guard =="
if "$BASE/bin/ai-guard" --workspace "$W" --policy "$W/input" -- /bin/true 2>/dev/null; then exit 15; fi
echo PASS

echo "== root guard =="
if [ "$(id -u)" -eq 0 ]; then
  echo "SKIP (already root)"
else
  if [ -x /usr/bin/sudo ]; then
    if sudo "$BASE/bin/ai-guard" --workspace "$W" -- /bin/true 2>/dev/null; then exit 16; fi
    echo PASS
  else
    echo "SKIP (sudo unavailable)"
  fi
fi

echo "== home =="
guard /bin/sh -c 'test -d "$HOME"; test ! -e "$HOME/../admin/.ssh"; touch "$HOME/home-write"; test -f "$HOME/home-write"'
echo PASS

echo "== docker sockets =="
guard /bin/sh -c 'test ! -S /var/run/docker.sock; test ! -S /run/docker.sock; test ! -S /var/run/containerd/containerd.sock'
echo PASS

echo "== capabilities/session =="
guard /bin/sh -c 'test "$(id -u)" -ne 0; grep -q "^CapEff:[[:space:]]*0000000000000000" /proc/self/status; test "$$" -ge 1'
echo PASS

echo "== pid namespace =="
PID=$(guard /bin/sh -c 'echo $$')
case "$PID" in 1|2|3|4|5|6|7|8|9) ;; *) echo "unexpected PID: $PID" >&2; exit 20;; esac
echo PASS

echo "== network namespace =="
guard /bin/sh -c 'grep -q "^[[:space:]]*lo:" /proc/net/dev; test "$(grep -Ec "^[[:space:]]*[^[:space:]]+:" /proc/net/dev)" = 1'
echo PASS

echo "== network host mode =="
HOST_NET_OUTPUT=$("$BASE/bin/ai-guard" --workspace "$W" --network host --debug -- /bin/true 2>&1)
case "$HOST_NET_OUTPUT" in
  *--unshare-net*) echo "host mode unexpectedly requested --unshare-net" >&2; exit 21;;
esac
echo PASS

echo "== symlink escape =="
ln -s /etc "$W/escape"
if guard /bin/sh -c 'echo bad > /workspace/escape/ai-guard-test' 2>/dev/null; then
  echo "symlink escape succeeded" >&2
  exit 30
fi
echo PASS

echo "ALL TESTS PASSED"
