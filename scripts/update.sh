#!/usr/bin/env bash
# Rebuild from latest upstream ref when the SHA changes; reinstall.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT_DIR/scripts/lib.sh"
load_config "${1:-"$ROOT_DIR/remote-desktop.config.env"}"

mkdir -p "$(dirname "$HERMES_WORKDIR")" "$(dirname "$LAST_INSTALLED_REF_FILE")"

if [[ ! -d "$HERMES_WORKDIR/.git" ]]; then
  echo "No worktree yet — building fresh."
  "$ROOT_DIR/scripts/build.sh" "${1:-"$ROOT_DIR/remote-desktop.config.env"}"
  "$ROOT_DIR/scripts/install.sh" "${1:-"$ROOT_DIR/remote-desktop.config.env"}"
  exit 0
fi

git -C "$HERMES_WORKDIR" fetch origin --tags --prune

if ! git -C "$HERMES_WORKDIR" rev-parse --verify "$HERMES_AGENT_REF" >/dev/null 2>&1; then
  echo "Ref not found after fetch: $HERMES_AGENT_REF" >&2
  exit 1
fi

NEW_SHA="$(git -C "$HERMES_WORKDIR" rev-parse "$HERMES_AGENT_REF")"
OLD_SHA=""
if [[ -f "$LAST_INSTALLED_REF_FILE" ]]; then
  OLD_SHA="$(tr -d '[:space:]' < "$LAST_INSTALLED_REF_FILE")"
fi

if [[ "${FORCE_UPDATE:-0}" != "1" && -n "$OLD_SHA" && "$OLD_SHA" == "$NEW_SHA" ]]; then
  APP_DST="/Applications/$INSTALL_APP_NAME"
  if [[ -d "$APP_DST" ]]; then
    echo "Already on $NEW_SHA and app present — nothing to do."
    echo "Set FORCE_UPDATE=1 to rebuild anyway."
    exit 0
  fi
fi

echo "Updating Desktop: ${OLD_SHA:-none} → $NEW_SHA"
"$ROOT_DIR/scripts/build.sh" "${1:-"$ROOT_DIR/remote-desktop.config.env"}"
"$ROOT_DIR/scripts/install.sh" "${1:-"$ROOT_DIR/remote-desktop.config.env"}"
echo "Update complete: $NEW_SHA"
