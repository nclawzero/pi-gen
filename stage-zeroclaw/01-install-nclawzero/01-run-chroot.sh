#!/bin/bash -e
# Add nclawzero internal apt repo
install -d /etc/apt/keyrings
curl -fsSL http://10.0.0.22:8081/apt/keys/nclawzero-internal-signing.asc \
    -o /etc/apt/keyrings/nclawzero-internal.asc

cat > /etc/apt/sources.list.d/nclawzero.sources <<'EOF'
Types: deb
URIs: http://10.0.0.22:8081/apt
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

# Pure-zeroclaw base + tailscale (also used by clawpi — nemoclaw
# is layered in stage-nclawzero).
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    nclawzero-rdp-init \
    zeroclaw \
    tailscale

# Operator user in docker group. FIRST_USER_NAME is exported into the
# chroot by pi-gen — quote-default to "pi" for safety on legacy builds
# where the var might be unset, but new images always set it via config.
# Failure here means the user genuinely doesn't exist — let it surface.
usermod -aG docker "${FIRST_USER_NAME:-pi}"

# Auto-upgrade periodic settings.  Origins-Pattern (which package origins
# to track for HEAD updates) lives in stage-zeroclaw/05-track-head-packages
# so there's a single source of truth — Tailscale + Raspberry Pi Foundation
# + nclawzero-internal whitelist is wider than the nclawzero-only set we
# would write here, and apt.conf.d files merge cumulatively.
cat > /etc/apt/apt.conf.d/50-nclawzero-autoupgrade <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
apt-get install -y --no-install-recommends unattended-upgrades
