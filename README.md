# nclawzero/pi-gen

Raspberry Pi image builder for nclawzero. Wraps upstream pi-gen with custom stages and produces flashable images for the nclawzero edge fleet.

> **Repo path note (2026-04-26 reorg):** this project lives at
> `gitlab.com/nclawzero/pi-gen` (canonical) /
> `github.com/nclawzero/pi-gen` (mirror) /
> `argonas:/mnt/datapool/git/nclawzero/pi-gen.git` (fleet backup).
> The previous flat `perlowja/pi-gen-nclawzero` URL auto-redirects on
> both forges. The on-disk directory name in working trees is still
> `pi-gen-nclawzero/` — that's a working-tree convenience, the project
> path is `nclawzero/pi-gen`.

## Profiles

| Profile | Target board | RAM | Image |
|---|---|---|---|
| `clawpi` | Raspberry Pi 4 8GB (192.168.207.54) | 8GB | nclawzero-clawpi.img.xz — full stack (zeroclaw + nemoclaw + XFCE + npm) |
| `zeropi` | Raspberry Pi 4 2GB (192.168.207.56) | 2GB | nclawzero-zeropi.img.xz — minimal stack (zeroclaw only) |

## Dependencies

- Docker (pi-gen runs its build inside a Debian container)
- Host: Linux native works directly. macOS Docker Desktop runs into LAN-reach limits (`192.168.207.22:8081` apt repo unreachable from container) — build on Linux for now.

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
  03-create-backup-user/             — jasonperlow defense-in-depth user
  04-bake-authorized-keys/           — fleet authorized_keys → ncz + jasonperlow
stage-nclawzero/                     — clawpi-only (full stack)
  00-install-packages/               — XFCE, browsers, dev tools
  01-install-nemoclaw/               — NemoClaw + Claude Code CLI
```

## First-boot user model (post 2026-04-26 reflash)

Two user accounts on every freshly flashed device:

- **`ncz`** — operator account (FIRST_USER_NAME). Sudo NOPASSWD. Created by Pi OS Trixie's userconfig service from the `userconf.txt` baked into `/boot/firmware/` at image-build time (stage `02-bake-userconf`). Without that bake, Trixie's userconfig service strips the account at first boot and SSH refuses every login — this is the bug that bricked clawpi+zeropi on 2026-04-26 and required a manual SD-pull recovery.
- **`jasonperlow`** — defense-in-depth backup user. Locked password (`-p '!'`), key-only access, sudo NOPASSWD via dedicated sudoers drop-in. Exists so a disrupted operator account doesn't lock the fleet out. Username matches the user's identity on every other fleet host (STUDIO, ULTRA, ARGOS, PYTHIA, CERBERUS) — muscle-memory works regardless.

Both accounts share the same baked `authorized_keys` (stage `04-bake-authorized-keys`).

## Auth-policy material is fleet-internal

`stage-zeroclaw/04-bake-authorized-keys/files/authorized_keys` is in `.gitignore`. The committed sibling is `authorized_keys.example` with placeholder content + format documentation. Real fleet pubkeys live at `/mnt/datapool/secrets/nclawzero-fleet-keys/authorized_keys` on ARGONAS — operators pull via `~/sync-fleet-keys.sh` before each build.

The build fails fast if the keys file is missing, contains the `AAAAREPLACEME` placeholder, or has any line that fails per-line `ssh-keygen` validation (including bullet-prefixed `- ssh-ed25519 ...` shapes that ssh-keygen accepts but sshd refuses).

Diagnostics on validation failure report only line numbers — line content is fleet-internal and never echoed to build logs.

## Flash

```bash
xz -dc deploy/image_*-nclawzero-clawpi.img.xz | sudo dd of=/dev/<sdcard> bs=4M conv=fsync status=progress
sudo eject /dev/<sdcard>
```

Or, on a Mac with the `~/flash-clawpi-sd.sh` / `~/flash-zeropi-sd.sh` wrappers, use those — they include a streaming xz from ARGONAS plus a 6-region byte-verify against the source.

## Auto-updates

Devices poll the nclawzero internal apt repo (`http://192.168.207.22:8081/apt`) every ~12h via `apt-daily-upgrade.timer` and install new betas. Scope: `origin=nclawzero-internal` only — stock Debian updates are not auto-applied.
