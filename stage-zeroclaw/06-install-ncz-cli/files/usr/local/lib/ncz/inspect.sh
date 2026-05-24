#!/usr/bin/env bash

ncz_cmd_inspect() {
    [ "$#" -eq 0 ] || ncz_die "usage: ncz inspect" 1
    local agent file
    printf '== ncz inspect ==\n'
    date -Is 2>/dev/null || date
    printf '\n== version ==\n'
    ncz_source version.sh
    ncz_cmd_version || true
    printf '\n== status ==\n'
    ncz_source status.sh
    ncz_cmd_status || true
    printf '\n== services ==\n'
    for agent in $NCZ_AGENTS; do
        systemctl --no-pager --full status "$(ncz_agent_service "$agent")" 2>/dev/null | sed -n '1,18p' || true
    done
    printf '\n== recent logs ==\n'
    for agent in $NCZ_AGENTS; do
        printf '\n-- %s --\n' "$agent"
        journalctl -u "$(ncz_agent_service "$agent")" -n 80 --no-pager 2>/dev/null | while IFS= read -r file; do
            ncz_redact_line "$file"
        done || true
    done
    printf '\n== sandbox ==\n'
    ncz_source sandbox.sh
    ncz_sandbox_show || true
    printf '\n== /etc/nclawzero ==\n'
    if [ -d "$NCZ_ETC_DIR" ]; then
        find "$NCZ_ETC_DIR" -maxdepth 3 -type f | sort | while IFS= read -r file; do
            printf '\n-- %s --\n' "$file"
            case "$file" in
                *key*|*token*|*secret*|*password*) printf '[redacted path]\n' ;;
                *) while IFS= read -r line || [ -n "$line" ]; do ncz_redact_line "$line"; done < "$file" ;;
            esac
        done
    else
        printf 'missing %s\n' "$NCZ_ETC_DIR"
    fi
}
