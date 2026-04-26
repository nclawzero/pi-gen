#!/bin/bash -e
#
# Bake fleet authorized_keys into /home/${FIRST_USER_NAME}/.ssh/ AND
# /home/jasonperlow/.ssh/ at image build time so a freshly-flashed Pi
# is SSH-reachable on first boot from any fleet workstation listed in
# the keys file.
#
# Source file:
#   files/authorized_keys  (gitignored — fleet-internal, see SECURITY note
#                           in repo root + .gitignore)
#   files/authorized_keys.example (committed — placeholder + format docs)
#
# Operator workflow before each rebuild:
#   1. cp files/authorized_keys.example files/authorized_keys
#   2. $EDITOR files/authorized_keys  (drop in real fleet pubkeys)
#   3. ./build.sh <profile>
#
# If files/authorized_keys is missing OR contains the placeholder OR
# parses as invalid via ssh-keygen, this stage prints a clear error
# and exits non-zero so the build fails fast — no silent ship of an
# image with no operator access.
#
# Idempotency:
#   `install -m` overwrites /home/<user>/.ssh/authorized_keys wholesale
#   each build — no accumulation across re-bakes.  Rotation = edit the
#   keys file + rebuild image + reflash.

KEYS_FILE="${BASH_SOURCE%/*}/files/authorized_keys"

# ── 1. presence + non-empty ────────────────────────────────────────
if [ ! -s "${KEYS_FILE}" ]; then
    cat <<EOF
[04-bake-authorized-keys] FATAL: ${KEYS_FILE} is missing or empty.

This file is gitignored on purpose — fleet pubkey lists reveal
topology (which workstation pairs with which device) and stay
out of public repos.

Populate from the committed .example sibling before rebuilding:
  cp ${KEYS_FILE}.example ${KEYS_FILE}
  \$EDITOR ${KEYS_FILE}
EOF
    exit 1
fi

# ── 2. reject placeholder content ──────────────────────────────────
if grep -q 'AAAAREPLACEME\|REPLACEME' "${KEYS_FILE}"; then
    cat <<EOF
[04-bake-authorized-keys] FATAL: ${KEYS_FILE} still contains the
.example placeholder (AAAAREPLACEME / REPLACEME). An image baked
with this content would be SSH-unreachable on first boot.

Replace the placeholder lines with real fleet pubkeys, then re-run.
EOF
    exit 1
fi

# ── 3. require at least one non-comment line ───────────────────────
REAL_LINE_COUNT=$(grep -cE '^[^#[:space:]]' "${KEYS_FILE}" || true)
if [ "${REAL_LINE_COUNT}" -lt 1 ]; then
    echo "[04-bake-authorized-keys] FATAL: ${KEYS_FILE} contains no key lines (only comments / blanks)."
    exit 1
fi

# ── 4. per-line validation: strict first-field + ssh-keygen ────────
# Two-stage check per non-comment line:
#   (1) STRICT first-field grammar — must be a sshd-supported key type
#       like ssh-ed25519 / ssh-rsa / ecdsa-sha2-nistp256.  ssh-keygen
#       fingerprints lines like `- ssh-ed25519 AAAA...` or
#       `bad-option ssh-ed25519 AAAA...` (it scans for any valid
#       token), but sshd then rejects them as malformed options syntax.
#       Reject at build time so we don't ship lines sshd will silently
#       ignore.
#   (2) ssh-keygen on the line — catches base64 corruption etc.
#       `ssh-keygen -l -f <wholefile>` is NOT enough: it returns 0 if
#       it can parse AT LEAST ONE valid key, even when other lines
#       are garbled. Per-line is the only way.
#
# The `|| [ -n "$LINE" ]` keeps the loop running for the final line
# when the file lacks a trailing newline (read returns nonzero but
# LINE is populated). Without that, unterminated invalid final lines
# slip past validation.
#
# Diagnostics report only line NUMBERS.  Line contents are
# fleet-internal (pubkey + comment fields reveal access topology) and
# CI build logs aren't fleet-internal — keep keys out of them.
SSHD_KEY_TYPES=" ssh-rsa ssh-dss ssh-ed25519 ssh-ed25519-cert-v01@openssh.com ssh-rsa-cert-v01@openssh.com ssh-dss-cert-v01@openssh.com ecdsa-sha2-nistp256 ecdsa-sha2-nistp384 ecdsa-sha2-nistp521 ecdsa-sha2-nistp256-cert-v01@openssh.com ecdsa-sha2-nistp384-cert-v01@openssh.com ecdsa-sha2-nistp521-cert-v01@openssh.com sk-ecdsa-sha2-nistp256@openssh.com sk-ssh-ed25519@openssh.com "

