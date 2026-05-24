#!/usr/bin/env bash

ncz_sandbox_landlock() {
    if [ -d /sys/kernel/security/landlock ] || grep -qw landlock /proc/filesystems 2>/dev/null; then
        printf 'available\n'
    else
        printf 'unknown\n'
    fi
}

ncz_sandbox_seccomp() {
    awk '/^Seccomp:/ {print $2; exit}' /proc/1/status 2>/dev/null || printf 'unknown\n'
}

ncz_sandbox_caps() {
    local agent="$1" quadlet
    quadlet="$(ncz_agent_quadlet "$agent")"
    if [ -r "$quadlet" ]; then
        awk -F= '/^[[:space:]]*(DropCapability|AddCapability|SecurityLabelDisable|NoNewPrivileges)[[:space:]]*=/ {print}' "$quadlet" | paste -sd ';' - 2>/dev/null
    fi
}

ncz_sandbox_policy_file() {
    local agent="$1"
    for path in \
        "${NCZ_SANDBOX_DIR}/${agent}/policy-additions.yaml" \
        "${NCZ_ETC_DIR}/${agent}/policy-additions.yaml" \
        "${NCZ_ETC_DIR}/policy-additions-${agent}.yaml"; do
        if [ -r "$path" ]; then
            printf '%s\n' "$path"
            return 0
        fi
    done
    printf '%s\n' "${NCZ_SANDBOX_DIR}/${agent}/policy-additions.yaml"
}

ncz_sandbox_show() {
    ncz_parse_global_flags "$@"
    [ "${#NCZ_ARGS[@]}" -le 1 ] || ncz_die "usage: ncz sandbox [agent] [--json]" 1
    local agent="${NCZ_ARGS[0]:-$(ncz_active_agent)}"
    local landlock seccomp caps policy
    ncz_validate_agent "$agent"
    landlock="$(ncz_sandbox_landlock)"
    seccomp="$(ncz_sandbox_seccomp)"
    caps="$(ncz_sandbox_caps "$agent")"
    policy="$(ncz_sandbox_policy_file "$agent")"

    if [ "$NCZ_JSON" = "1" ]; then
        printf '{"agent":"%s","landlock":"%s","seccomp":"%s","capabilities":"%s","policy_file":"%s","policy_present":%s}\n' \
            "$agent" "$(ncz_json_escape "$landlock")" "$(ncz_json_escape "$seccomp")" \
            "$(ncz_json_escape "$caps")" "$(ncz_json_escape "$policy")" "$(ncz_json_bool "$([ -r "$policy" ] && printf 1 || printf 0)")"
    else
        printf 'Agent:       %s\n' "$agent"
        printf 'Landlock:    %s\n' "$landlock"
        printf 'Seccomp:     %s\n' "$seccomp"
        printf 'Quadlet:     %s\n' "$(ncz_agent_quadlet "$agent")"
        printf 'Capabilities:%s\n' " ${caps:-not declared}"
        printf 'Policy:      %s\n' "$policy"
        [ -r "$policy" ] || printf 'Policy file is not present.\n'
    fi
}

ncz_sandbox_policy() {
    [ "$#" -eq 1 ] || ncz_die "usage: ncz sandbox policy <agent>" 1
    local agent="$1" policy
    ncz_validate_agent "$agent"
    policy="$(ncz_sandbox_policy_file "$agent")"
    [ -r "$policy" ] || ncz_die "missing policy file: $policy" 2
    while IFS= read -r line || [ -n "$line" ]; do
        ncz_redact_line "$line"
    done < "$policy"
}

ncz_cmd_sandbox() {
    local verb="${1:-}"
    if [ "$verb" = "policy" ]; then
        shift
        ncz_sandbox_policy "$@"
    else
        ncz_sandbox_show "$@"
    fi
}
