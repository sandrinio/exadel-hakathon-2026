#!/usr/bin/env bash
# file_surface_diff.sh — Parse §3.1 of the active story file and compare
# declared file paths against `git diff --cached --name-only`.
#
# Usage: file_surface_diff.sh [--story-file <path>] [--whitelist <path>] [--v1]
#
# Environment:
#   SKIP_SURFACE_GATE=1    — bypass the gate (exit 0 always)
#   CLEARGATE_REPO_ROOT    — override repo root (default: CWD git toplevel)
#
# Exit codes:
#   0  — all staged files are on-surface or whitelisted, or v1 mode
#   1  — off-surface files detected (v2 mode only)

set -euo pipefail

# ---- Configuration ---------------------------------------------------------

REPO_ROOT="${CLEARGATE_REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
WHITELIST_DEFAULT="${REPO_ROOT}/.cleargate/scripts/surface-whitelist.txt"
ACTIVE_SENTINEL="${REPO_ROOT}/.cleargate/sprint-runs/.active"
STATE_JSON_GLOB="${REPO_ROOT}/.cleargate/sprint-runs"

# Parse args
STORY_FILE=""
WHITELIST_FILE="${WHITELIST_DEFAULT}"
FORCE_V1=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --story-file) STORY_FILE="$2"; shift 2 ;;
    --whitelist)  WHITELIST_FILE="$2"; shift 2 ;;
    --v1)         FORCE_V1=1; shift ;;
    *) shift ;;
  esac
done

# ---- Bypass check ----------------------------------------------------------

if [[ "${SKIP_SURFACE_GATE:-0}" == "1" ]]; then
  echo "[surface-gate] SKIP_SURFACE_GATE=1 — bypassing gate" >&2
  exit 0
fi

# ---- Execution mode --------------------------------------------------------

detect_execution_mode() {
  local state_file="${STATE_JSON_GLOB}"
  # Determine active sprint
  local sprint_id=""
  if [[ -f "${ACTIVE_SENTINEL}" ]]; then
    sprint_id="$(tr -d '[:space:]' < "${ACTIVE_SENTINEL}")"
  fi
  if [[ -z "${sprint_id}" ]]; then
    echo "v1"
    return
  fi
  local state_json="${REPO_ROOT}/.cleargate/sprint-runs/${sprint_id}/state.json"
  if [[ -f "${state_json}" ]]; then
    local mode
    mode="$(grep -oE '"execution_mode"\s*:\s*"v[12]"' "${state_json}" 2>/dev/null | grep -oE 'v[12]' | head -1 || true)"
    if [[ -n "${mode}" ]]; then
      echo "${mode}"
      return
    fi
  fi
  # Fallback: check sprint file frontmatter
  local sprint_file
  sprint_file="$(ls "${REPO_ROOT}/.cleargate/delivery/pending-sync/SPRINT-${sprint_id}_"*.md 2>/dev/null | head -1 || true)"
  if [[ -z "${sprint_file}" ]]; then
    sprint_file="$(ls "${REPO_ROOT}/.cleargate/delivery/archive/SPRINT-${sprint_id}_"*.md 2>/dev/null | head -1 || true)"
  fi
  if [[ -n "${sprint_file}" ]]; then
    local mode
    mode="$(grep -E '^execution_mode:' "${sprint_file}" 2>/dev/null | grep -oE 'v[12]' | head -1 || true)"
    if [[ -n "${mode}" ]]; then
      echo "${mode}"
      return
    fi
  fi
  echo "v1"
}

if [[ "${FORCE_V1}" == "1" ]]; then
  EXECUTION_MODE="v1"
else
  EXECUTION_MODE="$(detect_execution_mode)"
fi

# ---- Resolve active story file ---------------------------------------------

resolve_story_file() {
  local sprint_id=""
  if [[ -f "${ACTIVE_SENTINEL}" ]]; then
    sprint_id="$(tr -d '[:space:]' < "${ACTIVE_SENTINEL}")"
  fi
  if [[ -z "${sprint_id}" ]]; then
    echo ""
    return
  fi

  local state_json="${REPO_ROOT}/.cleargate/sprint-runs/${sprint_id}/state.json"
  if [[ ! -f "${state_json}" ]]; then
    echo ""
    return
  fi

  # Find first non-terminal story (In Progress or Ready)
  local story_id=""
  story_id="$(python3 -c "
import json, sys
data = json.load(open('${state_json}'))
stories = data.get('stories', {})
for sid, st in stories.items():
    if st.get('state','') in ('In Progress','Ready','In Review'):
        print(sid)
        break
" 2>/dev/null || true)"

  if [[ -z "${story_id}" ]]; then
    # Fallback: most recently updated
    story_id="$(python3 -c "
import json, sys
data = json.load(open('${state_json}'))
stories = data.get('stories', {})
latest = max(stories.items(), key=lambda kv: kv[1].get('updated_at',''), default=(None,None))
if latest[0]:
    print(latest[0])
" 2>/dev/null || true)"
  fi

  if [[ -z "${story_id}" ]]; then
    echo ""
    return
  fi

  # Convert e.g. STORY-014-01 -> find file
  local story_num="${story_id#STORY-}"
  local story_file
  story_file="$(ls "${REPO_ROOT}/.cleargate/delivery/pending-sync/STORY-${story_num}_"*.md 2>/dev/null | head -1 || true)"
  if [[ -z "${story_file}" ]]; then
    story_file="$(ls "${REPO_ROOT}/.cleargate/delivery/archive/STORY-${story_num}_"*.md 2>/dev/null | head -1 || true)"
  fi
  echo "${story_file}"
}

if [[ -z "${STORY_FILE}" ]]; then
  STORY_FILE="$(resolve_story_file)"
