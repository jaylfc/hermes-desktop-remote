#!/usr/bin/env bash
# Clone/update hermes-agent and pack the official Desktop app.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT_DIR/scripts/lib.sh"
load_config "${1:-"$ROOT_DIR/remote-desktop.config.env"}"

mkdir -p "$(dirname "$HERMES_WORKDIR")"

if [[ ! -d "$HERMES_WORKDIR/.git" ]]; then
  echo "Cloning $HERMES_AGENT_REPO → $HERMES_WORKDIR"
  git clone "$HERMES_AGENT_REPO" "$HERMES_WORKDIR"
fi

echo "Fetching upstream…"
git -C "$HERMES_WORKDIR" fetch origin --tags --prune

# Resolve branch-style refs (origin/main) after fetch
echo "Checking out $HERMES_AGENT_REF"
if git -C "$HERMES_WORKDIR" rev-parse --verify "$HERMES_AGENT_REF" >/dev/null 2>&1; then
  git -C "$HERMES_WORKDIR" checkout --force -B hdr-build "$HERMES_AGENT_REF"
else
  echo "Ref not found: $HERMES_AGENT_REF" >&2
  exit 1
fi

SHA="$(git -C "$HERMES_WORKDIR" rev-parse HEAD)"
echo "Building Desktop at $SHA"

# Prefer npm ci at monorepo root (workspace links apps/desktop)
(
  cd "$HERMES_WORKDIR"
  if [[ -f package-lock.json ]]; then
    npm ci
  else
    npm install
  fi
)

(
  cd "$HERMES_WORKDIR/apps/desktop"
  # Unpacked dir build (faster than full DMG)
  npm run pack
)

APP="$(find_built_app "$HERMES_WORKDIR")"
echo "Built: $APP"
echo "$SHA" > "$ROOT_DIR/work/last-built-ref"
echo "done"
