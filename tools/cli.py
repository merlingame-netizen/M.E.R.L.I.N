#!/usr/bin/env python3
"""
CLI-Anything — Unified CLI dispatcher for Godot, PowerBI, Outlook.

Usage:
    python tools/cli.py <tool> <action> [options]
    python tools/cli.py --help
    python tools/cli.py godot --help
    python tools/cli.py godot validate
    python tools/cli.py godot export web
    python tools/cli.py godot test
    python tools/cli.py godot telemetry
    python tools/cli.py powerbi list-reports
    python tools/cli.py powerbi refresh <dataset_id>
    python tools/cli.py powerbi query --dax "EVALUATE {1}" --dataset <id>
    python tools/cli.py powerbi export <report_id> --format pdf
    python tools/cli.py powerbi open <pbix_path>
    python tools/cli.py outlook inbox --limit 10
    python tools/cli.py outlook search --query "rapport"
    python tools/cli.py outlook read --index 0
    python tools/cli.py outlook send --to "x@y.com" --subject "S" --body "B"
    python tools/cli.py dbeaver list-connections
    python tools/cli.py dbeaver list-tables --database prod_app_bcv_vm_v
    python tools/cli.py dbeaver describe --table prod_app_bcv_vm_v.v_org_r_compte_client_c
    python tools/cli.py dbeaver query --sql "SELECT * FROM prod_app_bcv_vm_v.v_org_r_compte_client_c" --limit 20
    python tools/cli.py dbeaver profile --table prod_app_bcv_vm_v.v_org_r_compte_client_c
    python tools/cli.py bigquery list-datasets
    python tools/cli.py bigquery list-tables --dataset my_dataset
    python tools/cli.py bigquery describe --dataset my_dataset --table my_table
    python tools/cli.py bigquery query --sql "SELECT * FROM proj.ds.t" --limit 50
    python tools/cli.py bigquery dry-run --sql "SELECT * FROM proj.ds.t"
    python tools/cli.py bigquery storage-info --dataset my_dataset --table my_table

Output: JSON by default. Use --human for pretty-printed output.
Exit code: 0 = success, 1 = error (for CI/AUTODEV integration).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

# Ensure project root is in sys.path regardless of invocation directory
_HERE = Path(__file__).resolve().parent        # tools/
_ROOT = _HERE.parent                           # project root
for _p in (_ROOT, _HERE):
    _s = str(_p)
    if _s not in sys.path:
        sys.path.insert(0, _s)

TOOLS = ["godot", "powerbi", "outlook", "dbeaver", "ollama", "git", "bigquery", "office", "browser"]


# ── Tool loader (lazy import to avoid cross-tool dependencies) ────────────────

def _load_adapter(tool: str):
    if tool == "godot":
        from adapters.godot_adapter import GodotAdapter
        return GodotAdapter()
    if tool == "powerbi":
        from adapters.powerbi_adapter import PowerBIAdapter
        return PowerBIAdapter()
    if tool == "outlook":
        from adapters.outlook_adapter import OutlookAdapter
        return OutlookAdapter()
    if tool == "dbeaver":
        from adapters.dbeaver_adapter import DBeaverAdapter
        return DBeaverAdapter()
    if tool == "bigquery":
        from adapters.bigquery_adapter import BigQueryAdapter
        return BigQueryAdapter()
    if tool == "office":
        from adapters.office_adapter import OfficeAdapter
        return OfficeAdapter()
    if tool == "ollama":
        from adapters.ollama_adapter import OllamaAdapter
        return OllamaAdapter()
    if tool == "git":
        from adapters.git_adapter import GitAdapter
        return GitAdapter()
    if tool == "browser":
        from adapters.browser_adapter import BrowserAdapter
        return BrowserAdapter()
    raise ValueError(f"Unknown tool: {tool!r}. Available: {TOOLS}")


# ── CLI parser ────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="cli.py",
        description="CLI-Anything — Unified agent-native CLI dispatcher",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Run `cli.py <tool> --help` for tool-specific actions.",
    )
    parser.add_argument("tool", choices=TOOLS, help="Target tool")
    parser.add_argument("action", nargs="?", default="help", help="Action to execute")
    parser.add_argument("--human", action="store_true", help="Pretty-print output (default: JSON)")
    parser.add_argument("--json", dest="json_out", action="store_true", default=True,
                        help="Machine-readable JSON output (default)")
    # Godot args
    parser.add_argument("preset", nargs="?", default=None,
                        help="[godot export] Export preset name (e.g. 'web', 'windows')")
    parser.add_argument("--step", type=int, default=None, help="[godot validate] Step number (0-5)")
    parser.add_argument("--scene", default=None, help="[godot smoke] Scene path to test")
    # PowerBI args
    parser.add_argument("--dataset", default=None, help="[powerbi] Dataset ID")
    parser.add_argument("--report", default=None, help="[powerbi] Report ID")
    parser.add_argument("--dax", default=None, help="[powerbi query] DAX query string")
    parser.add_argument("--format", default="PDF", help="[powerbi export] Format: PDF, XLSX, PNG")
    parser.add_argument("--workspace", default=None, help="[powerbi] Workspace/group ID")
    parser.add_argument("--pbix", default=None, help="[powerbi open/extract] .pbix file path")
    parser.add_argument("--out", default=None, help="[powerbi extract] Output directory")
    # Outlook args
    parser.add_argument("--to", default=None, help="[outlook send] Recipient(s)")
    parser.add_argument("--subject", default=None, help="[outlook send/new] Subject")
    parser.add_argument("--body", default=None, help="[outlook send/new/reply/forward] Body")
    parser.add_argument("--limit", type=int, default=10, help="[outlook inbox/search] Item count")
    parser.add_argument("--query", default=None, help="[outlook search] Search query")
    parser.add_argument("--index", type=int, default=0, help="[outlook read/reply/forward] Mail index")
    parser.add_argument("--reply-all", action="store_true", help="[outlook reply] Reply all")
    parser.add_argument("--attachments", nargs="*", default=None, help="[outlook send] Attachment paths")
    # DBeaver args
    parser.add_argument("--connection", default=None, help="[dbeaver] Connection ID (default: EDH_PRODv2)")
    parser.add_argument("--database", default=None, help="[dbeaver list-tables] Database/schema name")
    parser.add_argument("--table", default=None, help="[dbeaver describe/profile] Table name (schema.table)")
    parser.add_argument("--sql", default=None, help="[dbeaver query] SQL SELECT statement")
    # Office args
    parser.add_argument("--path", default=None, help="[office ppt-*] Path to .pptx file")
    parser.add_argument("--title", default=None, help="[office ppt-create/onenote-*] Title")
    parser.add_argument("--bullets", nargs="*", default=None, help="[office ppt-create] Bullet points")
    parser.add_argument("--notebook", default=None, help="[office onenote-sections] Notebook name or ID")
    parser.add_argument("--section", default=None, help="[office onenote-pages/create] Section name or ID")
    parser.add_argument("--page-id", default=None, help="[office onenote-read] Page ID")
    parser.add_argument("--body-html", default=None, help="[office onenote-create] HTML body content")
    # BigQuery args
    parser.add_argument("--project", default=None,
                        help="[bigquery] GCP project ID (default: ofr-ppx-propme-1-prd)")
    parser.add_argument("--dry-run", dest="dry_run", action="store_true", default=False,
                        help="[bigquery query] Estimate bytes scanned without executing")
    # Positional id (for powerbi refresh/export with positional dataset/report id)
    parser.add_argument("id", nargs="?", default=None, help="[powerbi] Resource ID (positional)")
    return parser


# ── Output ────────────────────────────────────────────────────────────────────

def print_result(result: dict, human: bool) -> None:
    if human:
        status = result.get("status", "?")
        tool = result.get("tool", "?")
        icon = "✓" if status == "ok" else "✗"
        print(f"{icon} [{tool}] {status.upper()}  ({result.get('duration_ms', 0)}ms)")
        data = result.get("data")
        if data:
            print(json.dumps(data, ensure_ascii=False, indent=2))
        if result.get("error"):
            print(f"  Error: {result['error']}")
        logs = result.get("logs", [])
        if logs:
            print("  Logs:")
            for line in logs:
                print(f"    {line}")
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2))


# ── Help ──────────────────────────────────────────────────────────────────────

def print_tool_help(tool: str) -> None:
    try:
        adapter = _load_adapter(tool)
        actions = adapter.list_actions()
        print(f"\n{tool.upper()} — available actions:\n")
        for action, desc in actions.items():
            print(f"  {action:<20} {desc}")
        print()
    except Exception as exc:
        print(f"Could not load {tool} adapter: {exc}")


# ── Main ──────────────────────────────────────────────────────────────────────

def main(argv: list[str] | None = None) -> int:
    parser = build_parser()

    # Support: cli.py godot --help (no action)
    if argv is None:
        argv = sys.argv[1:]
    if len(argv) >= 1 and argv[0] in TOOLS and (len(argv) == 1 or argv[1] in ("--help", "-h")):
        print_tool_help(argv[0])
        return 0

    args = parser.parse_args(argv)

    if args.action in ("help", "--help", "-h"):
        print_tool_help(args.tool)
        return 0

    # Build kwargs from parsed args
    kwargs: dict[str, Any] = {
        "preset": args.preset,
        "step": args.step,
        "scene": args.scene,
        "dataset": args.dataset or args.id,
        "report": args.report or args.id,
        "dax": args.dax,
        "format": args.format,
        "workspace": args.workspace,
        "pbix": args.pbix or args.id,
        "out": args.out,
        "to": args.to,
        "subject": args.subject,
        "body": args.body,
        "limit": args.limit,
        "query": args.query,
        "index": args.index,
        "reply_all": args.reply_all,
        "attachments": args.attachments,
        # DBeaver
        "connection": args.connection,
        "database": args.database,
        "table": args.table,
        "sql": args.sql,
        # Office
        "path": args.path,
        "title": args.title,
        "bullets": args.bullets,
        "notebook": args.notebook,
        "section": args.section,
        "page_id": getattr(args, "page_id", None),
        "body_html": getattr(args, "body_html", None),
        # BigQuery
        "project": getattr(args, "project", None),
        "dry_run": getattr(args, "dry_run", False) or None,
    }
    # Remove None values to keep adapter signatures clean
    kwargs = {k: v for k, v in kwargs.items() if v is not None}

    try:
        adapter = _load_adapter(args.tool)
    except ValueError as exc:
        print(json.dumps({"status": "error", "error": str(exc)}))
        return 1

    result = adapter.execute(args.action, **kwargs)
    print_result(result, human=args.human)
    return 0 if result.get("status") == "ok" else 1


if __name__ == "__main__":
    sys.exit(main())
