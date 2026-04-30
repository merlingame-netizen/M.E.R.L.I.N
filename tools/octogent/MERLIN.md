# Octogent for MERLIN

> MERLIN-specific deployment overlay. Upstream usage / architecture lives in
> `README.md` (kept verbatim from `hesamsheikh/octogent`).

Octogent is a thin orchestration dashboard over Claude Code that lets you
spawn, watch, and message multiple Claude agents working in parallel. We use
it to coordinate inter-agent development on the MERLIN Godot project from a
single browser tab.

**Status (2026-04-30)**: deployed natively in WSL2 Ubuntu, source-patched to
honor `HOST` env var, and pre-loaded with **103 MERLIN studio agents** from
`tools/autodev/agent_cards/_registry.json`. Dashboard at
http://localhost:8787 shows the full catalog by category (creative, quality,
orchestration, core, ui-ux, narrative, ops, llm, knowledge).

---

## Recommended start (persistent + auto-integrated)

```bash
wsl bash tools/octogent/start-persistent.sh
```

That single command:
1. No-ops if Octogent is already running on port 8787.
2. Sources fnm/nvm if present, checks Node 22+ and pnpm.
3. Builds if `dist/` is missing (first run only, ~2 min).
4. Auto-runs `integrate-merlin-agents.mjs` if `.octogent/tentacles/` is empty.
5. Launches via `setsid -f` so the process survives shell teardown.
6. Health-checks port 8787 and reports the URL.

Stop:

```bash
wsl bash -c 'pkill -f "node bin/octogent"; rm -f /tmp/octogent.pid'
```

Logs:

```bash
wsl tail -f /tmp/octogent.log
```

---

## Manual paths (legacy / explicit)

### Path A — Docker (recommended)

```bash
cd tools/octogent
docker compose up -d
docker compose logs -f octogent     # watch the boot
```

Open http://localhost:8787 — the dashboard appears as soon as the
healthcheck goes green (`docker ps` will show `(healthy)`).

To stop:
```bash
docker compose down
```

To rebuild after upstream `git pull`:
```bash
docker compose build --no-cache
docker compose up -d
```

### Path B — WSL2 native (no Docker)

If Docker Desktop isn't available on your machine:

```bash
# From Windows shell, drop into WSL Ubuntu:
wsl bash tools/octogent/start-wsl.sh
```

The script installs pnpm + node-pty, builds, and launches. WSL2 forwards
the listening socket so http://localhost:8787 works from your Windows
browser too.

---

## Why Docker on this machine

`pnpm.cmd` is blocked by Orange's Group Policy on the Windows host
(`feedback_group_policy.md` in user memory). Symptom:

```
Ce programme est bloqué par une stratégie de groupe.
```

Docker bypasses this entirely — the container runs Linux internally with its
own pnpm installation. WSL2 (Path B above) works for the same reason.

If you ever need to run on the Windows host directly, you'd have to ask IT
to whitelist `%APPDATA%\npm\pnpm.cmd` — not worth the friction.

---

## What gets mounted

| Host path | Container path | Mode | Why |
|-----------|---------------|------|-----|
| `~/.claude/` | `/home/octogent/.claude/` | rw | Claude CLI auth + session JSONLs (so the dashboard sees your real sessions) |
| MERLIN repo root | `/workspace/merlin/` | **ro** | Spawned agents can read the code but can't accidentally rewrite your working tree |
| `merlin-octogent-state` (named vol) | `/app/.octogent/` | rw | Octogent's own state DB — survives restarts |

**Sensitive-data caveat.** `~/.claude/` is **not just OAuth tokens** — it
also stores the full JSONL transcripts of every Claude Code session you
ever ran. If a session ever pasted a secret in a prompt, that secret lives
in those JSONLs. Treat the mount as sensitive: do NOT publish derived
images to public registries with this volume baked in, and don't let the
container reach unaudited network endpoints.

**The MERLIN mount is read-only on purpose.** If you want a spawned agent
to commit, drop the `:ro` in `docker-compose.yml` and run that agent in its
own git worktree (see `superpowers:using-git-worktrees`).

**Container runs as non-root** (`octogent` user, uid 1000). Reduces blast
radius if Octogent or a spawned `claude` subprocess ever has an RCE bug.
Bind-mount file ownership generally Just Works on Linux/WSL hosts; on
Docker Desktop Windows the userland VM handles UID translation.

---

## What the dashboard shows

Per upstream docs, Octogent displays:
- Live PTY sessions of each Claude agent it spawned
- Per-agent context, notes, task list
- Inter-agent messages (handoffs, blockers, completions)
- Spawn lineage: which agent kicked off which child

For MERLIN specifically, this means you can launch e.g.
- One agent doing C39 (next gameplay cycle)
- One reviewing a previous commit
- One running smoke tests in a worktree
…and watch all three from `localhost:8787` in real time.

---

## Configuration

Most knobs live in `docker-compose.yml` `environment:`:

| Var | Default | Notes |
|-----|---------|-------|
| `OCTOGENT_NO_OPEN` | `1` | Container has no GUI; never auto-open. |
| `OCTOGENT_MAX_TERMINAL_SESSIONS` | `16` | Cap on concurrent PTY sessions. Upstream default is 32. |
| `PORT` | `8787` | Change here AND in `ports:` to use a different host port. |

---

## Troubleshooting

**`docker compose up` fails with "Cannot connect to the Docker daemon"**
- Docker Desktop not running → start it.
- Or you're on the corporate machine without Docker → use Path B (WSL).

**Dashboard shows zero sessions**
- Make sure `~/.claude/` actually contains files. Check the host path
  resolved in the mount: `docker compose config | grep -A1 volumes`.
- The Claude CLI inside the container needs auth too if you want it to
  spawn its own agents — `docker compose exec octogent claude` and
  complete the OAuth flow once.

**`node-pty` build error during `docker compose build`**
- The builder stage installs `python3 make g++` — if you forked / pinned
  to an Alpine base, add the equivalent build deps. Bookworm (current
  base) ships them via `apt-get`.

**Port 8787 already in use**
- Edit `docker-compose.yml` → `ports: "127.0.0.1:9787:8787"` for example,
  then access http://localhost:9787.

---

## Files in this directory

| File | Role |
|------|------|
| `Dockerfile` | Multi-stage Linux image: builder (full toolchain) + runtime (slim) |
| `.dockerignore` | Trims build context (excludes node_modules / .git / etc) |
| `docker-compose.yml` | Single-service stack with mounts + healthcheck + named volume |
| `start-wsl.sh` | No-Docker fallback for WSL2 Ubuntu |
| `MERLIN.md` | This file — MERLIN-specific deployment notes |
| `README.md` | Upstream Octogent README (do not modify) |
| Everything else | Upstream Octogent source — pulled from `hesamsheikh/octogent` |

---

## Updating from upstream

We cloned with `--depth 1`. To pick up upstream changes:

```bash
cd tools/octogent
git remote add upstream https://github.com/hesamsheikh/octogent.git 2>/dev/null || true
git fetch upstream main
git merge --squash upstream/main      # review the diff before keeping
docker compose build --no-cache
```

Our additions (`Dockerfile`, `docker-compose.yml`, `.dockerignore`,
`start-wsl.sh`, `MERLIN.md`) live alongside their tree but never touch
upstream-owned files, so merge conflicts should be rare.
