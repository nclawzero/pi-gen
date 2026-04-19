#!/bin/bash -e
# Copy previous stage's rootfs as our working tree
if [ ! -d "${ROOTFS_DIR}" ]; then
    copy_previous
fi
