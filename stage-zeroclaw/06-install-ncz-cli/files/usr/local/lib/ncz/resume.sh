#!/usr/bin/env bash

ncz_cmd_resume() {
    [ "$#" -le 1 ] || ncz_die "usage: ncz resume [agent]" 1
    ncz_require_systemd
    local agent="${1:-$(ncz_active_agent)}"
    ncz_validate_agent "$agent"
    ncz_sudo systemctl start "$(ncz_agent_service "$agent")"
    printf 'Resumed %s.\n' "$agent"
}
