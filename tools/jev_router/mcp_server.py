"""Serveur MCP stdio minimal (sans dependance) : expose le routeur a Copilot (VS Code),
Claude Desktop ou tout client MCP local.

Outils : route_task, report_failure, decide, router_stats.
"""

from __future__ import annotations

import json
import sys

from router import describe, load_config, make_backend, record_failure, route, stats
from systemone import DecisionError, decide

PROTOCOL_VERSION = "2025-06-18"

TOOLS = [
    {
        "name": "route_task",
        "description": "A appeler AVANT toute implementation : classe la tache (small/medium/high/escalate) "
                       "et renvoie le modele le moins cher suffisant pour chaque outil.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "prompt": {"type": "string", "description": "La demande de l'utilisateur"},
                "task_id": {"type": "string", "description": "Identifiant pour suivre retries/escalades"},
            },
            "required": ["prompt"],
        },
    },
    {
        "name": "report_failure",
        "description": "Signale un cycle echoue (tests/build rouges). Renvoie retry, escalate ou stop.",
        "inputSchema": {"type": "object", "properties": {"task_id": {"type": "string"}}, "required": ["task_id"]},
    },
    {
        "name": "decide",
        "description": "Decision typee locale (noul/score/choice) avec probabilites, facon Jev System One.",
        "inputSchema": {
            "type": "object",
            "properties": {"context": {"type": "string"}, "questions": {"type": "array", "items": {"type": "object"}}},
            "required": ["context", "questions"],
        },
    },
    {
        "name": "router_stats",
        "description": "Repartition des lanes, echecs et fallbacks depuis le journal local.",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


def _call(name: str, args: dict) -> str:
    cfg = load_config()
    if name == "route_task":
        res = route(str(args.get("prompt", "")), args.get("task_id"), cfg)
        return describe(res) + "\n" + json.dumps(res, ensure_ascii=False)
    if name == "report_failure":
        return json.dumps(record_failure(str(args.get("task_id", "")), cfg), ensure_ascii=False)
    if name == "decide":
        return json.dumps(decide(args, make_backend(cfg)), ensure_ascii=False)
    if name == "router_stats":
        return json.dumps(stats(), ensure_ascii=False)
    raise DecisionError(f"outil inconnu : {name}")


def _handle(msg: dict) -> dict | None:
    method, mid = msg.get("method"), msg.get("id")
    if mid is None:  # notification
        return None
    if method == "initialize":
        result = {
            "protocolVersion": msg.get("params", {}).get("protocolVersion", PROTOCOL_VERSION),
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "jev-router-local", "version": "1.0.0"},
        }
    elif method == "tools/list":
        result = {"tools": TOOLS}
    elif method == "tools/call":
        params = msg.get("params", {})
        try:
            text, is_error = _call(params.get("name", ""), params.get("arguments") or {}), False
        except (DecisionError, ValueError, KeyError) as exc:
            text, is_error = str(exc), True
        result = {"content": [{"type": "text", "text": text}], "isError": is_error}
    elif method == "ping":
        result = {}
    else:
        return {"jsonrpc": "2.0", "id": mid, "error": {"code": -32601, "message": f"methode inconnue : {method}"}}
    return {"jsonrpc": "2.0", "id": mid, "result": result}


def run_stdio() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            reply = _handle(json.loads(line))
        except ValueError:
            reply = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "parse error"}}
        if reply is not None:
            sys.stdout.write(json.dumps(reply, ensure_ascii=False) + "\n")
            sys.stdout.flush()
