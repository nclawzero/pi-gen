#!/usr/bin/env bash

ncz_cmd_channel() {
    [ "$#" -le 1 ] || ncz_die "usage: ncz channel [stable|canary|beta]" 1
    local channel="${1:-}"
    if [ -z "$channel" ]; then
        sed -n '1p' "$NCZ_CHANNEL_FILE" 2>/dev/null || printf 'stable\n'
        return 0
    fi
    case "$channel" in
        stable|canary|beta) ;;
        *) ncz_die "usage: ncz channel [stable|canary|beta]" 1 ;;
    esac
    ncz_atomic_write "$NCZ_CHANNEL_FILE" 0644 root root "$channel"
    printf 'Update channel: %s\n' "$channel"
}
