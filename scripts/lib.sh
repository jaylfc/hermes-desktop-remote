#!/usr/bin/env bash
# Shared helpers for hermes-desktop-remote scripts.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load_config() {
  local config_file="${1:-"$ROOT_DIR/remote-desktop.config.env"}"
  if [[ -f "$config_file" ]]; then
    # shellcheck disable=SC1090
    set -a
    # shellcheck disable=SC1090
    source "$config_file"
    set +a
  fi

  : "${HERMES_AGENT_REPO:=https://github.com/NousResearch/hermes-agent.git}"
  : "${HERMES_AGENT_REF:=origin/main}"
  : "${HERMES_WORKDIR:="$ROOT_DIR/work/hermes-agent"}"
  : "${INSTALL_APP_NAME:=Hermes Desktop.app}"
  : "${INSTALL_TO_APPLICATIONS:=1}"
  : "${LAUNCHER_PATH:="$HOME/.local/bin/hermes-desktop"}"
  : "${LAST_INSTALLED_REF_FILE:="$ROOT_DIR/work/last-installed-ref"}"
  : "${UPDATE_INTERVAL_SECONDS:=172800}"
  : "${REMOTE_URL:=}"

  # Expand $HOME in LAUNCHER_PATH if user used that form
  LAUNCHER_PATH="${LAUNCHER_PATH/#\~/$HOME}"
  LAUNCHER_PATH="${LAUNCHER_PATH//\$HOME/$HOME}"
}

resolve_ref_sha() {
  local workdir="$1"
  local ref="$2"
  git -C "$workdir" rev-parse "$ref"
}

find_built_app() {
  local workdir="$1"
  local release="$workdir/apps/desktop/release"
  # Prefer arm64 pack path; fall back to any Hermes.app under release/
  if [[ -d "$release/mac-arm64/Hermes.app" ]]; then
    echo "$release/mac-arm64/Hermes.app"
    return 0
  fi
  if [[ -d "$release/mac/Hermes.app" ]]; then
    echo "$release/mac/Hermes.app"
    return 0
  fi
  local found
  found="$(find "$release" -name 'Hermes.app' -type d 2>/dev/null | head -1 || true)"
  if [[ -n "$found" ]]; then
    echo "$found"
    return 0
  fi
  return 1
}

support_dir() {
  echo "${HOME}/Library/Application Support/Hermes"
}
