#!/usr/bin/env bash
# Install packaged Desktop + remote connection defaults + launcher.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT_DIR/scripts/lib.sh"
load_config "${1:-"$ROOT_DIR/remote-desktop.config.env"}"

if [[ -z "$REMOTE_URL" ]]; then
  echo "REMOTE_URL is not set. Copy templates/remote-desktop.config.env.example → remote-desktop.config.env" >&2
  exit 1
fi

APP_SRC="$(find_built_app "$HERMES_WORKDIR" 2>/dev/null || true)"
if [[ -z "$APP_SRC" || ! -d "$APP_SRC" ]]; then
  echo "No built Hermes.app found. Run ./scripts/build.sh first." >&2
  exit 1
fi

APP_DST="/Applications/$INSTALL_APP_NAME"

if [[ "$INSTALL_TO_APPLICATIONS" == "1" ]]; then
  echo "Installing $APP_SRC → $APP_DST"
  osascript -e 'tell application id "com.nousresearch.hermes" to quit' >/dev/null 2>&1 || true
  sleep 1
  rm -rf "$APP_DST"
  ditto "$APP_SRC" "$APP_DST"
  xattr -dr com.apple.quarantine "$APP_DST" 2>/dev/null || true
else
  echo "INSTALL_TO_APPLICATIONS!=1; app left at $APP_SRC"
  APP_DST="$APP_SRC"
fi

SUPPORT="$(support_dir)"
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
print("Wrote", p)
PY

mkdir -p "$(dirname "$LAUNCHER_PATH")"
cat > "$LAUNCHER_PATH" <<LAUNCH
#!/bin/zsh
set -euo pipefail
APP="/Applications/${INSTALL_APP_NAME}"
if [[ ! -x "\$APP/Contents/MacOS/Hermes" ]]; then
  echo "Hermes Desktop not found at \$APP — run install.sh" >&2
  exit 1
fi
bid=\$(/usr/bin/defaults read "\$APP/Contents/Info" CFBundleIdentifier 2>/dev/null || true)
if [[ "\$bid" == "com.nousresearch.hermes.setup" ]]; then
  echo "Refusing to launch Hermes Setup installer." >&2
  exit 1
fi
unset HERMES_DESKTOP_REMOTE_URL 2>/dev/null || true
unset HERMES_DESKTOP_REMOTE_TOKEN 2>/dev/null || true
export HERMES_DESKTOP_IGNORE_EXISTING="\${HERMES_DESKTOP_IGNORE_EXISTING:-1}"
exec "\$APP/Contents/MacOS/Hermes" "\$@"
LAUNCH
chmod +x "$LAUNCHER_PATH"

if [[ -f "$ROOT_DIR/work/last-built-ref" ]]; then
  mkdir -p "$(dirname "$LAST_INSTALLED_REF_FILE")"
  cp "$ROOT_DIR/work/last-built-ref" "$LAST_INSTALLED_REF_FILE"
fi

echo
echo "Installed."
echo "  App:      $APP_DST"
echo "  Launcher: $LAUNCHER_PATH"
echo "  Remote:   $REMOTE_URL"
echo
echo "Launch with:  hermes-desktop"
echo "Then: Settings → Gateway → Sign in (if needed)"
