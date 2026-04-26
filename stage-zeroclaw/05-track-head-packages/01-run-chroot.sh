#!/bin/bash -e
#
# Extend unattended-upgrades to track HEAD on every configured apt
# repo — not just Debian main + security.
#
# Trixie ships unattended-upgrades enabled with the canonical
# /etc/apt/apt.conf.d/50unattended-upgrades whitelisting only:
#   - origin=Debian,codename=trixie,label=Debian
#   - origin=Debian,codename=trixie,label=Debian-Security
#   - origin=Debian,codename=trixie-security,label=Debian-Security
#
# Edge devices need every package current — Tailscale (mesh VPN),
# Raspberry Pi Foundation (firmware/kernel), and the nclawzero-internal
# apt repo (zeroclaw deb) all roll forward continuously.  Drop-in
# supplements the canonical file; apt.conf.d files merge cumulatively
# so this adds origins without overriding.
#
# Compatibility with HEAD-binary post-boot rsync:
#   sync-fleet-zeroclaw-binary.sh installs HEAD zeroclaw via dpkg-divert
#   (/usr/bin/zeroclaw → /usr/bin/zeroclaw.deb).  Auto-upgrade of the
#   zeroclaw deb lands at /usr/bin/zeroclaw.deb, leaving the HEAD binary
#   intact.  No conflict.
#
# Idempotent: whole-file overwrite each build.

cat > /etc/apt/apt.conf.d/52unattended-upgrades-nclaw.conf <<'EOF'
// nclawzero — extend unattended-upgrades to track HEAD on every
// configured apt repo.  Supplements the canonical
// /etc/apt/apt.conf.d/50unattended-upgrades whitelist.
//
// Whitelist:
//   - Tailscale            (mesh VPN, security-sensitive)
//   - Raspberry Pi Foundation (firmware, kernel, raspi-config)
//   - nclawzero-internal   (zeroclaw deb; HEAD binary at /usr/bin/zeroclaw
//                           is dpkg-diverted, deb upgrades land at
//                           /usr/bin/zeroclaw.deb without conflict)
Unattended-Upgrade::Origins-Pattern {
        "origin=Tailscale,codename=${distro_codename}";
        "origin=Raspberry Pi Foundation,codename=${distro_codename}";
        "origin=nclawzero-internal,codename=${distro_codename}";
};
EOF
chmod 0644 /etc/apt/apt.conf.d/52unattended-upgrades-nclaw.conf

# Enable both periodic update + unattended-upgrade (default on Trixie
# but explicit-set survives any upstream defaults change).  Idempotent:
# whole-file overwrite.
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
chmod 0644 /etc/apt/apt.conf.d/20auto-upgrades

# Bring the rootfs current at build-time so the freshly-flashed image
# starts from a known-current package set, not whatever Trixie point
# release was canonical when stage0 ran.  Subsequent in-life updates
# are unattended-upgrades' job.
echo "[05-track-head-packages] apt-get update + full-upgrade at build time"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    full-upgrade

echo "[05-track-head-packages] HEAD-tracking origins-pattern installed:"
echo "  Tailscale, Raspberry Pi Foundation, nclawzero-internal"
echo "  + Debian main + security (canonical)"
