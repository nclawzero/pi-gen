#!/bin/bash -e
# Add nclawzero internal apt repo
install -d /etc/apt/keyrings
curl -fsSL http://192.168.207.22:8081/apt/keys/nclawzero-internal-signing.asc \
    -o /etc/apt/keyrings/nclawzero-internal.asc

cat > /etc/apt/sources.list.d/nclawzero.sources <<'EOF'
Types: deb
URIs: http://192.168.207.22:8081/apt
Suites: trixie
Components: main
Signed-By: /etc/apt/keyrings/nclawzero-internal.asc
EOF

# Tailscale apt repo — not in Debian trixie default.
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg \
    -o /etc/apt/keyrings/tailscale-archive-keyring.gpg
cat > /etc/apt/sources.list.d/tailscale.sources <<'EOF'
Types: deb
URIs: https://pkgs.tailscale.com/stable/debian
Suites: trixie
Components: main
Signed-By: /etc/apt/keyrings/tailscale-archive-keyring.gpg
EOF

apt-get update

# Shared base + tailscale. NemoClaw and agent container quadlets are installed
# by the following substages, with optional agent stages skipped per profile.
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    nclawzero-rdp-init \
    tailscale

# Auto-upgrade scoped to our apt origin
cat > /etc/apt/apt.conf.d/50-nclawzero-autoupgrade <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
Unattended-Upgrade::Origins-Pattern {
    "origin=nclawzero-internal";
};
Unattended-Upgrade::Automatic-Reboot "false";
EOF
apt-get install -y --no-install-recommends unattended-upgrades || true
