#!/usr/bin/env bash
# test_test_ratchet.sh — STORY-014-04: Test-Failure Ratchet
# Gherkin scenarios from §2.1.
#
# Strategy: uses synthetic fixture JSON files and a mock vitest runner to test
# test_ratchet.mjs logic without running the full cleargate-cli test suite.
#
# Usage: bash .cleargate/scripts/test/test_test_ratchet.sh
# Exit:  0 if all assertions pass, non-zero on first failure

set -euo pipefail

REPO_ROOT="${CLEARGATE_REPO_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
SCRIPT="${REPO_ROOT}/.cleargate/scripts/test_ratchet.mjs"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Setup: create an isolated tmp workspace
# ---------------------------------------------------------------------------
TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

# We will override CLEARGATE_REPO_ROOT and mock vitest JSON by creating a
# wrapper node script that patches test_ratchet.mjs's runSuite() via env.
#
# Approach: test_ratchet.mjs reads CLEARGATE_REPO_ROOT for the baseline path.
# We create fake baseline files in TMPDIR_ROOT and pass synthetic vitest JSON
# via a wrapper that monkey-patches spawnSync via a helper shim.
#
# Simpler alternative: create a thin wrapper script that overrides runSuite()
# by writing a vitest-compatible JSON result file and pointing the script at it.
# Since test_ratchet.mjs spawns vitest directly, we instead create a
# FAKE_VITEST_OUTPUT env var + a small Node shim that replaces `npx vitest`.
#
# Implementation: use CLEARGATE_TEST_VITEST_JSON env to inject a prebuilt JSON
# result directly into test_ratchet.mjs's runSuite() function.
# We patch this via a wrapper mjs that re-exports the functions with mocked spawnSync.

# ---------------------------------------------------------------------------
# Create the patching harness shim
# ---------------------------------------------------------------------------
# Rather than modifying test_ratchet.mjs itself (which must be kept clean),
# we use a thin wrapper script per test scenario that:
# 1. Writes a fake baseline JSON to TMPDIR_ROOT
# 2. Creates a fake vitest result JSON
# 3. Runs test_ratchet.mjs with CLEARGATE_REPO_ROOT pointing to TMPDIR_ROOT
#    and CLEARGATE_TEST_VITEST_JSON pointing to the fake vitest output
#
# test_ratchet.mjs supports CLEARGATE_TEST_VITEST_JSON env to bypass spawnSync
# and use prebuilt JSON (set during testing only).
# NOTE: If test_ratchet.mjs does not support this env yet, tests still verify
# end-to-end behavior via the update-baseline and hook bypass paths.

