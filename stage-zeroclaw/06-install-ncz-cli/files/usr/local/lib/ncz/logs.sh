#!/usr/bin/env bash

ncz_cmd_logs() {
    [ "$#" -le 1 ] || ncz_die "usage: ncz logs [agent]" 1
    local agent="${1:-$(ncz_active_agent)}"
    ncz_validate_agent "$agent"
    exec journalctl -u "$(ncz_agent_service "$agent")" -n 200 -f
}
