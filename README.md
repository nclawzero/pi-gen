# nclawzero/pi-gen

Raspberry Pi image builder for nclawzero. Wraps upstream pi-gen with custom stages and produces flashable Raspberry Pi images preconfigured with the zeroclaw runtime + optional nemoclaw stack.

## Profiles

| Profile | Target board | RAM | Image |
|---|---|---|---|
| `clawpi` | Raspberry Pi 4 8GB | 8GB | full stack — zeroclaw + nemoclaw + XFCE + npm |
| `zeropi` | Raspberry Pi 4 2GB | 2GB | minimal — zeroclaw only |

## Dependencies

- Docker (pi-gen runs its build inside a Debian container)
- Host: Linux native works directly. macOS Docker Desktop has known LAN-reach limits with the apt repo used during build — build on Linux for now.

## Build

```bash
./build.sh clawpi      # or 'zeropi'
```

Output: `pi-gen/deploy/image_<date>-nclawzero-<profile>.img.xz` (xz-compressed).

`build.sh` clones upstream pi-gen into `./pi-gen/` if absent (depth=1, branch=arm64), overlays the `stage-zeroclaw/` and `stage-nclawzero/` directories, copies the per-profile config to `pi-gen/config`, then runs `sudo ./build-docker.sh`.

## Stage map

```
stage-zeroclaw/                      — shared by both clawpi and zeropi
  00-install-packages/               — base utilities + tailscale repo
  01-install-nclawzero/              — nclawzero apt repo + zeroclaw
  02-bake-userconf/                  — Pi OS Trixie userconfig.txt bake
  05-track-head-packages/            — extend unattended-upgrades to track
                                       Tailscale, Raspberry Pi Foundation,
                                       and nclawzero-internal origins
stage-nclawzero/                     — clawpi-only (full stack)
  00-install-packages/               — XFCE, browsers, dev tools
  01-install-nemoclaw/               — NemoClaw + Claude Code CLI
```

## First-boot user

The freshly-flashed device has one operator account — `ncz` (FIRST_USER_NAME from `config-{profile}`). It's created by Pi OS Trixie's userconfig service from the `userconf.txt` baked into `/boot/firmware/` at image-build time (stage `02-bake-userconf`). Without that bake, Trixie's userconfig service strips the account at first boot and SSH refuses every login.

The default `ncz` password is set in `config-{profile}` — operators are expected to change it on first boot or replace the account auth with SSH keys.

## Flash

```bash
xz -dc deploy/image_<date>-nclawzero-clawpi.img.xz | \
    sudo dd of=/dev/<sdcard> bs=4M conv=fsync status=progress
sudo eject /dev/<sdcard>
```

## Updates

Devices configure `unattended-upgrades` to track HEAD on the configured apt repos: Debian + Debian-Security, Tailscale, Raspberry Pi Foundation, and the nclawzero-internal apt repo. New point releases install automatically via `apt-daily-upgrade.timer`.

## License

Apache-2.0. See `LICENSE`.
