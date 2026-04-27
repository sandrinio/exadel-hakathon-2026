<!-- CLEARGATE:START -->
## 🔄 ClearGate Planning Framework

This repository uses **ClearGate** — a standalone planning framework for AI coding agents. ClearGate scaffolds *how work is planned* (proposals → epics → stories → sprints) and defines a four-agent loop for execution. ClearGate does not run builds, tests, or deployments; execution tooling remains the target repo's own.

**Session-start orientation (read in this order):**
1. `.cleargate/wiki/index.md` — compiled awareness layer (~3k tokens). Lists active sprint, in-flight items, recent shipments, open gates, planned work, and topic synthesis pages. **Read this first** to know what exists before grepping raw files. If absent, run `cleargate wiki build`.
2. `.cleargate/knowledge/cleargate-protocol.md` — delivery protocol (non-negotiable rules).
3. `.cleargate/FLASHCARD.md` — lessons tagged by topic (`#schema`, `#auth`, etc.). Grep for your area before starting.

**Triage first, draft second.** Every user request gets classified (Epic / Story / CR / Bug / Pull / Push) *before* any drafting. If the type is ambiguous, ask ONE targeted question — do not guess.

**Duplicate check before drafting.** Before drafting a Proposal or work item, grep `.cleargate/delivery/archive/` + `.cleargate/FLASHCARD.md` for similar past work. If you find overlap, surface it as a one-liner (*"This is very close to STORY-003-05 shipped in SPRINT-01 — are you extending it or redoing it?"*) instead of drafting a duplicate.

**Halt at gates.** You halt at Gate 1 (Proposal approval) and Gate 2 (Ambiguity resolution) and wait for explicit human sign-off. You never call `cleargate_push_item` without `approved: true` (hard reject) and explicit human confirmation. Readiness gates (`cached_gate_result.pass`) are advisory by default — the push proceeds and the item body receives an `[advisory: gate_failed — <criteria>]` prefix; opt into hard-reject via `STRICT_PUSH_GATES=true` on the MCP server.

**Drafting work items:**
- Use the templates in `.cleargate/templates/` (`proposal.md`, `epic.md`, `story.md`, `CR.md`, `Bug.md`, `Sprint Plan Template.md`, `initiative.md`).
- Save drafts to `.cleargate/delivery/pending-sync/{TYPE}-{ID}-{Name}.md`.
- After `cleargate_push_item` returns a Remote ID, update the frontmatter AND move the file to `.cleargate/delivery/archive/` — these two happen atomically, never one without the other.
- **Story granularity.** When decomposing an epic into stories, run the Granularity Rubric at the top of `story.md`. If a candidate story trips any signal (unrelated goals joined, >5 Gherkin scenarios, subsystems span, L4 complexity), emit two stories with consecutive IDs instead. Splits and merges are free at decomposition time — no remote IDs exist yet.

**Four-agent loop (roles in `.claude/agents/`):**
- `architect.md` — one plan per milestone; no production code.
- `developer.md` — one Story end-to-end; one commit per Story; runs typecheck + tests before commit.
- `qa.md` — independent verification gate; re-runs checks; never commits, never edits.
- `reporter.md` — one sprint retrospective at sprint end; synthesizes token ledger + git log + flashcards into `REPORT.md`.

**Conversational style.** Keep replies terse. Details live in the work-item file and `REPORT.md`, not in chat. State results and next steps; skip narration of your own thought process.

**Support infrastructure.** Flashcard protocol: `.claude/skills/flashcard/SKILL.md`. Token-ledger hook: `.claude/hooks/token-ledger.sh`, wired via `.claude/settings.json` (SubagentStop) — auto-logs agent cost per sprint for the Reporter.

**Cross-project orchestration.** When running an orchestrator from one project's repo against another project's sprint tree, export `ORCHESTRATOR_PROJECT_DIR=/absolute/path/to/target/repo` in the shell before launching the session. Overrides `CLAUDE_PROJECT_DIR`; sentinel + ledger writes route into the target's `.cleargate/sprint-runs/` tree. If the target has no `.cleargate/sprint-runs/.active` sentinel, writes land in the target's `_off-sprint` bucket — not the orchestrator's own repo.

**Project overrides.** Content OUTSIDE this `<!-- CLEARGATE:START -->...<!-- CLEARGATE:END -->` block takes precedence where it conflicts with ClearGate defaults.

**Scope reminder.** ClearGate is a *planning* framework. It scaffolds how work gets planned and how the four-agent loop runs. It does not replace your project's build system, CI, test runner, or deployment tooling.
<!-- CLEARGATE:END -->
