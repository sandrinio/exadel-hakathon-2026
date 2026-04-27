export type Solution = {
  id: "cleargate" | "teemo" | "exa";
  name: string;
  tagline: string;
  pitch: string;
  bullets: { title: string; body: string }[];
  visuals: string[];
  accent: "cleargate" | "teemo" | "exa";
  cta?: { label: string; href: string };
};

export const solutions: readonly Solution[] = [
  {
    id: "cleargate",
    name: "ClearGate",
    tagline: "Bridging vibe coding and enterprise delivery.",
    pitch:
      "ClearGate is the disciplined orchestration framework that turns Claude Code from a chaotic junior developer into an enterprise-ready engineering team. It is a planning framework, not a build tool — it scaffolds how AI agents plan and ship work, then hands execution back to your existing CI/test/deploy stack.",
    bullets: [
      {
        title: "Compiled Awareness (Karpathy Wiki)",
        body: "A PostToolUse hook rebuilds a ~3k-token index.md on every edit, so every session starts with full situational context instead of blind grepping.",
      },
      {
        title: "Three Ambiguity Gates",
        body: "Proposal → Epic → Story. Every phase requires human ratification (approved: true) before the AI can proceed.",
      },
      {
        title: "Four-Agent Execution Loop",
        body: "Architect (one milestone plan) → Developer (one story per commit) → QA (independent verification) → Reporter (sprint retrospective). Sub-agents never speak directly.",
      },
      {
        title: "Cryptographic Audit Trails",
        body: "Every Proposal, Epic, and Story is tied to a Git SHA — exact attribution of AI work, with explicit version control on every artifact.",
      },
      {
        title: "MCP Sync to Linear / Jira / GitHub Projects",
        body: "Local .cleargate/delivery/pending-sync/ is the source of truth; once approved, the MCP adapter pushes ratified Epics and Stories into your existing PM stack.",
      },
    ],
    visuals: [
      "/assets/cleargate/01-cover.jpg",
      "/assets/cleargate/02-vibe-trap.jpg",
      "/assets/cleargate/03-pipeline.jpg",
      "/assets/cleargate/04-gates.jpg",
      "/assets/cleargate/05-four-agents.jpg",
      "/assets/cleargate/06-karpathy-wiki.jpg",
      "/assets/cleargate/07-vs-vibe.jpg",
      "/assets/cleargate/08-ledger.jpg",
    ],
    accent: "cleargate",
  },
  {
    id: "teemo",
    name: "Tee-Mo",
    tagline: "Secure, Slack-native collaborative AI for the modern workspace.",
    pitch:
      "Tee-Mo replaces the single-player browser-tab bottleneck with a multiplayer workspace where AI lives directly inside Slack channels and the entire team shares, refines, and acts on the same context in real time.",
    bullets: [
      {
        title: "Read",
        body: "Deep context from Google Drive and local files via auto-generated, self-healing file catalogs — no stale caches, no shredded RAG chunks.",
      },
      {
        title: "Act",
        body: "External execution via MCP — query GitHub, draft Jira tickets, build synthesis pages directly in the workspace wiki (Karpathy Parity).",
      },
      {
        title: "Automate",
        body: "Scheduled cron tasks deliver background intelligence straight to Slack, with rich execution history and safe dry-run previews.",
      },
      {
        title: "Semantic Routing, not RAG",
        body: 'The "Librarian" model: read AI-generated catalogs of your 15 most critical files, select the right document, and read it entirely fresh. Perfect accuracy, zero staleness.',
      },
      {
        title: "Bring Your Own Key (BYOK)",
        body: "You hold the API keys; Tee-Mo is purely the engine. Every credential is encrypted at rest with AES-256-GCM. Zero in-process state.",
      },
      {
        title: "Channel-Level Isolation",
        body: "Each channel gets its own dedicated brain wired to its own documents and tools. Engineering's bot physically cannot reach Marketing's files.",
      },
    ],
    visuals: [
      "/assets/teemo/01-cover.jpg",
      "/assets/teemo/02-multiplayer.jpg",
      "/assets/teemo/03-zero-friction.jpg",
      "/assets/teemo/04-woven-thread.jpg",
      "/assets/teemo/05-read-act-automate.jpg",
      "/assets/teemo/06-rag-vs-router.jpg",
      "/assets/teemo/07-byok.jpg",
      "/assets/teemo/08-isolation.jpg",
    ],
    accent: "teemo",
  },
  {
    id: "exa",
    name: "Exa",
    tagline: "An AI-native workspace companion that lives inside Slack.",
    pitch:
      "Exa is the production-ready Slack-native AI brain we built for Exadel itself. Engineers @mention Exa in any channel and ask questions grounded in the team's own documents, PRs, and pipelines.",
    bullets: [
      {
        title: "Zero-Setup Ingestion",
        body: "Drop documents into Google Drive — Exa parses, indexes, and syncs PDFs, Word docs, spreadsheets, and presentations. No engineering required.",
      },
      {
        title: "Project-Isolated Knowledge",
        body: "Every project gets its own secure data boundary. Team A cannot see Team B's docs.",
      },
      {
        title: "PR & Pipeline Intelligence",
        body: "Real-time Slack alerts for PR reviews, approvals, and merge conflicts. Smart batching of CI/CD failures cuts noise without burying real breakage.",
      },
      {
        title: "Daily & Weekly Digests",
        body: "Morning summaries of merged PRs, open reviews, pipeline status, and document updates. Leadership gets clean velocity reports without status-meeting overhead.",
      },
      {
        title: "LLM-Wiki Knowledge Architecture",
        body: "Documents aren't a messy pile of text — they're parsed into summaries, concepts, entities, and cross-references, structured for LLM-native retrieval.",
      },
      {
        title: "Modular, Cloud-Native Microservices",
        body: "Slack bot, sync engine, LLM backend, question workers, batch processors — each a standalone service. Runs on a single VM (~$13/month on GCP) or scales to Kubernetes.",
      },
    ],
    visuals: [
      "/assets/exa/01-header.png",
      "/assets/exa/02-speak.png",
      "/assets/exa/03-pr.png",
      "/assets/exa/04-digest.png",
      "/assets/exa/05-llmwiki.png",
      "/assets/exa/06-arch-main.png",
      "/assets/exa/07-arch-scale.png",
    ],
    accent: "exa",
    cta: {
      label: "View on GitHub",
      href: "https://github.com/eugene-burachevskiy/exa-slack-agent",
    },
  },
];
