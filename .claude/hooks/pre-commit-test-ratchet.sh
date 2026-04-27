#!/usr/bin/env bash
# pre-commit-test-ratchet.sh — STORY-014-04: Pre-existing Test-Failure Ratchet
#
# Invoked by .claude/hooks/pre-commit.sh dispatcher (STORY-014-01).
# Runs test_ratchet.mjs in 'check' mode and blocks commit on regression.
#
# Bypass (discouraged): SKIP_TEST_RATCHET=1
# Timeout: 120s (enough for current cleargate-cli suite ~45s)
#
# macOS compatibility: 'timeout' is GNU coreutils; on macOS use 'gtimeout' (brew coreutils).
# Fallback: if neither is available, run without timeout and print a warning.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${CLEARGATE_REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# ---------------------------------------------------------------------------
# Bypass
# ---------------------------------------------------------------------------
if [[ "${SKIP_TEST_RATCHET:-0}" == "1" ]]; then
  echo "test-ratchet: SKIP_TEST_RATCHET=1 — bypassing test ratchet check (discouraged)" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Resolve timeout binary (GNU on Linux; gtimeout on macOS via brew)
# ---------------------------------------------------------------------------
TIMEOUT_CMD=""
if command -v timeout &>/dev/null; then
  TIMEOUT_CMD="timeout 120"
elif command -v gtimeout &>/dev/null; then
  TIMEOUT_CMD="gtimeout 120"
else
  echo "test-ratchet: WARNING — 'timeout' not found; running without 120s guard" >&2
fi

# ---------------------------------------------------------------------------
# Run ratchet
# ---------------------------------------------------------------------------
RATCHET_SCRIPT="${REPO_ROOT}/.cleargate/scripts/test_ratchet.mjs"

if [[ ! -f "${RATCHET_SCRIPT}" ]]; then
  echo "test-ratchet: ERROR — ratchet script not found at ${RATCHET_SCRIPT}" >&2
  exit 1
fi

export CLEARGATE_REPO_ROOT="${REPO_ROOT}"

${TIMEOUT_CMD} node "${RATCHET_SCRIPT}" check
STATUS=$?

if [[ ${STATUS} -eq 124 ]]; then
  echo "test-ratchet: ERROR — ratchet timed out after 120s; commit blocked" >&2
  exit 1
fi

exit ${STATUS}
