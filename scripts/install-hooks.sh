#!/usr/bin/env bash
# One-time hook installation. Copies the pre-commit hook into .git/hooks/.
# Run this once after cloning the repo, or after upgrading the script.
#   bash scripts/install-hooks.sh
set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_SRC="$REPO_ROOT/scripts/pre-commit-hook.sh"
HOOK_DST="$REPO_ROOT/.git/hooks/pre-commit"

if [ ! -f "$HOOK_SRC" ]; then
  echo "X $HOOK_SRC not found"
  exit 1
fi

cp "$HOOK_SRC" "$HOOK_DST"
chmod +x "$HOOK_DST"
echo "OK pre-commit hook installed at $HOOK_DST"
