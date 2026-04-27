# ── Build stage ──────────────────────────────────────────────────────────────
FROM node:22-alpine AS build
WORKDIR /app

# pnpm via corepack (no global install, deterministic)
RUN corepack enable

# Copy manifest first for layer cache
COPY site/package.json site/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Copy site sources
COPY site/ ./

# Source PDFs at the repo root land in /app so the prebuild hook (cp ./*.pdf public/) finds them
COPY ClearGate_AI_Orchestration.pdf Tee-Mo_Sovereign_Intelligence.pdf ./

# Builds dist/ via the prebuild + astro build pipeline
RUN pnpm build

# ── Runtime stage ────────────────────────────────────────────────────────────
FROM nginx:alpine AS runtime
COPY site/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1/ || exit 1

# Coolify configuration:
#   Build context: repository root (NOT /site)
#   Dockerfile path: site/Dockerfile
#   Domain: hackathon2026.soula.ge → :80
#   Auto-deploy on push to main
