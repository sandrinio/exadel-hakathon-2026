#!/usr/bin/env bash
set -u
REPO_ROOT="${CLAUDE_PROJECT_DIR}"
LOG="${REPO_ROOT}/.cleargate/hook-log/gate-check.log"
mkdir -p "$(dirname "$LOG")"

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

FILE=$(jq -r '.tool_input.file_path' 2>/dev/null || echo "")
[ -z "$FILE" ] && exit 0
case "$FILE" in *.cleargate/delivery/*) : ;; *) exit 0 ;; esac
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Ordered chain — stamp MUST precede gate (gate may read draft_tokens)
"${CG[@]}" stamp-tokens "$FILE" >>"$LOG" 2>&1
SR1=$?
"${CG[@]}" gate check "$FILE" >>"$LOG" 2>&1
SR2=$?
"${CG[@]}" wiki ingest "$FILE" >>"$LOG" 2>&1
SR3=$?
echo "[$TS] stamp=$SR1 gate=$SR2 ingest=$SR3 file=$FILE" >>"$LOG"
exit 0   # ALWAYS 0 — severity enforcement is at wiki lint, not hook
