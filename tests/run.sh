#!/bin/sh
# Regression tests for files/bin/force-ssh-run, run against a fake S50dropbear and a fake pgrep (no
# printer, no real dropbear, no root needed). The daemon's own install.service mechanism is covered by
# Bespok3d/daemon's tests, not re-tested here.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
FORCE_SSH_RUN="$HERE/../files/bin/force-ssh-run"
WORK="$(mktemp -d)"
watcher_pid=""
cleanup() {
  [ -n "$watcher_pid" ] && kill "$watcher_pid" 2> /dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# The fake init script logs every call's arguments, and "starts" dropbear by creating the marker the
# fake pgrep reads, exactly as the real one would leave a dropbear process behind.
INIT_CALLS="$WORK/init-calls"
DROPBEAR_UP="$WORK/dropbear-up"
cat > "$WORK/S50dropbear" << EOF
#!/bin/sh
echo "\$*" >> "$INIT_CALLS"
[ "\$1 \$2" = "start --force" ] && : > "$DROPBEAR_UP"
exit 0
EOF
chmod +x "$WORK/S50dropbear"

# Only `pgrep -x dropbear` is faked; the wrapper asks nothing else of pgrep.
mkdir "$WORK/bin"
cat > "$WORK/bin/pgrep" << EOF
#!/bin/sh
[ "\$*" = "-x dropbear" ] || exit 2
[ -e "$DROPBEAR_UP" ]
EOF
chmod +x "$WORK/bin/pgrep"
PATH="$WORK/bin:$PATH"
export PATH

init_call_count() {
  [ -f "$INIT_CALLS" ] || { echo 0; return; }
  wc -l < "$INIT_CALLS" | tr -d ' '
}

# Polls instead of sleeping a fixed time, so a slow CI runner does not make the suite flaky.
wait_for_init_calls() {
  expected_calls="$1"
  tries=0
  while [ "$(init_call_count)" -lt "$expected_calls" ]; do
    tries=$((tries + 1))
    [ "$tries" -le 50 ] || fail "expected $expected_calls init call(s), saw $(init_call_count)"
    sleep 0.1
  done
}

start_watcher() {
  sh "$FORCE_SSH_RUN" "$WORK/S50dropbear" 1 > "$WORK/watcher.log" 2>&1 &
  watcher_pid=$!
}

stop_watcher() {
  kill "$watcher_pid"
  wait "$watcher_pid" || fail "force-ssh-run did not exit 0 on TERM"
  watcher_pid=""
}

# 1. dropbear down at start: the stock init script is called with `start --force`, nothing else.
start_watcher
wait_for_init_calls 1
[ "$(cat "$INIT_CALLS")" = "start --force" ] || fail "init called with '$(cat "$INIT_CALLS")', want 'start --force'"

# 2. dropbear up: later checks leave it alone.
sleep 2.5
[ "$(init_call_count)" = "1" ] || fail "init was called again while dropbear was running"

# 3. dropbear dies (killed by hand, crashed): the next check forces it back on.
rm -f "$DROPBEAR_UP"
wait_for_init_calls 2
[ -e "$DROPBEAR_UP" ] || fail "dropbear was not restarted after it went down"

# 4. A stop signal ends the watcher at once, and never stops dropbear: a user's SSH session survives
# an uninstall or a service restart.
stop_started="$(date +%s)"
stop_watcher
[ $(($(date +%s) - stop_started)) -le 1 ] || fail "force-ssh-run took longer than its check interval to stop"
grep -q stop "$INIT_CALLS" && fail "force-ssh-run stopped dropbear on its way out"

# 5. dropbear already up when the service starts (a restart, or the stock UI already enabled SSH):
# no init call at all.
: > "$INIT_CALLS"
start_watcher
sleep 1.5
[ "$(init_call_count)" = "0" ] || fail "init was called although dropbear was already running"
stop_watcher

# 6. A missing init script (a firmware without S50dropbear) fails clearly instead of looping.
if sh "$FORCE_SSH_RUN" "$WORK/does-not-exist" 1 2> /dev/null; then
  fail "force-ssh-run ran with a missing init script"
fi

# 7. A check interval that is not a positive whole number is rejected before anything runs.
for bad_interval in "" 0 abc "5;reboot" -1; do
  if sh "$FORCE_SSH_RUN" "$WORK/S50dropbear" "$bad_interval" 2> /dev/null; then
    fail "force-ssh-run accepted the check interval '$bad_interval'"
  fi
done

echo "All force-ssh-run tests passed."
