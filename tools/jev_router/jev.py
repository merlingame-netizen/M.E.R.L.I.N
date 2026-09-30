"""Point d'entree du routeur local facon Jev.

  python tools/jev_router/jev.py serve [--port 8790]   # API HTTP locale
  python tools/jev_router/jev.py mcp                   # serveur MCP stdio (Copilot, Claude Desktop)
  python tools/jev_router/jev.py hook                  # hook UserPromptSubmit Claude Code (stdin JSON)
  python tools/jev_router/jev.py route "<demande>" [--task ID]
  python tools/jev_router/jev.py fail --task ID
  python tools/jev_router/jev.py decide <requete.json>
  python tools/jev_router/jev.py stats
  python tools/jev_router/jev.py eval [cases.json]            # mesure la justesse du decideur
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from router import describe, load_config, make_backend, record_failure, route, stats  # noqa: E402
from systemone import DecisionError, decide  # noqa: E402

HOOK_MIN_CHARS = 20
EVAL_CASES = Path(__file__).resolve().parent / "eval_cases.json"


def _hook() -> int:
    """Fail-open : ne bloque jamais le prompt, n'ecrit rien si le decideur est absent."""
    try:
        payload = json.loads(sys.stdin.read() or "{}")
        prompt = str(payload.get("prompt", ""))
        if len(prompt) < HOOK_MIN_CHARS or prompt[:1] in "*/!":
            return 0
        res = route(prompt, payload.get("session_id"))
        if res["source"] == "heuristic":
            return 0
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": describe(res)
            + " — Deleguer l'implementation a un sous-agent de ce modele ; ne monter qu'apres echec verifie.",
        }}, ensure_ascii=False))
    except Exception:  # noqa: BLE001 — un hook ne doit jamais casser la session
        pass
    return 0


def _eval(path: Path) -> dict:
    """Compare la lane choisie a la lane attendue (sans journaliser dans le state des taches)."""
    cases = json.loads(path.read_text(encoding="utf-8"))
    rows, exact = [], 0
    for case in cases:
        res = route(case["prompt"])
        exact += res["lane"] == case["expected"]
        rows.append({"expected": case["expected"], "got": res["lane"], "confidence": res["confidence"],
                     "source": res["source"], "prompt": case["prompt"][:60]})
    return {"exact": exact, "total": len(cases), "rows": rows}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="jev")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("serve")
    p.add_argument("--port", type=int, default=8790)
    sub.add_parser("mcp")
    sub.add_parser("hook")
    p = sub.add_parser("route")
    p.add_argument("prompt")
    p.add_argument("--task")
    p = sub.add_parser("fail")
    p.add_argument("--task", required=True)
    p = sub.add_parser("decide")
    p.add_argument("request_file")
    sub.add_parser("stats")
    p = sub.add_parser("eval")
    p.add_argument("cases", nargs="?", default=str(EVAL_CASES))
    args = ap.parse_args(argv)

    if args.cmd == "serve":
        from server import serve
        serve(args.port)
        return 0
    if args.cmd == "mcp":
        from mcp_server import run_stdio
        run_stdio()
        return 0
    if args.cmd == "hook":
        return _hook()
    try:
        if args.cmd == "route":
            res = route(args.prompt, args.task)
            print(describe(res))
        elif args.cmd == "fail":
            res = record_failure(args.task)
        elif args.cmd == "decide":
            req = json.loads(Path(args.request_file).read_text(encoding="utf-8"))
            res = decide(req, make_backend(load_config()))
        elif args.cmd == "eval":
            res = _eval(Path(args.cases))
        else:
            res = stats()
    except DecisionError as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 1
    print(json.dumps(res, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
