#!/bin/bash -e

install -d -m 0755 "${ROOTFS_DIR}/etc/containers/systemd"
install -m 0644 files/zeroclaw.container "${ROOTFS_DIR}/etc/containers/systemd/"

install -d -m 0755 "${ROOTFS_DIR}/var/lib/nclawzero/agent-images"
if ! command -v skopeo >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends skopeo
fi

image="ghcr.io/perlowja/nclawzero-demo:latest"
archive="${ROOTFS_DIR}/var/lib/nclawzero/agent-images/zeroclaw.oci.tar"
echo "Archiving zeroclaw arm64 image for first-boot Podman load: ${image}"
skopeo copy --retry-times 3 --override-os linux --override-arch arm64 \
    "docker://${image}" "oci-archive:${archive}:${image}"
