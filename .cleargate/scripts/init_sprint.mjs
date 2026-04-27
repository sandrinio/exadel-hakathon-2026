#!/usr/bin/env node
/**
 * init_sprint.mjs — Initialize a sprint state.json
 *
 * Usage: node init_sprint.mjs <sprint-id> --stories ID1,ID2,... [--force]
 *
 * Creates .cleargate/sprint-runs/<sprint-id>/state.json with initial state
 * "Ready to Bounce" for each story. Refuses if state.json already exists
 * unless --force is passed.
 *
 * Under execution_mode: v2 (read from sprint frontmatter):
 *   - Asserts all story files exist in pending-sync/ before writing state.json.
 *   - On failure: prints missing list to stderr and exits 1 WITHOUT creating state.json.
 *
 * Under execution_mode: v1:
 *   - Runs the same assertion but only warns on failure (does not block).
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { SCHEMA_VERSION, VALID_STATES, TERMINAL_STATES } from './constants.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Resolve repo root: .cleargate/scripts/ -> ../../ (two levels up)
// CLEARGATE_REPO_ROOT env var overrides for testing
const REPO_ROOT = process.env.CLEARGATE_REPO_ROOT
  ? path.resolve(process.env.CLEARGATE_REPO_ROOT)
  : path.resolve(__dirname, '..', '..');

function usage() {
  process.stderr.write(
    'Usage: node init_sprint.mjs <sprint-id> --stories ID1,ID2,... [--force]\n'
  );
  process.exit(2);
}

/**
 * Read execution_mode from a sprint file's YAML frontmatter.
 * Uses a single-field regex — does NOT hand-roll a full YAML parser.
 * Returns 'v2' | 'v1' (defaults to 'v1' if field absent or unreadable).
 */
function readExecutionMode(sprintFilePath) {
  let content;
  try {
    content = fs.readFileSync(sprintFilePath, 'utf8');
  } catch {
    return 'v1';
  }
  // Match frontmatter block
  const fm = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!fm) return 'v1';
  const modeMatch = fm[1].match(/^execution_mode:\s*["']?(v[12])/m);
  if (!modeMatch) return 'v1';
  return modeMatch[1];
}

/**
 * Locate the sprint file in pending-sync/ or archive/ for the given sprint ID.
 * Returns the absolute path if found, null otherwise.
 */
function findSprintFile(repoRoot, sprintId) {
  const searchDirs = [
    path.join(repoRoot, '.cleargate', 'delivery', 'pending-sync'),
    path.join(repoRoot, '.cleargate', 'delivery', 'archive'),
  ];
  for (const dir of searchDirs) {
    let entries;
    try {
      entries = fs.readdirSync(dir);
    } catch {
      continue;
    }
    const prefix = `${sprintId}_`;
    const match = entries.find(
      (e) => (e === `${sprintId}.md` || e.startsWith(prefix)) && e.endsWith('.md')
    );
    if (match) return path.join(dir, match);
  }
  return null;
}

/**
 * Run assert_story_files.mjs for the given sprint file.
 * Returns { exitCode, stderr }.
 */
function runAssertStoryFiles(repoRoot, sprintFilePath) {
  // Use __dirname to locate the sibling script (not CLEARGATE_REPO_ROOT, which is a test-isolation
  // override that points to a tmpdir without scripts).
  const assertScript = path.join(__dirname, 'assert_story_files.mjs');
  const env = { ...process.env, CLEARGATE_REPO_ROOT: repoRoot };
  const result = spawnSync(process.execPath, [assertScript, sprintFilePath], {
    encoding: 'utf8',
    env,
  });
  return {
    exitCode: result.status ?? 1,
    stderr: result.stderr || '',
    stdout: result.stdout || '',
  };
}

function main() {
  const args = process.argv.slice(2);

  const sprintId = args[0];
  if (!sprintId || sprintId.startsWith('--')) usage();

  const storiesIdx = args.indexOf('--stories');
  if (storiesIdx === -1 || !args[storiesIdx + 1]) usage();

  const storyIds = args[storiesIdx + 1].split(',').map((s) => s.trim()).filter(Boolean);
  if (storyIds.length === 0) {
    process.stderr.write('Error: --stories requires at least one story ID\n');
    process.exit(2);
  }

  const force = args.includes('--force');

  const sprintDir = path.join(REPO_ROOT, '.cleargate', 'sprint-runs', sprintId);
  const stateFile = path.join(sprintDir, 'state.json');

  if (fs.existsSync(stateFile) && !force) {
    process.stderr.write(
      `state.json already exists at ${stateFile}; pass --force to overwrite\n`
    );
    process.exit(1);
  }

  // --- Read execution_mode from sprint frontmatter ---
  const sprintFilePath = findSprintFile(REPO_ROOT, sprintId);
  const executionMode = sprintFilePath ? readExecutionMode(sprintFilePath) : 'v1';

  // --- Gate-2 story-file assertion ---
  if (sprintFilePath) {
    const { exitCode, stderr, stdout } = runAssertStoryFiles(REPO_ROOT, sprintFilePath);
    if (exitCode !== 0) {
      if (executionMode === 'v2') {
        // Hard block: do not create state.json
        process.stderr.write(stderr);
        // Count categories from structured stderr lines
        const missingCount = (stderr.match(/^MISSING \((\d+)\):/m) ?? [])[1] ?? '0';
        const unapprovedCount = (stderr.match(/^UNAPPROVED \((\d+)\):/m) ?? [])[1] ?? '0';
        const emptyCount = (stderr.match(/^STUB-EMPTY \((\d+)\):/m) ?? [])[1] ?? '0';
        process.stderr.write(
          `ERROR: v2 sprint init blocked — ${missingCount} items missing, ${unapprovedCount} unapproved, ${emptyCount} stub-empty. Fix the above, then re-run init.\n`
        );
        process.exit(1);
      } else {
        // v1: warn only
        process.stderr.write(
          `WARN: missing story files: ${stderr.trim().split('\n').pop() || 'see above'}\n`
        );
      }
    }
  }

  const now = new Date().toISOString();
  const stories = {};
  for (const id of storyIds) {
    stories[id] = {
      state: 'Ready to Bounce',
      qa_bounces: 0,
      arch_bounces: 0,
      worktree: null,
      updated_at: now,
      notes: '',
      lane: 'standard',
      lane_assigned_by: 'migration-default',
      lane_demoted_at: null,
      lane_demotion_reason: null,
    };
  }

  const state = {
    schema_version: SCHEMA_VERSION,
    sprint_id: sprintId,
    execution_mode: executionMode,
    sprint_status: 'Active',
    stories,
    last_action: `Sprint ${sprintId} initialised`,
    updated_at: now,
  };

  fs.mkdirSync(sprintDir, { recursive: true });

  const tmpFile = `${stateFile}.tmp.${process.pid}`;
  fs.writeFileSync(tmpFile, JSON.stringify(state, null, 2) + '\n', 'utf8');
  fs.renameSync(tmpFile, stateFile);

  process.stdout.write(`Initialized state.json for sprint ${sprintId} with ${storyIds.length} stories\n`);
}

main();
