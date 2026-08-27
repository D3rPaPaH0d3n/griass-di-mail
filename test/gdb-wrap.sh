#!/bin/sh
# CI diagnostics: run a test binary under gdb so a crash leaves a backtrace
# in the test log. meson truncates to the last 100 lines, which is where the
# backtrace lands. Falls back to running the binary directly where gdb is
# unavailable, so this cannot turn a passing environment red.
if command -v gdb >/dev/null 2>&1; then
    exec gdb -batch \
        -ex run \
        -ex 'thread apply all bt' \
        --args "$@"
fi
exec "$@"
