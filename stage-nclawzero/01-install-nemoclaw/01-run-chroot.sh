#!/bin/bash -e
# stage-zeroclaw already added the apt repo
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    nemoclaw-firstboot

# --- Enable xrdp for remote desktop -----------------------------------
# xrdp generates its own self-signed cert on package install via its
# postinst; nclawzero-rdp-init's /etc/weston/tls.cert path is vestigial
# (stays as a no-op on Pi OS images since weston isn't installed).
systemctl enable xrdp.service || true
usermod -aG ssl-cert pi || true

# --- XFCE4 session for pi via xrdp ------------------------------------
# XFCE4 has proper HiDPI/DPI scaling controls in xfce4-settings-manager,
# unlike LXDE which hardcodes 26px panels that render tiny on Retina
# RDP clients. Point pi's ~/.xsession at startxfce4.
cat > /home/pi/.xsession <<'EOF'
#!/bin/sh
exec /usr/bin/startxfce4
EOF
chmod 0755 /home/pi/.xsession
chown pi:pi /home/pi/.xsession

# --- Chromium managed policy: homepage = ZeroClaw web dashboard -------
install -d /etc/chromium/policies/managed
cat > /etc/chromium/policies/managed/nclawzero.json <<'EOF'
{
  "HomepageLocation": "http://localhost:42617/",
  "HomepageIsNewTabPage": false,
  "ShowHomeButton": true,
  "RestoreOnStartup": 4,
  "RestoreOnStartupURLs": ["http://localhost:42617/"]
}
EOF

# --- Firefox Enterprise policy: homepage + start page -----------------
install -d /etc/firefox-esr/policies
cat > /etc/firefox-esr/policies/policies.json <<'EOF'
{
  "policies": {
    "Homepage": {
      "URL": "http://localhost:42617/",
      "Locked": false,
      "StartPage": "homepage"
    }
  }
}
EOF

# --- Desktop shortcut (for pi + future users via /etc/skel) -----------
install -d /etc/skel/Desktop /home/pi/Desktop
cat > /etc/skel/Desktop/ZeroClaw.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=ZeroClaw Dashboard
Comment=Open the ZeroClaw web portal
Exec=chromium --new-window http://localhost:42617/
Icon=chromium
Terminal=false
Categories=Network;WebBrowser;
EOF
chmod 0755 /etc/skel/Desktop/ZeroClaw.desktop
cp /etc/skel/Desktop/ZeroClaw.desktop /home/pi/Desktop/
chmod 0755 /home/pi/Desktop/ZeroClaw.desktop
chown -R pi:pi /home/pi/Desktop

# --- nclawzero-set-keys helper ----------------------------------------
# Usage: sudo nclawzero-set-keys <env-file>
# Installs a user-supplied env file to /etc/zeroclaw/env with correct
# perms and restarts zeroclaw. Expected format: KEY=value per line,
# typically TOGETHER_API_KEY / OPENAI_API_KEY / GROQ_API_KEY / etc.
cat > /usr/local/bin/nclawzero-set-keys <<'EOF'
#!/bin/bash
# Apply an API-key env file to /etc/zeroclaw/env and restart zeroclaw.
set -e
if [ $# -ne 1 ] || [ ! -f "$1" ]; then
    cat <<HELP >&2
usage: $(basename "$0") <env-file>

Installs the given env file to /etc/zeroclaw/env (mode 0600,
owner zeroclaw:zeroclaw) and restarts the zeroclaw daemon so it
picks up the new keys. Expected format: KEY=value per line.

Common keys ZeroClaw recognises: TOGETHER_API_KEY, OPENAI_API_KEY,
ANTHROPIC_API_KEY, GROQ_API_KEY, MISTRAL_API_KEY, GOOGLE_API_KEY,
GEMINI_API_KEY, XAI_API_KEY, PERPLEXITY_API_KEY, MINIMAX_API_KEY,
FIREWORKS_API_KEY, OPENROUTER_API_KEY, NVIDIA_API_KEY, and others.
HELP
    exit 1
fi

SRC="$1"
DST=/etc/zeroclaw/env

# Validate: reject anything that isn't KEY=value
if grep -qvE '^(#.*|[A-Z_][A-Z0-9_]*=.*|)$' "$SRC"; then
    echo "error: $SRC contains lines that are not KEY=value" >&2
    exit 2
fi

install -d -o root -g root -m 0755 /etc/zeroclaw
install -m 0600 -o zeroclaw -g zeroclaw "$SRC" "$DST"
echo "wrote $(grep -cE '^[A-Z_]+=' "$DST") keys to $DST"

if systemctl is-active --quiet zeroclaw; then
    systemctl restart zeroclaw
    echo "restarted zeroclaw.service"
fi
EOF
chmod 0755 /usr/local/bin/nclawzero-set-keys
