#!/bin/bash -e
# Target-side validation and permission convergence for ncz.

chmod 0755 /usr/local/bin/ncz
chmod 0644 /usr/local/lib/ncz/*.sh
chmod 0440 /etc/sudoers.d/95-ncz-cli
chmod 0644 /etc/nclawzero/agent /etc/nclawzero/channel
install -d -m 0755 /etc/nclawzero/providers.d /etc/nclawzero/agents /etc/nclawzero/sandbox

if command -v visudo >/dev/null 2>&1; then
    visudo -cf /etc/sudoers.d/95-ncz-cli
fi

bash -n /usr/local/bin/ncz
for f in /usr/local/lib/ncz/*.sh; do
    bash -n "$f"
done

if /usr/local/bin/ncz selftest; then
    echo "[06-install-ncz-cli] ncz selftest passed"
else
    rc=$?
    echo "[06-install-ncz-cli] WARNING: ncz selftest exited ${rc}; continuing because systemd may be offline in pi-gen chroot" >&2
fi
