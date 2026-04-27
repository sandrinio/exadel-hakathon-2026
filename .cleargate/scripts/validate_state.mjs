#!/usr/bin/env node
/**
 * validate_state.mjs — Validate state.json schema and invariants
 *
 * Usage: node validate_state.mjs [--state-file <path>]
 *
 * Reads .cleargate/sprint-runs/<sprint-id>/state.json (or a specified path),
 * confirms schema version, and reports invariant violations.
 *
 * Exports validateState(state) for use by other scripts.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { SCHEMA_VERSION, VALID_STATES, BOUNCE_CAP } from './constants.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');

/**
 * Validate a parsed state object.
 * @param {object} state - Parsed state.json content
 * @returns {{ valid: boolean, errors: string[] }}
 */
export function validateState(state) {
  const errors = [];

  if (typeof state !== 'object' || state === null) {
    errors.push('state is not an object');
    return { valid: false, errors };
  }

  if (state.schema_version !== SCHEMA_VERSION) {
    errors.push(
      `schema_version mismatch: expected ${SCHEMA_VERSION}, got ${state.schema_version}`
    );
  }

  if (!state.sprint_id) {
    errors.push('missing required field: sprint_id');
  }

  if (!state.execution_mode) {
    errors.push('missing required field: execution_mode');
  }

  if (!state.sprint_status) {
    errors.push('missing required field: sprint_status');
  }

  if (typeof state.stories !== 'object' || state.stories === null) {
    errors.push('stories field must be an object');
    return { valid: false, errors };
  }

  for (const [storyId, story] of Object.entries(state.stories)) {
    if (typeof story !== 'object' || story === null) {
      errors.push(`story ${storyId}: not an object`);
      continue;
    }

    if (!VALID_STATES.includes(story.state)) {
      errors.push(
        `story ${storyId}: invalid state "${story.state}"; expected one of: ${VALID_STATES.join(', ')}`
      );
    }

    if (typeof story.qa_bounces !== 'number') {
      errors.push(`story ${storyId}: qa_bounces must be a number`);
    } else if (story.qa_bounces > BOUNCE_CAP) {
      errors.push(
        `invariant violation: story ${storyId} qa_bounces=${story.qa_bounces} exceeds BOUNCE_CAP (${BOUNCE_CAP})`
      );
    } else if (story.qa_bounces < 0) {
      errors.push(`story ${storyId}: qa_bounces must be >= 0`);
    }

    if (typeof story.arch_bounces !== 'number') {
      errors.push(`story ${storyId}: arch_bounces must be a number`);
    } else if (story.arch_bounces > BOUNCE_CAP) {
      errors.push(
        `invariant violation: story ${storyId} arch_bounces=${story.arch_bounces} exceeds BOUNCE_CAP (${BOUNCE_CAP})`
      );
    } else if (story.arch_bounces < 0) {
      errors.push(`story ${storyId}: arch_bounces must be >= 0`);
    }

    if (!story.updated_at) {
      errors.push(`story ${storyId}: missing required field: updated_at`);
    }
  }

  if (!state.updated_at) {
    errors.push('missing required top-level field: updated_at');
  }

  return { valid: errors.length === 0, errors };
}

// CLI mode
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const fileIdx = args.indexOf('--state-file');
  let stateFile;

  if (fileIdx !== -1 && args[fileIdx + 1]) {
    stateFile = path.resolve(args[fileIdx + 1]);
  } else {
    // Attempt to discover via environment or fallback
    const envStateFile = process.env.CLEARGATE_STATE_FILE;
    if (envStateFile) {
      stateFile = path.resolve(envStateFile);
    } else {
      // Look for state.json in sprint-runs/
      const sprintRunsDir = path.join(REPO_ROOT, '.cleargate', 'sprint-runs');
      if (!fs.existsSync(sprintRunsDir)) {
        process.stderr.write(`Error: sprint-runs directory not found at ${sprintRunsDir}\n`);
        process.exit(1);
      }
      const entries = fs.readdirSync(sprintRunsDir);
      const found = entries
        .map((e) => path.join(sprintRunsDir, e, 'state.json'))
        .filter((p) => fs.existsSync(p));
      if (found.length === 0) {
        process.stderr.write('Error: no state.json found in sprint-runs/\n');
        process.exit(1);
      }
      if (found.length > 1) {
        process.stderr.write(
          `Multiple state.json files found; specify --state-file:\n${found.join('\n')}\n`
        );
        process.exit(1);
      }
      stateFile = found[0];
    }
  }

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

  const { valid, errors } = validateState(state);

  if (valid) {
    process.stdout.write(`state.json at ${stateFile} is valid (schema_version=${state.schema_version})\n`);
    process.exit(0);
  } else {
    process.stderr.write(`Validation failed for ${stateFile}:\n`);
    for (const err of errors) {
      process.stderr.write(`  - ${err}\n`);
    }
    process.exit(1);
  }
}
