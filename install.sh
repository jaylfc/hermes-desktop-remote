#!/usr/bin/env bash
# =============================================================================
# Hermes Desktop (remote-only) — zero-friction macOS installer
# =============================================================================
#
# Copy-paste (Apple Silicon):
#
#   curl -fsSL https://raw.githubusercontent.com/jaylfc/hermes-desktop-remote/main/install.sh \
#     | bash -s -- 'http://YOUR-HOST:9119'
#
# What this does for you (no manual Gatekeeper clicks if possible):
#   • Downloads the latest prebuilt Desktop .app from GitHub Releases
#   • Installs to /Applications/Hermes Desktop.app
#   • Strips quarantine + ad-hoc codesigns (unsigned community build)
#   • Writes remote-only connection.json
#   • Installs hermes-desktop + hermes-desktop-update helpers
#   • Enables a LaunchAgent that auto-updates the app from Releases
#   • Opens the app
#
# Update later (same remote URL kept automatically):
#   hermes-desktop-update
#   # or re-run this install.sh
#
# Disable auto-update at install time:
#   SKIP_AUTO_UPDATE=1 curl -fsSL …/install.sh | bash -s -- 'http://host:9119'
#
# =============================================================================
set -euo pipefail

REPO="${HERMES_DESKTOP_REMOTE_REPO:-jaylfc/hermes-desktop-remote}"
APP_NAME="${INSTALL_APP_NAME:-Hermes Desktop.app}"
APP_DST="/Applications/$APP_NAME"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
SHARE_DIR="${SHARE_DIR:-$HOME/.local/share/hermes-desktop-remote}"
LAUNCHER_PATH="$BIN_DIR/hermes-desktop"
UPDATE_PATH="$BIN_DIR/hermes-desktop-update"
VERSION_FILE="$SHARE_DIR/installed-release.txt"
ASSET_NAME="Hermes-Desktop-mac-arm64.zip"
# SKIP_AUTO_UPDATE=1 → do not install/refresh LaunchAgent
INSTALL_AUTO_UPDATE=1
if [[ "${SKIP_AUTO_UPDATE:-0}" == "1" || "${SKIP_AUTO_UPDATE:-}" == "true" ]]; then
  INSTALL_AUTO_UPDATE=0
fi
UPDATE_INTERVAL_SECONDS="${UPDATE_INTERVAL_SECONDS:-86400}" # daily default
OPEN_APP="${OPEN_APP:-1}"

TMPDIR_ROOT="${TMPDIR:-/tmp}"
WORKDIR="$(mktemp -d "$TMPDIR_ROOT/hermes-desktop-remote.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

die() { echo "error: $*" >&2; exit 1; }
log() { echo "→ $*"; }

# --- platform ---
[[ "$(uname -s)" == "Darwin" ]] || die "This installer is for macOS only."
ARCH="$(uname -m)"
if [[ "$ARCH" != "arm64" ]]; then
  die "Prebuilt builds are Apple Silicon (arm64) only (this Mac is $ARCH). See https://github.com/$REPO"
fi

# --- resolve remote URL (arg, env, or existing connection.json) ---
REMOTE_URL="${1:-${REMOTE_URL:-}}"
SUPPORT="$HOME/Library/Application Support/Hermes"
CONN="$SUPPORT/connection.json"

if [[ -z "$REMOTE_URL" && -f "$CONN" ]]; then
  REMOTE_URL="$(python3 -c "
import json
from pathlib import Path
p=Path('''$CONN''')
try:
    d=json.loads(p.read_text())
    print((d.get('remote') or {}).get('url') or '')
except Exception:
    print('')
" 2>/dev/null || true)"
  [[ -n "$REMOTE_URL" ]] && log "Using existing remote URL from connection.json"
fi

if [[ -z "$REMOTE_URL" ]]; then
  if [[ -t 0 ]]; then
    echo "Hermes Desktop — remote-only client"
    echo "Paste your remote gateway URL (example: http://100.x.x.x:9119)"
    printf "Remote URL: "
    read -r REMOTE_URL
  else
    die "Usage: bash install.sh 'http://host:9119'"
  fi
fi

REMOTE_URL="$(printf '%s' "$REMOTE_URL" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's#/*$##')"
[[ "$REMOTE_URL" == http://* || "$REMOTE_URL" == https://* ]] || die "URL must start with http:// or https://"

log "Remote:  $REMOTE_URL"
log "Install: $APP_DST"
log "Repo:    $REPO"

# --- fetch latest release ---
API="https://api.github.com/repos/${REPO}/releases/latest"
log "Fetching latest release…"
JSON="$(curl -fsSL -H "Accept: application/vnd.github+json" "$API")" \
  || die "Could not fetch releases. Has CI published one? https://github.com/$REPO/releases"

TAG="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tag_name") or "")' <<<"$JSON")"
ASSET_URL="$(python3 -c '
import json,sys
name=sys.argv[1]
rel=json.load(sys.stdin)
for a in rel.get("assets") or []:
    if a.get("name")==name:
        print(a.get("browser_download_url") or "")
        break
