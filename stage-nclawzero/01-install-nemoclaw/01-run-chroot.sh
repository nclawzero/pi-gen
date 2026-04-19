#!/bin/bash -e
# stage-zeroclaw already added the apt repo
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    nemoclaw-firstboot

# --- Enable xrdp for remote desktop -----------------------------------
# xrdp generates its own self-signed cert on package install via its
# postinst; nclawzero-rdp-init's /etc/weston/tls.cert path is vestigial
# (stays as a no-op on Pi OS images since weston isn't installed).
systemctl enable xrdp.service || true
# Add pi to ssl-cert so it can read xrdp key material if needed
usermod -aG ssl-cert pi || true

# --- LXDE default session for pi via xrdp -----------------------------
# xrdp spawns X sessions via sesman, which picks up ~/.xsession. Point
# pi at lxsession so the RDP connection lands in LXDE.
cat > /home/pi/.xsession <<'EOF'
#!/bin/sh
exec /usr/bin/lxsession -s LXDE -e LXDE
EOF
chmod 0755 /home/pi/.xsession
chown pi:pi /home/pi/.xsession
