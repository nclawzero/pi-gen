#!/usr/bin/env bash

ncz_cmd_health() {
    [ "$#" -eq 0 ] || ncz_die "usage: ncz health" 1
    local active running count network result
    active="$(ncz_active_agent)"
    running="$(ncz_running_agents | paste -sd, - 2>/dev/null || true)"
    count=0
    [ -n "$running" ] && count="$(printf '%s\n' "$running" | awk -F, '{print NF}')"
    network="down"
    if ncz_have ip && ip route get 1.1.1.1 >/dev/null 2>&1; then
        network="ok"
    fi
    result="green"
    if [ "$count" -gt 1 ] || { [ "$count" -eq 1 ] && [ "$running" != "$active" ]; }; then
        result="red"
    elif [ "$count" -eq 0 ] || [ "$network" != "ok" ]; then
        result="yellow"
    fi
    printf '%s active=%s running=%s network=%s\n' "$result" "$active" "${running:-none}" "$network"
    [ "$result" = "red" ] && return 3
    return 0
}
