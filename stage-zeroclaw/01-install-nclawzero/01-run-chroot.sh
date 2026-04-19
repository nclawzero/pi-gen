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

apt-get update

# Pure-zeroclaw base (also used by clawpi — nemoclaw is layered in stage-nclawzero)
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    nclawzero-rdp-init \
    zeroclaw

# pi user in docker group
usermod -aG docker pi || true

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
