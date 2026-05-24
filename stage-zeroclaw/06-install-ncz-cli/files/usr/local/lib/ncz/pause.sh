#!/usr/bin/env bash

ncz_cmd_pause() {
    [ "$#" -le 1 ] || ncz_die "usage: ncz pause [agent]" 1
    ncz_require_systemd
    local agent="${1:-$(ncz_active_agent)}"
    ncz_validate_agent "$agent"
    ncz_sudo systemctl stop "$(ncz_agent_service "$agent")"
    printf 'Paused %s.\n' "$agent"
}
