#!/usr/bin/env node
/**
 * suggest_improvements.mjs — Generate stable improvement suggestions from REPORT.md
 *
 * Usage: node suggest_improvements.mjs <sprint-id>
 *
 * Reads:
 *   - .cleargate/sprint-runs/<id>/REPORT.md §5 Framework Self-Assessment tables
 *   - .cleargate/sprint-runs/<prev-id>/improvement-suggestions.md (if present, for context)
 *
 * Emits:
 *   - .cleargate/sprint-runs/<id>/improvement-suggestions.md
 *     with stable SUG-<sprint>-<n> IDs
 *
 * Append-only idempotency (R5):
 *   - IDs are derived from a stable hash of (category, title) tuple
 *   - Re-running produces zero new entries if all suggestions already captured
 *   - Script exits 0 in both cases
 *
 * Note: "section" as used in §5 table extraction refers to the Framework Self-Assessment
 * subsections: Templates, Handoffs, Skills, Process, Tooling.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');

// §5 subsection names used in sprint_report.md template
const SELF_ASSESSMENT_SECTIONS = ['Templates', 'Handoffs', 'Skills', 'Process', 'Tooling'];

/**
 * Generate a stable short hash from a string.
 * Used for SUG ID stability — same (category, title) always produces same ID.
 * @param {string} input
 * @returns {string} 6-char hex
 */
function stableHash(input) {
  return createHash('sha256').update(input).digest('hex').slice(0, 6);
}

/**
 * Parse §5 Framework Self-Assessment from REPORT.md content.
 * Extracts Yellow/Red-rated rows as improvement candidates.
 * @param {string} content
 * @returns {{ category: string, item: string, rating: string, notes: string }[]}
 */
