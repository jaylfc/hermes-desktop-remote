#!/usr/bin/env bash
# Install the latest CI-built .app from GitHub Releases (no local compile).
# Wrapper around the root install.sh so repo scripts stay consistent.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$ROOT_DIR/install.sh" "$@"
