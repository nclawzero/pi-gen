#!/usr/bin/env bash

ncz_update_allowed_origin() {
    local pkg="$1"
    apt-cache policy "$pkg" 2>/dev/null | grep -Eq \
        'origin (192\.168\.207\.22|pkgs\.tailscale\.com|archive\.raspberrypi\.com)|o=(nclawzero-internal|Tailscale|Raspberry Pi Foundation)'
}

ncz_update_candidates() {
    apt list --upgradable 2>/dev/null | awk -F/ 'NR > 1 {print $1}' | while read -r pkg; do
        [ -n "$pkg" ] || continue
        if ncz_update_allowed_origin "$pkg"; then
            printf '%s\n' "$pkg"
        fi
    done
}

ncz_update_check() {
    ncz_sudo apt-get update
    printf '\nOS package upgrades:\n'
    local pkg count
    count=0
    while IFS= read -r pkg; do
        [ -n "$pkg" ] || continue
        count=$((count + 1))
        printf '  %s\n' "$pkg"
    done < <(ncz_update_candidates)
    [ "$count" -gt 0 ] || printf '  none from nclawzero-internal, Raspberry Pi, or Tailscale origins\n'
    printf '\nContainer image updates:\n'
    if ncz_have podman; then
        podman auto-update --dry-run 2>/dev/null || true
    else
        printf '  podman unavailable\n'
    fi
}

ncz_update_apply() {
    ncz_sudo apt-get update
    local packages
    packages="$(ncz_update_candidates | paste -sd ' ' -)"
    if [ -n "$packages" ]; then
        # shellcheck disable=SC2086
        ncz_sudo env DEBIAN_FRONTEND=noninteractive apt-get -y \
            -o Dpkg::Options::=--force-confdef \
            -o Dpkg::Options::=--force-confold \
            install --only-upgrade $packages
    else
        printf 'No OS package upgrades from nclawzero-internal, Raspberry Pi, or Tailscale origins.\n'
    fi
    if ncz_have podman; then
        ncz_sudo podman auto-update || true
        local agent image
        for agent in $NCZ_AGENTS; do
            image="$(ncz_agent_image "$agent")"
            if [ -n "$image" ]; then
                ncz_sudo podman pull "$image" || ncz_warn "failed to pull $image"
            fi
        done
    fi
}

ncz_cmd_update() {
    case "${1:-}" in
        --check)
            [ "$#" -eq 1 ] || ncz_die "usage: ncz update [--check]" 1
            ncz_update_check
            ;;
        "")
            ncz_update_apply
            ;;
        *)
            ncz_die "usage: ncz update [--check]" 1
            ;;
    esac
}
