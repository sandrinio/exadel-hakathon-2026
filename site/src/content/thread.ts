export type ThreadRow = {
  axis: string;
  cleargate: string;
  teemo: string;
  exa: string;
};

export const thread: readonly ThreadRow[] = [
  {
    axis: "Layer",
    cleargate: "Agent orchestration",
    teemo: "Workspace AI fabric",
    exa: "Org-wide knowledge brain",
  },
  {
    axis: "Surface",
    cleargate: "CLI + MCP",
    teemo: "Slack + MCP",
    exa: "Slack + MCP",
  },
  {
    axis: "Knowledge model",
    cleargate: "Karpathy Wiki (index.md)",
    teemo: "Karpathy Parity synthesis",
    exa: "LLM-Wiki structured graph",
  },
  {
    axis: "Trust model",
    cleargate: "Human-gated, Git-attributed",
    teemo: "BYOK + zero-state",
    exa: "Per-project isolation",
  },
  {
    axis: "Status",
    cleargate: "Planning framework, ready to use",
    teemo: "Sovereign engine, BYOK",
    exa: "Production-ready",
  },
];