' "$ASSET_NAME" <<<"$JSON")"
[[ -n "$TAG" && -n "$ASSET_URL" ]] || die "No $ASSET_NAME on release $TAG"

# Skip download if same tag already installed and app exists (still refresh config/helpers)
if [[ -f "$VERSION_FILE" && -x "$APP_DST/Contents/MacOS/Hermes" ]]; then
  CUR="$(tr -d '[:space:]' < "$VERSION_FILE" || true)"
  if [[ "$CUR" == "$TAG" && "${FORCE_REINSTALL:-0}" != "1" ]]; then
    log "Already on $TAG — refreshing config, helpers, and Gatekeeper trust"
    SKIP_DOWNLOAD=1
  fi
fi
SKIP_DOWNLOAD="${SKIP_DOWNLOAD:-0}"

if [[ "$SKIP_DOWNLOAD" != "1" ]]; then
  log "Release: $TAG"
  log "Downloading $ASSET_NAME…"
  curl -fL --progress-bar -o "$WORKDIR/$ASSET_NAME" "$ASSET_URL"
  log "Unzipping…"
  ditto -x -k "$WORKDIR/$ASSET_NAME" "$WORKDIR/extract"
  APP_SRC="$(find "$WORKDIR/extract" -name 'Hermes.app' -type d | head -1 || true)"
  [[ -n "${APP_SRC:-}" && -d "$APP_SRC" ]] || die "Zip missing Hermes.app"

  log "Installing app…"
  osascript -e 'tell application id "com.nousresearch.hermes" to quit' >/dev/null 2>&1 || true
  sleep 1
  # kill stragglers by path without self-matching patterns in this script argv
  # shellcheck disable=SC2009
  ps -axo pid=,command= | while read -r pid cmd; do
    case "$cmd" in
      *"/Applications/Hermes Desktop.app/Contents/MacOS/Hermes"*) kill "$pid" 2>/dev/null || true ;;
    esac
  done
  sleep 1
  rm -rf "$APP_DST"
  ditto "$APP_SRC" "$APP_DST"
else
  log "Keeping existing app binary"
fi

# --- unsigned / Gatekeeper handling (no Right-click needed in normal cases) ---
log "Clearing quarantine + ad-hoc codesign (unsigned community build)…"
# Strip all xattrs that mark the app as "downloaded"
xattr -cr "$APP_DST" 2>/dev/null || true
xattr -dr com.apple.quarantine "$APP_DST" 2>/dev/null || true
# Ad-hoc sign so macOS treats it as a local binary (still not Developer ID)
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DST" 2>/dev/null \
    || codesign --force --sign - "$APP_DST" 2>/dev/null \
    || log "codesign skipped (non-fatal)"
fi
# Ensure executable bits
chmod +x "$APP_DST/Contents/MacOS/Hermes" 2>/dev/null || true

# --- remote connection config (preserve profiles) ---
mkdir -p "$SUPPORT"
export HDR_SUPPORT="$SUPPORT"
export HDR_REMOTE_URL="$REMOTE_URL"
python3 - <<'PY'
import json, os
from pathlib import Path
p = Path(os.environ["HDR_SUPPORT"]) / "connection.json"
url = os.environ["HDR_REMOTE_URL"]
cfg = {"mode": "remote", "remote": {"url": url, "authMode": "oauth"}, "profiles": {}}
if p.exists():
    try:
        old = json.loads(p.read_text())
        if isinstance(old.get("profiles"), dict):
            cfg["profiles"] = old["profiles"]
    except Exception:
        pass
p.write_text(json.dumps(cfg, indent=2) + "\n")
print("→ Wrote", p)
PY

# --- record installed tag ---
mkdir -p "$SHARE_DIR" "$BIN_DIR"
printf '%s\n' "$TAG" > "$VERSION_FILE"

# --- launcher ---
cat > "$LAUNCHER_PATH" <<LAUNCH
#!/bin/zsh
# Hermes Desktop remote-only launcher (installed by hermes-desktop-remote)
set -euo pipefail
APP="$APP_DST"
if [[ ! -x "\$APP/Contents/MacOS/Hermes" ]]; then
  echo "Hermes Desktop not found at \$APP" >&2
  echo "Reinstall: curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | bash" >&2
  exit 1
