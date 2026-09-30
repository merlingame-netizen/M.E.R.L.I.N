"""Tests du routeur local (backend factice, aucun appel reseau).

  python -m unittest discover -s tools/jev_router/tests -v
"""

from __future__ import annotations

import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
os.environ["JEV_ROUTER_HOME"] = tempfile.mkdtemp(prefix="jev_test_")

import jev  # noqa: E402
import mcp_server  # noqa: E402
import router  # noqa: E402
import systemone  # noqa: E402


class FakeBackend:
    """Renvoie une distribution scriptee selon un mot-cle de la question."""

    name = "fake"

    def __init__(self, complexity: dict[str, float], risk: dict[str, float] | None = None,
                 calibrated: bool = True) -> None:
        self.complexity, self.risk, self.calibrated = complexity, risk or {"A": 1.0}, calibrated

    def letter_distribution(self, prompt, letters):
        dist = self.risk if "code sensible" in prompt else self.complexity
        return dict(dist), self.calibrated


class DownBackend:
    name = "down"

    def letter_distribution(self, prompt, letters):
        raise systemone.DecisionError("Ollama injoignable")


CFG = router.load_config()


class SystemOneTests(unittest.TestCase):
    def test_noul_score_choice(self):
        req = {"context": ["tweet 1", "tweet 2"], "questions": [
            {"id": "q1", "type": "noul", "text": "Parle de sport ?", "criteria": {"true": "sport", "false": "autre"}},
            {"id": "q2", "type": "score", "text": "Toxicite ?", "min": 0, "max": 2},
            {"id": "q3", "type": "choice", "text": "Langue ?",
             "options": [{"value": "fr"}, {"value": "en"}]},
        ]}
        res = systemone.decide(req, FakeBackend({"A": 0.2, "B": 0.8}))
        a = {x["id"]: x for x in res["answers"]}
        self.assertIs(a["q1"]["value"], False)
        self.assertEqual(a["q2"]["value"], 1)
        self.assertAlmostEqual(a["q2"]["expected"], 0.8)
        self.assertEqual(a["q3"]["value"], "en")
        self.assertAlmostEqual(a["q3"]["confidence"], 0.8)

    def test_invalid_requests(self):
        for bad in ({"questions": []},
                    {"questions": [{"id": "x", "type": "wat"}]},
                    {"questions": [{"id": "x", "type": "score", "min": 0, "max": 50}]},
                    {"questions": [{"id": "x", "type": "choice", "options": [{"value": "a"}]}]}):
            with self.assertRaises(systemone.DecisionError):
                systemone.decide(bad, FakeBackend({"A": 1.0}))

    def test_logprobs_parsing(self):
        lp = [{"token": "B", "logprob": -0.1, "top_logprobs": [
            {"token": "B", "logprob": -0.1}, {"token": " A", "logprob": -2.5}, {"token": "zz", "logprob": -1}]}]
        dist = systemone._dist_from_logprobs(lp, ["A", "B"])
        self.assertGreater(dist["B"], 0.9)
        self.assertAlmostEqual(sum(dist.values()), 1.0)
        self.assertEqual(systemone._dist_from_logprobs(None, ["A"]), {})

    def test_first_letter(self):
        self.assertEqual(systemone._first_letter(" (b) blabla", ["A", "B"]), "B")
        self.assertIsNone(systemone._first_letter("Je pense A", ["A", "B"]))

    def test_vote_fallback_without_logprobs(self):
        be = systemone.OllamaBackend("http://x", "m", vote_samples=4)
        replies = iter([{"response": "A"}, {"response": "A"}, {"response": "B"}, {"response": "A"}])
        with mock.patch.object(be, "_generate", side_effect=lambda *a, **k: next(replies)):
            dist, calibrated = be.letter_distribution("p", ["A", "B"])
        self.assertFalse(calibrated)
        self.assertAlmostEqual(dist["A"], 0.75)


