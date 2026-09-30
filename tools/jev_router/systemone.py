"""Moteur de decision local facon Jev (System One) — 100% poste, zero cle API.

Contrat (compatible dans l'esprit avec /v1/systemone de TypeSafe) :
  requete  : {"context": str | list, "questions": [Question, ...]}
  Question : {"id": str, "type": "noul" | "score" | "choice", "text": str,
              "criteria": {"true": str, "false": str},        # noul (optionnel)
              "options": [{"value": str, "description": str}], # choice
              "min": int, "max": int}                          # score (0..10 max)
  reponse  : {"answers": [{"id", "type", "value", "confidence",
                           "probabilities", "calibrated"}], "model", "latency_ms"}

Confiance : probabilites issues des logprobs Ollama (calibrated=true), sinon vote
par echantillonnage (calibrated=false). Jamais d'auto-evaluation du modele.
"""

from __future__ import annotations

import json
import math
import string
import time
import urllib.error
import urllib.request
from collections import Counter
from typing import Any, Protocol

LETTERS = string.ascii_uppercase


class DecisionError(ValueError):
    """Requete invalide ou backend indisponible."""


class Backend(Protocol):
    name: str

    def letter_distribution(self, prompt: str, letters: list[str]) -> tuple[dict[str, float], bool]:
        """Retourne ({lettre: proba}, calibre?) sur les lettres autorisees."""


# ── Backend Ollama ──────────────────────────────────────────────────────────


class OllamaBackend:
    def __init__(self, url: str, model: str, vote_samples: int = 5, timeout_s: float = 20.0) -> None:
        self.url = url.rstrip("/")
        self.model = model
        self.vote_samples = max(1, vote_samples)
        self.timeout_s = timeout_s
        self.name = f"ollama:{model}"

    def _generate(self, prompt: str, temperature: float, logprobs: bool) -> dict:
        payload: dict[str, Any] = {
            "model": self.model,
            "prompt": prompt,
            "stream": False,
            "think": False,
            "options": {"temperature": temperature, "num_predict": 2},
        }
        if logprobs:
            payload["logprobs"] = True
            payload["top_logprobs"] = 20
        req = urllib.request.Request(
            f"{self.url}/api/generate",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=self.timeout_s) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            raise DecisionError(f"Ollama injoignable ({self.url}) : {exc}") from exc

    def letter_distribution(self, prompt: str, letters: list[str]) -> tuple[dict[str, float], bool]:
        data = self._generate(prompt, temperature=0.0, logprobs=True)
        dist = _dist_from_logprobs(data.get("logprobs"), letters)
        if dist:
            return dist, True
        votes: Counter[str] = Counter()
        first = _first_letter(data.get("response", ""), letters)
        if first:
            votes[first] += 1
        for _ in range(self.vote_samples - 1):
            pick = _first_letter(self._generate(prompt, 0.8, False).get("response", ""), letters)
            if pick:
                votes[pick] += 1
        total = sum(votes.values())
        if total == 0:
            raise DecisionError("Reponse du modele illisible (aucune lettre valide)")
        return {k: v / total for k, v in votes.items()}, False


def _first_letter(text: str, letters: list[str]) -> str | None:
    for ch in text.strip().upper():
        if ch in letters:
            return ch
        if not ch.isspace() and ch not in "(\"'*":
            return None
    return None


def _dist_from_logprobs(logprobs: Any, letters: list[str]) -> dict[str, float]:
    if not isinstance(logprobs, list) or not logprobs:
        return {}
    first = logprobs[0]
    candidates = first.get("top_logprobs") or [first]
    scores: dict[str, float] = {}
    for cand in candidates:
        tok = str(cand.get("token", "")).strip().upper()
        lp = cand.get("logprob")
        if tok in letters and isinstance(lp, (int, float)):
            scores[tok] = scores.get(tok, 0.0) + math.exp(lp)
    total = sum(scores.values())
    return {k: v / total for k, v in scores.items()} if total > 0 else {}


# ── Engine ─────────────────────────────────────────────────────────────────


def _options_for(q: dict) -> list[tuple[str, str]]:
    qtype = q.get("type")
    if qtype == "noul":
        crit = q.get("criteria") or {}
        return [("true", crit.get("true", "oui")), ("false", crit.get("false", "non"))]
    if qtype == "score":
        lo, hi = int(q.get("min", 0)), int(q.get("max", 10))
        if not 0 <= lo < hi or hi - lo > 10:
            raise DecisionError(f"score '{q.get('id')}' : bornes invalides {lo}..{hi} (11 valeurs max)")
        return [(str(v), "") for v in range(lo, hi + 1)]
    if qtype == "choice":
        opts = q.get("options") or []
        if not 2 <= len(opts) <= len(LETTERS):
            raise DecisionError(f"choice '{q.get('id')}' : 2 a 26 options requises")
        return [(str(o["value"]), str(o.get("description", ""))) for o in opts]
    raise DecisionError(f"type inconnu '{qtype}' (noul | score | choice)")


def _build_prompt(context: str, q: dict, options: list[tuple[str, str]]) -> str:
    lines = [
        "Tu es un classifieur. Lis le contexte, puis reponds a la question par UNE seule lettre.",
        "",
        "### Contexte",
        context.strip(),
        "",
        "### Question",
        str(q.get("text", "")).strip(),
        "",
        "### Options",
    ]
    for letter, (value, desc) in zip(LETTERS, options):
        lines.append(f"{letter}) {value}" + (f" — {desc}" if desc else ""))
    lines += ["", "Reponse (une lettre) :"]
    return "\n".join(lines)


def decide(request: dict, backend: Backend) -> dict:
    """Execute toutes les questions d'une requete System One."""
    started = time.monotonic()
    raw_ctx = request.get("context", "")
    context = raw_ctx if isinstance(raw_ctx, str) else json.dumps(raw_ctx, ensure_ascii=False, indent=1)
    questions = request.get("questions")
    if not isinstance(questions, list) or not questions:
        raise DecisionError("'questions' doit etre une liste non vide")

    answers = []
    for q in questions:
        options = _options_for(q)
        letters = list(LETTERS[: len(options)])
        dist, calibrated = backend.letter_distribution(_build_prompt(context, q, options), letters)
        probs = {options[LETTERS.index(k)][0]: round(p, 4) for k, p in dist.items()}
        value = max(probs, key=probs.get)
        answer: dict[str, Any] = {
            "id": q.get("id"),
            "type": q["type"],
            "value": value,
            "confidence": probs[value],
            "probabilities": probs,
            "calibrated": calibrated,
        }
        if q["type"] == "noul":
            answer["value"] = value == "true"
        elif q["type"] == "score":
            answer["value"] = int(value)
            answer["expected"] = round(sum(int(k) * p for k, p in probs.items()), 2)
        answers.append(answer)

    return {
        "answers": answers,
        "model": backend.name,
        "latency_ms": int((time.monotonic() - started) * 1000),
    }
