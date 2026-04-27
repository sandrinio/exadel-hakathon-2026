#!/usr/bin/env node
/**
 * assert_story_files.mjs — Gate-2 work-item file existence + approval assertion
 *
 * Usage: node assert_story_files.mjs <sprint-file-path>
 *
 * Parses the "## 1. Consolidated Deliverables" section of a sprint file for
 * all six work-item id shapes:
 *   STORY-\d+-\d+, CR-\d+, BUG-\d+, EPIC-\d+, PROPOSAL-\d+ (PROP-\d+ normalised),
 *   HOTFIX-\d+
 * then checks that each has a corresponding pending-sync/<ID>_*.md file under
 * the repo root, and that each present file is approved + structurally non-empty.
 *
 * Exit 0:  all work-item files present, approved, and non-empty (prints summary to stdout)
 * Exit 1:  one or more missing / unapproved / stub-empty (prints structured stderr)
 * Exit 2:  usage / parse error
 *
 * Env:
 *   CLEARGATE_REPO_ROOT  override repo root (for test isolation)
 *   CLEARGATE_EXEC_MODE  override execution_mode ('v1'|'v2') — for test isolation
 *
 * Returns (from assertWorkItemFiles):
 *   { missing: string[], present: string[], unapproved: string[], empty: string[] }
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Resolve repo root: .cleargate/scripts/ -> ../../ (two levels up)
const REPO_ROOT = process.env.CLEARGATE_REPO_ROOT
  ? path.resolve(process.env.CLEARGATE_REPO_ROOT)
  : path.resolve(__dirname, '..', '..');

function usage() {
  process.stderr.write('Usage: node assert_story_files.mjs <sprint-file-path>\n');
  process.exit(2);
}

/**
 * Extract the "## 1. Consolidated Deliverables" section from sprint markdown.
 * Returns the section text or null if not found.
 *
 * Strategy: split on ^## headings, find the one starting with "1. Consolidated Deliverables".
 * This avoids regex lookahead pitfalls with end-of-string anchors in JS.
 */
