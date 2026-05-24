#!/bin/bash -e
# Install ncz CLI files into the target rootfs. Runs outside chroot.

SRC="${BASH_SOURCE%/*}/files"

install -d "${ROOTFS_DIR}/usr/local/bin"
install -m0755 "${SRC}/usr/local/bin/ncz" \
    "${ROOTFS_DIR}/usr/local/bin/ncz"

find "${SRC}/usr/local/lib/ncz" -type f -name '*.sh' | sort | while read -r file; do
    rel="${file#"${SRC}"/}"
    install -d "$(dirname "${ROOTFS_DIR}/${rel}")"
    install -m0644 "$file" "${ROOTFS_DIR}/${rel}"
done

install -d "${ROOTFS_DIR}/usr/local/share/doc/ncz"
install -m0644 "${SRC}/usr/local/share/doc/ncz/README.md" \
    "${ROOTFS_DIR}/usr/local/share/doc/ncz/README.md"

install -d "${ROOTFS_DIR}/etc/sudoers.d"
install -m0440 "${SRC}/etc/sudoers.d/95-ncz-cli" \
    "${ROOTFS_DIR}/etc/sudoers.d/95-ncz-cli"

install -d "${ROOTFS_DIR}/etc/nclawzero"
install -m0644 "${SRC}/etc/nclawzero/agent" \
    "${ROOTFS_DIR}/etc/nclawzero/agent"
install -m0644 "${SRC}/etc/nclawzero/channel" \
    "${ROOTFS_DIR}/etc/nclawzero/channel"

install -d -m 0755 "${ROOTFS_DIR}/etc/nclawzero/providers.d"
install -d -m 0755 "${ROOTFS_DIR}/etc/nclawzero/agents"
install -d -m 0755 "${ROOTFS_DIR}/etc/nclawzero/sandbox"

echo "[06-install-ncz-cli] installed ncz dispatcher, handlers, docs, sudoers, and default state"
