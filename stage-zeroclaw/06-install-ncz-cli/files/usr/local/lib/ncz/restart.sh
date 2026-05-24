#!/usr/bin/env bash

ncz_cmd_restart() {
    [ "$#" -le 1 ] || ncz_die "usage: ncz restart [agent]" 1
    ncz_require_systemd
    local agent="${1:-$(ncz_active_agent)}"
    ncz_validate_agent "$agent"
    ncz_sudo systemctl restart "$(ncz_agent_service "$agent")"
    printf 'Restarted %s.\n' "$agent"
}