function extractDeliverablesSection(content) {
  // Split on lines that start a new ## section (lookahead keeps delimiter in next part)
  const parts = content.split(/^(?=## )/m);
  const deliverables = parts.find((p) =>
    /^## 1\.? Consolidated Deliverables\b/m.test(p)
  );
  if (!deliverables) return null;
  // Strip the header line itself, return the rest
  return deliverables.replace(/^## [^\n]*\n/, '');
}

/**
 * Extract deduplicated work-item IDs from a text block.
 *
 * ID shapes (longest-alternative-first to avoid prefix collisions):
 *   STORY-\d+-\d+         (e.g. STORY-022-07)
 *   CR-\d+                (e.g. CR-008)
 *   BUG-\d+               (e.g. BUG-007)
 *   EPIC-\d+              (e.g. EPIC-013)
 *   HOTFIX-\d+            (e.g. HOTFIX-001)
 *   PROPOSAL-\d+          (e.g. PROPOSAL-013)
 *   PROP-\d+              normalised to PROPOSAL-NNN post-extract (BUG-009 lesson)
 *
 * STORY before CR/BUG/EPIC/HOTFIX, PROPOSAL before PROP — BUG-010 longest-first rule.
 */
function extractWorkItemIds(text) {
  const re = /(STORY-\d+-\d+|(CR|BUG|EPIC|HOTFIX)-\d+|(PROPOSAL|PROP)-\d+)/g;
  const raw = [];
  let m;
  while ((m = re.exec(text)) !== null) {
    raw.push(m[0]);
  }
  // BUG-009 normalize: PROP-NNN → PROPOSAL-NNN
  const normalised = raw.map((id) => id.replace(/^PROP-(\d+)$/, 'PROPOSAL-$1'));
  return [...new Set(normalised)];
}

/**
 * Check whether pending-sync OR archive contains a file matching <ID>_*.md
 * Returns the matching absolute path or null.
 */
function findWorkItemFile(repoRoot, workItemId) {
  const searchDirs = [
    path.join(repoRoot, '.cleargate', 'delivery', 'pending-sync'),
    path.join(repoRoot, '.cleargate', 'delivery', 'archive'),
  ];
  const prefix = `${workItemId}_`;
  for (const dir of searchDirs) {
    let entries;
    try {
      entries = fs.readdirSync(dir);
    } catch {
      continue;
    }
    const match = entries.find(
      (e) => e.startsWith(prefix) && e.endsWith('.md')
    );
    if (match) return path.join(dir, match);
  }
  return null;
}

/**
 * Inline YAML frontmatter extractor.
 * Returns { approved: boolean, has_heading: boolean }.
 *
 * - approved: frontmatter contains `approved: true` (quoted or unquoted).
 * - has_heading: body after frontmatter contains at least one "## " line.
 *
 * Tolerate files with no frontmatter (approved=false, has_heading per body scan).
 */
function assertWorkItemApproved(filePath) {
  let content;
  try {
    content = fs.readFileSync(filePath, 'utf8');
  } catch {
    return { approved: false, has_heading: false };
  }

  let body = content;
  let approved = false;

  // Match YAML frontmatter block: starts with --- on first line
  const fmMatch = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (fmMatch) {
    const fmBlock = fmMatch[1];
    body = fmMatch[2] ?? '';

    // Look for `approved: true` (unquoted) or `approved: "true"` (quoted)
    const approvedMatch = fmBlock.match(/^approved:\s*["']?(true)["']?\s*$/m);
    approved = approvedMatch !== null;
  }

  // has_heading: body contains at least one "## " markdown heading
  const has_heading = /^## /m.test(body);

  return { approved, has_heading };
}

/**
 * Main assertion logic.
 * Returns { missing: string[], present: string[], unapproved: string[], empty: string[] }
 *
 * - missing:    id referenced in §1 with no file in pending-sync/ or archive/
 * - present:    id with a file found
 * - unapproved: present but approved: false in frontmatter
 * - empty:      present + approved but body has no ## heading (stub)
 */
function assertWorkItemFiles(sprintFilePath, repoRoot) {
  let content;
  try {
    content = fs.readFileSync(sprintFilePath, 'utf8');
  } catch (err) {
    process.stderr.write(`Error: cannot read sprint file: ${err.message}\n`);
    process.exit(2);
  }

  const section = extractDeliverablesSection(content);
  if (section === null) {
    process.stderr.write(
      'Error: "## 1. Consolidated Deliverables" section not found in sprint file\n'
    );
    process.exit(2);
  }

  const workItemIds = extractWorkItemIds(section);
  if (workItemIds.length === 0) {
    process.stderr.write('Warning: no work-item IDs found in §1 Consolidated Deliverables\n');
    // Return empty — no files to check, nothing is missing
    return { missing: [], present: [], unapproved: [], empty: [] };
  }

  const missing = [];
  const present = [];
  const unapproved = [];
  const empty = [];

  for (const id of workItemIds) {
    const found = findWorkItemFile(repoRoot, id);
    if (found) {
      present.push(id);
      const { approved, has_heading } = assertWorkItemApproved(found);
      if (!approved) {
        unapproved.push(id);
      } else if (!has_heading) {
        empty.push(id);
      }
    } else {
      missing.push(id);
    }
  }

  return { missing, present, unapproved, empty };
}

function main() {
  const args = process.argv.slice(2);
  if (args.length === 0 || args[0].startsWith('--')) usage();

  const sprintFilePath = path.resolve(args[0]);

  // Allow test-isolation override of execution_mode
  const execMode = process.env.CLEARGATE_EXEC_MODE ?? 'v2';

  const { missing, present, unapproved, empty } = assertWorkItemFiles(sprintFilePath, REPO_ROOT);

  const hasProblems = missing.length > 0 || unapproved.length > 0 || empty.length > 0;

  if (!hasProblems) {
    process.stdout.write(
      `OK: all ${present.length} work-item file(s) present, approved, and non-empty in pending-sync/ or archive/\n`
    );
    process.exit(0);
  }

  // Build structured stderr output
  if (missing.length > 0) {
    process.stderr.write(`MISSING (${missing.length}): ${missing.join(', ')}\n`);
  }
  if (unapproved.length > 0) {
    process.stderr.write(`UNAPPROVED (${unapproved.length}): ${unapproved.join(', ')}\n`);
  }
  if (empty.length > 0) {
    process.stderr.write(`STUB-EMPTY (${empty.length}): ${empty.join(', ')}\n`);
  }

  if (execMode === 'v2') {
    process.exit(1);
  } else {
    // v1: warn only, exit 0
    process.exit(0);
  }
}

main();
