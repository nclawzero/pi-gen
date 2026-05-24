#!/usr/bin/env bash

ncz_os_pretty_name() {
    if [ -r /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        printf '%s\n' "${PRETTY_NAME:-unknown}"
    else
        printf 'unknown\n'
    fi
}

ncz_distro_version() {
    if [ -r "${NCZ_ETC_DIR}/version" ]; then
        sed -n '1p' "${NCZ_ETC_DIR}/version"
    elif dpkg-query -W -f='${Version}\n' nclawzero-rdp-init >/dev/null 2>&1; then
        dpkg-query -W -f='${Version}\n' nclawzero-rdp-init 2>/dev/null
    else
        printf 'unknown\n'
    fi
}

ncz_agent_version() {
    local agent="$1"
    local image version
    image="$(ncz_agent_image "$agent")"
    version="not-installed"
    if [ -n "$image" ] && ncz_have podman && podman image exists "$image" >/dev/null 2>&1; then
        version="$(podman image inspect --format '{{ index .Labels "org.opencontainers.image.version" }}' "$image" 2>/dev/null || true)"
        [ -n "$version" ] || version="$(podman image inspect --format '{{ index .Labels "org.opencontainers.image.revision" }}' "$image" 2>/dev/null || true)"
        [ -n "$version" ] || version="$image"
    elif [ -n "$image" ]; then
        version="image-missing:$image"
    fi
    printf '%s\n' "$version"
}

ncz_cmd_version() {
    ncz_parse_global_flags "$@"
    [ "${#NCZ_ARGS[@]}" -eq 0 ] || ncz_die "usage: ncz version [--json]" 1
    local distro os kernel agent first
    distro="$(ncz_distro_version)"
    os="$(ncz_os_pretty_name)"
    kernel="$(uname -r 2>/dev/null || true)"

    if [ "$NCZ_JSON" = "1" ]; then
        printf '{"nclawzero":"%s","os":"%s","kernel":"%s","agents":{' \
            "$(ncz_json_escape "$distro")" "$(ncz_json_escape "$os")" "$(ncz_json_escape "$kernel")"
        first=1
        for agent in $NCZ_AGENTS; do
            [ "$first" = 1 ] || printf ','
            first=0
            printf '"%s":"%s"' "$agent" "$(ncz_json_escape "$(ncz_agent_version "$agent")")"
        done
        printf '}}\n'
    else
        printf 'nclawzero: %s\n' "$distro"
        printf 'OS:        %s\n' "$os"
        printf 'Kernel:    %s\n' "$kernel"
        for agent in $NCZ_AGENTS; do
            printf '%-10s %s\n' "${agent}:" "$(ncz_agent_version "$agent")"
        done
    fi
}
