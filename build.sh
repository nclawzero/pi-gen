#!/bin/bash -e
# Wrapper: clone/update upstream pi-gen, overlay our stages, build an image
# for the given profile.
#
# Usage: ./build.sh <zeropi|clawpi>
#
# Profiles:
#   zeropi — pure ZeroClaw base (stage-zeroclaw only). Minimal footprint for
#            baseline ZeroClaw testing on constrained Pi 4 2GB.
#   clawpi — full nclawzero image (stage-zeroclaw + stage-nclawzero).
#            Adds NemoClaw + extended utility set. For Pi 4 8GB.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

PROFILE="${1:-}"
if [ -z "${PROFILE}" ] || [ ! -f "${SCRIPT_DIR}/config-${PROFILE}" ]; then
    echo "Usage: $0 <zeropi|clawpi>"
    echo "Available profiles:"
    ls "${SCRIPT_DIR}"/config-* 2>/dev/null | sed 's|.*config-||; s|^|  - |'
    exit 1
fi

PIGEN_DIR="${PIGEN_DIR:-${SCRIPT_DIR}/pi-gen}"

if [ ! -d "${PIGEN_DIR}/.git" ]; then
    echo "==> Cloning upstream pi-gen"
    git clone --depth=1 --branch=arm64 \
        https://github.com/RPi-Distro/pi-gen.git "${PIGEN_DIR}"
else
    echo "==> Updating upstream pi-gen"
    git -C "${PIGEN_DIR}" pull --ff-only
fi

echo "==> Overlaying stages for profile: ${PROFILE}"
rm -rf "${PIGEN_DIR}/stage-zeroclaw" "${PIGEN_DIR}/stage-nclawzero"
cp -r "${SCRIPT_DIR}/stage-zeroclaw" "${PIGEN_DIR}/"
cp -r "${SCRIPT_DIR}/stage-nclawzero" "${PIGEN_DIR}/"
cp "${SCRIPT_DIR}/config-${PROFILE}" "${PIGEN_DIR}/config"

# Skip upstream stages beyond stage2
for s in stage3 stage4 stage5; do
    touch "${PIGEN_DIR}/${s}/SKIP" "${PIGEN_DIR}/${s}/SKIP_IMAGES" 2>/dev/null || true
done

echo "==> Starting pi-gen build (25-40 min)"
cd "${PIGEN_DIR}"
sudo ./build-docker.sh

echo "==> Done. Image(s) in ${PIGEN_DIR}/deploy/"
ls -lah "${PIGEN_DIR}/deploy/" 2>/dev/null | grep "${PROFILE}" || ls -lah "${PIGEN_DIR}/deploy/"
