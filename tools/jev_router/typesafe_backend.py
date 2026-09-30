"""Client de l'API TypeSafe System One (Jev), au contrat local de systemone.decide.

  POST https://api.typesafe.ai/v1/systemone   Authorization: Bearer $TYPESAFE_API_KEY
  requete distante : {"state", "model", "questions": {id: {"type", "instructions", "criteria"}}}
  reponse distante : {"model", "answers": {id: {"type", "noul" | "choice" | "score",
                      "probabilities", "confidence", "legend"}}, "usage"}

N'est appele que par router.py, et seulement pour un projet de la liste blanche
(lanes.json -> decider_policy). Toute erreur leve DecisionError : le routeur retombe sur Qwen.
"""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from typing import Any

from systemone import DecisionError, _options_for

API_KEY_ENV = "TYPESAFE_API_KEY"
MAX_SCORE_LEVELS = 10


def _to_remote(q: dict) -> dict:
    options = _options_for(q)  # valide la question comme le moteur local
    qtype = q["type"]
    remote: dict[str, Any] = {"type": qtype, "instructions": str(q.get("text", "")).strip()}
    if qtype == "noul":
        if q.get("criteria"):
            remote["criteria"] = {"true": options[0][1], "false": options[1][1]}
    elif qtype == "choice":
        remote["criteria"] = {value: (desc or None) for value, desc in options}
    else:  # score : niveaux ordonnes, le rang 0 correspond a q["min"]
        if len(options) > MAX_SCORE_LEVELS:
            raise DecisionError(f"score '{q.get('id')}' : {MAX_SCORE_LEVELS} niveaux max cote TypeSafe")
        remote["criteria"] = [value for value, _ in options]
    return remote


def _from_remote(q: dict, ans: dict) -> dict:
    qtype = q["type"]
    out: dict[str, Any] = {"id": q.get("id"), "type": qtype, "calibrated": True}
    try:
        if qtype == "noul":
            p = float(ans["noul"])
            out.update(value=p >= 0.5, probabilities={"true": round(p, 4), "false": round(1 - p, 4)},
                       confidence=round(float(ans.get("confidence", max(p, 1 - p))), 4))
        elif qtype == "choice":
            probs = {str(k): float(v) for k, v in (ans.get("probabilities") or {}).items()}
            value = str(ans["choice"])
            out.update(value=value, probabilities=probs,
                       confidence=round(float(ans.get("confidence", probs.get(value, 0.0))), 4))
        else:
            lo = int(q.get("min", 0))
            rank = float(ans["score"])
            out.update(value=lo + int(round(rank)), expected=round(lo + rank, 2),
                       probabilities=ans.get("probabilities") or {},
                       confidence=round(float(ans.get("confidence", 0.0)), 4))
    except (KeyError, TypeError, ValueError) as exc:
        raise DecisionError(f"reponse TypeSafe illisible pour '{q.get('id')}' : {exc}") from exc
    return out


class TypeSafeClient:
    def __init__(self, api_url: str, model: str, api_key: str, timeout_s: float = 10.0) -> None:
        if not api_key:
            raise DecisionError(f"{API_KEY_ENV} absente")
        self.api_url = api_url
        self.model = model
        self._api_key = api_key
        self.timeout_s = timeout_s

    @classmethod
    def from_policy(cls, policy: dict) -> "TypeSafeClient":
        return cls(policy.get("api_url", "https://api.typesafe.ai/v1/systemone"),
                   policy.get("model", "jev-latest"), os.environ.get(API_KEY_ENV, ""),
                   policy.get("timeout_s", 10))

    def _post(self, payload: dict) -> dict:
        req = urllib.request.Request(
            self.api_url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json", "Authorization": f"Bearer {self._api_key}"},
        )
        try:
            with urllib.request.urlopen(req, timeout=self.timeout_s) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:  # 401, 422, 429, 529 : jamais le corps (peut citer la cle)
            raise DecisionError(f"TypeSafe HTTP {exc.code}") from exc
        except (urllib.error.URLError, TimeoutError, OSError, ValueError) as exc:
            raise DecisionError(f"TypeSafe injoignable : {type(exc).__name__}") from exc

    def decide(self, request: dict) -> dict:
        """Meme entree/sortie que systemone.decide, execute par Jev."""
        started = time.monotonic()
        questions = request.get("questions")
        if not isinstance(questions, list) or not questions:
            raise DecisionError("'questions' doit etre une liste non vide")
        data = self._post({
            "state": request.get("context", ""),
            "model": self.model,
            "questions": {str(q.get("id")): _to_remote(q) for q in questions},
        })
        remote_answers = data.get("answers") if isinstance(data, dict) else None
        if not isinstance(remote_answers, dict):
            raise DecisionError("reponse TypeSafe sans 'answers'")
        answers = []
        for q in questions:
            ans = remote_answers.get(str(q.get("id")))
            if not isinstance(ans, dict):
                raise DecisionError(f"TypeSafe n'a pas repondu a '{q.get('id')}'")
            answers.append(_from_remote(q, ans))
        return {
            "answers": answers,
            "model": f"typesafe:{data.get('model', self.model)}",
            "latency_ms": int((time.monotonic() - started) * 1000),
        }
