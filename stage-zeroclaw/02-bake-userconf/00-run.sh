#!/bin/bash -e
#
# Pre-provision FIRST_USER_NAME via /boot/firmware/userconf.txt so Pi OS
# Trixie's userconfig service does not strip the user account at first
# boot.
#
# Why this is needed:
#   Starting with Pi OS Bookworm (and continuing into Trixie), the
#   `userconf-pi` package wires sshd and a firstboot service to refuse
#   logins until /boot/firmware/userconf.txt provisions a user. pi-gen
#   creates the FIRST_USER_NAME account during stage1, but userconfig
#   then runs at first boot and either disables that user or refuses
#   SSH for it. The visible symptom is sshd printing
#       "Please note that SSH may not work until a valid user has been
#        set up." (...) Permission denied (publickey,password).
#   even though the username + password from the build config look
#   correct.
#
# The fix:
#   Bake userconf.txt with the same FIRST_USER_NAME / FIRST_USER_PASS
#   that pi-gen used to create the account. userconfig then accepts
#   the account as "provisioned" and SSH works on first boot without
#   a console step.
#
# History:
#   - 2026-04-26: clawpi + zeropi were re-flashed from this image and
#     hit the userconfig hard-block. Required physical SD-pull +
#     manual userconf.txt drop to recover. Adding this stage so future
#     builds are reflash-and-go.
#
# This runs as part of stage-zeroclaw (which is in BOTH the zeropi and
# clawpi profiles), so both profiles get the fix.

USERCONF_DIR="${ROOTFS_DIR}/boot/firmware"
mkdir -p "${USERCONF_DIR}"

# openssl passwd -6 produces a SHA-512 crypt hash.  userconfig accepts
# any libc crypt format; SHA-512 is the modern default.
ENC_PASS="$(openssl passwd -6 "${FIRST_USER_PASS}")"

# username:hash on a single line. No trailing comments — userconfig is
# strict about the format.
echo "${FIRST_USER_NAME}:${ENC_PASS}" > "${USERCONF_DIR}/userconf.txt"
chmod 0644 "${USERCONF_DIR}/userconf.txt"

echo "[02-bake-userconf] pre-provisioned ${FIRST_USER_NAME} via /boot/firmware/userconf.txt"
