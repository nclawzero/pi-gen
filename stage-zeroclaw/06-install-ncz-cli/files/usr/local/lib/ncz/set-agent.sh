#!/usr/bin/env bash

ncz_cmd_set_agent() {
    [ "$#" -eq 1 ] || ncz_die "usage: ncz set-agent <zeroclaw|openclaw|hermes>" 1
    ncz_require_systemd
    ncz_require_podman

    local target="$1"
    local current image port url agent running
    ncz_validate_agent "$target"

    current="$(ncz_active_agent)"
    running="$(ncz_running_agents | paste -sd, - 2>/dev/null || true)"
    if [ "$current" = "$target" ]; then
        if [ "$running" = "$target" ]; then
            printf 'Already %s.\n' "$target"
            return 0
        fi
        printf 'Reconciling active agent %s; running=%s.\n' "$target" "${running:-none}"
    fi

    if ! ncz_quadlet_exists "$target"; then
        ncz_die "missing quadlet for ${target}: $(ncz_agent_quadlet "$target")" 2
    fi

    image="$(ncz_agent_image "$target")"
    if ! ncz_image_present "$image"; then
        ncz_die "container image for ${target} is missing (${image:-unknown}); run 'ncz update' first" 2
    fi

    port="$(ncz_agent_port "$target")"
    url="http://127.0.0.1:${port}/health"

    ncz_sudo systemctl daemon-reload

    for agent in $NCZ_AGENTS; do
        if [ "$agent" != "$target" ]; then
            ncz_sudo systemctl stop "$(ncz_agent_service "$agent")" >/dev/null 2>&1 || true
            ncz_sudo systemctl disable "$(ncz_agent_service "$agent")" >/dev/null 2>&1 || true
        fi
    done

    if ! systemctl is-enabled --quiet "$(ncz_agent_service "$target")" 2>/dev/null; then
        ncz_sudo systemctl enable "$(ncz_agent_service "$target")" >/dev/null 2>&1 || true
    fi
    ncz_sudo systemctl start "$(ncz_agent_service "$target")"

    if ! ncz_probe_health "$url" 30; then
        ncz_sudo systemctl stop "$(ncz_agent_service "$target")" >/dev/null 2>&1 || true
        ncz_sudo systemctl disable "$(ncz_agent_service "$target")" >/dev/null 2>&1 || true
        if ncz_is_agent "$current" && [ "$current" != "$target" ] && ncz_quadlet_exists "$current"; then
            ncz_sudo systemctl start "$(ncz_agent_service "$current")" >/dev/null 2>&1 || true
        fi
        ncz_die "health probe failed for ${target}; rolled back to ${current}" 2
    fi

    ncz_atomic_write "$NCZ_STATE_FILE" 0644 root root "$target"
    printf 'Active agent: %s\n' "$target"
}
