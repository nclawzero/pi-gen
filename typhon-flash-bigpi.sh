#!/bin/bash
# TYPHON-direct flash of bigpi SD card with byte-verify
# Streams from ARGONAS via SSH directly to local dd; no Mac in the path.

set -e

DEVICE=/dev/sda
EXPECTED_SIZE_BYTES=63864569856  # 64GB SD (59.5 GiB)
ARGONAS_PASS="Gumbo@Kona1b"
IMAGE_BASE=/mnt/datapool/projects/pi-gen-nclawzero/pi-gen/deploy
IMAGE_NAME=$(sshpass -p "$ARGONAS_PASS" ssh -o PubkeyAuthentication=no -o StrictHostKeyChecking=no root@192.168.207.101 "ls -1t $IMAGE_BASE/image_*-nclawzero-bigpi.img.xz 2>/dev/null | head -1 | xargs -n1 basename")
if [ -z "$IMAGE_NAME" ]; then echo "ABORT: no bigpi image on ARGONAS"; exit 1; fi
IMAGE_PATH="$IMAGE_BASE/$IMAGE_NAME"
echo "Resolved image: $IMAGE_NAME"

echo === sanity check $DEVICE ===
ACTUAL_SIZE=$(cat /sys/block/$(basename $DEVICE)/size 2>/dev/null | awk '{print $1*512}')
REMOVABLE=$(cat /sys/block/$(basename $DEVICE)/removable 2>/dev/null)
echo "  size: $ACTUAL_SIZE bytes (expected: $EXPECTED_SIZE_BYTES)"
echo "  removable: $REMOVABLE"
if [ "$ACTUAL_SIZE" != "$EXPECTED_SIZE_BYTES" ] || [ "$REMOVABLE" != "1" ]; then
    echo "ABORT: $DEVICE doesn't look like the expected 64GB SD"
    exit 1
fi
echo "  OK"

echo
echo === umount any auto-mounted partitions ===
umount /dev/sda1 /dev/sda2 2>/dev/null || true

echo
echo === verify image present + xz integrity on ARGONAS ===
sshpass -p "$ARGONAS_PASS" ssh -o PubkeyAuthentication=no -o StrictHostKeyChecking=no \
    root@192.168.207.101 \
    "ls -la $IMAGE_PATH && xz -t $IMAGE_PATH && echo OK"

echo
echo === STREAM FLASH from ARGONAS direct to $DEVICE ===
echo "  source: argonas:$IMAGE_PATH"
echo "  target: $DEVICE"
echo "  started: $(date -u)"
echo

sshpass -p "$ARGONAS_PASS" ssh -o PubkeyAuthentication=no -o StrictHostKeyChecking=no \
    root@192.168.207.101 \
    "xz -dc $IMAGE_PATH" \
  | dd of="$DEVICE" bs=4M conv=fsync status=progress

echo
echo === sync + settle ===
sync
sleep 3
partprobe $DEVICE 2>/dev/null || true
sleep 1
echo "  finished: $(date -u)"

echo
echo === BYTE-VERIFY: sample regions vs source ===
SAMPLE_OFFSETS=(0 2048 16384 1064960 5000000 8000000)
FAIL=0
for off in "${SAMPLE_OFFSETS[@]}"; do
    src_md5=$(sshpass -p "$ARGONAS_PASS" ssh -o PubkeyAuthentication=no -o StrictHostKeyChecking=no \
        root@192.168.207.101 \
        "xz -dc $IMAGE_PATH | dd bs=512 count=1024 skip=$off 2>/dev/null | md5sum" 2>/dev/null | awk '{print $1}')
    dst_md5=$(dd if="$DEVICE" bs=512 count=1024 skip=$off iflag=direct 2>/dev/null | md5sum | awk '{print $1}')
    if [ "$src_md5" = "$dst_md5" ]; then
        printf "  [OK]   sector %10d: %s\n" "$off" "${src_md5:0:16}"
    else
        printf "  [FAIL] sector %10d: src=%s dst=%s\n" "$off" "${src_md5:0:16}" "${dst_md5:0:16}"
        FAIL=1
    fi
done

echo
if [ "$FAIL" = "1" ]; then
    echo "VERIFICATION FAILED: SD has silent write corruption."
    echo "This card / reader path is unreliable. Try a different SD or reader."
    exit 2
fi
echo "Verify passed: all sampled regions match source. SD is bootable."
echo
echo === final partition state ===
lsblk -f $DEVICE 2>&1 | head -10
fdisk -l $DEVICE 2>&1 | tail -8
echo
echo "Eject + insert into bigpi, power on."
