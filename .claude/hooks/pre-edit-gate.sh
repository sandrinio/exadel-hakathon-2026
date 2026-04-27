#!/usr/bin/env bash
# pre-edit-gate.sh — CR-008 Phase B: planning-first PreToolUse gate
#
# Registered as a PreToolUse hook for Edit|Write tool calls.
# In warn mode (default), logs would-block decisions but always exits 0.
# In enforce mode, exits 1 to block the tool call when planning is missing.
#
# Mode controlled by CLEARGATE_PLANNING_GATE_MODE (warn|enforce|off). Default: warn.
# Bypass: CLEARGATE_PLANNING_BYPASS=1 → skip check, log bypass=true, exit 0.

set -u

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MODE="${CLEARGATE_PLANNING_GATE_MODE:-warn}"
LOG_FILE="${REPO_ROOT}/.cleargate/hook-log/pre-edit-gate-warn.log"

# ── 0. Off mode — do nothing ──────────────────────────────────────────────────
if [ "${MODE}" = "off" ]; then
  exit 0
fi

# ── 1. Read file path from stdin (PreToolUse JSON payload) ────────────────────
# Claude Code sends JSON on stdin: {"tool_name":"Edit","tool_input":{"file_path":"..."}}
INPUT=$(cat)
FILE=$(printf '%s' "${INPUT}" | node -e "
try {
  var d = require('fs').readFileSync('/dev/stdin','utf8');
  var o = JSON.parse(d);
  var fp = (o.tool_input && o.tool_input.file_path) ? o.tool_input.file_path : '';
  process.stdout.write(fp);
} catch(e) {
  process.stdout.write('');
}
" 2>/dev/null || true)

TOOL_NAME=$(printf '%s' "${INPUT}" | node -e "
try {
  var d = require('fs').readFileSync('/dev/stdin','utf8');
  var o = JSON.parse(d);
  process.stdout.write(o.tool_name || '');
} catch(e) {
  process.stdout.write('');
}
" 2>/dev/null || true)

# ── Guard: if we couldn't parse the file path, fail-open ──────────────────────
if [ -z "${FILE}" ]; then
  exit 0
fi

# ── 2. Bypass env var ─────────────────────────────────────────────────────────
if [ "${CLEARGATE_PLANNING_BYPASS:-0}" = "1" ]; then
  ISO_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
  mkdir -p "$(dirname "${LOG_FILE}")"
  printf '[%s] mode=%s bypass=true file=%s\n' "${ISO_TS}" "${MODE}" "${FILE}" >> "${LOG_FILE}"
  exit 0
fi

# ── 3. Whitelist: always allow these paths ────────────────────────────────────
# Normalise: strip leading REPO_ROOT prefix for matching
REL_FILE="${FILE}"
if [[ "${FILE}" == "${REPO_ROOT}/"* ]]; then
  REL_FILE="${FILE#${REPO_ROOT}/}"
fi

is_whitelisted() {
  local f="$1"
  # Exact or prefix matches for whitelisted directories/files
  case "${f}" in
    .cleargate/*|.claude/*|cleargate-planning/*) return 0 ;;
    CLAUDE.md|MANIFEST.json|README.md|.gitignore|.gitkeep) return 0 ;;
    package.json|package-lock.json) return 0 ;;
    .env|.env.*|.npmrc|.editorconfig) return 0 ;;
    # Also allow absolute paths that fall under the repo's cleargate dirs
  esac
  # Check absolute path variants
  case "${FILE}" in
    "${REPO_ROOT}/.cleargate/"*|"${REPO_ROOT}/.claude/"*|"${REPO_ROOT}/cleargate-planning/"*) return 0 ;;
  esac
  return 1
}

if is_whitelisted "${REL_FILE}"; then
  exit 0
fi

# ── 3.5 Sprint-active sentinel bypass ────────────────────────────────────────
# If a sprint is actively running, all in-sprint edits bypass the gate.
if [ -f "${REPO_ROOT}/.cleargate/sprint-runs/.active" ]; then
  exit 0
fi

# ── 4. Resolve cleargate CLI (three-branch resolver — CR-009) ────────────────
if [ -f "${REPO_ROOT}/cleargate-cli/dist/cli.js" ]; then
  CG=(node "${REPO_ROOT}/cleargate-cli/dist/cli.js")
elif command -v cleargate >/dev/null 2>&1; then
  CG=(cleargate)
else
  # Read pinned version from stamp-and-gate.sh
  HOOK_PIN=""
  HOOK_SH="${REPO_ROOT}/.claude/hooks/stamp-and-gate.sh"
  if [ -f "${HOOK_SH}" ]; then
    HOOK_PIN=$(grep -oP '(?<=# cleargate-pin: )[\S]+' "${HOOK_SH}" 2>/dev/null || \
               grep -oE 'cleargate@[^"]+' "${HOOK_SH}" 2>/dev/null | head -1 | sed 's/.*@//' || true)
  fi
  if [ -z "${HOOK_PIN}" ]; then
    HOOK_PIN="__CLEARGATE_VERSION__"
  fi
  CG=(npx -y "cleargate@${HOOK_PIN}")
fi

# ── 5. Read user prompt snippet for log context (optional; best-effort) ───────
PROMPT_SNIPPET=$(printf '%s' "${INPUT}" | node -e "
try {
  var d = require('fs').readFileSync('/dev/stdin','utf8');
  var o = JSON.parse(d);
  var p = (o.user_prompt || '').slice(0, 200);
  process.stdout.write(p);
} catch(e) {
  process.stdout.write('');
}
" 2>/dev/null || true)

# ── 6. Ask doctor --can-edit ──────────────────────────────────────────────────
# Capture both stdout AND exit code without || true swallowing the exit code.
_DOCTOR_TMPFILE=$(mktemp)
"${CG[@]}" doctor --can-edit "${FILE}" --cwd "${REPO_ROOT}" > "${_DOCTOR_TMPFILE}" 2>/dev/null
DOCTOR_EXIT=$?
DOCTOR_OUT=$(cat "${_DOCTOR_TMPFILE}")
rm -f "${_DOCTOR_TMPFILE}"

# Parse reason from doctor output
REASON=$(printf '%s' "${DOCTOR_OUT}" | grep -oP '(?<=blocked: )\S+' 2>/dev/null || \
         printf '%s' "${DOCTOR_OUT}" | sed -n 's/blocked: //p' 2>/dev/null || \
         echo "unknown")

# Count approved stories in pending-sync (for log entry)
PENDING_DIR="${REPO_ROOT}/.cleargate/delivery/pending-sync"
PENDING_MATCH_COUNT=0
if [ -d "${PENDING_DIR}" ]; then
  PENDING_MATCH_COUNT=$(grep -rl 'approved: true' "${PENDING_DIR}" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
fi

# ── 7. Gate decision ──────────────────────────────────────────────────────────
if [ "${DOCTOR_EXIT}" -ne 0 ]; then
  # Would block
  ISO_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
  mkdir -p "$(dirname "${LOG_FILE}")"
  printf '[%s] mode=%s would_block file=%s reason=%s tool=%s pending_match_count=%d prompt_snippet=%s\n' \
    "${ISO_TS}" "${MODE}" "${FILE}" "${REASON}" "${TOOL_NAME}" "${PENDING_MATCH_COUNT}" "${PROMPT_SNIPPET}" \
    >> "${LOG_FILE}"

  if [ "${MODE}" = "enforce" ]; then
    printf 'ClearGate: planning-first gate — no approved story covers %s (%s). Draft a work item first.\n' \
      "${FILE}" "${REASON}" >&2
    exit 1
  fi

  # warn mode: log written above, exit 0 (do not block)
fi

exit 0
