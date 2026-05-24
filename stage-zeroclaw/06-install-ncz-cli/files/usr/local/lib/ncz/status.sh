#!/usr/bin/env bash

ncz_status_collect() {
    NCZ_STATUS_ACTIVE="$(ncz_active_agent)"
    NCZ_STATUS_RUNNING="$(ncz_running_agents | paste -sd, - 2>/dev/null || true)"
    NCZ_STATUS_RUNNING_COUNT=0
    if [ -n "$NCZ_STATUS_RUNNING" ]; then
        NCZ_STATUS_RUNNING_COUNT="$(printf '%s\n' "$NCZ_STATUS_RUNNING" | awk -F, '{print NF}')"
    fi
    NCZ_STATUS_INCONSISTENT=0
    if ! ncz_is_agent "$NCZ_STATUS_ACTIVE"; then
        NCZ_STATUS_INCONSISTENT=1
    elif [ "$NCZ_STATUS_RUNNING_COUNT" -gt 1 ]; then
        NCZ_STATUS_INCONSISTENT=1
    elif [ "$NCZ_STATUS_RUNNING_COUNT" -eq 1 ] && [ "$NCZ_STATUS_RUNNING" != "$NCZ_STATUS_ACTIVE" ]; then
        NCZ_STATUS_INCONSISTENT=1
    fi

    NCZ_STATUS_NETWORK="unknown"
    if ncz_have ip && ip route get 1.1.1.1 >/dev/null 2>&1; then
        NCZ_STATUS_NETWORK="ok"
    elif ncz_have ping && ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
        NCZ_STATUS_NETWORK="ok"
    else
        NCZ_STATUS_NETWORK="down"
    fi

    NCZ_STATUS_STORAGE="$(df -h / 2>/dev/null | awk 'NR==2 {print $5 " used (" $4 " free)"}')"
    NCZ_STATUS_KERNEL="$(uname -r 2>/dev/null || true)"
    NCZ_STATUS_HOST="$(hostname 2>/dev/null || true)"
}

ncz_cmd_status() {
    ncz_parse_global_flags "$@"
    [ "${#NCZ_ARGS[@]}" -eq 0 ] || ncz_die "usage: ncz status [--json]" 1
    ncz_status_collect

    if [ "$NCZ_JSON" = "1" ]; then
        cat <<EOF
{"host":"$(ncz_json_escape "$NCZ_STATUS_HOST")","kernel":"$(ncz_json_escape "$NCZ_STATUS_KERNEL")","active_agent":"$(ncz_json_escape "$NCZ_STATUS_ACTIVE")","running_agents":"$(ncz_json_escape "$NCZ_STATUS_RUNNING")","state_inconsistent":$(ncz_json_bool "$NCZ_STATUS_INCONSISTENT"),"network":"$(ncz_json_escape "$NCZ_STATUS_NETWORK")","storage":"$(ncz_json_escape "$NCZ_STATUS_STORAGE")"}
EOF
    else
        printf 'Device:       %s\n' "${NCZ_STATUS_HOST:-unknown}"
        printf 'Kernel:       %s\n' "${NCZ_STATUS_KERNEL:-unknown}"
        printf 'Active agent: %s\n' "$NCZ_STATUS_ACTIVE"
        printf 'Running:      %s\n' "${NCZ_STATUS_RUNNING:-none}"
        printf 'Network:      %s\n' "$NCZ_STATUS_NETWORK"
        printf 'Storage:      %s\n' "${NCZ_STATUS_STORAGE:-unknown}"
        if [ "$NCZ_STATUS_INCONSISTENT" = "1" ]; then
            printf 'State:        inconsistent\n'
        else
            printf 'State:        ok\n'
        fi
    fi

    if [ "$NCZ_STATUS_INCONSISTENT" = "1" ]; then
        return 3
    fi
}
