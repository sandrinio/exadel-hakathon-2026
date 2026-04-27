#!/usr/bin/env node
/**
 * update_state.mjs — Atomic state/counter update for a story in state.json
 *
 * Usage:
 *   node update_state.mjs <STORY-ID> <new-state>          — transition to a new state
 *   node update_state.mjs <STORY-ID> --qa-bounce          — increment qa_bounces counter
 *   node update_state.mjs <STORY-ID> --arch-bounce        — increment arch_bounces counter
 *   node update_state.mjs <STORY-ID> --lane <standard|fast> — set lane for a story
 *   node update_state.mjs <STORY-ID> --lane-demote <reason> — demote story from fast lane
 *
 * Atomic write: write to .tmp.<pid> file, then rename to final path.
 * Idempotent: if new state equals current (for state transitions) and
 *   no counter change, exit 0 without rewriting the file.
 *
 * Auto-escalation: when qa_bounces or arch_bounces reaches BOUNCE_CAP (3),
 *   state is automatically set to "Escalated".
 *
 * Migration: reads v1 state.json transparently; upgrades to v2 on first touch
 *   (injects lane fields with defaults; emits one stderr log line).
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { SCHEMA_VERSION, VALID_STATES, TERMINAL_STATES, BOUNCE_CAP } from './constants.mjs';
import { validateState, validateShapeIgnoringVersion } from './validate_state.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');

function usage() {
  process.stderr.write(
    'Usage:\n' +
    '  node update_state.mjs <STORY-ID> <new-state>\n' +
    '  node update_state.mjs <STORY-ID> --qa-bounce\n' +
    '  node update_state.mjs <STORY-ID> --arch-bounce\n' +
    '  node update_state.mjs <STORY-ID> --lane <standard|fast>\n' +
    '  node update_state.mjs <STORY-ID> --lane-demote <reason>\n'
  );
  process.exit(2);
}

/**
 * Migrate a v1 state.json to v2 by injecting lane fields with defaults.
 * Mutates the state object in-place and returns it.
 * Emits a single stderr log line describing the migration.
 * @param {object} state - Parsed v1 state object
 * @returns {object} - The mutated (now v2) state object
 */
export function migrateV1ToV2(state) {
  state.schema_version = 2;
  const storyIds = Object.keys(state.stories || {});
  for (const id of storyIds) {
    const story = state.stories[id];
    if (story.lane == null) story.lane = 'standard';
    if (story.lane_assigned_by == null) story.lane_assigned_by = 'migration-default';
    if (story.lane_demoted_at === undefined) story.lane_demoted_at = null;
    if (story.lane_demotion_reason === undefined) story.lane_demotion_reason = null;
  }
  process.stderr.write(
    `migration: schema_version 1 → 2 for sprint ${state.sprint_id} (${storyIds.length} stories defaulted to lane: standard)\n`
  );
  return state;
}

function resolveStateFile() {
  const envFile = process.env.CLEARGATE_STATE_FILE;
  if (envFile) return path.resolve(envFile);
  throw new Error(
    'CLEARGATE_STATE_FILE env var not set; cannot resolve state.json'
  );
}

function atomicWrite(stateFile, state) {
  const tmpFile = `${stateFile}.tmp.${process.pid}`;
  fs.writeFileSync(tmpFile, JSON.stringify(state, null, 2) + '\n', 'utf8');
  fs.renameSync(tmpFile, stateFile);
}

