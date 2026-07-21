#!/usr/bin/env bash
# One-liner install for remote-only Hermes Desktop (macOS Apple Silicon).
#
#   curl -fsSL https://raw.githubusercontent.com/jaylfc/hermes-desktop-remote/main/install.sh \
#     | bash -s -- 'http://YOUR-HOST:9119'
#
# Or interactive:
#   curl -fsSL …/install.sh | bash
#
set -euo pipefail

REPO="${HERMES_DESKTOP_REMOTE_REPO:-jaylfc/hermes-desktop-remote}"
APP_NAME="${INSTALL_APP_NAME:-Hermes Desktop.app}"
APP_DST="/Applications/$APP_NAME"
LAUNCHER_PATH="${LAUNCHER_PATH:-$HOME/.local/bin/hermes-desktop}"
ASSET_NAME="Hermes-Desktop-mac-arm64.zip"
TMPDIR_ROOT="${TMPDIR:-/tmp}"
WORKDIR="$(mktemp -d "$TMPDIR_ROOT/hermes-desktop-remote.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

die() { echo "error: $*" >&2; exit 1; }

# --- platform checks ---
[[ "$(uname -s)" == "Darwin" ]] || die "This installer is for macOS only."
ARCH="$(uname -m)"
if [[ "$ARCH" != "arm64" ]]; then
  die "Prebuilt releases are Apple Silicon (arm64) only right now (this machine is $ARCH). Build from source: https://github.com/$REPO"
fi

# --- remote URL ---
REMOTE_URL="${1:-${REMOTE_URL:-}}"
if [[ -z "$REMOTE_URL" ]]; then
  if [[ -t 0 ]]; then
    echo "Hermes Desktop (remote-only client)"
    echo "Enter your remote Hermes gateway URL"
    echo "  example: http://100.x.x.x:9119"
    printf "Remote URL: "
    read -r REMOTE_URL
  else
    die "Pass the remote URL:  bash install.sh 'http://host:9119'"
  fi
fi
REMOTE_URL="$(echo "$REMOTE_URL" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's#/*$##')"
[[ "$REMOTE_URL" == http://* || "$REMOTE_URL" == https://* ]] || die "URL must start with http:// or https://"

echo "→ Remote:  $REMOTE_URL"
echo "→ Repo:    $REPO"
echo "→ Install: $APP_DST"

# --- download latest release asset ---
API="https://api.github.com/repos/${REPO}/releases/latest"
echo "→ Fetching latest release…"
JSON="$(curl -fsSL "$API")" || die "Could not fetch $API — has a release been published yet?"

TAG="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tag_name",""))' <<<"$JSON")"
ASSET_URL="$(python3 -c '
import json,sys
name=sys.argv[1]
rel=json.load(sys.stdin)
for a in rel.get("assets") or []:
    if a.get("name")==name:
        print(a.get("browser_download_url",""))
        break
' "$ASSET_NAME" <<<"$JSON")"

[[ -n "$ASSET_URL" ]] || die "Release $TAG has no asset named $ASSET_NAME. Wait for CI or build from source."

echo "→ Release: $TAG"
echo "→ Download $ASSET_NAME…"
curl -fL --progress-bar -o "$WORKDIR/$ASSET_NAME" "$ASSET_URL"

echo "→ Unzip…"
ditto -x -k "$WORKDIR/$ASSET_NAME" "$WORKDIR/extract"
APP_SRC="$(find "$WORKDIR/extract" -name 'Hermes.app' -type d | head -1 || true)"
[[ -n "$APP_SRC" && -d "$APP_SRC" ]] || die "Zip did not contain Hermes.app"

# --- install app ---
echo "→ Installing app (may ask to quit Hermes)…"
osascript -e 'tell application id "com.nousresearch.hermes" to quit' >/dev/null 2>&1 || true
sleep 1
rm -rf "$APP_DST"
ditto "$APP_SRC" "$APP_DST"
xattr -dr com.apple.quarantine "$APP_DST" 2>/dev/null || true

# --- connection.json (remote only) ---
SUPPORT="$HOME/Library/Application Support/Hermes"
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

# --- launcher ---
mkdir -p "$(dirname "$LAUNCHER_PATH")"
cat > "$LAUNCHER_PATH" <<LAUNCH
#!/bin/zsh
set -euo pipefail
APP="$APP_DST"
if [[ ! -x "\$APP/Contents/MacOS/Hermes" ]]; then
  echo "Hermes Desktop not found at \$APP" >&2
  exit 1
fi
unset HERMES_DESKTOP_REMOTE_URL 2>/dev/null || true
unset HERMES_DESKTOP_REMOTE_TOKEN 2>/dev/null || true
export HERMES_DESKTOP_IGNORE_EXISTING="\${HERMES_DESKTOP_IGNORE_EXISTING:-1}"
exec "\$APP/Contents/MacOS/Hermes" "\$@"
LAUNCH
chmod +x "$LAUNCHER_PATH"

# Ensure ~/.local/bin on PATH hint
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "→ Tip: add \$HOME/.local/bin to your PATH to run: hermes-desktop" ;;
esac

echo
echo "Done."
echo "  App:      $APP_DST"
echo "  Launcher: $LAUNCHER_PATH"
echo "  Remote:   $REMOTE_URL"
echo "  Build:    $TAG"
echo
echo "Next:"
echo "  1. Open Hermes Desktop (Spotlight or: open \"$APP_DST\")"
echo "  2. If macOS blocks it: Right-click app → Open → Open"
echo "  3. Settings → Gateway → Sign in (username/password or OAuth)"
echo
echo "No local Hermes agent was installed. Keep the agent running on your remote host."
