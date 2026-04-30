#!/usr/bin/env bash
# Source for .git/hooks/pre-commit. Calls scripts/check-integrity.sh so the
# local hook and the GitHub Action share one source of truth.
set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$REPO_ROOT/scripts/check-integrity.sh"

if [ -f "$SCRIPT" ]; then
  chmod +x "$SCRIPT" 2>/dev/null || true
  "$SCRIPT" "$REPO_ROOT/index.html"
else
  echo "X pre-commit: scripts/check-integrity.sh not found"
  exit 1
fi
