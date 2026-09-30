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
import typesafe_backend  # noqa: E402


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
                mock.patch.object(mcp_server, "route", side_effect=lambda p, t, c, **kw: router.route(
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
                mock.patch.object(jev, "route", side_effect=lambda p, t, **kw: router.route(p, t, CFG, backend)):
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


def _fake_urlopen(reply: dict, sent: list):
    """Remplace urlopen : capture la requete, renvoie la reponse TypeSafe scriptee."""
    class _Resp(io.BytesIO):
        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

    def _open(req, timeout=None):
        sent.append({"url": req.full_url, "auth": req.get_header("Authorization"),
                     "body": json.loads(req.data)})
        return _Resp(json.dumps(reply).encode("utf-8"))
    return _open


JEV_REPLY = {"model": "jev-1.13.0", "answers": {
    "complexity": {"type": "choice", "choice": "medium", "confidence": 0.91,
                   "probabilities": {"small": 0.05, "medium": 0.91, "high": 0.04, "escalate": 0.0}},
    "risk_flag": {"type": "choice", "choice": "none", "confidence": 0.97,
                  "probabilities": {"none": 0.97, "security": 0.02, "data_loss": 0.01}}}}
MERLIN = str(Path("C:/Users/x/M.E.R.L.I.N/scripts"))
QWEN = FakeBackend({"A": 0.95})


class TypeSafeTests(unittest.TestCase):
    def setUp(self):
        self.sent: list = []
        patches = [mock.patch.dict(os.environ, {"TYPESAFE_API_KEY": "cle-test"}),
                   mock.patch.object(router, "make_backend", return_value=QWEN)]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)

    def _route(self, prompt="Ajoute un bouton pause au HUD", cwd=MERLIN, reply=JEV_REPLY):
        with mock.patch("urllib.request.urlopen", side_effect=_fake_urlopen(reply, self.sent)):
            return router.route(prompt, cfg=CFG, cwd=cwd)

    def test_whitelisted_project_uses_jev_with_spec_payload(self):
        res = self._route()
        self.assertEqual((res["source"], res["lane"]), ("typesafe:jev-1.13.0", "medium"))
        self.assertEqual(len(self.sent), 1)
        req = self.sent[0]
        self.assertEqual(req["url"], "https://api.typesafe.ai/v1/systemone")
        self.assertEqual(req["auth"], "Bearer cle-test")
        self.assertEqual(req["body"]["model"], "jev-latest")
        self.assertEqual(req["body"]["state"], "Ajoute un bouton pause au HUD")
        q = req["body"]["questions"]["complexity"]
        self.assertEqual((q["type"], list(q["criteria"])), ("choice", ["small", "medium", "high", "escalate"]))

    def test_other_project_unknown_or_no_key_stays_local(self):
        for cwd in (str(Path("C:/Users/x/OneDrive - orange.com/Partage VOC/Data")), None):
            self.assertEqual(self._route(cwd=cwd)["source"], "fake")
        with mock.patch.dict(os.environ, {"TYPESAFE_API_KEY": ""}):
            self.assertEqual(self._route()["source"], "fake")
        self.assertEqual(self.sent, [])

    def test_whitelist_matches_whole_folder_only(self):
        self.assertEqual(self._route(cwd=str(Path("C:/Users/x/M.E.R.L.I.N-fork")))["source"], "fake")
        self.assertEqual(self.sent, [])

    def test_security_prompt_never_sent(self):
        res = self._route(prompt="Change le mot de passe admin dans la config")
        self.assertEqual((res["source"], res["lane"]), ("fake", "high"))
        self.assertEqual(self.sent, [])

    def test_api_failure_falls_back_to_qwen(self):
        with mock.patch("urllib.request.urlopen",
                        side_effect=typesafe_backend.urllib.error.HTTPError("u", 529, "Overloaded", {}, None)):
            res = router.route("Ajoute un bouton pause au HUD", cfg=CFG, cwd=MERLIN)
        self.assertEqual(res["source"], "fake")
        self.assertTrue(any("HTTP 529" in r for r in res["reasons"]))
        res = self._route(reply={"model": "jev", "answers": {}})
        self.assertEqual(res["source"], "fake")

    def test_noul_and_score_mapping(self):
        client = typesafe_backend.TypeSafeClient("https://x.test/v1/systemone", "jev-latest", "k")
        reply = {"model": "jev", "answers": {
            "u": {"type": "noul", "noul": 0.2},
            "s": {"type": "score", "score": 1.6, "confidence": 0.7, "legend": {"0": "1", "1": "2", "2": "3"}}}}
        with mock.patch("urllib.request.urlopen", side_effect=_fake_urlopen(reply, self.sent)):
            res = client.decide({"context": "x", "questions": [
                {"id": "u", "type": "noul", "text": "Urgent ?", "criteria": {"true": "vite", "false": "calme"}},
                {"id": "s", "type": "score", "text": "Note ?", "min": 1, "max": 3}]})
        a = {x["id"]: x for x in res["answers"]}
        self.assertIs(a["u"]["value"], False)
        self.assertAlmostEqual(a["u"]["confidence"], 0.8)
        self.assertEqual((a["s"]["value"], a["s"]["expected"]), (3, 2.6))
        body = self.sent[0]["body"]["questions"]
        self.assertEqual(body["u"]["criteria"], {"true": "vite", "false": "calme"})
        self.assertEqual(body["s"]["criteria"], ["1", "2", "3"])
        with self.assertRaises(systemone.DecisionError):
            client.decide({"questions": [{"id": "s", "type": "score", "min": 0, "max": 10}]})

    def test_missing_key_refused(self):
        with self.assertRaises(systemone.DecisionError):
            typesafe_backend.TypeSafeClient("u", "m", "")

    def test_hook_passes_cwd(self):
        seen = {}
        payload = {"prompt": "Corrige le calcul de score du minigame", "cwd": MERLIN}
        with mock.patch.object(sys, "stdin", io.StringIO(json.dumps(payload))),                 mock.patch.object(sys, "stdout", io.StringIO()),                 mock.patch.object(jev, "route", side_effect=lambda p, t, **kw: seen.update(kw) or
                                  router.route(p, t, CFG, QWEN)):
            jev.main(["hook"])
        self.assertEqual(seen["cwd"], MERLIN)


if __name__ == "__main__":
    unittest.main()
