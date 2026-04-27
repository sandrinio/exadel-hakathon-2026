#!/usr/bin/env bash
# pre-commit-surface-gate.sh
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SCRIPT="${REPO_ROOT}/.cleargate/scripts/file_surface_diff.sh"
if [[ ! -f "${SCRIPT}" ]]; then
  echo "[surface-gate] WARNING: file_surface_diff.sh not found — skipping" >&2
  exit 0
fi
exec bash "${SCRIPT}" "$@"
