#!/usr/bin/env bash
# test_assert_story_files.sh — 4-scenario Gherkin test for STORY-014-02
#
# Tests:
#   Scenario 1: v2 init refuses when stories are missing
#   Scenario 2: v2 init succeeds when all stories exist
#   Scenario 3: v1 init warns but does not block
#   Scenario 4: assert_story_files standalone CLI
#
# Run: bash .cleargate/scripts/test/test_assert_story_files.sh
# Requires Node 24+.
#
# Story IDs must use digit-only parts (STORY-\d+-\d+), e.g. STORY-099-01.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${SCRIPTS_DIR}/../.." && pwd)"

PASS=0
FAIL=0
ERRORS=()

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    echo "        expected: $expected"
    echo "        actual:   $actual"
    FAIL=$((FAIL + 1))
    ERRORS+=("$label")
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (needle not found)"
    echo "        needle:   $needle"
    echo "        haystack: $haystack"
    FAIL=$((FAIL + 1))
    ERRORS+=("$label")
  fi
}

assert_not_exists() {
  local label="$1" filepath="$2"
  if [ ! -e "$filepath" ]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (file exists but should not)"
    echo "        path: $filepath"
    FAIL=$((FAIL + 1))
    ERRORS+=("$label")
  fi
}

assert_exists() {
  local label="$1" filepath="$2"
  if [ -e "$filepath" ]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (file does not exist)"
    echo "        path: $filepath"
    FAIL=$((FAIL + 1))
    ERRORS+=("$label")
  fi
}

# Create a minimal sprint file with given execution_mode
# Story IDs must be STORY-\d+-\d+ (all numeric parts) for the regex to match.
# Usage: make_sprint_file <dir> <sprint-id> <execution_mode> <story-id-1> [<story-id-2> ...]
make_sprint_file() {
  local dir="$1" sprint_id="$2" exec_mode="$3"
  shift 3
  local story_ids=("$@")

  local sprint_file="${dir}/.cleargate/delivery/pending-sync/${sprint_id}_Test_Sprint.md"
  mkdir -p "$(dirname "$sprint_file")"

  {
    echo "---"
    echo "sprint_id: \"${sprint_id}\""
    echo "execution_mode: \"${exec_mode}\""
    echo "approved: true"
    echo "---"
    echo ""
    echo "# ${sprint_id}: Test Sprint"
    echo ""
    echo "## 1. Consolidated Deliverables"
    echo ""
    echo "| Story | Complexity | Milestone |"
    echo "|---|---|---|"
    for sid in "${story_ids[@]}"; do
      echo "| [\`${sid}\`](${sid}_Placeholder.md) Placeholder | L2 | M1 |"
    done
    echo ""
    echo "## 2. Other Section"
    echo ""
    echo "Some content here."
  } > "$sprint_file"

  echo "$sprint_file"
}

# Create a minimal story file in pending-sync/
make_story_file() {
  local dir="$1" story_id="$2"
  local pending_sync="${dir}/.cleargate/delivery/pending-sync"
  mkdir -p "$pending_sync"
  echo "# ${story_id}: Placeholder" > "${pending_sync}/${story_id}_Placeholder.md"
}

# ---------------------------------------------------------------------------
echo ""
echo "=== Scenario 1: v2 init refuses when stories are missing ==="
# ---------------------------------------------------------------------------
TMP1="$(mktemp -d)"
trap 'rm -rf "$TMP1"' EXIT

SPRINT_ID="SPRINT-099"
make_sprint_file "$TMP1" "$SPRINT_ID" "v2" \
  "STORY-099-01" "STORY-099-02" "STORY-099-03" > /dev/null

# Only create STORY-099-01, leave 02 and 03 missing
make_story_file "$TMP1" "STORY-099-01"

STATE_JSON="${TMP1}/.cleargate/sprint-runs/${SPRINT_ID}/state.json"

STDERR_OUT=""
EXIT_CODE=0
STDERR_OUT="$(CLEARGATE_REPO_ROOT="$TMP1" node "$SCRIPTS_DIR/init_sprint.mjs" \
  "$SPRINT_ID" --stories "STORY-099-01,STORY-099-02,STORY-099-03" 2>&1 >/dev/null)" || EXIT_CODE=$?

assert_eq "Sc1: exit code non-zero" "1" "$EXIT_CODE"
assert_contains "Sc1: stderr mentions STORY-099-02" "STORY-099-02" "$STDERR_OUT"
assert_contains "Sc1: stderr mentions STORY-099-03" "STORY-099-03" "$STDERR_OUT"
assert_not_exists "Sc1: state.json NOT created" "$STATE_JSON"

trap - EXIT
rm -rf "$TMP1"

# ---------------------------------------------------------------------------
echo ""
echo "=== Scenario 2: v2 init succeeds when all stories exist ==="
# ---------------------------------------------------------------------------
TMP2="$(mktemp -d)"
trap 'rm -rf "$TMP2"' EXIT

