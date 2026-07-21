# hermes-desktop-remote

**Just want Hermes Desktop as a remote client?** No local agent. No multi‑GB install.

Prebuilt **macOS Apple Silicon** app, rebuilt from official [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) `main` via GitHub Actions.

> Not affiliated with Nous Research. Official “lite client” is still tracked upstream ([#38602](https://github.com/NousResearch/hermes-agent/issues/38602), [PR #60489](https://github.com/NousResearch/hermes-agent/pull/60489)).

---

## Install (one command)

You need:

1. A remote machine already running Hermes (`hermes serve` / dashboard on a reachable URL, e.g. Tailscale).
2. A Mac with **Apple Silicon**.

```bash
curl -fsSL https://raw.githubusercontent.com/jaylfc/hermes-desktop-remote/main/install.sh \
  | bash -s -- 'http://YOUR-HOST:9119'
```

Examples:

```bash
# Tailscale
curl -fsSL https://raw.githubusercontent.com/jaylfc/hermes-desktop-remote/main/install.sh \
  | bash -s -- 'http://100.x.x.x:9119'

# Interactive (prompts for URL)
curl -fsSL https://raw.githubusercontent.com/jaylfc/hermes-desktop-remote/main/install.sh | bash
```

Then:

1. Open **Hermes Desktop** (Spotlight or Applications).
2. First open: **Right‑click → Open** if macOS Gatekeeper warns (unsigned community build).
3. **Settings → Gateway → Sign in** (username/password or OAuth — whatever your remote uses).

That’s it. Nothing under `~/.hermes` agent runtime is required on this Mac.

[**Download zip from Releases**](https://github.com/jaylfc/hermes-desktop-remote/releases/latest) if you prefer manual install.

---

## Update the Desktop app

Re-run the same install command (keeps your remote URL if you pass it again, or edit Settings):

```bash
curl -fsSL https://raw.githubusercontent.com/jaylfc/hermes-desktop-remote/main/install.sh \
  | bash -s -- 'http://YOUR-HOST:9119'
```

Or download the newest zip from [Releases](https://github.com/jaylfc/hermes-desktop-remote/releases/latest).

**Agent updates** (models, tools, gateway) still happen on the **remote host**:

```bash
# on the server
hermes update
```

---

## What gets installed

| Path | Purpose |
|---|---|
| `/Applications/Hermes Desktop.app` | Electron UI only |
| `~/.local/bin/hermes-desktop` | Launcher (remote-safe env) |
| `~/Library/Application Support/Hermes/connection.json` | `mode: remote` + your URL |

No local Python venv, no agent checkout, no `hermes serve` on the client.

---

## CI / releases

| | |
|---|---|
| Workflow | [`.github/workflows/release-macos.yml`](.github/workflows/release-macos.yml) |
| Runner | `macos-14` (arm64) |
| Trigger | Daily schedule, manual dispatch, or relevant pushes to `main` |
| Artifact | `Hermes-Desktop-mac-arm64.zip` + `build-info.json` |
| Tag | `desktop-upstream-<full-sha>` (skips rebuild if that SHA already released) |

Manual rebuild in GitHub Actions → **Release macOS Desktop** → Run workflow.

---

## Build from source (optional)

Only if you need a custom ref, Intel Mac, or CI isn’t available:

```bash
git clone https://github.com/jaylfc/hermes-desktop-remote.git
cd hermes-desktop-remote
cp templates/remote-desktop.config.env.example remote-desktop.config.env
# set REMOTE_URL=...

./scripts/build.sh
./scripts/install.sh
hermes-desktop
```

| Script | Purpose |
|---|---|
| `install.sh` | **Preferred** — download CI release + configure remote |
| `scripts/build.sh` | Compile Desktop from upstream `main` |
| `scripts/install.sh` | Install a locally built `.app` |
| `scripts/update.sh` | Local rebuild when upstream SHA changes |
| `scripts/install-release.sh` | Same as root `install.sh` |

---

## Config notes

Remote connection lives in:

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

`authMode: "oauth"` is correct for gateways with `auth_required: true` (including **username/password** — Desktop uses cookie sessions).

**Do not** set `HERMES_DESKTOP_REMOTE_URL` without `HERMES_DESKTOP_REMOTE_TOKEN`. URL-only env forces token-auth and breaks password login.

---

## Uninstall

```bash
rm -rf "/Applications/Hermes Desktop.app"
rm -f ~/.local/bin/hermes-desktop
# optional UI state only (does not touch the remote agent):
# rm -rf "$HOME/Library/Application Support/Hermes"
```

---

## Security

- Prefer **Tailscale / VPN**; don’t expose `:9119` to the open internet with password auth.
- Builds are **unsigned** (no Apple Developer ID in this project). Gatekeeper will warn once.
- Never commit passwords or session tokens.

---

## Why latest upstream `main`?

The shell tracks **newest Desktop UI**; the agent stays on your server. See [docs/WHY-MAIN.md](docs/WHY-MAIN.md).

---

## Related

- Official Desktop source: https://github.com/NousResearch/hermes-agent/tree/main/apps/desktop  
- Remote backend docs: https://hermes-agent.nousresearch.com/docs/user-guide/desktop#connecting-to-a-remote-backend  
- SSH-tunnel build kit: https://github.com/KimFischer99/Hermes-Desktop-Remote  

## License

MIT (this repo’s scripts/templates). Upstream Hermes Agent remains MIT under Nous Research.