fi

if [[ -z "${STORY_FILE}" || ! -f "${STORY_FILE}" ]]; then
  echo "[surface-gate] WARNING: No active story file found — skipping surface check" >&2
  exit 0
fi

# ---- Parse §3.1 file surface table -----------------------------------------

parse_surface_paths() {
  local story_file="$1"
  # Extract rows between "### 3.1" and the next "### " header.
  # Table rows: | Item | Value |
  # Only rows where Value cell looks like a path (contains . or /)
  # Strip backticks. Split on ", " for multiple paths in one cell.
  awk '
    /^### 3\.1/ { in_section=1; next }
    in_section && /^### / { in_section=0; next }
    in_section && /^\|/ {
      # Remove leading/trailing pipe, split into fields
      line=$0
      gsub(/^\||\|$/, "", line)
      n=split(line, cols, "|")
      if (n < 2) next
      val=cols[2]
      # Trim whitespace
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      # Only process if value looks like a path (contains . or /)
      if (val !~ /[.\/]/) next
      # Strip backticks
      gsub(/`/, "", val)
      # Handle multiple paths separated by ", "
      npaths=split(val, paths, ", ")
      for (i=1; i<=npaths; i++) {
        p=paths[i]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", p)
        if (p != "" && (p ~ /[.\/]/)) print p
      }
    }
  ' "${story_file}"
}

# Collect declared paths into array (portable bash 3.2 compat — no mapfile)
declared_paths=()
while IFS= read -r p; do
  declared_paths+=("$p")
done < <(parse_surface_paths "${STORY_FILE}")

if [[ ${#declared_paths[@]} -eq 0 ]]; then
  echo "[surface-gate] WARNING: No file paths found in §3.1 of ${STORY_FILE} — skipping surface check" >&2
  exit 0
fi

# ---- Get staged files -------------------------------------------------------

staged_files=()
while IFS= read -r f; do
  staged_files+=("$f")
done < <(git -C "${REPO_ROOT}" diff --cached --name-only 2>/dev/null || true)

if [[ ${#staged_files[@]} -eq 0 ]]; then
  # Nothing staged — nothing to check
  exit 0
fi

# ---- Load whitelist ---------------------------------------------------------

whitelist_patterns=()
if [[ -f "${WHITELIST_FILE}" ]]; then
  while IFS= read -r line; do
    # Skip comments and blank lines
    [[ -z "${line}" || "${line}" =~ ^# ]] && continue
    whitelist_patterns+=("$line")
  done < "${WHITELIST_FILE}"
fi

# ---- Helper: match file against whitelist -----------------------------------

is_whitelisted() {
  local file="$1"
  local pattern
  for pattern in "${whitelist_patterns[@]+"${whitelist_patterns[@]}"}"; do
    # Use bash glob matching — convert ** to * for simple matching
    # Try direct fnmatch with case
    if [[ "${file}" == ${pattern} ]]; then
      return 0
    fi
    # Try matching basename
    local basename="${file##*/}"
    local pat_base="${pattern##*/}"
    if [[ "${basename}" == ${pat_base} && "${pat_base}" == "${basename}" ]]; then
      : # need full path match
    fi
    # Try: if pattern has **, match any path segment
    local simple_pat="${pattern//\*\*\//*/}"
    if [[ "${file}" == ${simple_pat} ]]; then
      return 0
    fi
    # Also: check if file path contains the pattern as suffix
    if [[ "${file}" == *"${pattern}" ]]; then
      return 0
    fi
  done
  return 1
}

# ---- Helper: normalize path for comparison ----------------------------------

normalize_path() {
  local p="$1"
  # Strip leading ./
  p="${p#./}"
  # If absolute path under REPO_ROOT, make it relative
  if [[ "${p}" == "${REPO_ROOT}/"* ]]; then
    p="${p#${REPO_ROOT}/}"
  fi
  echo "${p}"
}

# ---- Compare staged vs declared ---------------------------------------------

off_surface=()
for staged in "${staged_files[@]}"; do
  staged_norm="$(normalize_path "${staged}")"

  # Check whitelist first
  if is_whitelisted "${staged_norm}"; then
    continue
  fi
  # Also check absolute path against whitelist
  if is_whitelisted "${REPO_ROOT}/${staged_norm}"; then
    continue
  fi

  # Check against declared surface
  found=0
  for declared in "${declared_paths[@]+"${declared_paths[@]}"}"; do
    declared_norm="$(normalize_path "${declared}")"
    if [[ "${staged_norm}" == "${declared_norm}" ]]; then
      found=1
      break
    fi
  done

  if [[ "${found}" == "0" ]]; then
    off_surface+=("${staged_norm}")
  fi
done

# ---- Report -----------------------------------------------------------------

if [[ ${#off_surface[@]} -eq 0 ]]; then
  exit 0
fi

# Off-surface files detected
if [[ "${EXECUTION_MODE}" == "v1" ]]; then
  echo "[surface-gate] WARNING (v1 advisory): staged files outside declared §3.1 surface:" >&2
  for f in "${off_surface[@]}"; do
    echo "  off-surface: ${f}" >&2
  done
  echo "[surface-gate] v1 mode — not blocking commit. Switch to v2 to enforce." >&2
  exit 0
else
  echo "[surface-gate] BLOCKED: staged files outside declared §3.1 surface:" >&2
  for f in "${off_surface[@]}"; do
    echo "  off-surface: ${f}" >&2
  done
  echo "[surface-gate] Commit blocked. Declare these files in §3.1 or open a CR:scope-change." >&2
  echo "[surface-gate] Set SKIP_SURFACE_GATE=1 to bypass (v2 mode — use sparingly)." >&2
  exit 1
fi