SPRINT_ID="SPRINT-098"
make_sprint_file "$TMP2" "$SPRINT_ID" "v2" \
  "STORY-098-01" "STORY-098-02" "STORY-098-03" > /dev/null

make_story_file "$TMP2" "STORY-098-01"
make_story_file "$TMP2" "STORY-098-02"
make_story_file "$TMP2" "STORY-098-03"

STATE_JSON="${TMP2}/.cleargate/sprint-runs/${SPRINT_ID}/state.json"

EXIT_CODE=0
CLEARGATE_REPO_ROOT="$TMP2" node "$SCRIPTS_DIR/init_sprint.mjs" \
  "$SPRINT_ID" --stories "STORY-098-01,STORY-098-02,STORY-098-03" 2>/dev/null || EXIT_CODE=$?

assert_eq "Sc2: exit code 0" "0" "$EXIT_CODE"
assert_exists "Sc2: state.json created" "$STATE_JSON"

# Verify execution_mode in state.json is v2
if [ -f "$STATE_JSON" ]; then
  EM="$(node -e "const s=JSON.parse(require('fs').readFileSync('$STATE_JSON','utf8')); console.log(s.execution_mode)")"
  assert_eq "Sc2: state.json execution_mode=v2" "v2" "$EM"
fi

trap - EXIT
rm -rf "$TMP2"

# ---------------------------------------------------------------------------
echo ""
echo "=== Scenario 3: v1 init warns but does not block ==="
# ---------------------------------------------------------------------------
TMP3="$(mktemp -d)"
trap 'rm -rf "$TMP3"' EXIT

SPRINT_ID="SPRINT-097"
make_sprint_file "$TMP3" "$SPRINT_ID" "v1" \
  "STORY-097-01" "STORY-097-02" > /dev/null

# Only create STORY-097-01, leave 02 missing
make_story_file "$TMP3" "STORY-097-01"

STATE_JSON="${TMP3}/.cleargate/sprint-runs/${SPRINT_ID}/state.json"

EXIT_CODE=0
STDERR_OUT="$(CLEARGATE_REPO_ROOT="$TMP3" node "$SCRIPTS_DIR/init_sprint.mjs" \
  "$SPRINT_ID" --stories "STORY-097-01,STORY-097-02" 2>&1 >/dev/null)" || EXIT_CODE=$?

assert_eq "Sc3: exit code 0 (v1 warns but continues)" "0" "$EXIT_CODE"
assert_exists "Sc3: state.json created despite missing file" "$STATE_JSON"
assert_contains "Sc3: stderr contains WARN" "WARN" "$STDERR_OUT"
assert_contains "Sc3: stderr mentions STORY-097-02" "STORY-097-02" "$STDERR_OUT"

trap - EXIT
rm -rf "$TMP3"

# ---------------------------------------------------------------------------
echo ""
echo "=== Scenario 4: assert_story_files standalone CLI ==="
# ---------------------------------------------------------------------------
TMP4="$(mktemp -d)"
trap 'rm -rf "$TMP4"' EXIT

SPRINT_ID="SPRINT-096"
SPRINT_FILE="$(make_sprint_file "$TMP4" "$SPRINT_ID" "v2" \
  "STORY-096-01" "STORY-096-02")"

# Only create STORY-096-01, leave 02 missing
make_story_file "$TMP4" "STORY-096-01"

# Run standalone assert_story_files.mjs — should exit 1 with missing list
STDERR_OUT=""
EXIT_CODE=0
STDERR_OUT="$(CLEARGATE_REPO_ROOT="$TMP4" node "$SCRIPTS_DIR/assert_story_files.mjs" \
  "$SPRINT_FILE" 2>&1 >/dev/null)" || EXIT_CODE=$?

assert_eq "Sc4: standalone exits non-zero when missing" "1" "$EXIT_CODE"
assert_contains "Sc4: stderr lists STORY-096-02 as missing" "STORY-096-02" "$STDERR_OUT"

# Now add the missing story file and re-run — should exit 0
make_story_file "$TMP4" "STORY-096-02"

EXIT_CODE=0
STDOUT_OUT="$(CLEARGATE_REPO_ROOT="$TMP4" node "$SCRIPTS_DIR/assert_story_files.mjs" \
  "$SPRINT_FILE" 2>/dev/null)" || EXIT_CODE=$?

assert_eq "Sc4: standalone exits 0 when all present" "0" "$EXIT_CODE"
assert_contains "Sc4: stdout confirms all present" "OK:" "$STDOUT_OUT"

trap - EXIT
rm -rf "$TMP4"

# ---------------------------------------------------------------------------
echo ""
echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "Failing scenarios:"
  for e in "${ERRORS[@]}"; do
    echo "  - $e"
  done
  exit 1
fi
echo "All tests passed."
exit 0
