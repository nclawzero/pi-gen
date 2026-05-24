#!/usr/bin/env bash
#
# sync-fleet-creds.sh — pull canonical agent-env from ARGONAS to a local
# nclawzero edge device.
#
# Source of truth on ARGONAS:
#   /mnt/datapool/secrets/nclawzero-fleet-creds/agent-env  (root:root, 0600)
#
# Destination on the device:
#   /etc/nclawzero/agent-env  (root:root, 0600)
#
# Loaded by every agent quadlet via:
#   EnvironmentFile=/etc/nclawzero/agent-env
#
# Idempotent: md5-compares before and after; only restarts agents if the
# file actually changed. Safe to run repeatedly (cron, post-reflash, manual).
#
# Usage:
#   sudo ./sync-fleet-creds.sh                # pull from ARGONAS via root@argonas
#   sudo SOURCE=user@host:/path ./sync-...    # override source
#   sudo DRY_RUN=1 ./sync-fleet-creds.sh      # diff only, no write
#   sudo NO_RESTART=1 ./sync-fleet-creds.sh   # write but skip agent restart
#
# Requires: ssh + sshpass (for the default ARGONAS path), or a working
# pubkey for whatever SOURCE you provide.

set -euo pipefail

ARGONAS_HOST="${ARGONAS_HOST:-192.168.207.101}"
ARGONAS_PASS="${ARGONAS_PASS:-Gumbo@Kona1b}"
ARGONAS_PATH="${ARGONAS_PATH:-/mnt/datapool/secrets/nclawzero-fleet-creds/agent-env}"
SOURCE="${SOURCE:-root@${ARGONAS_HOST}:${ARGONAS_PATH}}"

DEST="/etc/nclawzero/agent-env"
DEST_DIR="$(dirname "$DEST")"
TMP="$(mktemp /tmp/agent-env.sync.XXXXXX)"
trap 'rm -f "$TMP"' EXIT

DRY_RUN="${DRY_RUN:-0}"
NO_RESTART="${NO_RESTART:-0}"

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "ERROR: run as root (sudo)" >&2
        exit 2
    fi
}

fetch() {
    if [[ "$SOURCE" == "root@${ARGONAS_HOST}:"* ]]; then
        sshpass -p "$ARGONAS_PASS" scp -q \
            -o PubkeyAuthentication=no \
            -o StrictHostKeyChecking=no \
            -o IdentitiesOnly=yes \
            "$SOURCE" "$TMP"
    else
        scp -q -o StrictHostKeyChecking=no "$SOURCE" "$TMP"
    fi
}

md5_of() {
    if [ -f "$1" ]; then
        md5sum "$1" | awk '{print $1}'
    else
        echo "(absent)"
    fi
}

main() {
    require_root

    echo "[sync-fleet-creds] source=$SOURCE"
    echo "[sync-fleet-creds] dest=$DEST"

    fetch
    local got bytes
    got="$(md5_of "$TMP")"
    bytes="$(wc -c < "$TMP")"
    echo "[sync-fleet-creds] fetched ${bytes} bytes md5=${got}"

    if [ "$bytes" -lt 32 ]; then
        echo "ERROR: fetched payload suspiciously small (${bytes} bytes); refusing to deploy" >&2
        exit 3
    fi

    local current
    current="$(md5_of "$DEST")"
    echo "[sync-fleet-creds] current md5=${current}"

    if [ "$got" = "$current" ]; then
        echo "[sync-fleet-creds] no change; nothing to do"
        exit 0
    fi

    if [ "$DRY_RUN" = "1" ]; then
        echo "[sync-fleet-creds] DRY_RUN=1; not writing"
        exit 0
    fi

    install -d -m 0700 -o root -g root "$DEST_DIR"
    install -m 0600 -o root -g root "$TMP" "$DEST"
    echo "[sync-fleet-creds] wrote ${DEST}"

    if [ "$NO_RESTART" = "1" ]; then
        echo "[sync-fleet-creds] NO_RESTART=1; not restarting agents"
        exit 0
    fi

    # Restart whichever agent is currently the active one. Other agents
    # are stopped (HA-passive on the runtime side); they'll pick up the
    # new env on next ncz set-agent.
    local active
    active="$(cat /etc/nclawzero/agent 2>/dev/null || echo zeroclaw)"
    if systemctl is-active --quiet "${active}.service" 2>/dev/null; then
        echo "[sync-fleet-creds] restarting ${active}.service to pick up new env"
        systemctl restart "${active}.service"
    else
        echo "[sync-fleet-creds] ${active}.service not active; skipping restart"
    fi
}

main "$@"
