#!/bin/sh
# CI diagnostics: run a test binary under gdb so a crash leaves a backtrace in
# the test log. meson only shows the last 100 lines, and this suite prints
# pages of TLS certificate dumps and Fontconfig warnings, so filter that noise
# out and lead with the crash if there was one. Falls back to running the
# binary directly where gdb is unavailable, so this cannot turn a passing
# environment red.
if ! command -v gdb >/dev/null 2>&1; then
    exec "$@"
fi

LOG=$(mktemp)
gdb -batch \
    -ex 'set pagination off' \
    -ex 'set confirm off' \
    -ex run \
    -ex 'thread apply all bt full' \
    --args "$@" > "$LOG" 2>&1
status=$?

# Certificate hex dumps and font warnings crowd out everything useful.
denoise() {
    grep -vE 'Fontconfig error|^[[:space:]]+[0-9a-f]{2}(:[0-9a-f]{2})+$|^[[:space:]]+(sha1|sha256|pin-sha256):|^[[:space:]]*$' "$LOG"
}

if grep -q 'Program received signal' "$LOG"; then
    echo "=== gdb: crash and backtrace ==="
    sed -n '/Program received signal/,$p' "$LOG" | head -150
else
    echo "=== gdb: no signal caught; last 80 lines (denoised) ==="
    denoise | tail -80
fi
exit $status
