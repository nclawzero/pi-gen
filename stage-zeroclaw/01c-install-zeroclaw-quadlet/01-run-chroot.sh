#!/bin/bash -e

install -d -m 0755 /usr/local/sbin
cat > /usr/local/sbin/nclawzero-load-agent-images <<'EOF'
#!/bin/bash -e

while read -r agent image archive; do
    [ -n "${agent}" ] || continue
    if [ ! -s "${archive}" ]; then
        echo "${agent}: archive missing, skipping ${archive}"
        continue
    fi
    if podman image exists "${image}" >/dev/null 2>&1; then
        echo "${agent}: ${image} already present"
    else
        echo "${agent}: loading ${image} from ${archive}"
        podman load -i "${archive}"
    fi

    pulled_arch="$(podman image inspect --format '{{.Architecture}}' "${image}" 2>/dev/null || true)"
    if [ "${pulled_arch}" != "arm64" ]; then
        echo "ERROR: ${image} resolved as architecture '${pulled_arch}', not arm64" >&2
        exit 1
    fi
done <<'IMAGES'
zeroclaw ghcr.io/perlowja/nclawzero-demo:latest /var/lib/nclawzero/agent-images/zeroclaw.oci.tar
openclaw ghcr.io/openclaw/openclaw:main /var/lib/nclawzero/agent-images/openclaw.oci.tar
hermes docker.io/nousresearch/hermes-agent:latest /var/lib/nclawzero/agent-images/hermes.oci.tar
IMAGES
EOF
chmod 0755 /usr/local/sbin/nclawzero-load-agent-images

cat > /etc/systemd/system/nclawzero-load-agent-images.service <<'EOF'
[Unit]
Description=Load baked nclawzero agent container images into Podman
DefaultDependencies=no
After=local-fs.target
Before=zeroclaw.service openclaw.service hermes.service
ConditionPathExists=/var/lib/nclawzero/agent-images

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/nclawzero-load-agent-images
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cat > /usr/local/sbin/nclawzero-enable-default-agent <<'EOF'
#!/bin/bash -e

stamp=/etc/nclawzero/default-agent-enabled
if [ -e "${stamp}" ]; then
    echo "Default agent already enabled; leaving current operator choice unchanged."
    exit 0
fi

systemctl daemon-reload
systemctl start zeroclaw.service
systemctl enable --now podman-auto-update.timer
printf 'zeroclaw\n' > /etc/nclawzero/agent
chmod 0644 /etc/nclawzero/agent
touch "${stamp}"
EOF
chmod 0755 /usr/local/sbin/nclawzero-enable-default-agent

cat > /etc/systemd/system/nclawzero-enable-default-agent.service <<'EOF'
[Unit]
Description=Enable default nclawzero agent after first image load
Requires=nclawzero-load-agent-images.service
After=nclawzero-load-agent-images.service network-online.target
Wants=network-online.target
ConditionPathExists=!/etc/nclawzero/default-agent-enabled

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/nclawzero-enable-default-agent

[Install]
WantedBy=multi-user.target
EOF

install -d -m 0755 /etc/nclawzero
printf 'zeroclaw\n' > /etc/nclawzero/agent
chmod 0644 /etc/nclawzero/agent

systemctl daemon-reload || true
systemctl enable nclawzero-load-agent-images.service
systemctl enable nclawzero-enable-default-agent.service
systemctl enable podman-auto-update.timer

cat > /etc/nclawzero/agent-auto-update.md <<'EOF'
# Agent Container Auto-Update

The baked agent quadlets use floating, HEAD-tracking image tags and
Podman's `AutoUpdate=registry` directive. The image carries arm64 OCI archives
for first boot, and `nclawzero-load-agent-images.service` loads them into
Podman before the default agent starts. `nclawzero-enable-default-agent.service`
enables and starts `zeroclaw.service` once on first boot after the quadlet
generator has created the unit. The system `podman-auto-update.timer` is enabled
so Podman checks the registries daily and restarts changed agent services
through systemd.

Operators who want manual control can opt out with:

    systemctl disable --now podman-auto-update.timer

Manual update checks can be inspected with:

    podman auto-update --dry-run
EOF
