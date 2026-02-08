# Audit Candidates (Review Before Archiving)

Purpose
- List files that may be redundant, dev-only, or superseded.
- These are not archived yet. Review and confirm before moving.

Candidates and status
1) docs/10_llm/FOC_MerlinLLM.md
   - Reason: overlaps with STATE_Claude_MerlinLLM.md and SPEC_OptimisationLLM_MERLIN.md.
   - Status: moved to docs/old/10_llm/FOC_MerlinLLM.md.

2) docs/00_overview/godot-addon-readme.md
   - Reason: overlaps with installation-guide.md and command-reference.md.
   - Status: moved to docs/old/00_overview/godot-addon-readme.md.

3) docs/60_companion/BESTIOLE_TEST_MENU_SPEC.md
   - Reason: dev-only test menu spec; not part of final player flow.
   - Status: kept (still used for dev/test; marked dev-only).

4) docs/00_overview/command-reference.md
   - Reason: may contain outdated node paths and legacy commands.
   - Status: kept (canonical command list; header normalized).

5) docs/10_llm/STATE_Claude_MerlinLLM.md
   - Reason: snapshot-style state file; may need periodic refresh or archive by date.
   - Status: kept (current state reference; update date when revised).
