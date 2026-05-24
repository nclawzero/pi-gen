#!/bin/bash -e
# Wrapper: clone/update upstream pi-gen, overlay our stages, build an image
# for the given profile.
#
# Usage: ./build.sh <zeropi|clawpi|bigpi>
#
# Profiles:
#   zeropi — constrained all-agent image (stage-zeroclaw only).
#            Includes the agent quadlets and first-boot OCI image archives.
#   clawpi — full nclawzero image (stage-zeroclaw + stage-nclawzero).
#            Adds optional agent quadlets + extended utility set. For Pi 4 8GB.
#   bigpi  — full nclawzero image for Pi 5 16GB. Uses the same software
#            profile as clawpi on the upstream arm64/trixie base.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

PROFILE="${1:-}"
if [ -z "${PROFILE}" ] || [ ! -f "${SCRIPT_DIR}/config-${PROFILE}" ]; then
    echo "Usage: $0 <zeropi|clawpi|bigpi>"
    echo "Available profiles:"
    ls "${SCRIPT_DIR}"/config-* 2>/dev/null | sed 's|.*config-||; s|^|  - |'
    exit 1
fi

# Load wrapper-only profile metadata, then hand the same config to pi-gen.
# pi-gen ignores unknown variables such as SKIP_AGENT_QUADLET_STAGES.
# shellcheck disable=SC1090
. "${SCRIPT_DIR}/config-${PROFILE}"

case "${PROFILE}" in
    zeropi)
        SKIP_AGENT_QUADLET_STAGES="01d-install-openclaw-quadlet 01e-install-hermes-quadlet"
        ;;
    clawpi|bigpi)
        SKIP_AGENT_QUADLET_STAGES=""
        ;;
esac

PIGEN_DIR="${PIGEN_DIR:-${SCRIPT_DIR}/pi-gen}"
SUDO_CMD=(sudo)
if [ -n "${SUDO_ASKPASS:-}" ]; then
    SUDO_CMD=(sudo -A)
fi

if [ ! -d "${PIGEN_DIR}/.git" ]; then
    echo "==> Cloning upstream pi-gen"
    git clone --depth=1 --branch=arm64 \
        https://github.com/RPi-Distro/pi-gen.git "${PIGEN_DIR}"
else
    echo "==> Updating upstream pi-gen"
    git -C "${PIGEN_DIR}" pull --ff-only
    git -C "${PIGEN_DIR}" reset --hard HEAD
fi

echo "==> Overlaying stages for profile: ${PROFILE}"
"${SUDO_CMD[@]}" rm -rf "${PIGEN_DIR}/stage-zeroclaw" "${PIGEN_DIR}/stage-nclawzero"
"${SUDO_CMD[@]}" cp -r "${SCRIPT_DIR}/stage-zeroclaw" "${PIGEN_DIR}/"
"${SUDO_CMD[@]}" cp -r "${SCRIPT_DIR}/stage-nclawzero" "${PIGEN_DIR}/"
"${SUDO_CMD[@]}" cp "${SCRIPT_DIR}/config-${PROFILE}" "${PIGEN_DIR}/config"

if [ -n "${SKIP_AGENT_QUADLET_STAGES:-}" ]; then
    echo "==> Profile ${PROFILE}: skipping agent substages: ${SKIP_AGENT_QUADLET_STAGES}"
    for substage in ${SKIP_AGENT_QUADLET_STAGES}; do
        if [ ! -d "${PIGEN_DIR}/stage-zeroclaw/${substage}" ]; then
            echo "ERROR: configured skip substage does not exist: ${substage}" >&2
            exit 1
        fi
        "${SUDO_CMD[@]}" touch "${PIGEN_DIR}/stage-zeroclaw/${substage}/SKIP"
    done
else
    echo "==> Profile ${PROFILE}: installing full agent quadlet stack"
fi

# Skip upstream stages beyond stage2
for s in stage3 stage4 stage5; do
    "${SUDO_CMD[@]}" touch "${PIGEN_DIR}/${s}/SKIP" "${PIGEN_DIR}/${s}/SKIP_IMAGES" 2>/dev/null || true
done

echo "==> Starting pi-gen build (25-40 min)"
cd "${PIGEN_DIR}"
"${SUDO_CMD[@]}" ./build-docker.sh

echo "==> Done. Image(s) in ${PIGEN_DIR}/deploy/"
ls -lah "${PIGEN_DIR}/deploy/" 2>/dev/null | grep "${PROFILE}" || ls -lah "${PIGEN_DIR}/deploy/"
