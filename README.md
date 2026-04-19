# pi-gen-nclawzero

Raspberry Pi image builder for nclawzero. Produces a flashable
`nclawzero-pi-arm64.img.xz` from a pi-gen custom stage overlaid on
Pi OS Lite (Debian trixie).

## Dependencies

- Upstream pi-gen (clone as sibling or configure `PIGEN_PATH`)
- Docker (for pi-gen's build container)
- Host: x86_64 Ubuntu/Debian with binfmt-misc for arm64 emulation

## Build

```bash
./build.sh
```

Output: `deploy/<date>-nclawzero.img.xz`

## What's in the image

- Pi OS Lite trixie arm64 base (stage0-2 from upstream)
- Our custom `stage-nclawzero` adds:
  - `zeroclaw` (from apt.nclawzero.internal → tracks upstream master betas)
  - `nemoclaw-firstboot` (git-clones NVIDIA/nemoclaw at first boot, ff-only updates)
  - `nclawzero-rdp-init` (seeds pi password, generates TLS cert)
  - System utilities: docker, tailscale, starship, bat, fd-find, etc.
  - Auto-upgrade timer pinned to `origin=nclawzero-internal`

## First-boot

1. Pi OS creates user `pi` per `config` (password: `nclawzero`)
2. `nclawzero-rdp-init.service` seeds password from
   `/etc/nclawzero/initial-password`
3. `nemoclaw-firstboot.service` clones NemoClaw, npm install
4. `zeroclaw.service` starts daemon on `[::]:42617`
5. Web dashboard at `http://<pi>:42617/`

## Auto-updates

Device polls `apt.nclawzero.internal` every ~12h via
`apt-daily-upgrade.timer` and installs new betas published by the
track-master pipeline. Scope limited to `origin=nclawzero-internal`,
so stock Debian updates are not automatic.
