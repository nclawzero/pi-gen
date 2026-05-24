# NCZ CLI Design

`ncz` is the nclawzero device-ops umbrella CLI. It is installed into every Pi image and is intended for daily operator use from the `ncz` account.

## Layout

```text
/usr/local/bin/ncz                  dispatcher
/usr/local/lib/ncz/common.sh        shared helpers
/usr/local/lib/ncz/<command>.sh     command handlers
/usr/local/share/doc/ncz/README.md  operator reference
/etc/nclawzero/agent                active agent state
/etc/sudoers.d/95-ncz-cli           NOPASSWD allowlist
```

The dispatcher parses the first argument, sources `/usr/local/lib/ncz/<command>.sh`, and calls `ncz_cmd_<command>`. This keeps the installed entrypoint small and lets later image iterations replace individual handlers.

## Agent Runtime Policy

All three runtimes may be baked as Podman quadlet units:

```text
/etc/containers/systemd/zeroclaw.container
/etc/containers/systemd/openclaw.container
/etc/containers/systemd/hermes.container
```

Only one generated service is enabled/running at a time. The default active agent is `zeroclaw`, stored in `/etc/nclawzero/agent`.

`ncz set-agent <target>`:

1. Validates `<target>` is one of `zeroclaw`, `openclaw`, `hermes`.
2. Verifies the target quadlet exists.
3. Verifies the target container image is already present locally.
4. Stops and disables all non-target agent services.
5. Enables and starts the target service.
6. Probes `http://127.0.0.1:<agent-port>/health` for up to 30 seconds.
7. Rolls back to the previous active agent on failed health probe.
8. Atomically writes the successful target to `/etc/nclawzero/agent`.

Ports:

```text
zeroclaw  42617
openclaw  18789
hermes    8642
```

## Output And Monitoring

Human-readable output is the default. `--json` is implemented for `status`, `version`, `providers list`, and `sandbox` so fleet tooling can ingest stable data without scraping text.

`ncz health` returns a single line:

```text
green active=zeroclaw running=zeroclaw network=ok
```

It reports `red` and exits `3` when the active-agent state disagrees with running services or more than one agent is running.

## Secrets

Default output redacts secret-looking values in provider config, sandbox policies, logs from `inspect`, and `/etc/nclawzero` dumps. Operators must pass `--show-secrets` where supported for explicit local debugging.

## Sudo

`/etc/sudoers.d/95-ncz-cli` grants NOPASSWD access for `systemctl`, `journalctl`, `apt`/`apt-get`, `podman`, and the small set of file operations needed for atomic writes under `/etc/nclawzero`. This is narrower than full NOPASSWD sudo and keeps routine operations noninteractive for key-only operator logins.

## Install Stage

The pi-gen sub-stage is:

```text
stage-zeroclaw/06-install-ncz-cli/
  00-run.sh
  01-run-chroot.sh
  files/
```

`00-run.sh` installs the staged files into `${ROOTFS_DIR}`. `01-run-chroot.sh` validates sudoers syntax, permissions, and runs `ncz selftest` inside the target rootfs when possible.
