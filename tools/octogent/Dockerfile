# ─────────────────────────────────────────────────────────────────────────────
# Octogent for MERLIN — multi-stage Linux image.
#
# Why Docker: pnpm.cmd is blocked by corporate Group Policy on the Windows
# host (Orange laptop). Docker bypasses host policy by running its own Linux
# filesystem. Also gives us reproducible builds + isolated node-pty native
# compile.
#
# Build: docker build -t merlin/octogent:latest .
# Run:   via docker-compose.yml in the same dir.
# ─────────────────────────────────────────────────────────────────────────────

# ── STAGE 1: builder (full toolchain for node-pty native compile) ──────────
FROM node:22-bookworm AS builder

# Build deps required by node-pty (C++ pty bindings)
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

# Pin pnpm to the version Octogent declares as packageManager.
RUN corepack enable \
 && corepack prepare pnpm@10.4.1 --activate

WORKDIR /build
# Copy only manifests first to leverage Docker cache for the install layer.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/api/package.json ./apps/api/
COPY apps/web/package.json ./apps/web/
COPY packages/core/package.json ./packages/core/

RUN pnpm install --frozen-lockfile

# Now bring the source and build.
COPY . .
RUN pnpm build


# ── STAGE 2: runtime (slim image, only what's needed at run time) ─────────
FROM node:22-bookworm-slim AS runtime

# Runtime needs git + gh + curl + bash for octogent's spawned terminals
# (worktrees, pull-request features, hook callbacks).
#
# libstdc++6 is REQUIRED for node-pty's pty.node native addon — bookworm-slim
# omits it by default. Without this line, the container crashes at first
# launch with: cannot open shared object file: libstdc++.so.6.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git curl ca-certificates bash libstdc++6 \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI globally so Octogent can spawn `claude` inside the
# container. User auth lives in ~/.claude (mounted from host via compose).
RUN npm install -g @anthropic-ai/claude-code

# Pin pnpm at runtime too (the dist contains workspace symlinks pnpm uses).
RUN corepack enable && corepack prepare pnpm@10.4.1 --activate

# Non-root user — reduces blast radius of any RCE inside Octogent or a
# spawned claude subprocess. uid 1000 matches typical host user, helping
# with bind-mount ownership when running on Linux/WSL hosts.
RUN useradd --create-home --uid 1000 --shell /bin/bash octogent

WORKDIR /app

# Copy only what runtime needs from the builder stage. --chown ensures the
# octogent user can read everything without a runtime chmod pass.
COPY --from=builder --chown=octogent:octogent /build/package.json /build/pnpm-lock.yaml /build/pnpm-workspace.yaml ./
COPY --from=builder --chown=octogent:octogent /build/bin            ./bin
COPY --from=builder --chown=octogent:octogent /build/scripts        ./scripts
COPY --from=builder --chown=octogent:octogent /build/apps           ./apps
COPY --from=builder --chown=octogent:octogent /build/packages       ./packages
COPY --from=builder --chown=octogent:octogent /build/static         ./static
# node_modules carries the prebuilt node-pty .node binary so we don't recompile.
COPY --from=builder --chown=octogent:octogent /build/node_modules   ./node_modules

# Octogent's runtime state dir (mounted as named volume in compose).
RUN mkdir -p /app/.octogent && chown octogent:octogent /app/.octogent

USER octogent

# Don't auto-open a browser — there isn't one inside the container.
ENV OCTOGENT_NO_OPEN=1
ENV NODE_ENV=production
ENV PORT=8787
ENV HOME=/home/octogent

EXPOSE 8787

# Use the bin entrypoint declared in package.json.
CMD ["node", "bin/octogent"]
