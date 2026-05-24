#!/bin/bash -e

if [ -f /config ]; then
    . /config
fi

if [ "${IMG_NAME:-}" = "nclawzero-zeropi" ] || [ "${TARGET_HOSTNAME:-}" = "zeropi" ]; then
    echo "Skipping openclaw quadlet for zeropi profile"
    exit 0
fi

install -d -m 0755 "${ROOTFS_DIR}/etc/containers/systemd"
install -m 0644 files/openclaw.container "${ROOTFS_DIR}/etc/containers/systemd/"

install -d -m 0755 "${ROOTFS_DIR}/var/lib/nclawzero/agent-images"
if ! command -v skopeo >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends skopeo
fi

image="ghcr.io/openclaw/openclaw:main"
archive="${ROOTFS_DIR}/var/lib/nclawzero/agent-images/openclaw.oci.tar"
echo "Archiving openclaw arm64 image for first-boot Podman load: ${image}"
skopeo copy --retry-times 3 --override-os linux --override-arch arm64 \
    "docker://${image}" "oci-archive:${archive}:${image}"
