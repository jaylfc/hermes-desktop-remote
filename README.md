# hermes-desktop-remote

**Remote-only Hermes Desktop client** for macOS (and buildable elsewhere).

This is a thin ops repo: scripts + templates. It does **not** vendor [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent). It builds the official Desktop app from **latest upstream `main`**, installs it as a standalone GUI, and keeps you on a **remote gateway** (no local Hermes agent required on the client machine).

Inspired by [KimFischer99/Hermes-Desktop-Remote](https://github.com/KimFischer99/Hermes-Desktop-Remote) (SSH-forward approach). This project targets **direct remote URLs** (Tailscale / LAN / VPN) instead of mandatory SSH tunnels.

> Not affiliated with Nous Research. Official lite-client support is still open upstream ([#38602](https://github.com/NousResearch/hermes-agent/issues/38602), [PR #60489](https://github.com/NousResearch/hermes-agent/pull/60489)).

## Why track latest upstream `main`?

| Strategy | Pros | Cons |
|---|---|---|
| **Latest `main` (this repo)** | Newest Desktop UI; simple; one branch | Remote agent can lag slightly behind the GUI |
| Pin Desktop to remote agent commit | Max protocol alignment | Rebuild only when remote updates; miss pure-UI fixes |

**Recommendation:** track **`main`** for the shell, and keep the remote host on a reasonably current Hermes (`hermes update` there). Gateway APIs are usually backward-compatible across nearby versions. If you ever hit a hard protocol break, pin `HERMES_AGENT_REF` to a known-good commit until the remote is updated.

## What this gives you

- Standalone `/Applications/Hermes Desktop.app` (Electron shell only on the client)
- Default **remote** connection config (no local `hermes serve`)
- `hermes-desktop` launcher that refuses the Setup installer and avoids token-only env traps
- `update` script that rebuilds when upstream `main` moves
- Optional LaunchAgent for periodic checks

## Requirements (build machine)

- macOS Apple Silicon recommended for `mac-arm64` packs (this repo’s default)
- Node.js 20+ (Homebrew is fine)
- git, network access to GitHub
- Disk for a temporary hermes-agent worktree (~2–4 GB while building)

**You do not need** a permanent local Hermes agent install for day-to-day use.

## Quick start

```bash
git clone https://github.com/jaylfc/hermes-desktop-remote.git
cd hermes-desktop-remote

cp templates/remote-desktop.config.env.example remote-desktop.config.env
# edit REMOTE_URL (and optional auth notes)

./scripts/build.sh
./scripts/install.sh
hermes-desktop
```

On first useful launch, open **Settings → Gateway**, confirm **Remote**, and **Sign in** (username/password or OAuth — whatever the remote advertises).

## Config

### `remote-desktop.config.env` (gitignored)

See `templates/remote-desktop.config.env.example`.

| Variable | Meaning |
|---|---|
| `REMOTE_URL` | e.g. `http://100.x.x.x:9119` (Tailscale / LAN) |
| `HERMES_AGENT_REF` | default `origin/main` |
| `INSTALL_APP_NAME` | default `Hermes Desktop.app` |
| `HERMES_WORKDIR` | clone path for builds (default `./work/hermes-agent`) |

### Desktop connection (runtime)

Install writes:

`~/Library/Application Support/Hermes/connection.json`

```json
{
  "mode": "remote",
  "remote": {
    "url": "http://YOUR-HOST:9119",
    "authMode": "oauth"
  },
  "profiles": {}
}
```

`authMode: "oauth"` is correct for gateways with `auth_required: true` (including the **username/password** provider — Desktop uses cookie sessions).

**Do not** set `HERMES_DESKTOP_REMOTE_URL` without `HERMES_DESKTOP_REMOTE_TOKEN`. URL-only env forces token-auth and breaks password/cookie login.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/build.sh` | Fetch upstream ref, install deps, `npm run pack` in `apps/desktop` |
| `scripts/install.sh` | Install `.app` to `/Applications`, seed connection.json, install launcher |
| `scripts/update.sh` | Rebuild + reinstall if upstream SHA changed |
| `scripts/launch.sh` | Same as `hermes-desktop` |
| `scripts/install-launchagent.sh` | Optional periodic `update.sh` |

## Updates

```bash
./scripts/update.sh
```

Or install the LaunchAgent (default every 48h):

```bash
./scripts/install-launchagent.sh
```

**Agent updates** still happen on the **remote host** (`hermes update` there). This repo only refreshes the client GUI.

## Uninstall client

```bash
rm -rf "/Applications/Hermes Desktop.app"
rm -f ~/.local/bin/hermes-desktop
# optional: wipe UI state (keeps nothing remote-side)
# rm -rf "~/Library/Application Support/Hermes"
```

Do **not** run Hermes Setup on the client unless you intentionally want a full local agent again.

## Security notes

- Prefer Tailscale / VPN over exposing `:9119` to the public internet.
- Username/password backends are for trusted networks; see official dashboard auth docs.
- Never commit real passwords or session tokens to this repo.

## Related

- Official Desktop: https://github.com/NousResearch/hermes-agent/tree/main/apps/desktop
- Docs (remote backend): https://hermes-agent.nousresearch.com/docs/user-guide/desktop#connecting-to-a-remote-backend
- SSH-tunnel variant: https://github.com/KimFischer99/Hermes-Desktop-Remote

## License

MIT (scripts/templates in this repo). Upstream Hermes Agent remains under its own license (MIT).
