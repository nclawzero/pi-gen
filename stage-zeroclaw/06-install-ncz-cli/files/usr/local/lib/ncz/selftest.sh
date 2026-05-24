#!/usr/bin/env bash

ncz_selftest_run() {
    local name="$1"
    shift
    printf 'selftest: %-18s' "$name"
    if "$@" >/tmp/ncz-selftest.out 2>/tmp/ncz-selftest.err; then
        printf ' ok\n'
        return 0
    fi
    local rc=$?
    if [ "$name" = "status" ] && [ "$rc" -eq 3 ]; then
        printf ' ok (reported inconsistent state)\n'
        return 0
    fi
    printf ' failed (exit %s)\n' "$rc"
    sed -n '1,8p' /tmp/ncz-selftest.err >&2
    return "$rc"
}

ncz_cmd_selftest() {
    [ "$#" -eq 0 ] || ncz_die "usage: ncz selftest" 1
    local bin="${NCZ_SELFTEST_BIN:-/usr/local/bin/ncz}"
    if [ ! -x "$bin" ]; then
        bin="${BASH_SOURCE%/*}/../../bin/ncz"
    fi
    [ -x "$bin" ] || ncz_die "cannot find executable ncz dispatcher" 2

    local failures=0
    ncz_selftest_run "help" "$bin" help || failures=$((failures + 1))
    ncz_selftest_run "version" "$bin" version --json || failures=$((failures + 1))
    ncz_selftest_run "status" "$bin" status --json || failures=$((failures + 1))
    ncz_selftest_run "sandbox" "$bin" sandbox --json || failures=$((failures + 1))
    ncz_selftest_run "providers list" "$bin" providers list --json || failures=$((failures + 1))

    rm -f /tmp/ncz-selftest.out /tmp/ncz-selftest.err
    if [ "$failures" -gt 0 ]; then
        ncz_die "selftest failed: ${failures} check(s)" 2
    fi
    printf 'selftest: all checks passed\n'
}