fi
# Never force token-only env (breaks password/cookie auth)
unset HERMES_DESKTOP_REMOTE_URL 2>/dev/null || true
unset HERMES_DESKTOP_REMOTE_TOKEN 2>/dev/null || true
export HERMES_DESKTOP_IGNORE_EXISTING="\${HERMES_DESKTOP_IGNORE_EXISTING:-1}"
# Refresh trust on each launch (cheap if already clean)
xattr -dr com.apple.quarantine "\$APP" 2>/dev/null || true
exec "\$APP/Contents/MacOS/Hermes" "\$@"
LAUNCH
chmod +x "$LAUNCHER_PATH"

# --- update helper (re-runs install.sh from GitHub; keeps URL from connection.json) ---
cat > "$UPDATE_PATH" <<UPDATE
#!/bin/zsh
# Update Hermes Desktop remote-only client from GitHub Releases.
set -euo pipefail
REPO="${REPO}"
export OPEN_APP="\${OPEN_APP:-0}"
# Don't re-register LaunchAgent on every daily tick
export SKIP_AUTO_UPDATE="\${SKIP_AUTO_UPDATE:-1}"
if [[ -n "\${1:-}" ]]; then
  curl -fsSL "https://raw.githubusercontent.com/\${REPO}/main/install.sh" | bash -s -- "\$1"
else
  # No URL arg → install.sh reuses connection.json
  curl -fsSL "https://raw.githubusercontent.com/\${REPO}/main/install.sh" | bash
fi
UPDATE
chmod +x "$UPDATE_PATH"

# --- auto-update LaunchAgent ---
if [[ "$INSTALL_AUTO_UPDATE" == "1" ]]; then
  PLIST_DIR="$HOME/Library/LaunchAgents"
  PLIST="$PLIST_DIR/com.jaylfc.hermes-desktop-remote.autoupdate.plist"
  mkdir -p "$PLIST_DIR" "$SHARE_DIR/logs"
  LABEL="com.jaylfc.hermes-desktop-remote.autoupdate"
  # XML-escape paths
  UPDATE_XML="$(printf '%s' "$UPDATE_PATH" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"
  LOG_OUT_XML="$(printf '%s' "$SHARE_DIR/logs/autoupdate.out.log" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"
  LOG_ERR_XML="$(printf '%s' "$SHARE_DIR/logs/autoupdate.err.log" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"
  cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${UPDATE_XML}</string>
  </array>
  <key>StartInterval</key>
  <integer>${UPDATE_INTERVAL_SECONDS}</integer>
  <key>RunAtLoad</key>
  <false/>
  <key>StandardOutPath</key>
  <string>${LOG_OUT_XML}</string>
  <key>StandardErrorPath</key>
  <string>${LOG_ERR_XML}</string>
</dict>
</plist>
PLIST
  UID_NUM="$(id -u)"
  launchctl bootout "gui/${UID_NUM}/${LABEL}" 2>/dev/null || true
  if launchctl bootstrap "gui/${UID_NUM}" "$PLIST" 2>/dev/null; then
    log "Auto-update enabled (every ${UPDATE_INTERVAL_SECONDS}s) → $PLIST"
  elif launchctl load "$PLIST" 2>/dev/null; then
    log "Auto-update enabled (legacy load) → $PLIST"
  else
    log "Could not load LaunchAgent (non-fatal). Manual update: hermes-desktop-update"
  fi
else
  log "Skipping auto-update agent (SKIP_AUTO_UPDATE=1)"
fi

# PATH hint
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    log "Add to PATH (once):  export PATH=\"$BIN_DIR:\$PATH\""
    # best-effort append to zshrc if missing
    if [[ -f "$HOME/.zshrc" ]] && ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
      printf '\n# hermes-desktop-remote\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.zshrc"
      log "Appended ~/.local/bin to ~/.zshrc"
    fi
    ;;
esac

# --- open app ---
if [[ "$OPEN_APP" == "1" ]]; then
  log "Opening Hermes Desktop…"
  open "$APP_DST" 2>/dev/null || "$LAUNCHER_PATH" >/dev/null 2>&1 &
fi

echo
echo "============================================================"
echo "  Hermes Desktop (remote-only) is ready"
echo "============================================================"
echo "  App:         $APP_DST"
echo "  Launch:      hermes-desktop   or Spotlight: Hermes Desktop"
echo "  Update now:  hermes-desktop-update"
echo "  Auto-update: $([ "$INSTALL_AUTO_UPDATE" = 1 ] && echo "on (daily)" || echo "off")"
echo "  Remote:      $REMOTE_URL"
echo "  Build:       $TAG"
echo
echo "  Sign in once: Settings → Gateway → Sign in"
echo "  (username/password or OAuth — whatever your remote uses)"
echo
echo "  No local Hermes agent was installed on this Mac."
echo "============================================================"
