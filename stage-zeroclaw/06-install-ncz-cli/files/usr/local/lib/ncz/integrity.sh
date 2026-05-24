#!/usr/bin/env bash

ncz_cmd_integrity() {
    [ "$#" -eq 0 ] || ncz_die "usage: ncz integrity" 1
    local manifest="$NCZ_MANIFEST_FILE"
    if [ ! -r "$manifest" ] && [ -r /usr/share/nclawzero/manifest.sha256 ]; then
        manifest=/usr/share/nclawzero/manifest.sha256
    fi
    [ -r "$manifest" ] || ncz_die "missing integrity manifest: $manifest" 2
    (cd / && sha256sum -c "$manifest")
}
