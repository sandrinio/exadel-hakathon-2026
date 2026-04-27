#!/usr/bin/env bash
# run_script.sh — Wrapper that captures stdout/stderr separately and prints a
# structured diagnostic block on non-zero exit.
# Usage: run_script.sh <script-name> [args...]
# Supported extensions: .mjs (runs via node), .sh (runs via bash)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Usage guard
# ---------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "Usage: run_script.sh <script-name> [args...]" >&2
  exit 2
fi

SCRIPT_NAME="$1"
shift
SCRIPT_ARGS=()
if [[ $# -gt 0 ]]; then
  SCRIPT_ARGS=("$@")
fi

# ---------------------------------------------------------------------------
# Resolve path — script may be an absolute path or relative to SCRIPT_DIR
# ---------------------------------------------------------------------------
if [[ "$SCRIPT_NAME" == /* ]]; then
  SCRIPT_PATH="$SCRIPT_NAME"
else
  SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"
fi

# ---------------------------------------------------------------------------
# Extension routing
# ---------------------------------------------------------------------------
EXT="${SCRIPT_NAME##*.}"
case "$EXT" in
  mjs)  RUNNER="node" ;;
  sh)   RUNNER="bash" ;;
  *)
    echo "unsupported extension: .${EXT}" >&2
    exit 2
    ;;
esac

# ---------------------------------------------------------------------------
# Check script exists
# ---------------------------------------------------------------------------
if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "run_script.sh: script not found: ${SCRIPT_PATH}" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Capture stdout + stderr to temp files
# ---------------------------------------------------------------------------
STDOUT_FILE="$(mktemp)"
STDERR_FILE="$(mktemp)"
trap 'rm -f "$STDOUT_FILE" "$STDERR_FILE"' EXIT

EXIT_CODE=0
if [[ ${#SCRIPT_ARGS[@]} -gt 0 ]]; then
  "$RUNNER" "$SCRIPT_PATH" "${SCRIPT_ARGS[@]}" > "$STDOUT_FILE" 2> "$STDERR_FILE" || EXIT_CODE=$?
else
  "$RUNNER" "$SCRIPT_PATH" > "$STDOUT_FILE" 2> "$STDERR_FILE" || EXIT_CODE=$?
fi

# ---------------------------------------------------------------------------
# On success: pass through and exit 0
# ---------------------------------------------------------------------------
if [[ $EXIT_CODE -eq 0 ]]; then
  cat "$STDOUT_FILE"
  cat "$STDERR_FILE" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# On failure: pass stdout through, then print structured diagnostic to stderr
# ---------------------------------------------------------------------------
cat "$STDOUT_FILE"

# Root-cause heuristic (6-branch)
STDERR_CONTENT="$(cat "$STDERR_FILE")"
ROOT_CAUSE="unknown error"
SUGGESTED_FIX="check the script output above for details"

if echo "$STDERR_CONTENT" | grep -q "state\.json not found"; then
  ROOT_CAUSE="state.json not found — sprint may not be initialized"
  SUGGESTED_FIX="run: node .cleargate/scripts/init_sprint.mjs <sprint-id> --stories <ids>"
elif echo "$STDERR_CONTENT" | grep -qi "ENOENT"; then
  ROOT_CAUSE="missing file (ENOENT)"
  SUGGESTED_FIX="verify all required files exist at the expected paths"
elif echo "$STDERR_CONTENT" | grep -qi "EACCES"; then
  ROOT_CAUSE="permission denied (EACCES)"
  SUGGESTED_FIX="chmod 755 the target file or directory"
elif echo "$STDERR_CONTENT" | grep -qi "SyntaxError"; then
  ROOT_CAUSE="JavaScript syntax error"
  SUGGESTED_FIX="fix the syntax error in the script; run: node --check <file>"
elif echo "$STDERR_CONTENT" | grep -qi "Cannot find module"; then
  ROOT_CAUSE="missing module (import resolution failure)"
  SUGGESTED_FIX="run npm install in the relevant package directory"
elif echo "$STDERR_CONTENT" | grep -qi "command not found"; then
  ROOT_CAUSE="required command not found on PATH"
  SUGGESTED_FIX="install the missing tool or add it to PATH"
fi

{
  echo ""
  echo "## Script Incident"
  echo "Script:     ${SCRIPT_NAME}"
  echo "Runner:     ${RUNNER}"
  echo "Exit code:  ${EXIT_CODE}"
  echo ""
  echo "### First 10 lines of stderr:"
  echo "$STDERR_CONTENT" | head -10
  echo ""
  echo "Root cause: ${ROOT_CAUSE}"
  echo "Suggested fix: ${SUGGESTED_FIX}"
  echo "## End Incident"
} >&2

exit $EXIT_CODE