# ssh-keygen presence — pi-gen's Debian trixie build container does
# NOT install openssh-client by default, so this stage script (which
# runs in the host context, not the chroot) has no `ssh-keygen` to
# call. Detect once + fall back to first-field-only validation when
# absent, instead of treating every "command not found" exit code as
# a malformed-key signal.
if command -v ssh-keygen > /dev/null 2>&1; then
    HAS_SSH_KEYGEN=1
else
    HAS_SSH_KEYGEN=0
    echo "[04-bake-authorized-keys] note: ssh-keygen not in PATH inside the pi-gen build container — falling back to first-field-grammar validation only"
fi

LINE_NO=0
BAD_LINES=""
while IFS= read -r LINE || [ -n "$LINE" ]; do
    LINE_NO=$((LINE_NO + 1))
    case "$LINE" in
        ''|'#'*) continue ;;
    esac
    # First whitespace-separated token.
    FIRST="${LINE%%[[:space:]]*}"
    case "$SSHD_KEY_TYPES" in
        *" $FIRST "*) ;;  # known type, fall through to ssh-keygen
        *) BAD_LINES="${BAD_LINES} ${LINE_NO}"; continue ;;
    esac
    # Optional second-stage check via ssh-keygen — only when available.
    if [ "$HAS_SSH_KEYGEN" = 1 ]; then
        if ! printf '%s\n' "$LINE" | ssh-keygen -l -f /dev/stdin > /dev/null 2>&1; then
            BAD_LINES="${BAD_LINES} ${LINE_NO}"
        fi
    fi
done < "${KEYS_FILE}"
if [ -n "$BAD_LINES" ]; then
    echo "[04-bake-authorized-keys] FATAL: ${KEYS_FILE} has malformed line(s) at:${BAD_LINES}"
    echo "Each line must start with an sshd-supported key type (ssh-ed25519,"
    echo "ssh-rsa, ecdsa-sha2-nistp256, etc.) followed by base64 + optional"
    echo "comment. No bullet prefixes, no leading options-style fields."
    echo "Line content NOT echoed (fleet-internal). Read ${KEYS_FILE} locally."
    exit 1
fi

# ── 5. bake into both users' home dirs ─────────────────────────────
bake_for_user() {
    local user="$1"
    local kind="$2"   # primary | backup
    local home="${ROOTFS_DIR}/home/${user}"

    if [ ! -d "${home}" ]; then
        # Primary user (FIRST_USER_NAME) MUST have a home — pi-gen
        # stage1 creates it.  Missing primary home means stage1
        # ordering broke (e.g. FIRST_USER_NAME rename to "ncz" without
        # flushing the prior pi-gen/work cache that still has /home/pi).
        # Fail loudly rather than silently shipping a primary user
        # with no SSH access.
        if [ "$kind" = "primary" ]; then
            echo "[04-bake-authorized-keys] FATAL: primary user home ${home} does not exist."
            echo "Likely cause: stage1 didn't create the user (config/cache mismatch)."
            echo "Fix: clean pi-gen/work and re-run ./build.sh <profile>."
            exit 1
        fi
        # Backup user home is also expected — 03-create-backup-user
        # creates it.  Treat missing as a lesser warning since the
        # primary user is still SSH-reachable, but warn loudly.
        echo "[04-bake-authorized-keys] WARN: backup home ${home} missing — skipping ${user}"
        return 0
    fi

    install -d -m 0700 "${home}/.ssh"
    install -m 0600 "${KEYS_FILE}" "${home}/.ssh/authorized_keys"
}

bake_for_user "${FIRST_USER_NAME}" primary
bake_for_user "jasonperlow"        backup

# ── 6. chown inside chroot so target uid/gid resolve correctly ─────
# on_chroot is the pi-gen helper that runs the heredoc inside chroot
# ${ROOTFS_DIR}.  Quoted heredoc <<'CHROOT' so ${FIRST_USER_NAME} is
# evaluated INSIDE the chroot's environment (pi-gen exports it).
on_chroot << 'CHROOT'
set -e
for u in "${FIRST_USER_NAME:-pi}" jasonperlow; do
    if id "$u" > /dev/null 2>&1; then
        chown -R "$u:$u" "/home/$u/.ssh"
    fi
done
CHROOT

echo "[04-bake-authorized-keys] baked authorized_keys for ${FIRST_USER_NAME} + jasonperlow (${REAL_LINE_COUNT} keys)"