function parseSelfAssessment(content) {
  const suggestions = [];

  // Find the §5 Framework Self-Assessment section
  const selfAssessmentMatch = content.match(/##\s*§5[^\n]*\n([\s\S]*?)(?=##\s*§6|$)/);
  if (!selfAssessmentMatch) return suggestions;

  const sectionContent = selfAssessmentMatch[1];

  // Extract each subsection table
  for (const category of SELF_ASSESSMENT_SECTIONS) {
    // Find table rows under the category header
    // Pattern: ### <category>\n | <item> | <rating> | <notes> |
    const categoryMatch = sectionContent.match(
      new RegExp(`###\\s+${category}\\s*\\n([\\s\\S]*?)(?=###|$)`, 'i')
    );
    if (!categoryMatch) continue;

    const tableContent = categoryMatch[1];
    // Parse table rows (skip header rows with ---)
    const rows = tableContent.split('\n').filter(l => l.startsWith('|') && !l.includes('---'));

    for (const row of rows) {
      const cells = row.split('|').map(c => c.trim()).filter(Boolean);
      if (cells.length < 2) continue;

      const item = cells[0];
      const rating = cells[1] || '';
      const notes = cells[2] || '';

      // Only flag Yellow or Red items as needing improvement
      if (rating.toLowerCase().includes('yellow') || rating.toLowerCase().includes('red')) {
        // Skip header rows
        if (item === 'Item' || item === '---') continue;
        suggestions.push({ category, item, rating, notes });
      }
    }
  }

  return suggestions;
}

/**
 * Parse existing improvement-suggestions.md to extract already-captured SUG IDs.
 * @param {string} content
 * @returns {Set<string>} Set of SUG IDs
 */
function parseExistingIds(content) {
  const ids = new Set();
  // Match SUG-<sprint>-<n> patterns
  const matches = content.matchAll(/SUG-[A-Z0-9-]+-\d+/g);
  for (const m of matches) {
    ids.add(m[0]);
  }
  return ids;
}

/**
 * Atomic write using tmp+rename pattern.
 * @param {string} filePath
 * @param {string} content
 */
function atomicWrite(filePath, content) {
  const tmpFile = `${filePath}.tmp.${process.pid}`;
  fs.writeFileSync(tmpFile, content, 'utf8');
  fs.renameSync(tmpFile, filePath);
}

function main() {
  const args = process.argv.slice(2);
  if (args.length < 1) {
    process.stderr.write('Usage: node suggest_improvements.mjs <sprint-id>\n');
    process.exit(2);
  }

  const sprintId = args[0];
  const sprintDir = process.env.CLEARGATE_SPRINT_DIR
    ? path.resolve(process.env.CLEARGATE_SPRINT_DIR)
    : path.join(REPO_ROOT, '.cleargate', 'sprint-runs', sprintId);

  if (!fs.existsSync(sprintDir)) {
    process.stderr.write(`Error: sprint directory not found: ${sprintDir}\n`);
    process.exit(1);
  }

  const reportFile = path.join(sprintDir, 'REPORT.md');
  const suggestionsFile = path.join(sprintDir, 'improvement-suggestions.md');

  if (!fs.existsSync(reportFile)) {
    process.stderr.write(`Error: REPORT.md not found at ${reportFile}\n`);
    process.stderr.write('Run the Reporter agent first to generate the report.\n');
    process.exit(1);
  }

  const reportContent = fs.readFileSync(reportFile, 'utf8');

  // Parse §5 self-assessment for improvement candidates
  const candidates = parseSelfAssessment(reportContent);

  // Read existing suggestions if present (idempotency)
  let existingContent = '';
  const existingIds = new Set();
  let nextN = 1;

  if (fs.existsSync(suggestionsFile)) {
    existingContent = fs.readFileSync(suggestionsFile, 'utf8');
    // Parse existing IDs
    const parsed = parseExistingIds(existingContent);
    for (const id of parsed) {
      existingIds.add(id);
    }
    // Determine the highest existing N for this sprint to continue from
    const sprintPrefix = `SUG-${sprintId}-`;
    let maxN = 0;
    for (const id of parsed) {
      if (id.startsWith(sprintPrefix)) {
        const n = parseInt(id.slice(sprintPrefix.length), 10);
        if (!isNaN(n) && n > maxN) maxN = n;
      }
    }
    nextN = maxN + 1;
  }

  // Determine which candidates are new (stable hash-based dedup)
  const newEntries = [];
  for (const candidate of candidates) {
    const hashKey = `${candidate.category}|${candidate.item}`;
    const hash = stableHash(hashKey);
    // Check if we already have an entry with this hash in existing content
    // We encode the hash in a comment to enable stable lookup
    const hashMarker = `<!-- hash:${hash} -->`;
    if (existingContent.includes(hashMarker)) {
      continue; // Already captured
    }
    const sugId = `SUG-${sprintId}-${String(nextN).padStart(2, '0')}`;
    nextN++;
    newEntries.push({ sugId, hash, hashMarker, ...candidate });
  }

  if (newEntries.length === 0) {
    process.stdout.write(
      `Idempotent: no new suggestions to add for sprint ${sprintId}.\n` +
      `Existing file has ${existingIds.size} suggestion(s).\n`
    );
    process.exit(0);
  }

  // Build new entries markdown
  const timestamp = new Date().toISOString();
  const newEntriesLines = [];

  // If file doesn't exist yet, write a header
  if (!existingContent) {
    newEntriesLines.push(`# Improvement Suggestions — ${sprintId}`);
    newEntriesLines.push('');
    newEntriesLines.push('Generated by `suggest_improvements.mjs`. Append-only; IDs are stable.');
    newEntriesLines.push(`Vocabulary: Templates | Handoffs | Skills | Process | Tooling`);
    newEntriesLines.push('');
    newEntriesLines.push('---');
    newEntriesLines.push('');
  }

  for (const entry of newEntries) {
    newEntriesLines.push(`## ${entry.sugId} — ${entry.category}: ${entry.item}`);
    newEntriesLines.push(`${entry.hashMarker}`);
    newEntriesLines.push('');
    newEntriesLines.push(`**Category:** ${entry.category}`);
    newEntriesLines.push(`**Rating:** ${entry.rating}`);
    newEntriesLines.push(`**Added:** ${timestamp}`);
    newEntriesLines.push('');
    if (entry.notes && entry.notes !== '' && entry.notes !== '<notes>') {
      newEntriesLines.push(`**Context from report:** ${entry.notes}`);
      newEntriesLines.push('');
    }
    newEntriesLines.push('**Suggested action:**');
    newEntriesLines.push(`> _(to be filled by orchestrator or next sprint planning)_`);
    newEntriesLines.push('');
    newEntriesLines.push('---');
    newEntriesLines.push('');
  }

  const appendContent = newEntriesLines.join('\n');
  const finalContent = existingContent
    ? existingContent.trimEnd() + '\n\n' + appendContent
    : appendContent;

  atomicWrite(suggestionsFile, finalContent);

  process.stdout.write(
    `suggest_improvements: added ${newEntries.length} new suggestion(s) to ${suggestionsFile}\n`
  );
  for (const e of newEntries) {
    process.stdout.write(`  ${e.sugId}: [${e.category}] ${e.item} (${e.rating})\n`);
  }
}

main();
