#!/usr/bin/env bash
# pre-commit.sh — Dispatcher: chains all pre-commit-*.sh hooks in lexical order.
#
# Install: ln -sf ../../.claude/hooks/pre-commit.sh .git/hooks/pre-commit
#
# Each pre-commit-*.sh is expected to exit 0 on success or non-zero to block.
# The dispatcher exits on the first non-zero exit code.

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for hook in "${HOOK_DIR}"/pre-commit-*.sh; do
  [[ -f "${hook}" ]] || continue
  [[ -x "${hook}" ]] || continue
  bash "${hook}" || exit $?
done

exit 0
