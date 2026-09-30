"""Jev adapter — routeur local facon Jev (decideur Ollama, zero cle API). Voir tools/jev_router/."""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve().parent
_ROOT = _HERE.parent
for _p in (_ROOT, _HERE, _ROOT / "jev_router"):
    _s = str(_p)
    if _s not in sys.path:
        sys.path.insert(0, _s)

from adapters.base_adapter import BaseAdapter  # noqa: E402


class JevAdapter(BaseAdapter):
    """Adapter for the local Jev-like task router."""

    def __init__(self) -> None:
        super().__init__("jev")

    def list_actions(self) -> dict[str, str]:
        return {
            "route":  "Classe une demande -> lane + modele par outil (requires prompt=, optional task=)",
            "fail":   "Signale un cycle echoue -> retry/escalate/stop (requires task=)",
            "stats":  "Repartition des lanes depuis le journal local",
            "eval":   "Justesse du decideur sur tools/jev_router/eval_cases.json",
            "health": "Verifie que le decideur Ollama repond",
        }

    def health_probe(self) -> tuple[str, dict]:
        return "health", {}

    def run(self, action: str, **kwargs: Any) -> dict:
        import router
        from systemone import DecisionError

        match action:
            case "route":
                prompt = kwargs.get("prompt")
                if not prompt:
                    return self.error("prompt= requis")
                return self.ok(router.route(str(prompt), kwargs.get("task")))
            case "fail":
                if not kwargs.get("task"):
                    return self.error("task= requis")
                return self.ok(router.record_failure(str(kwargs["task"])))
            case "stats":
                return self.ok(router.stats())
            case "eval":
                import jev
                return self.ok(jev._eval(jev.EVAL_CASES))
            case "health":
                cfg = router.load_config()
                try:
                    res = router.decide({"context": "ping", "questions": [
                        {"id": "p", "type": "noul", "text": "Le contexte dit-il ping ?"}]},
                        router.make_backend(cfg))
                except DecisionError as exc:
                    return self.error(str(exc))
                return self.ok({"decider": cfg["decider"]["model"], "latency_ms": res["latency_ms"],
                                "calibrated": res["answers"][0]["calibrated"]})
            case _:
                raise NotImplementedError(action)
