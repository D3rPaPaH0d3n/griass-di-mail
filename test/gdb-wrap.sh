#!/bin/sh
# TEMPORARY CI diagnostic: run a test binary under gdb so a crash leaves a
# backtrace. meson shows only the last 100 lines and this suite prints pages
# of certificate dumps and font warnings, so filter those and lead with the
# crash. Falls back to running directly where gdb is absent.
if ! command -v gdb >/dev/null 2>&1; then
    exec "$@"
fi
LOG=$(mktemp)
gdb -batch -ex 'set pagination off' -ex 'set confirm off' \
    -ex run -ex 'thread apply all bt' --args "$@" > "$LOG" 2>&1
status=$?
if grep -q 'Program received signal' "$LOG"; then
    echo "=== gdb: crash and backtrace ==="
    sed -n '/Program received signal/,$p' "$LOG" | head -120
else
    echo "=== gdb: no signal caught; tail ==="
    grep -vE 'Fontconfig error|libenchant-DEBUG|^[[:space:]]+[0-9a-f]{2}(:[0-9a-f]{2})+$|^[[:space:]]*$' "$LOG" | tail -60
fi
exit $status
