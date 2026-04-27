#!/usr/bin/env bash
set -u
REPO_ROOT="${CLAUDE_PROJECT_DIR}"

# cleargate-pin: 0.8.1
# Resolve cleargate CLI (three-branch resolver — CR-009):
#   1. meta-repo dogfood dist (fastest; only present in ClearGate's own repo)
#   2. on-PATH binary (global install or shim)
#   3. pinned npx invocation (always works wherever Node is present)
if [ -f "${REPO_ROOT}/cleargate-cli/dist/cli.js" ]; then
  CG=(node "${REPO_ROOT}/cleargate-cli/dist/cli.js")
elif command -v cleargate >/dev/null 2>&1; then
  CG=(cleargate)
else
  CG=(npx -y "cleargate@0.8.1")
fi

"${CG[@]}" doctor --session-start || true

# ── §14.9 SessionStart sync nudge (STORY-010-08) ─────────────────────────────
# Daily-throttled: probe remote for updates at most once per 24h.
# Never auto-pulls or auto-pushes. Exits 0 regardless of outcome.
MARKER="${REPO_ROOT}/.cleargate/.sync-marker.json"
NOW_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
NOW_EPOCH=$(date +%s)

if [ ! -f "${MARKER}" ]; then
  # First run — write marker with current timestamp and skip MCP call (24h grace).
  mkdir -p "$(dirname "${MARKER}")"
  printf '{"last_check":"%s"}' "${NOW_ISO}" > "${MARKER}"
else
  # Parse last_check epoch from marker using node (portable, avoids jq dep)
  LAST_CHECK_ISO=$(node -e "try{const m=JSON.parse(require('fs').readFileSync('${MARKER}','utf8'));process.stdout.write(m.last_check||'1970-01-01T00:00:00Z')}catch{process.stdout.write('1970-01-01T00:00:00Z')}" 2>/dev/null || echo "1970-01-01T00:00:00Z")
  LAST_EPOCH=$(node -e "process.stdout.write(String(Math.floor(new Date('${LAST_CHECK_ISO}').getTime()/1000)))" 2>/dev/null || echo "0")
  ELAPSED=$(( NOW_EPOCH - LAST_EPOCH ))

  if [ "${ELAPSED}" -ge 86400 ]; then
    # ≥24h since last check — run probe (3s timeout, R7 mitigation)
    RESULT_FILE=$(mktemp)
    # Cross-platform 3-second timeout: prefer `timeout` (Linux); fall back to
    # background-process kill (macOS where GNU coreutils may be absent).
    if command -v timeout > /dev/null 2>&1; then
      timeout 3 "${CG[@]}" sync --check > "${RESULT_FILE}" 2>/dev/null || true
    else
      "${CG[@]}" sync --check > "${RESULT_FILE}" 2>/dev/null &
      _PROBE_PID=$!
      (sleep 3 && kill "${_PROBE_PID}" 2>/dev/null) &
      _KILL_PID=$!
      wait "${_PROBE_PID}" 2>/dev/null || true
      kill "${_KILL_PID}" 2>/dev/null || true
      wait "${_KILL_PID}" 2>/dev/null || true
    fi
    UPDATES=$(node -e "
try {
  var data = require('fs').readFileSync(process.argv[1], 'utf8').trim();
  var obj = JSON.parse(data);
  process.stdout.write(String(obj.updates || 0));
} catch(e) {
  process.stdout.write('0');
}
" "${RESULT_FILE}" 2>/dev/null || echo "0")
    rm -f "${RESULT_FILE}"
    if [ "${UPDATES}" -gt 0 ] 2>/dev/null; then
      printf '📡 ClearGate: %s remote updates since yesterday — run `cleargate sync` to reconcile.\n' "${UPDATES}"
    fi
    # Marker is updated by sync --check itself; no re-write needed here.
  fi
fi
exit 0
