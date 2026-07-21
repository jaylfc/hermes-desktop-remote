# hermes-desktop-remote

Hermes Desktop as a **remote-only client** — no local agent, one terminal command.

Prebuilt **macOS Apple Silicon** app from official [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) `main`, published by this repo’s CI.

> Not affiliated with Nous Research.

---

## Install (copy & paste)

You need a Mac (**Apple Silicon**) and a remote Hermes already running (`hermes serve` reachable, e.g. over Tailscale).

```bash
curl -fsSL https://raw.githubusercontent.com/jaylfc/hermes-desktop-remote/main/install.sh \
  | bash -s -- 'http://YOUR-HOST:9119'
```

That single command:

| Step | Handled for you |
|---|---|
| Download latest `.app` from Releases | yes |
| Install to `/Applications/Hermes Desktop.app` | yes |
| Clear quarantine + ad-hoc codesign (unsigned build) | yes |
| Write remote-only `connection.json` | yes |
| Install `hermes-desktop` launcher | yes |
| Enable **daily auto-update** (LaunchAgent) | yes |
| Open the app | yes |

Then once: **Settings → Gateway → Sign in** (username/password or OAuth).

No Right‑click → Open dance in normal cases. No local Python/agent install.

---

## Commands after install

```bash
hermes-desktop          # open the app
hermes-desktop-update   # check GitHub Releases and update the app now
```

Auto-update runs **daily** in the background (same install path; keeps your remote URL).

```bash
# Disable auto-update at install time
SKIP_AUTO_UPDATE=1 curl -fsSL …/install.sh | bash -s -- 'http://host:9119'

# Force re-download of the same release tag
FORCE_REINSTALL=1 hermes-desktop-update
```

---

## Update the agent (remote machine only)

Desktop updates ≠ agent updates.

```bash
# on the server that runs Hermes
hermes update
```

---

## What gets installed

| Path | Purpose |
|---|---|
| `/Applications/Hermes Desktop.app` | Electron UI |
| `~/.local/bin/hermes-desktop` | Launcher |
| `~/.local/bin/hermes-desktop-update` | Update from Releases |
| `~/Library/LaunchAgents/com.jaylfc.hermes-desktop-remote.autoupdate.plist` | Daily auto-update |
| `~/Library/Application Support/Hermes/connection.json` | `mode: remote` + URL |
| `~/.local/share/hermes-desktop-remote/` | Installed release tag + logs |

---

## Uninstall

```bash
# stop auto-update
launchctl bootout "gui/$(id -u)/com.jaylfc.hermes-desktop-remote.autoupdate" 2>/dev/null || true
rm -f ~/Library/LaunchAgents/com.jaylfc.hermes-desktop-remote.autoupdate.plist

rm -rf "/Applications/Hermes Desktop.app"
rm -f ~/.local/bin/hermes-desktop ~/.local/bin/hermes-desktop-update
rm -rf ~/.local/share/hermes-desktop-remote
# optional UI state only (does not touch remote agent):
# rm -rf "$HOME/Library/Application Support/Hermes"
```

---

## Releases / CI

- Workflow: [`.github/workflows/release-macos.yml`](.github/workflows/release-macos.yml)
- Daily rebuild from upstream `main` when the SHA changes
- Asset: `Hermes-Desktop-mac-arm64.zip`
- [Latest release](https://github.com/jaylfc/hermes-desktop-remote/releases/latest)

**Note:** Builds are **unsigned** (no Apple Developer ID). The installer ad-hoc codesigns and strips quarantine so Gatekeeper usually stays quiet. Corporate MDM policies may still block it.

---

## Security

- Prefer Tailscale/VPN; don’t expose password-gated `:9119` to the public internet.
- Never commit tokens/passwords into this repo.

---

## Advanced / build from source

```bash
git clone https://github.com/jaylfc/hermes-desktop-remote.git
cd hermes-desktop-remote
cp templates/remote-desktop.config.env.example remote-desktop.config.env
# set REMOTE_URL=...
./scripts/build.sh && ./scripts/install.sh
```

See [docs/WHY-MAIN.md](docs/WHY-MAIN.md).

## License

MIT (this repo). Upstream Hermes Agent remains MIT under Nous Research.