function main() {
  const args = process.argv.slice(2);

  if (args.length < 2) usage();

  const storyId = args[0];
  const action = args[1];

  const stateFile = resolveStateFile();

  if (!fs.existsSync(stateFile)) {
    process.stderr.write(`Error: state.json not found at ${stateFile}\n`);
    process.exit(1);
  }

  let state;
  try {
    state = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
  } catch (err) {
    process.stderr.write(`Error: failed to parse state.json: ${err.message}\n`);
    process.exit(1);
  }

  // Pre-migration: validate shape (ignoring version) before potentially migrating
  const preCheck = validateShapeIgnoringVersion(state);
  if (!preCheck.valid) {
    process.stderr.write(`Error: state.json is invalid:\n`);
    for (const e of preCheck.errors) process.stderr.write(`  - ${e}\n`);
    process.exit(1);
  }

  // Migrate v1 → v2 if needed; write atomically so subsequent reads see v2
  if (state.schema_version === 1) {
    state = migrateV1ToV2(state);
    atomicWrite(stateFile, state);
  }

  // Post-migration strict validation
  const { valid, errors } = validateState(state);
  if (!valid) {
    process.stderr.write(`Error: state.json is invalid after migration:\n`);
    for (const e of errors) process.stderr.write(`  - ${e}\n`);
    process.exit(1);
  }

  if (!state.stories[storyId]) {
    process.stderr.write(`Error: story ${storyId} not found in state.json\n`);
    process.exit(1);
  }

  const story = state.stories[storyId];

  if (action === '--lane') {
    const laneValue = args[2];
    if (!laneValue || !['standard', 'fast'].includes(laneValue)) {
      process.stderr.write(
        `Error: --lane requires a value of "standard" or "fast"\n`
      );
      process.exit(2);
    }
    // TODO(STORY-022-04): cross-read sprint plan to enforce rubric §6 contradiction check
    // (expected_bounce_exposure: med|high + lane: fast is a contradiction per PROPOSAL-013 §2.3 #6)
    story.lane = laneValue;
    story.lane_assigned_by = 'human-override';
    story.updated_at = new Date().toISOString();
    state.last_action = `lane-set ${storyId}: lane=${laneValue} (human-override)`;
    state.updated_at = story.updated_at;
    atomicWrite(stateFile, state);
    process.stdout.write(
      `Updated ${storyId}: lane="${laneValue}", lane_assigned_by="human-override"\n`
    );

  } else if (action === '--lane-demote') {
    const reason = args[2];
    if (!reason) {
      process.stderr.write(
        `Error: --lane-demote requires a reason string\n`
      );
      process.exit(2);
    }
    story.lane = 'standard';
    story.lane_demoted_at = new Date().toISOString();
    story.lane_demotion_reason = reason;
    story.qa_bounces = 0;
    story.arch_bounces = 0;
    story.updated_at = story.lane_demoted_at;
    state.last_action = `lane-demote ${storyId}: "${reason}"`;
    state.updated_at = story.updated_at;
    atomicWrite(stateFile, state);
    process.stdout.write(
      `Updated ${storyId}: lane="standard", lane_demoted_at="${story.lane_demoted_at}", qa_bounces=0, arch_bounces=0\n`
    );

  } else if (action === '--qa-bounce') {
    if (story.state === 'Escalated') {
      process.stderr.write(`Error: story ${storyId} is already Escalated\n`);
      process.exit(1);
    }
    story.qa_bounces += 1;
    if (story.qa_bounces >= BOUNCE_CAP) {
      story.state = 'Escalated';
    }
    story.updated_at = new Date().toISOString();
    state.last_action = `qa-bounce ${storyId}: qa_bounces=${story.qa_bounces}`;
    state.updated_at = story.updated_at;
    atomicWrite(stateFile, state);
    process.stdout.write(
      `Updated ${storyId}: qa_bounces=${story.qa_bounces}, state=${story.state}\n`
    );

  } else if (action === '--arch-bounce') {
    if (story.state === 'Escalated') {
      process.stderr.write(`Error: story ${storyId} is already Escalated\n`);
      process.exit(1);
    }
    story.arch_bounces += 1;
    if (story.arch_bounces >= BOUNCE_CAP) {
      story.state = 'Escalated';
    }
    story.updated_at = new Date().toISOString();
    state.last_action = `arch-bounce ${storyId}: arch_bounces=${story.arch_bounces}`;
    state.updated_at = story.updated_at;
    atomicWrite(stateFile, state);
    process.stdout.write(
      `Updated ${storyId}: arch_bounces=${story.arch_bounces}, state=${story.state}\n`
    );

  } else {
    // State transition
    const newState = action;

    if (!VALID_STATES.includes(newState)) {
      process.stderr.write(
        `Error: invalid state "${newState}"; valid states: ${VALID_STATES.join(', ')}\n`
      );
      process.exit(1);
    }

    // Idempotency: if state is already the target, no-op
    if (story.state === newState) {
      process.stdout.write(`No-op: ${storyId} is already in state "${newState}"\n`);
      process.exit(0);
    }

    // Reset worktree to null on Done
    if (newState === 'Done') {
      story.worktree = null;
    }

    story.state = newState;
    story.updated_at = new Date().toISOString();
    state.last_action = `transition ${storyId} → ${newState}`;
    state.updated_at = story.updated_at;
    atomicWrite(stateFile, state);
    process.stdout.write(`Updated ${storyId}: state="${newState}"\n`);
  }
}

main();
