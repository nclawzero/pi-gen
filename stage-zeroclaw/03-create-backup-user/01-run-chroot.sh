#!/bin/bash -e
#
# Create + reconcile the jasonperlow backup user — defense-in-depth
# recovery account.  Always converges target state every build, even
# if the user already exists from a stale rootfs / incremental rebuild.
#
# Why a second user:
#   2026-04-26 incident — Pi OS Trixie's userconfig service stripped
#   the FIRST_USER account (the only configured login) from clawpi
#   and zeropi at first boot.  SSH was unreachable; recovery required
#   physical SD-pull and userconf.txt drop.  Adding a second locked-
#   password account that shares the same authorized_keys gives a
#   real fleet recovery path that survives any disruption to the
#   primary FIRST_USER account.
#
# Why "jasonperlow" specifically:
#   Matches the user's identity on every other fleet host (STUDIO,
#   ULTRA, ARGOS, PYTHIA, CERBERUS) — muscle-memory works regardless
#   of whether you're SSH'ing the operator (ncz) or the backup
#   (jasonperlow).  The Yocto-built Jetson images use the same
#   convention (see meta-nclawzero / nclawzero-image-common.inc
#   EXTRA_USERS_PARAMS).
#
# State-convergent (not just create-once):
#   pi-gen wraps stages can run against a stale rootfs/work tree
#   from a previous build.  An existing jasonperlow with the wrong
#   shell, an unlocked password, missing home, or stale group
#   membership would otherwise pass through unchecked and ship a
#   recovery account with the wrong posture.  Every property below
#   is reconciled to the intended state on every run.

USR=jasonperlow
SHELL_PATH=/bin/bash
GROUPS_TARGET="adm,dialout,cdrom,audio,users,sudo,video,games,plugdev,input,gpio,spi,i2c,netdev,render,docker"

if getent passwd "${USR}" > /dev/null; then
    echo "[03-create-backup-user] ${USR} exists — reconciling state"
else
    useradd -m -s "${SHELL_PATH}" -G "${GROUPS_TARGET}" -p '!' "${USR}"
    echo "[03-create-backup-user] created ${USR} with locked password (key-only)"
fi

# ── always converge target state, even if account already existed ──
# Lock password (idempotent — re-locking a locked password is a no-op).
passwd -l "${USR}" > /dev/null

# Login shell.
usermod -s "${SHELL_PATH}" "${USR}"

# Reset supplementary groups to exactly the target set.  -G replaces;
# without -a, removed groups disappear from the user's set.  Don't add
# -a here — drift cleanup is the whole point.
usermod -G "${GROUPS_TARGET}" "${USR}"

# Home dir must exist (some pi-gen rebuilds skip useradd's -m if user
# row already exists).  Create + chown if missing.
if [ ! -d "/home/${USR}" ]; then
    install -d -m 0755 -o "${USR}" -g "${USR}" "/home/${USR}"
fi

# NOPASSWD sudo drop-in.  Whole-file overwrite = idempotent.
cat > /etc/sudoers.d/95-jasonperlow-nopasswd <<'EOF'
# Defense-in-depth backup account — full sudo without password so a key-
# only login (no password to type) can still escalate for repair / recovery.
# Companion to the locked password set by `passwd -l` above; without this
# drop-in the recovery path is unusable (SSH lands but sudo prompts for a
# password that does not exist).
jasonperlow ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/95-jasonperlow-nopasswd

echo "[03-create-backup-user] converged: shell=${SHELL_PATH} groups=${GROUPS_TARGET} pwd=locked"
