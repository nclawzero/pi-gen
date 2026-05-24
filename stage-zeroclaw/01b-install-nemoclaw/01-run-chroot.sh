#!/bin/bash -e

# NemoClaw is the host-side sandbox runtime and is present on every
# deployment shape. Agent quadlets are installed by the following substages.
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    nemoclaw-firstboot