class RouterTests(unittest.TestCase):
    def test_confident_small(self):
        res = router.route("Renomme la variable x en count", cfg=CFG, backend=FakeBackend({"A": 0.95}))
        self.assertEqual(res["lane"], "small")
        self.assertEqual(res["models"]["claude_code"], "haiku")

    def test_low_confidence_bumps_one_lane(self):
        res = router.route("Ajoute un filtre", cfg=CFG, backend=FakeBackend({"A": 0.55, "B": 0.45}))
        self.assertEqual(res["lane"], "medium")

    def test_regex_risk_forces_high(self):
        res = router.route("Stocke le mot de passe utilisateur", cfg=CFG, backend=FakeBackend({"A": 0.99}))
        self.assertEqual(res["risk_flag"], "security")
        self.assertEqual(res["lane"], "high")

    def test_decider_risk_needs_confidence(self):
        be = FakeBackend({"A": 0.99}, risk={"A": 0.4, "C": 0.6})
        self.assertEqual(router.route("Ajoute un bouton", cfg=CFG, backend=be)["risk_flag"], "none")
        be = FakeBackend({"A": 0.99}, risk={"C": 0.9, "A": 0.1})
        res = router.route("Ajoute un bouton", cfg=CFG, backend=be)
        self.assertEqual((res["risk_flag"], res["lane"]), ("data_loss", "high"))

    def test_decider_down_uses_heuristic(self):
        res = router.route("court", cfg=CFG, backend=DownBackend())
        self.assertEqual((res["source"], res["lane"]), ("heuristic", "small"))

    def test_budget_retries_escalation_and_kill_switch(self):
        router.route("Refacto", task_id="t1", cfg=CFG, backend=FakeBackend({"C": 0.9}))  # high
        actions = [router.record_failure("t1", CFG)["action"] for _ in range(3)]
        self.assertEqual(actions, ["retry", "retry", "escalate"])
        self.assertEqual(router._load_state()["t1"]["lane"], "escalate")
        actions = [router.record_failure("t1", CFG)["action"] for _ in range(3)]
        self.assertEqual(actions[-1], "stop")
        self.assertIn("error", router.record_failure("inconnu", CFG))

    def test_stats(self):
        s = router.stats()
        self.assertGreater(s["routes"], 0)


class IntegrationTests(unittest.TestCase):
    def test_mcp_roundtrip(self):
        self.assertEqual(mcp_server._handle({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                                             "params": {}})["result"]["serverInfo"]["name"], "jev-router-local")
        tools = mcp_server._handle({"id": 2, "method": "tools/list"})["result"]["tools"]
        self.assertIn("route_task", [t["name"] for t in tools])
        self.assertIsNone(mcp_server._handle({"method": "notifications/initialized"}))
        with mock.patch.object(router, "make_backend", return_value=FakeBackend({"B": 0.9})), \
                mock.patch.object(mcp_server, "route", side_effect=lambda p, t, c: router.route(
                    p, t, c, backend=FakeBackend({"B": 0.9}))):
            out = mcp_server._handle({"id": 3, "method": "tools/call",
                                      "params": {"name": "route_task", "arguments": {"prompt": "fix bug"}}})
        self.assertIn("lane=medium", out["result"]["content"][0]["text"])
        err = mcp_server._handle({"id": 4, "method": "tools/call", "params": {"name": "nope"}})
        self.assertTrue(err["result"]["isError"])

    def _run_hook(self, payload: dict, backend) -> str:
        out = io.StringIO()
        with mock.patch.object(sys, "stdin", io.StringIO(json.dumps(payload))), \
                mock.patch.object(sys, "stdout", out), \
                mock.patch.object(jev, "route", side_effect=lambda p, t: router.route(p, t, CFG, backend)):
            self.assertEqual(jev.main(["hook"]), 0)
        return out.getvalue()

    def test_hook_injects_context(self):
        out = self._run_hook({"prompt": "Corrige le calcul de score du minigame", "session_id": "s"},
                             FakeBackend({"B": 0.9}))
        ctx = json.loads(out)["hookSpecificOutput"]["additionalContext"]
        self.assertIn("model=sonnet", ctx)

    def test_hook_fail_open(self):
        self.assertEqual(self._run_hook({"prompt": "Corrige le calcul de score du minigame"}, DownBackend()), "")
        self.assertEqual(self._run_hook({"prompt": "* bypass avec un prompt assez long"}, FakeBackend({"A": 1})), "")
        with mock.patch.object(sys, "stdin", io.StringIO("pas du json")):
            self.assertEqual(jev.main(["hook"]), 0)


if __name__ == "__main__":
    unittest.main()
