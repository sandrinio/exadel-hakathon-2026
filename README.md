# Slop-Masters @ Exadel Code Fest 2026

> Three solutions. One thesis: **AI is only as good as the structure you give it.**

We are a three-person team that spent the hackathon attacking the same hard problem from three different altitudes: **how do you make AI agents reliable enough for real enterprise work?** Each of us led a solution. All three converge on the same architectural idea — **compiled, structured knowledge wins over blind retrieval** — but they apply it at different layers of the stack.

---

## The Team

| | | |
|:---|:---|:---|
| **Eugene Burachevskiy** | `eburachevskiy@exadel.com` | Lead — Exa |
| **Sandro Suladze** | `ssuladze@exadel.com` | Lead — ClearGate |
| **Christophe Domingos** | `cdomingos@exadel.com` | Lead — Tee-Mo |

## How We Collaborated

We deliberately split into three parallel tracks instead of converging on a single product. Each lead owned end-to-end design and shipping for one solution; the rest of the team rotated in as reviewers, second pairs of eyes, and architecture sparring partners.

The split worked because we noticed a shared pattern early: every "AI agent gone wrong" story we kept seeing in our day jobs traced back to the same root — **the agent didn't know what it didn't know.** Fragmented files, blind grepping, hallucinated context, no audit trail. So we agreed on a thesis, picked three layers of the stack to attack it on, and went heads-down. We re-synced daily to share what was working.

The three solutions ended up rhyming on purpose. All three lean on **Karpathy's LLM-Wiki concept** (compiled awareness pages instead of raw retrieval), all three use **MCP (Model Context Protocol)** as the integration surface, and all three treat structured markdown as the source of truth.

---

## What We Built

### 1. ClearGate — AI Orchestration Framework
*Bridging vibe coding and enterprise delivery.*

ClearGate is the disciplined orchestration framework that turns Claude Code from a chaotic junior developer into an enterprise-ready engineering team. It is **a planning framework, not a build tool** — it scaffolds *how* AI agents plan and ship work, then hands execution back to your existing CI/test/deploy stack.

**Core ideas:**
- **Compiled Awareness (Karpathy Wiki).** A `PostToolUse` hook rebuilds a ~3k-token `index.md` on every edit, so every session starts with full situational context instead of blind grepping.
- **Three Ambiguity Gates.** Proposal → Epic → Story. Every phase requires human ratification (`approved: true`) before the AI can proceed.
- **Four-Agent Execution Loop.** Architect (one milestone plan) → Developer (one story per commit) → QA (independent verification) → Reporter (sprint retrospective). Sub-agents never speak directly; the orchestrator dispatches and aggregates.
- **Cryptographic Audit Trails.** Every Proposal, Epic, and Story is tied to a Git SHA — exact attribution of AI work, with explicit version control (v1, v2, v3) on every artifact.
- **MCP Sync to Linear / Jira / GitHub Projects.** Local `.cleargate/delivery/pending-sync/` is the source of truth; once approved, the MCP adapter pushes ratified Epics and Stories into your existing PM stack.

> *One command. Zero chaos. Ready for the enterprise standard.*

See: `ClearGate_AI_Orchestration.pdf`

---

### 2. Tee-Mo — The Sovereign Team Brain
*Secure, Slack-native collaborative AI for the modern workspace.*

Tee-Mo replaces the single-player browser-tab bottleneck with a **multiplayer workspace** where AI lives directly inside Slack channels and the entire team shares, refines, and acts on the same context in real time.

**Core ideas:**
- **Read.** Deep context from Google Drive and local files via auto-generated, self-healing file catalogs — no stale caches, no shredded RAG chunks.
- **Act.** External execution via MCP — query GitHub, draft Jira tickets, build synthesis pages directly in the workspace wiki ("Karpathy Parity").
- **Automate.** Scheduled cron tasks deliver background intelligence straight to Slack, with rich execution history and safe dry-run previews. Move from reactive queries to proactive multipliers.
- **Semantic Routing, not RAG.** The "Librarian" model: read AI-generated catalogs of your 15 most critical files, select the right document, and read it *entirely fresh*. Perfect accuracy, zero staleness — vs. industry-standard "Shredder" RAG that returns mismatched paragraphs and hallucinations.
- **Bring Your Own Key (BYOK).** You hold the API keys; Tee-Mo is purely the engine. Every Slack token, API key, and Drive credential is encrypted at rest with AES-256-GCM. Zero in-process state — memory is wiped the moment a Slack message is delivered.
- **Channel-Level Isolation.** Each channel gets its own dedicated brain wired to its own documents and tools. Engineering's bot physically cannot reach Marketing's files. Strict departmental privacy without complex permission matrices.

> *Not a destination. The connective tissue of your workspace.*

See: `Tee-Mo_Sovereign_Intelligence.pdf`

---

### 3. Exa — Your Organization's Collective Intelligence
*An AI-native workspace companion that lives inside Slack.*

Exa is the production-ready Slack-native AI brain we built for Exadel itself. Engineers `@mention` Exa in any channel and ask questions grounded in the team's own documents, PRs, and pipelines.

**Core ideas:**
- **Zero-Setup Ingestion.** Drop documents into Google Drive — Exa parses, indexes, and syncs PDFs, Word docs, spreadsheets, and presentations. No engineering required.
- **Project-Isolated Knowledge.** Every project gets its own secure data boundary. Team A cannot see Team B's docs.
- **PR & Pipeline Intelligence.** Real-time Slack alerts for PR reviews, approvals, and merge conflicts. Smart batching of CI/CD failures cuts noise without burying real breakage.
- **Daily & Weekly Digests.** Morning summaries of merged PRs, open reviews, pipeline status, and document updates. Leadership gets clean velocity reports without status-meeting overhead.
- **LLM-Wiki Knowledge Architecture.** Documents aren't a messy pile of text — they're parsed into summaries, concepts, entities, and cross-references, structured for LLM-native retrieval.
- **Modular, Cloud-Native Microservices.** Slack bot, sync engine, LLM backend, question workers, batch processors — each a standalone service. Swap Slack for Teams/Telegram/Discord with a single service replacement. Runs on a single VM (~$13/month on GCP) for small teams or scales to Kubernetes for enterprise.

> *Your company's second brain — always on, always informed, always helpful.*

Repo: [github.com/eugene-burachevskiy/exa-slack-agent](https://github.com/eugene-burachevskiy/exa-slack-agent)

---

## The Common Thread

| | ClearGate | Tee-Mo | Exa |
|:---|:---|:---|:---|
| **Layer** | Agent orchestration | Workspace AI fabric | Org-wide knowledge brain |
| **Surface** | CLI + MCP | Slack + MCP | Slack + MCP |
| **Knowledge model** | Karpathy Wiki (`index.md`) | Karpathy Parity synthesis | LLM-Wiki structured graph |
| **Trust model** | Human-gated, Git-attributed | BYOK + zero-state | Per-project isolation |
| **Status** | Planning framework, ready to use | Sovereign engine, BYOK | Production-ready |

Three different altitudes, one philosophy: **structure beats magic.** Give an AI agent compiled awareness, hard gates, and a clean integration surface — and it stops being a fast, unpredictable tool and starts being a disciplined teammate.

---

<sub>Built with passion at **Exadel Code Fest 2026** by the **Slop-Masters** team.</sub>
