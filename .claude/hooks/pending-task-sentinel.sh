#!/usr/bin/env bash
# PreToolUse hook for Task (Agent subagent dispatch).
#
# Purpose: when the orchestrator spawns a subagent via the Task tool, record the
# dispatch metadata (agent_type, work_item_id, turn_index) into a sentinel file
# under the active sprint dir. The SubagentStop hook reads the newest sentinel
# to attribute the token-ledger row correctly.
#
# Why: SubagentStop fires on the ORCHESTRATOR's session with the orchestrator's
# transcript_path. Without a sentinel, the hook can only grep the full
# transcript and every row tags against the orchestrator — per-story cost is
# uncomputable. The sentinel provides (a) ground-truth agent_type and
# work_item_id, and (b) a turn_index pivot so the post-hook can compute the
# delta instead of the cumulative sum.
#
# Input: JSON on stdin from Claude Code with fields:
#   session_id, transcript_path, cwd, hook_event_name, tool_name, tool_input
# For tool_name == "Task", tool_input has: subagent_type, description, prompt.
#
# Output: writes .cleargate/sprint-runs/<sprint-id>/.pending-task-<turn_index>.json
#         with { agent_type, work_item_id, turn_index, started_at }
#
# Robustness: under v1 never blocks the tool call (exit 0 always). Under v2,
# exits non-zero to block Task spawn when unprocessed flashcards exist.
# Set SKIP_FLASHCARD_GATE=1 to bypass the flashcard gate in both modes.

set -u

REPO_ROOT="${ORCHESTRATOR_PROJECT_DIR:-${CLAUDE_PROJECT_DIR}}"
LOG_DIR="${REPO_ROOT}/.cleargate/hook-log"
mkdir -p "${LOG_DIR}"
HOOK_LOG="${LOG_DIR}/pending-task-sentinel.log"
ACTIVE_SENTINEL="${REPO_ROOT}/.cleargate/sprint-runs/.active"

# Read stdin once — must happen before the grouped block
INPUT="$(cat)"

# Determine active sprint (needed for flashcard gate and sentinel)
SPRINT_ID=""
if [[ -f "${ACTIVE_SENTINEL}" ]]; then
  SPRINT_ID="$(tr -d '[:space:]' < "${ACTIVE_SENTINEL}")"
fi
[[ -z "${SPRINT_ID}" ]] && SPRINT_ID="_off-sprint"
SPRINT_DIR="${REPO_ROOT}/.cleargate/sprint-runs/${SPRINT_ID}"
mkdir -p "${SPRINT_DIR}"

# --- Flashcard gate (STORY-014-03) ---
# Runs BEFORE the logged block so stderr goes to real process stderr (not log),
# allowing Claude Code to surface the message to the orchestrator.
# Bypass: set SKIP_FLASHCARD_GATE=1 in environment.
TOOL_NAME_EARLY="$(printf '%s' "${INPUT}" | jq -r '.tool_name // empty')"

