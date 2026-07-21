#!/usr/bin/env bash
# Periodic update check via launchd.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT_DIR/scripts/lib.sh"
load_config "${1:-"$ROOT_DIR/remote-desktop.config.env"}"

if [[ ! "$UPDATE_INTERVAL_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "Invalid UPDATE_INTERVAL_SECONDS" >&2
  exit 1
fi

CONFIG_ABS="$ROOT_DIR/remote-desktop.config.env"
if [[ ! -f "$CONFIG_ABS" ]]; then
  echo "Create remote-desktop.config.env first." >&2
  exit 1
fi

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  printf '%s' "$value"
}

PLIST="$HOME/Library/LaunchAgents/com.jaylfc.hermes-desktop-remote.update.plist"
mkdir -p "$(dirname "$PLIST")" "$ROOT_DIR/work"

ROOT_XML="$(xml_escape "$ROOT_DIR")"
CFG_XML="$(xml_escape "$CONFIG_ABS")"

cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.jaylfc.hermes-desktop-remote.update</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${ROOT_XML}/scripts/update.sh</string>
    <string>${CFG_XML}</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${ROOT_XML}</string>
  <key>StartInterval</key>
  <integer>${UPDATE_INTERVAL_SECONDS}</integer>
  <key>RunAtLoad</key>
  <false/>
  <key>StandardOutPath</key>
  <string>${ROOT_XML}/work/autoupdate.out.log</string>
  <key>StandardErrorPath</key>
  <string>${ROOT_XML}/work/autoupdate.err.log</string>
</dict>
</plist>
PL

launchctl bootout "gui/$(id -u)/com.jaylfc.hermes-desktop-remote.update" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || launchctl load "$PLIST"
echo "Installed LaunchAgent: $PLIST"
echo "Interval: ${UPDATE_INTERVAL_SECONDS}s"
echo "Logs: $ROOT_DIR/work/autoupdate.*.log"
