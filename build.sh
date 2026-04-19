#!/bin/bash -e
# Wrapper: clone/update upstream pi-gen, overlay our stage, build image.
# Run from repo root.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

PIGEN_DIR="${PIGEN_DIR:-${SCRIPT_DIR}/pi-gen}"

if [ ! -d "${PIGEN_DIR}/.git" ]; then
    echo "==> Cloning upstream pi-gen"
    git clone --depth=1 --branch=arm64 \
        https://github.com/RPi-Distro/pi-gen.git "${PIGEN_DIR}"
else
    echo "==> Updating upstream pi-gen"
    git -C "${PIGEN_DIR}" pull --ff-only
fi

echo "==> Overlaying stage-nclawzero"
rm -rf "${PIGEN_DIR}/stage-nclawzero"
cp -r "${SCRIPT_DIR}/stage-nclawzero" "${PIGEN_DIR}/"
cp "${SCRIPT_DIR}/config" "${PIGEN_DIR}/config"

# Skip stage3-5 (desktop + wireless-specific extras) via empty SKIP markers
touch "${PIGEN_DIR}/stage3/SKIP" "${PIGEN_DIR}/stage3/SKIP_IMAGES" 2>/dev/null || true
touch "${PIGEN_DIR}/stage4/SKIP" "${PIGEN_DIR}/stage4/SKIP_IMAGES" 2>/dev/null || true
touch "${PIGEN_DIR}/stage5/SKIP" "${PIGEN_DIR}/stage5/SKIP_IMAGES" 2>/dev/null || true

echo "==> Starting pi-gen build (this takes 25-40 min)"
cd "${PIGEN_DIR}"
sudo ./build-docker.sh

echo "==> Done. Image(s) in ${PIGEN_DIR}/deploy/"
ls -lah "${PIGEN_DIR}/deploy/" 2>/dev/null | tail -5
