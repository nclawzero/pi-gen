#!/bin/bash -e
#
# Create the jasonperlow backup user — defense-in-depth recovery account.
#
# Why a second user:
#   2026-04-26 incident — Pi OS Trixie's userconfig service stripped
#   the FIRST_USER account (the only configured login) from clawpi
#   and zeropi at first boot. SSH was unreachable; recovery required
#   physical SD-pull and userconf.txt drop. Adding a second locked-
#   password account that shares the same authorized_keys gives a
#   real fleet recovery path that survives any disruption to the
#   primary FIRST_USER account.
#
# Why "jasonperlow" specifically:
#   Matches the user's identity on every other fleet host (STUDIO,
#   ULTRA, ARGOS, PYTHIA, CERBERUS) — muscle-memory works regardless
#   of whether you're SSH'ing the operator (ncz) or the backup
#   (jasonperlow). The Yocto-built Jetson images use the same convention
#   (see meta-nclawzero / nclawzero-image-common.inc EXTRA_USERS_PARAMS).
#
# Locked password (-p '!') => key-only access; the bake stage at
# 04-bake-authorized-keys drops the same fleet authorized_keys into
# /home/jasonperlow/.ssh/ as it does for the operator, giving SSH access.
#
# Idempotent: getent guard means re-running the stage script (or
# rebuilding incrementally) is a no-op if the user already exists.

if getent passwd jasonperlow > /dev/null; then
    echo "[03-create-backup-user] jasonperlow already exists — no-op"
else
    # Same group set as the FIRST_USER (set in stage2/01-sys-tweaks/01-run.sh):
    #   adm dialout cdrom audio users sudo video games plugdev input gpio spi i2c netdev render
    # Plus docker (added in stage-zeroclaw/01-install-nclawzero) for parity.
    useradd -m -s /bin/bash \
        -G adm,dialout,cdrom,audio,users,sudo,video,games,plugdev,input,gpio,spi,i2c,netdev,render,docker \
        -p '!' \
        jasonperlow
    echo "[03-create-backup-user] created jasonperlow with locked password (key-only)"
fi

# NOPASSWD sudo for the backup user — same posture as the operator
# user (see stage-nclawzero/01-install-nemoclaw/01-run-chroot.sh).
# Idempotent: tee with redirect overwrites; chmod is fixed-mode.
cat > /etc/sudoers.d/95-jasonperlow-nopasswd <<'EOF'
# Defense-in-depth backup account — full sudo without password so a key-
# only login (no password to type) can still escalate for repair / recovery.
jasonperlow ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/95-jasonperlow-nopasswd
