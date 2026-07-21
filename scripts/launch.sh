#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT_DIR/scripts/lib.sh"
load_config "${1:-"$ROOT_DIR/remote-desktop.config.env"}"
if [[ -x "$LAUNCHER_PATH" ]]; then
  exec "$LAUNCHER_PATH"
fi
exec "$ROOT_DIR/scripts/install.sh" "${1:-"$ROOT_DIR/remote-desktop.config.env"}"