# ---------------------------------------------------------------------------
# Helper: write a vitest-compatible JSON result
# vitest 2.x top-level keys: numPassedTests, numFailedTests, numTotalTests,
# numPendingTests, numTodoTests, testResults[].assertionResults[]
# ---------------------------------------------------------------------------
write_vitest_json() {
  local dest="$1" total="$2" passed="$3" failed="$4"
  # Build failing_tests from remaining args
  local failing_json="[]"
  if [[ $# -gt 4 ]]; then
    failing_json="["
    local sep=""
    for name in "${@:5}"; do
      failing_json="${failing_json}${sep}{\"status\":\"failed\",\"fullName\":\"${name}\",\"title\":\"${name}\"}"
      sep=","
    done
    failing_json="${failing_json}]"
  fi

  local file_path="/fake/test.ts"
  cat > "${dest}" <<JSONEOF
{
  "numTotalTests": ${total},
  "numPassedTests": ${passed},
  "numFailedTests": ${failed},
  "numPendingTests": 0,
  "numTodoTests": 0,
  "testResults": [
    {
      "testFilePath": "${file_path}",
      "assertionResults": ${failing_json}
    }
  ]
}
JSONEOF
}

write_baseline_json() {
  local dest="$1" total="$2" passed="$3" failed="$4"
  shift 4
  # Remaining args are failing test names
  local failing_json="[]"
  if [[ $# -gt 0 ]]; then
    failing_json="["
    local sep=""
    for name in "$@"; do
      failing_json="${failing_json}${sep}\"${file_path}::${name}\""
      sep=","
    done
    failing_json="${failing_json}]"
  fi
  cat > "${dest}" <<JSONEOF
{
  "total": ${total},
  "passed": ${passed},
  "failed": ${failed},
  "skipped": 0,
  "updated_at": "2026-01-01T00:00:00Z",
  "failing_tests": []
}
JSONEOF
}

# ---------------------------------------------------------------------------
# Scenario 1: Commit allowed when pass-count matches or exceeds baseline
# ---------------------------------------------------------------------------
# Given test-baseline.json records passed=800
# And current suite reports passed=829
# When the ratchet check runs
# Then exit code is 0
# And the delta summary shows "+29 tests passing"

WORK1="${TMPDIR_ROOT}/s1"
mkdir -p "${WORK1}"
# Write baseline: passed=800
cat > "${WORK1}/test-baseline.json" <<'EOF'
{
  "total": 800,
  "passed": 800,
  "failed": 0,
  "skipped": 0,
  "updated_at": "2026-01-01T00:00:00Z",
  "failing_tests": []
}
EOF
# Write vitest JSON: passed=829
write_vitest_json "${WORK1}/vitest-output.json" 829 829 0

OUTPUT=$(CLEARGATE_REPO_ROOT="${WORK1}" CLEARGATE_TEST_VITEST_JSON="${WORK1}/vitest-output.json" node "${SCRIPT}" check 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

if [[ ${EXIT_CODE} -eq 0 ]]; then
  if echo "${OUTPUT}" | grep -q "+29"; then
    pass "Scenario 1: exit 0 and +29 delta shown"
  else
    fail "Scenario 1: exit 0 but delta '+29' not found in output: ${OUTPUT}"
  fi
else
  fail "Scenario 1: expected exit 0, got ${EXIT_CODE}. Output: ${OUTPUT}"
fi

# ---------------------------------------------------------------------------
# Scenario 2: Commit blocked on regression
# ---------------------------------------------------------------------------
# Given test-baseline.json records passed=829
# And current suite reports passed=820
# When the ratchet check runs
# Then exit code is non-zero
# And stderr says "regression: -9 tests"

WORK2="${TMPDIR_ROOT}/s2"
mkdir -p "${WORK2}"
cat > "${WORK2}/test-baseline.json" <<'EOF'
{
  "total": 829,
  "passed": 829,
  "failed": 0,
  "skipped": 0,
  "updated_at": "2026-01-01T00:00:00Z",
  "failing_tests": []
}
EOF
write_vitest_json "${WORK2}/vitest-output.json" 820 820 0

OUTPUT=$(CLEARGATE_REPO_ROOT="${WORK2}" CLEARGATE_TEST_VITEST_JSON="${WORK2}/vitest-output.json" node "${SCRIPT}" check 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

if [[ ${EXIT_CODE} -ne 0 ]]; then
  if echo "${OUTPUT}" | grep -q "regression: -9"; then
    pass "Scenario 2: non-zero exit and regression message shown"
  else
    fail "Scenario 2: non-zero exit but 'regression: -9' not in output: ${OUTPUT}"
  fi
else
  fail "Scenario 2: expected non-zero exit, got 0. Output: ${OUTPUT}"
fi

# ---------------------------------------------------------------------------
# Scenario 3: update-baseline mode overwrites atomically
# ---------------------------------------------------------------------------
# Given an existing test-baseline.json with passed=800
# When update-baseline is run
# Then test-baseline.json is overwritten with current suite count

WORK3="${TMPDIR_ROOT}/s3"
mkdir -p "${WORK3}"
cat > "${WORK3}/test-baseline.json" <<'EOF'
{
  "total": 800,
  "passed": 800,
  "failed": 0,
  "skipped": 0,
  "updated_at": "2026-01-01T00:00:00Z",
  "failing_tests": []
}
EOF
write_vitest_json "${WORK3}/vitest-output.json" 855 855 0

CLEARGATE_REPO_ROOT="${WORK3}" CLEARGATE_TEST_VITEST_JSON="${WORK3}/vitest-output.json" node "${SCRIPT}" update-baseline > /dev/null 2>&1 && EXIT_CODE=0 || EXIT_CODE=$?

if [[ ${EXIT_CODE} -eq 0 ]]; then
  NEW_PASSED=$(node -e "const b=JSON.parse(require('fs').readFileSync('${WORK3}/test-baseline.json','utf8')); process.stdout.write(String(b.passed))")
  if [[ "${NEW_PASSED}" == "855" ]]; then
    pass "Scenario 3: update-baseline overwrote passed=855"
  else
    fail "Scenario 3: expected passed=855 in baseline, got ${NEW_PASSED}"
  fi
else
  fail "Scenario 3: update-baseline exited ${EXIT_CODE}"
fi

# ---------------------------------------------------------------------------
# Scenario 4: list-regressions emits only newly failing tests
# ---------------------------------------------------------------------------
# Given baseline's failing set is {A, B}
# And current failing set is {A, B, C, D}
# When list-regressions runs
# Then stdout lists C and D only (not A, B)

WORK4="${TMPDIR_ROOT}/s4"
mkdir -p "${WORK4}"
cat > "${WORK4}/test-baseline.json" <<'EOF'
{
  "total": 100,
  "passed": 98,
  "failed": 2,
  "skipped": 0,
  "updated_at": "2026-01-01T00:00:00Z",
  "failing_tests": [
    "/fake/test.ts::A",
    "/fake/test.ts::B"
  ]
}
EOF
# Current: A, B still failing + newly C, D
cat > "${WORK4}/vitest-output.json" <<'EOF'
{
  "numTotalTests": 100,
  "numPassedTests": 96,
  "numFailedTests": 4,
  "numPendingTests": 0,
  "numTodoTests": 0,
  "testResults": [
    {
      "testFilePath": "/fake/test.ts",
      "assertionResults": [
        {"status": "failed", "fullName": "A", "title": "A"},
        {"status": "failed", "fullName": "B", "title": "B"},
        {"status": "failed", "fullName": "C", "title": "C"},
        {"status": "failed", "fullName": "D", "title": "D"}
      ]
    }
  ]
}
EOF

OUTPUT=$(CLEARGATE_REPO_ROOT="${WORK4}" CLEARGATE_TEST_VITEST_JSON="${WORK4}/vitest-output.json" node "${SCRIPT}" list-regressions 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

if [[ ${EXIT_CODE} -eq 0 ]]; then
  if echo "${OUTPUT}" | grep -q "C" && echo "${OUTPUT}" | grep -q "D"; then
    if ! echo "${OUTPUT}" | grep -q "newly failing.*A" && ! (echo "${OUTPUT}" | grep -E "^  - /fake/test.ts::A$"); then
      pass "Scenario 4: list-regressions shows C and D, not A and B"
    else
      # A might appear in the output as part of the count or path — check strictly
      # The output line format is "  - /fake/test.ts::C" etc
      NEW_LINES=$(echo "${OUTPUT}" | grep "^  - " || true)
      if echo "${NEW_LINES}" | grep -q "::C" && echo "${NEW_LINES}" | grep -q "::D" && ! echo "${NEW_LINES}" | grep -q "::A" && ! echo "${NEW_LINES}" | grep -q "::B"; then
        pass "Scenario 4: list-regressions shows C and D only"
      else
        fail "Scenario 4: output mismatch. New lines: ${NEW_LINES}"
      fi
    fi
  else
    fail "Scenario 4: C or D not found in output: ${OUTPUT}"
  fi
else
  fail "Scenario 4: list-regressions exited ${EXIT_CODE}"
fi

# ---------------------------------------------------------------------------
# Scenario 5: SKIP_TEST_RATCHET=1 bypass
# ---------------------------------------------------------------------------
# Given SKIP_TEST_RATCHET=1 env is set
# When the pre-commit hook runs
# Then it prints a bypass warning and exits 0 without running tests

# Check pre-commit hook script exists in cleargate-planning
HOOK_SCAFFOLD="${REPO_ROOT}/cleargate-planning/.claude/hooks/pre-commit-test-ratchet.sh"
if [[ ! -f "${HOOK_SCAFFOLD}" ]]; then
  fail "Scenario 5: hook scaffold not found at ${HOOK_SCAFFOLD}"
else
  OUTPUT=$(SKIP_TEST_RATCHET=1 CLEARGATE_REPO_ROOT="${TMPDIR_ROOT}" bash "${HOOK_SCAFFOLD}" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?
  if [[ ${EXIT_CODE} -eq 0 ]]; then
    if echo "${OUTPUT}" | grep -qi "bypass\|SKIP_TEST_RATCHET"; then
      pass "Scenario 5: SKIP_TEST_RATCHET=1 exits 0 with bypass message"
    else
      fail "Scenario 5: exit 0 but no bypass message in output: ${OUTPUT}"
    fi
  else
    fail "Scenario 5: expected exit 0 with SKIP_TEST_RATCHET=1, got ${EXIT_CODE}"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ ${FAIL} -gt 0 ]]; then
  exit 1
fi
exit 0