if [[ "${TOOL_NAME_EARLY}" == "Task" && "${SKIP_FLASHCARD_GATE:-0}" != "1" && "${SPRINT_ID}" != "_off-sprint" ]]; then
  # Read execution_mode from state.json
  EXEC_MODE="v1"
  if [[ -f "${SPRINT_DIR}/state.json" ]]; then
    EXEC_MODE="$(jq -r '.execution_mode // "v1"' "${SPRINT_DIR}/state.json" 2>/dev/null)"
    [[ -z "${EXEC_MODE}" || "${EXEC_MODE}" == "null" ]] && EXEC_MODE="v1"
  fi

  # Collect flagged cards from all STORY-*-dev.md and STORY-*-qa.md in SPRINT_DIR (flat layout).
  UNPROCESSED_CARDS=()
  UNPROCESSED_HASHES=()

  # Use ls -t (portable) to process report files; portable array accumulation (bash 3.2 safe).
  REPORT_FILES=()
  while IFS= read -r f; do
    REPORT_FILES+=("$f")
  done < <(ls -t "${SPRINT_DIR}"/STORY-*-dev.md "${SPRINT_DIR}"/STORY-*-qa.md 2>/dev/null)

  for REPORT_FILE in "${REPORT_FILES[@]}"; do
    [[ ! -f "${REPORT_FILE}" ]] && continue
    # Parse flashcards_flagged list. Handles two formats:
    #   YAML key (frontmatter):          Markdown section heading:
    #   flashcards_flagged: []           ## flashcards_flagged
    #   flashcards_flagged:
    #   - "card text"                    - "card text"
    #   - bare card text                 - bare card text
    IN_BLOCK=0
    BLOCK_TYPE=""  # "yaml" or "md"
    while IFS= read -r line; do
      # YAML inline empty list — no cards in this format
      if [[ "${line}" =~ ^flashcards_flagged:[[:space:]]*\[\] ]]; then
        break
      fi
      # YAML key (block form) — matches "flashcards_flagged:" or "flashcards_flagged: " with nothing after
      if [[ "${line}" =~ ^flashcards_flagged:[[:space:]]*$ ]]; then
        IN_BLOCK=1
        BLOCK_TYPE="yaml"
        continue
      fi
      # Markdown section heading (## flashcards_flagged or ## Flashcards_flagged)
      if [[ "${line}" =~ ^##[[:space:]]+[Ff]lashcards_flagged ]]; then
        IN_BLOCK=1
        BLOCK_TYPE="md"
        continue
      fi

      if [[ "${IN_BLOCK}" == "1" ]]; then
        # Stop conditions differ by block type
        if [[ "${BLOCK_TYPE}" == "yaml" ]]; then
          # Stop at next top-level YAML key (non-indented, non-list, non-blank line)
          if [[ "${line}" =~ ^[a-zA-Z_] ]]; then
            break
          fi
        elif [[ "${BLOCK_TYPE}" == "md" ]]; then
          # Stop at next markdown heading (any level)
          if [[ "${line}" =~ ^# ]]; then
            break
          fi
        fi
        # Match list items: "- ..." (leading whitespace allowed)
        if [[ "${line}" =~ ^[[:space:]]*-[[:space:]]+(.*) ]]; then
          CARD="${BASH_REMATCH[1]}"
          # Strip surrounding quotes (double or single)
          CARD="${CARD#\"}"
          CARD="${CARD%\"}"
          CARD="${CARD#\'}"
          CARD="${CARD%\'}"
          [[ -z "${CARD}" ]] && continue
          # Compute SHA-1, first 12 chars (portable: shasum -a 1 per flashcard #bash #macos)
          HASH="$(printf '%s' "${CARD}" | shasum -a 1 | cut -c1-12)"
          MARKER="${SPRINT_DIR}/.processed-${HASH}"
          if [[ ! -f "${MARKER}" ]]; then
            UNPROCESSED_CARDS+=("${CARD}")
            UNPROCESSED_HASHES+=("${HASH}")
          fi
        fi
      fi
    done < "${REPORT_FILE}"
  done

  if [[ "${#UNPROCESSED_CARDS[@]}" -gt 0 ]]; then
    printf '[%s] flashcard-gate: %d unprocessed card(s) found (mode=%s)\n' \
      "$(date -u +%FT%TZ)" "${#UNPROCESSED_CARDS[@]}" "${EXEC_MODE}" >> "${HOOK_LOG}"
    if [[ "${EXEC_MODE}" == "v2" ]]; then
      # Block Task spawn — exit 1 with diagnostic on stderr (real stderr, not log)
      printf 'FLASHCARD GATE BLOCKED: %d unprocessed flashcard(s) must be processed before spawning next Task.\n' \
        "${#UNPROCESSED_CARDS[@]}" >&2
      for i in "${!UNPROCESSED_CARDS[@]}"; do
        CARD="${UNPROCESSED_CARDS[$i]}"
        HASH="${UNPROCESSED_HASHES[$i]}"
        printf '  card: %s\n' "${CARD}" >&2
        printf '  mark processed: touch %s/.processed-%s\n' "${SPRINT_DIR}" "${HASH}" >&2
      done
      exit 1
    else
      # v1: advisory warning only, continue to sentinel write
      printf 'FLASHCARD GATE WARNING (v1 advisory): %d unprocessed flashcard(s).\n' \
        "${#UNPROCESSED_CARDS[@]}" >&2
      for i in "${!UNPROCESSED_CARDS[@]}"; do
        CARD="${UNPROCESSED_CARDS[$i]}"
        HASH="${UNPROCESSED_HASHES[$i]}"
        printf '  card: %s\n' "${CARD}" >&2
        printf '  mark processed: touch %s/.processed-%s\n' "${SPRINT_DIR}" "${HASH}" >&2
      done
    fi
  fi
fi
# --- End flashcard gate ---

{
  TOOL_NAME="$(printf '%s' "${INPUT}" | jq -r '.tool_name // empty')"
  if [[ "${TOOL_NAME}" != "Task" ]]; then
    # Not a subagent dispatch — no sentinel needed.
    exit 0
  fi

  TRANSCRIPT_PATH="$(printf '%s' "${INPUT}" | jq -r '.transcript_path // empty')"
  AGENT_TYPE="$(printf '%s' "${INPUT}" | jq -r '.tool_input.subagent_type // "unknown"')"
  PROMPT="$(printf '%s' "${INPUT}" | jq -r '.tool_input.prompt // empty')"

  # Extract work_item_id from prompt — by convention first line is STORY=NNN-NN
  # or an inline PROPOSAL-NNN / EPIC-NNN / CR-NNN / BUG-NNN reference.
  WORK_ITEM_ID="$(printf '%s' "${PROMPT}" | grep -oE '(STORY|PROPOSAL|EPIC|CR|BUG)[-=]?[0-9]+(-[0-9]+)?' | head -1 | sed 's/=/-/g')"
  [[ -z "${WORK_ITEM_ID}" ]] && WORK_ITEM_ID=""

  # Compute turn_index: count of assistant turns in the orchestrator transcript so far.
  TURN_INDEX=0
  if [[ -n "${TRANSCRIPT_PATH}" && -f "${TRANSCRIPT_PATH}" ]]; then
    TURN_INDEX="$(jq -cs '[.[] | select(.type == "assistant" and .message.usage)] | length' "${TRANSCRIPT_PATH}" 2>/dev/null)"
    [[ -z "${TURN_INDEX}" || "${TURN_INDEX}" == "null" ]] && TURN_INDEX=0
  fi

  STARTED_AT="$(date -u +%FT%TZ)"
  SENTINEL_FILE="${SPRINT_DIR}/.pending-task-${TURN_INDEX}.json"

  # Write the sentinel atomically (tmp + mv).
  TMP="${SENTINEL_FILE}.tmp.$$"
  jq -cn \
    --arg agent "${AGENT_TYPE}" \
    --arg work_item "${WORK_ITEM_ID}" \
    --argjson idx "${TURN_INDEX}" \
    --arg started "${STARTED_AT}" \
    '{agent_type: $agent, work_item_id: $work_item, turn_index: $idx, started_at: $started}' \
    > "${TMP}" 2>/dev/null \
    && mv "${TMP}" "${SENTINEL_FILE}" \
    && printf '[%s] wrote sentinel sprint=%s agent=%s work_item=%s turn=%s\n' \
        "${STARTED_AT}" "${SPRINT_ID}" "${AGENT_TYPE}" "${WORK_ITEM_ID}" "${TURN_INDEX}" \
        >> "${HOOK_LOG}" \
    || printf '[%s] failed to write sentinel %s\n' "${STARTED_AT}" "${SENTINEL_FILE}" >> "${HOOK_LOG}"
} 2>> "${HOOK_LOG}"

exit 0
