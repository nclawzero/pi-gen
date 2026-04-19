#!/bin/bash -e
# stage-zeroclaw already added the apt repo
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    nemoclaw-firstboot
