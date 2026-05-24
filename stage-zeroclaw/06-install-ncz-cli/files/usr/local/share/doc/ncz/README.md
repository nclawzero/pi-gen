# ncz device-ops CLI

`ncz` is the operator CLI shipped on nclawzero devices. It manages the active agent runtime, inference provider routing, sandbox inspection, updates, and support diagnostics.

Only one agent runtime is enabled at a time. The image may contain `zeroclaw`, `openclaw`, and `hermes` quadlets, but `ncz set-agent` stops and disables non-target agents before enabling the target.

## Tier 1

```bash
ncz status
ncz status --json
ncz set-agent zeroclaw
ncz set-agent openclaw
ncz set-agent hermes
ncz logs
ncz logs openclaw
ncz restart
ncz pause
ncz resume
ncz version
ncz version --json
```

`ncz set-agent <name>` validates the target quadlet and local container image, stops/disables other agents, starts the target, probes `http://127.0.0.1:<port>/health`, and rolls back to the prior active agent on failure. The active agent is persisted in `/etc/nclawzero/agent` with an atomic write.

Agent ports:

```text
zeroclaw  42617
openclaw  18789
hermes    8642
```

## Tier 2

```bash
ncz providers list
ncz providers list --json
ncz providers test local
ncz providers set-primary local

ncz sandbox
ncz sandbox --json
ncz sandbox policy zeroclaw

ncz integrity
ncz update --check
ncz update
ncz channel
ncz channel canary
ncz health
ncz inspect
ncz selftest
```

Provider config is discovered from `/etc/nclawzero/providers.d/*.env`, `*.conf`, and `*.json`. Default output masks API keys, tokens, secrets, and passwords. Use `--show-secrets` only during explicit local debugging.

`ncz inspect` redacts secret-looking values and dumps versions, service state, recent agent logs, sandbox state, and `/etc/nclawzero` files for support.

## Agent Auto-Update

Agent quadlets use floating, HEAD-tracking image tags and Podman's `AutoUpdate=registry` directive. The image carries arm64 OCI archives that `nclawzero-load-agent-images.service` loads into Podman on first boot before the default agent starts. `nclawzero-enable-default-agent.service` enables and starts `zeroclaw.service` once after the quadlet generator has created it. `podman-auto-update.timer` is enabled by default so Podman checks registries daily and restarts changed agent services through systemd.

To opt out and update manually:

```bash
sudo systemctl disable --now podman-auto-update.timer
```

## Exit Codes

```text
0  success
1  user error, such as bad command or bad agent name
2  system error, such as missing quadlet, missing image, or failed service start
3  state inconsistency, such as /etc/nclawzero/agent disagreeing with running services
```

## Files

```text
/usr/local/bin/ncz
/usr/local/lib/ncz/*.sh
/etc/nclawzero/agent
/etc/nclawzero/channel
/etc/nclawzero/providers.d/
/etc/nclawzero/sandbox/<agent>/policy-additions.yaml
/etc/sudoers.d/95-ncz-cli
```
