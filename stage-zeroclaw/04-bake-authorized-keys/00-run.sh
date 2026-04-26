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
# If files/authorized_keys is missing, this stage prints a clear error
# and exits non-zero so the build fails fast — no silent ship of an
# image with no operator access.
#
# Idempotency:
#   `install -m` overwrites /home/<user>/.ssh/authorized_keys wholesale
#   each build — no accumulation across re-bakes. Rotation = edit the
#   keys file + rebuild.

KEYS_FILE="${BASH_SOURCE%/*}/files/authorized_keys"

if [ ! -s "${KEYS_FILE}" ]; then
    echo "[04-bake-authorized-keys] FATAL: ${KEYS_FILE} is missing or empty."
    echo
    echo "  This file is gitignored on purpose — fleet pubkey lists reveal"
    echo "  topology (which workstation pairs with which device) and stay"
    echo "  out of public repos."
    echo
    echo "  Populate from the committed .example sibling before rebuilding:"
    echo "    cp ${KEYS_FILE}.example ${KEYS_FILE}"
    echo "    \$EDITOR ${KEYS_FILE}"
    echo
    exit 1
fi

bake_for_user() {
    local user="$1"
    local home="${ROOTFS_DIR}/home/${user}"

    if [ ! -d "${home}" ]; then
        # User home dir not present in rootfs — useradd in 03-create-
        # backup-user (or pi-gen's stage1 user creation for FIRST_USER)
        # should have made it. Skip with a warning rather than aborting,
        # so a partial build still produces an image that other users
        # can SSH to.
        echo "[04-bake-authorized-keys] skip ${user}: ${home} does not exist"
        return 0
    fi

    install -d -m 0700 "${home}/.ssh"
    install -m 0600 "${KEYS_FILE}" "${home}/.ssh/authorized_keys"

    # uid/gid for these users live in the rootfs's /etc/passwd. The
    # chown happens inside the chroot during a small follow-up stage,
    # but install -m here is enough for the file mode; chown on the
    # build host would set wrong uid/gid values for the target.
}

bake_for_user "${FIRST_USER_NAME}"
bake_for_user "jasonperlow"

# Reconcile ownership inside the chroot so the files are owned by the
# correct uid/gid as defined in /etc/passwd on the target. on_chroot is
# the pi-gen helper that runs the heredoc inside chroot ${ROOTFS_DIR}.
on_chroot << 'CHROOT'
for u in "${FIRST_USER_NAME:-pi}" jasonperlow; do
    if id "$u" > /dev/null 2>&1; then
        chown -R "$u:$u" "/home/$u/.ssh"
    fi
done
CHROOT

echo "[04-bake-authorized-keys] baked authorized_keys for ${FIRST_USER_NAME} + jasonperlow"
