#!/usr/bin/env bash

NCZ_LIB_DIR="${NCZ_LIB_DIR:-/usr/local/lib/ncz}"
NCZ_ETC_DIR="${NCZ_ETC_DIR:-/etc/nclawzero}"
NCZ_STATE_FILE="${NCZ_STATE_FILE:-${NCZ_ETC_DIR}/agent}"
NCZ_CHANNEL_FILE="${NCZ_CHANNEL_FILE:-${NCZ_ETC_DIR}/channel}"
NCZ_PRIMARY_PROVIDER_FILE="${NCZ_PRIMARY_PROVIDER_FILE:-${NCZ_ETC_DIR}/primary-provider}"
NCZ_QUADLET_DIR="${NCZ_QUADLET_DIR:-/etc/containers/systemd}"
NCZ_PROVIDERS_DIR="${NCZ_PROVIDERS_DIR:-${NCZ_ETC_DIR}/providers.d}"
NCZ_AGENT_CONFIG_DIR="${NCZ_AGENT_CONFIG_DIR:-${NCZ_ETC_DIR}/agents}"
NCZ_SANDBOX_DIR="${NCZ_SANDBOX_DIR:-${NCZ_ETC_DIR}/sandbox}"
NCZ_MANIFEST_FILE="${NCZ_MANIFEST_FILE:-${NCZ_ETC_DIR}/manifest.sha256}"

NCZ_AGENTS="zeroclaw openclaw hermes"
NCZ_DEFAULT_AGENT="zeroclaw"

ncz_die() {
    local code="${2:-1}"
    printf 'ncz: %s\n' "$1" >&2
    exit "$code"
}

ncz_warn() {
    printf 'warning: %s\n' "$1" >&2
}

ncz_have() {
    command -v "$1" >/dev/null 2>&1
}

ncz_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

ncz_is_agent() {
    case " ${NCZ_AGENTS} " in
        *" $1 "*) return 0 ;;
        *) return 1 ;;
    esac
}

ncz_validate_agent() {
    ncz_is_agent "$1" || ncz_die "unknown agent: $1" 1
}

ncz_active_agent() {
    local active
    active="$(sed -n '1{s/[[:space:]]//g;p;q;}' "$NCZ_STATE_FILE" 2>/dev/null || true)"
    if [ -n "$active" ]; then
        printf '%s\n' "$active"
    else
        printf '%s\n' "$NCZ_DEFAULT_AGENT"
    fi
}

ncz_agent_port() {
    case "$1" in
        zeroclaw) printf '42617\n' ;;
        openclaw) printf '18789\n' ;;
        hermes) printf '8642\n' ;;
        *) return 1 ;;
    esac
}

ncz_agent_service() {
    printf '%s.service\n' "$1"
}

ncz_agent_quadlet() {
    printf '%s/%s.container\n' "$NCZ_QUADLET_DIR" "$1"
}

ncz_agent_image() {
    local quadlet
    quadlet="$(ncz_agent_quadlet "$1")"
    awk -F= '
        /^[[:space:]]*Image[[:space:]]*=/ {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
            print $2
            exit
        }
    ' "$quadlet" 2>/dev/null
}

ncz_service_running() {
    systemctl is-active --quiet "$(ncz_agent_service "$1")" 2>/dev/null
}

ncz_service_enabled() {
    systemctl is-enabled --quiet "$(ncz_agent_service "$1")" 2>/dev/null
}

ncz_running_agents() {
    local agent
    for agent in $NCZ_AGENTS; do
        if ncz_service_running "$agent"; then
            printf '%s\n' "$agent"
        fi
    done
}

ncz_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

ncz_json_bool() {
    if [ "$1" = "1" ] || [ "$1" = "true" ]; then
        printf 'true'
    else
        printf 'false'
    fi
}

# shellcheck disable=SC2034
ncz_parse_global_flags() {
    NCZ_JSON=0
    NCZ_SHOW_SECRETS=0
    NCZ_ARGS=()
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --json) NCZ_JSON=1 ;;
            --show-secrets) NCZ_SHOW_SECRETS=1 ;;
            --) shift; break ;;
            *) NCZ_ARGS+=("$1") ;;
        esac
        shift
    done
    while [ "$#" -gt 0 ]; do
        NCZ_ARGS+=("$1")
        shift
    done
}

ncz_atomic_write() {
    local path="$1"
    local mode="${2:-0644}"
    local owner="${3:-root}"
    local group="${4:-root}"
    local content="$5"
    local dir base tmp

    dir="$(dirname "$path")"
    base="$(basename "$path")"
    ncz_sudo mkdir -p "$dir"
    tmp="$(ncz_sudo mktemp "${dir}/${base}.tmp.XXXXXX")" || return 1
    if ! printf '%s\n' "$content" | ncz_sudo tee "$tmp" >/dev/null; then
        ncz_sudo rm -f "$tmp" || true
        return 1
    fi
    ncz_sudo chown "$owner:$group" "$tmp"
    ncz_sudo chmod "$mode" "$tmp"
    ncz_sudo mv -f "$tmp" "$path"
}

ncz_probe_health() {
    local url="$1"
    local timeout="${2:-30}"
    local deadline
    deadline=$((SECONDS + timeout))
    while [ "$SECONDS" -le "$deadline" ]; do
        if curl -fsS --max-time 2 "$url" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

ncz_health_url() {
    printf 'http://127.0.0.1:%s/health\n' "$(ncz_agent_port "$1")"
}

ncz_require_systemd() {
    ncz_have systemctl || ncz_die "systemctl is not available" 2
}

ncz_require_podman() {
    ncz_have podman || ncz_die "podman is not available" 2
}

ncz_quadlet_exists() {
    [ -s "$(ncz_agent_quadlet "$1")" ]
}

ncz_image_present() {
    local image="$1"
    [ -n "$image" ] || return 1
    ncz_sudo podman image exists "$image" >/dev/null 2>&1
}

ncz_mask_value() {
    local value="$1"
    if [ "$NCZ_SHOW_SECRETS" = "1" ]; then
        printf '%s' "$value"
    elif [ -n "$value" ]; then
        printf '***'
    fi
}

ncz_redact_line() {
    local line="$1"
    if [ "$NCZ_SHOW_SECRETS" = "1" ]; then
        printf '%s\n' "$line"
    else
        printf '%s\n' "$line" | sed -E 's/(token|secret|password|api[_-]?key|authorization)([[:space:]_=-]*).*/\1\2***/Ig'
    fi
}

ncz_source() {
    # shellcheck source=/dev/null
    . "${NCZ_LIB_DIR}/$1"
}
