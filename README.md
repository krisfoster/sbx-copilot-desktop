# sbx-copilot-desktop

A Docker Sandboxes (`sbx`) **workload kit** and a one-command runner that open **Microsoft Copilot** in its own
window from inside a sandbox, with the sign-in kept across restarts.

There is no official Linux build of the Microsoft Copilot desktop app, so the kit runs the Copilot web app in
Chromium app-mode (no tabs, no address bar) on the sandbox's Wayland display. Nothing third-party is installed
besides Debian's `chromium`.

## Use

**Requirements (on your Mac):** `sbx` 0.45 or later, and Docker running (the kit is built from source on first use).
The kit targets arm64, like Apple Silicon hosts.

```bash
./run-copilot               # no host bind mount
./run-copilot ./workspace   # also mount a host folder into the sandbox
./run-copilot --recreate    # remove and rebuild the sandbox (deletes its saved sign-in)
```

The first run creates the sandbox with `--display` (which can only be set at creation) and attaches, so the
Copilot window appears. Sign in with a personal Microsoft account or a work or school account. Closing the window
or pressing Ctrl-C stops it; run `./run-copilot` again and you are still signed in.

| Variable | Default | Meaning |
|---|---|---|
| `COPILOT_KIT` | `./copilot-desktop` | Local kit directory (built from source) or an OCI, ZIP or git reference |
| `COPILOT_SANDBOX` | `copilot-desktop` | Sandbox name |
| `COPILOT_URL` | `https://copilot.microsoft.com` | Start page; set it inside the sandbox environment to open something else |

The equivalent manual commands:

```bash
sbx create --display --name copilot-desktop ./copilot-desktop
sbx run copilot-desktop
```

## How it works

`copilot-desktop/` is a v3 workload kit (`copilot-desktop.yaml` plus `copilot-desktop.dockerfile`) on Docker's
shell base image.

- `copilot-session` (the entrypoint) waits for the Wayland socket at `/run/display/wayland-0`, then starts a
  private D-Bus session.
- `copilot-bus` unlocks a `gnome-keyring` "login" keyring on that bus, so Chromium has a Secret Service and keeps
  its credentials, then runs `chromium --app=https://copilot.microsoft.com`.
- Chromium runs with `--no-sandbox` (the container has no user namespaces), software rendering (no GPU in the
  sandbox, otherwise the window stays blank), `--disable-quic` (the sandbox proxy carries TCP only) and
  `--password-store=gnome-libsecret`.
- The profile lives in `~/.config/copilot-desktop` on the sandbox's disk, so it survives restarts but not
  `--recreate`.

## Network

The sandbox is default-deny. The kit allows `copilot.microsoft.com`, the Microsoft sign-in hosts for personal
(`login.live.com`) and work or school (`login.microsoftonline.com`) accounts, and a set of Microsoft and CDN
wildcards. A wildcard matches exactly one label. **This list is a starting point, not a verified minimum.** After a
real sign-in, check what was blocked or used and tighten or extend `copilot-desktop.yaml`:

```bash
sbx policy log
```

Work or school accounts may be refused by Conditional Access if the tenant requires a managed or compliant device;
a sandbox browser is neither, and the kit cannot change that.

## Security notes

- No credentials are stored in the kit and no `sbx secret` is used. You sign in interactively.
- The keyring password is a fixed string in `copilot-bus`. The keyring file sits on the sandbox's own disk, no
  weaker than Chromium's plain-text fallback, but it is not a secret store against anything that can read the
  sandbox.
- `--no-sandbox` turns off Chromium's own sandbox; the sandbox VM is the isolation boundary here.

## Development

```bash
bash scripts/test.sh        # shellcheck, syntax and static checks, no Docker needed
docker buildx build -f copilot-desktop/copilot-desktop.yaml copilot-desktop --output type=cacheonly
sbx kit inspect ./copilot-desktop
```

A sandbox keeps the kit it was created with, so after editing the kit use `./run-copilot --recreate`.

## Publishing

A v3 kit is published with `docker buildx build --push`, not `sbx kit push`:

```bash
docker login
DOCKERHUB_NAMESPACE=<your-namespace> ./scripts/publish.sh
COPILOT_KIT=docker.io/<your-namespace>/copilot-desktop-kit:latest ./run-copilot
```

## Status

Built and run on `sbx` 0.54.0-rc4 (arm64, macOS): the kit builds, `sbx kit inspect` accepts it, and
`./run-copilot` opens a Copilot window that loads and renders the page. A gnome-keyring `login.keyring` is created
in the sandbox.

Sign-in worked, but the first attempt did not complete and a second click on sign in did. Neither the Chromium log
nor the policy log shows why, so the cause is unknown.

Not verified yet:

- That a completed sign-in survives closing the window and running `./run-copilot` again, for either account type.
- The multi-label hosts added after the first run (`*.svc.cloud.microsoft`, `*.teams.microsoft.com`,
  `*.static.microsoft` and similar) were taken from the policy log, not tested under a strict policy.
- That the network allow list is the minimum. The test machine's default policy allowed hosts outside the kit's
  list (Google update and component hosts that Chromium contacts in the background), so a blocked host would not
  have shown up. Check on a machine with a strict default policy.
- Work or school sign-in against a tenant with Conditional Access.

Licensed under Apache-2.0.
