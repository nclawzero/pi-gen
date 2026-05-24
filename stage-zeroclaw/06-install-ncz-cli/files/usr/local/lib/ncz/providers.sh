#!/usr/bin/env bash

ncz_provider_files() {
    find "$NCZ_PROVIDERS_DIR" -maxdepth 1 -type f \( -name '*.env' -o -name '*.conf' -o -name '*.json' \) 2>/dev/null | sort
}

ncz_provider_name_from_file() {
    local file="$1" name
    name="$(awk -F= '/^[[:space:]]*(PROVIDER_NAME|NAME)[[:space:]]*=/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); gsub(/^"|"$/, "", $2); print $2; exit}' "$file" 2>/dev/null || true)"
    if [ -z "$name" ] && [ "${file##*.}" = "json" ] && ncz_have jq; then
        name="$(jq -r '.name // .provider // empty' "$file" 2>/dev/null || true)"
    fi
    [ -n "$name" ] || name="$(basename "$file" | sed -E 's/\.(env|conf|json)$//')"
    printf '%s\n' "$name"
}

ncz_provider_field() {
    local file="$1" field="$2" regex value
    case "$field" in
        url) regex='(PROVIDER_URL|BASE_URL|ENDPOINT|URL)' ;;
        health_url) regex='(PROVIDER_HEALTH_URL|HEALTH_URL)' ;;
        model) regex='(MODEL|DEFAULT_MODEL|PROVIDER_MODEL)' ;;
        key) regex='(API_KEY|TOKEN|SECRET|PASSWORD)' ;;
        *) return 1 ;;
    esac
    value="$(awk -F= -v re="$regex" '
        $0 ~ "^[[:space:]]*" re "[[:space:]]*=" {
            v=$2
            for (i=3; i<=NF; i++) v=v "=" $i
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
            gsub(/^"|"$/, "", v)
            print v
            exit
        }
    ' "$file" 2>/dev/null || true)"
    if [ -z "$value" ] && [ "${file##*.}" = "json" ] && ncz_have jq; then
        case "$field" in
            url) value="$(jq -r '.url // .base_url // .endpoint // empty' "$file" 2>/dev/null || true)" ;;
            health_url) value="$(jq -r '.health_url // empty' "$file" 2>/dev/null || true)" ;;
            model) value="$(jq -r '.model // .default_model // empty' "$file" 2>/dev/null || true)" ;;
            key) value="$(jq -r '.api_key // .token // empty' "$file" 2>/dev/null || true)" ;;
        esac
    fi
    printf '%s\n' "$value"
}

ncz_provider_find_file() {
    local wanted="$1" file name
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        name="$(ncz_provider_name_from_file "$file")"
        if [ "$name" = "$wanted" ] || [ "$(basename "$file")" = "$wanted" ]; then
            printf '%s\n' "$file"
            return 0
        fi
    done < <(ncz_provider_files)
    return 1
}

ncz_provider_health() {
    local file="$1" url health_url
    health_url="$(ncz_provider_field "$file" health_url)"
    url="$(ncz_provider_field "$file" url)"
    [ -n "$health_url" ] || health_url="${url%/}/health"
    if [ -z "$url" ] && [ "$health_url" = "/health" ]; then
        printf 'unknown\n'
        return 0
    fi
    if curl -fsS --max-time 3 "$health_url" >/dev/null 2>&1; then
        printf 'ok\n'
    else
        printf 'unhealthy\n'
    fi
}

ncz_providers_list() {
    ncz_parse_global_flags "$@"
    [ "${#NCZ_ARGS[@]}" -eq 0 ] || ncz_die "usage: ncz providers list [--json] [--show-secrets]" 1
    local primary file name url model key health first
    primary="$(sed -n '1p' "$NCZ_PRIMARY_PROVIDER_FILE" 2>/dev/null || true)"

    if [ "$NCZ_JSON" = "1" ]; then
        printf '{"primary":"%s","providers":[' "$(ncz_json_escape "$primary")"
        first=1
        while IFS= read -r file; do
            [ -n "$file" ] || continue
            name="$(ncz_provider_name_from_file "$file")"
            url="$(ncz_provider_field "$file" url)"
            model="$(ncz_provider_field "$file" model)"
            key="$(ncz_provider_field "$file" key)"
            health="$(ncz_provider_health "$file")"
            [ "$first" = 1 ] || printf ','
            first=0
            printf '{"name":"%s","url":"%s","model":"%s","key":"%s","health":"%s"}' \
                "$(ncz_json_escape "$name")" "$(ncz_json_escape "$url")" "$(ncz_json_escape "$model")" \
                "$(ncz_json_escape "$(ncz_mask_value "$key")")" "$(ncz_json_escape "$health")"
        done < <(ncz_provider_files)
        printf ']}\n'
    else
        printf 'Primary: %s\n' "${primary:-none}"
        if [ ! -d "$NCZ_PROVIDERS_DIR" ]; then
            printf 'No provider directory found: %s\n' "$NCZ_PROVIDERS_DIR"
            return 0
        fi
        while IFS= read -r file; do
            [ -n "$file" ] || continue
            name="$(ncz_provider_name_from_file "$file")"
            url="$(ncz_provider_field "$file" url)"
            model="$(ncz_provider_field "$file" model)"
            key="$(ncz_provider_field "$file" key)"
            health="$(ncz_provider_health "$file")"
            printf '%-18s health=%-10s url=%s model=%s key=%s\n' "$name" "$health" "${url:-unknown}" "${model:-unknown}" "$(ncz_mask_value "$key")"
        done < <(ncz_provider_files)
    fi
}

ncz_providers_test() {
    [ "$#" -eq 1 ] || ncz_die "usage: ncz providers test <name>" 1
    local name="$1" file status
    file="$(ncz_provider_find_file "$name")" || ncz_die "unknown provider: $name" 1
    status="$(ncz_provider_health "$file")"
    if [ "$status" = "ok" ]; then
        printf 'Provider %s: ok\n' "$name"
    else
        ncz_die "provider ${name} smoke test failed (${status})" 2
    fi
}

ncz_providers_set_primary() {
    [ "$#" -eq 1 ] || ncz_die "usage: ncz providers set-primary <name>" 1
    local name="$1" active agent_file
    ncz_provider_find_file "$name" >/dev/null || ncz_die "unknown provider: $name" 1
    ncz_atomic_write "$NCZ_PRIMARY_PROVIDER_FILE" 0644 root root "$name"
    active="$(ncz_active_agent)"
    agent_file="${NCZ_AGENT_CONFIG_DIR}/${active}/primary-provider"
    ncz_atomic_write "$agent_file" 0644 root root "$name"
    printf 'Primary provider: %s\n' "$name"
}

ncz_cmd_providers() {
    local verb="${1:-list}"
    [ "$#" -gt 0 ] && shift || true
    case "$verb" in
        list) ncz_providers_list "$@" ;;
        test) ncz_providers_test "$@" ;;
        set-primary) ncz_providers_set_primary "$@" ;;
        *) ncz_die "usage: ncz providers list|test|set-primary ..." 1 ;;
    esac
}
