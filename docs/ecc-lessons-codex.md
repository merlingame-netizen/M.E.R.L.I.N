# ECC Lessons for Claude and Codex

Date: 2026-02-12
Source: https://github.com/affaan-m/everything-claude-code

## What Was Deployed

- Claude marketplace added: `everything-claude-code`
- Claude plugin installed: `everything-claude-code@everything-claude-code` (user scope)
- Claude rules synced to `~/.claude/rules/`:
  - `common/`
  - `typescript/`
  - `python/`
  - `golang/`

## Core Lessons Extracted

1. Plan-first gates reduce rework on complex tasks.
2. Severity-first review output improves decision speed.
3. TDD + verification loops create predictable delivery quality.
4. Iterative retrieval solves the context problem in large codebases.
5. Continuous learning should be atomic, confidence-weighted, and auditable.

## Codex Adaptation

Created Codex skills in `~/.codex/skills/`:

- `ecc-orchestrate`
  - Planning + phased execution + structured handoffs
- `ecc-review`
  - Security and quality review, severity-first reporting
- `ecc-tdd-verify`
  - RED/GREEN/REFACTOR + build/type/lint/test/security verification
- `ecc-continuous-learning`
  - Instinct extraction and confidence-based evolution
- `ecc-agent-profiles`
  - Emulates ECC specialist agents through profile routing

Each skill references mirrored upstream ECC materials in its `references/` folder.

## Auto-Update Design

Script: `C:\Users\PGNK2128\.claude\scripts\ecc-sync.ps1`

The sync script does all of the following in one run:
- Update Claude marketplaces
- Install/update ECC plugin
- Resync Claude rules from upstream ECC repo
- Resync Codex skill references from upstream ECC repo
- Persist sync metadata in:
  - `C:\Users\PGNK2128\.codex\vendor_imports\ecc-memory\last-sync.json`

Scheduled task:
- Name: `ECC-Sync-Daily`
- Frequency: Daily at `09:00`
- Command: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Users\PGNK2128\.claude\scripts\ecc-sync.ps1`

## Operational Notes

- Claude plugin installation on this machine requires setting `TEMP/TMP` under `~/.claude/plugins/temp` to avoid Windows `EXDEV` rename issues.
- Rules are still synced manually because Claude plugins do not distribute rules automatically.
- Codex skills were validated with `quick_validate.py` from the `skill-creator` system skill.
