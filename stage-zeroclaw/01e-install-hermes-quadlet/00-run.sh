#!/bin/bash -e

if [ -f /config ]; then
    . /config
fi

if [ "${IMG_NAME:-}" = "nclawzero-zeropi" ] || [ "${TARGET_HOSTNAME:-}" = "zeropi" ]; then
    echo "Skipping hermes quadlet for zeropi profile"
    exit 0
fi

install -d -m 0755 "${ROOTFS_DIR}/etc/containers/systemd"
install -m 0644 files/hermes.container "${ROOTFS_DIR}/etc/containers/systemd/"

install -d -m 0755 "${ROOTFS_DIR}/var/lib/nclawzero/agent-images"
if ! command -v skopeo >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends skopeo
fi

image="docker.io/nousresearch/hermes-agent:latest"
archive="${ROOTFS_DIR}/var/lib/nclawzero/agent-images/hermes.oci.tar"
echo "Archiving hermes arm64 image for first-boot Podman load: ${image}"
skopeo copy --retry-times 3 --override-os linux --override-arch arm64 \
    "docker://${image}" "oci-archive:${archive}:${image}"
