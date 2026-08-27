#!/usr/bin/env python3
"""Patch v48.1g — L'ISSUE ECRIT ENFIN A PLEIN REGIME, ET NE PEUT PLUS TOMBER DE LA FALAISE.

Trois changements, tous issus de l'autopsie adversariale (17 agents), tous mesures sur le code.

1. LE PLEIN REGIME — le levier direct sur la cible des 20 secondes.

   L'issue est la SEULE generation de la chaine chaude a ne pas demander `plein_regime`. La
   selection le pose, la scene just-in-time le pose, l'amorcage le pose : elle non. Sans lui,
   `_apply_regime` sert `_fils_menage()` = la MOITIE des coeurs (merlin_native.gd:468-482), soit
   2 fils sur les 4 OCPU de la machine.

   Autrement dit, les 8,4 a 8,7 tokens par seconde mesures a p68 sont un debit a DEMI-REGIME :
   le debit plein du Vif n'a jamais ete mesure. Or l'issue est precisement la generation que le
   joueur attend le plus activement — c'est le cas d'usage pour lequel le plein regime a ete
   ecrit (« true quand le joueur ATTEND devant un voile »).

   L'evaluation du prompt ne change pas : `n_threads_batch` est deja a `_fils_plein()` dans les
   deux regimes. Seule l'ECRITURE accelere.

   RISQUE, nomme et a juger a l'oeil : l'issue se streame sous les yeux du joueur
   (_stream_resolution) et le rendu est logiciel (llvmpipe). Lui prendre deux coeurs peut faire
   saccader l'affichage. La partie temoin prend des captures : on regardera. Si le rendu souffre,
   ce patch se retire en un mot — c'est le seul du lot dont le verdict n'est pas qu'un chiffre.

2. LA FALAISE — le garde-fou qui supprime la panne silencieuse.

   Au-dela de n_ctx-4 = 2044 tokens, la GDExtension tronque le prompt PAR L'AVANT
   (merlin_llm.cpp:243-249) : elle jette le gabarit de chat, la consigne systeme et le haut des
   regles, ET desactive la reutilisation du prefixe KV (:271). Resultat mesure a p68 : 40 a 57
   secondes de relecture pour ne plus rien pouvoir ecrire.

   v48.1b a rendu ~450 tokens, ce qui eloigne la falaise mais ne la supprime pas : la narration
   injectee en queue varie de 239 a 694 caracteres selon les beats, et rien ne la borne. On la
   borne, en gardant la FIN — c'est la que vivent l'instant suspendu et les etres nommes que
   l'issue doit faire reagir, et c'est la coupe qui abime le moins.

3. LA TAILLE DU PROMPT, ENFIN LISIBLE.

   `prompt_tokens` est le DELTA decode (remis a zero a chaque generation) : il vaut 2 quand le
   cache a tout servi et 2045 quand tout a ete relu. Il ne dit donc RIEN de la longueur du
   prompt, donc rien de la place restante. Sans `prompt_chars` a cote, aucun ratio
   caracteres/token n'est mesurable sur cette machine — il n'y a ni tokenizer Gemma ni source
   llama.cpp — et tout raisonnement sur le budget reste une estimation. Deux champs de plus, et
   la prochaine partie tranche.
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return t.replace(vieux, neuf)


# ============================================================ 1 & 2 — le constructeur de prompt
p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")

t = exact(
    t,
    '''	return {"system": SYSTEM_PREFIX, "user": usr, "opts": {"creative": true, "max_tokens": tok_budget,
			"cerveau": "vif", "fin_phrase": true, "label": "issue (combinaison)"}}''',
    '''	# v48.1g — PLEIN REGIME. L'issue est la SEULE generation de la chaine chaude a ne pas le
	# demander : la selection le pose, scene_jit le pose, l'amorcage le pose, elle non. Sans lui
	# _apply_regime sert _fils_menage() = la moitie des coeurs (merlin_native.gd:468-482), soit
	# 2 fils sur 4. Les 8,4-8,7 tok/s mesures a p68 sont donc un debit a DEMI-REGIME, et le
	# debit plein du Vif n'a jamais ete mesure. Or l'issue est exactement le cas pour lequel le
	# plein regime a ete ecrit : la generation que le joueur attend le plus activement.
	# L'evaluation du prompt ne bouge pas (n_threads_batch est deja au plein dans les deux
	# regimes) ; seule l'ECRITURE accelere.
	return {"system": SYSTEM_PREFIX, "user": usr, "opts": {"creative": true, "max_tokens": tok_budget,
			"cerveau": "vif", "fin_phrase": true, "plein_regime": true,
			"label": "issue (combinaison)"}}''',
    "le plein regime de l'issue",
)

t = exact(
    t,
    '	var situ_txt: String = str(situation.get("narration", "")).strip_edges()\n',
    '''	var situ_txt: String = str(situation.get("narration", "")).strip_edges()
	# v48.1g — LA QUEUE NE DOIT JAMAIS POUSSER LE PROMPT DANS LA FALAISE. Au-dela de
	# n_ctx-4 = 2044 tokens, le natif tronque PAR L'AVANT (merlin_llm.cpp:243-249) : il jette le
	# gabarit de chat, SYSTEM_PREFIX et le haut des regles, ET desactive la reutilisation du
	# prefixe KV (:271) — 40 a 57 s de relecture pour ne plus rien pouvoir ecrire (p68).
	# v48.1b a rendu ~450 tokens, ce qui ELOIGNE la falaise sans la supprimer : la narration
	# injectee ici variait de 239 a 694 caracteres selon les beats, et rien ne la bornait.
	# On garde la FIN : c'est la que vivent l'instant suspendu et les etres nommes que l'issue
	# doit faire reagir, et on repart d'une frontiere de phrase pour ne pas commencer en plein mot.
	const SITU_MAX: int = 480
	if situ_txt.length() > SITU_MAX:
		var _coupe: String = situ_txt.substr(situ_txt.length() - SITU_MAX)
		var _p: int = maxi(_coupe.find(". "), _coupe.find("\\n"))
		situ_txt = _coupe.substr(_p + 1).strip_edges() if _p > 0 else _coupe
''',
    "la borne de narration",
)

p.write_text(t, encoding="utf-8")

# ============================================================ 3 — la taille du prompt, journalisee
p2 = pathlib.Path("scripts/llm/merlin_native.gd")
t2 = p2.read_text(encoding="utf-8")

t2 = exact(
    t2,
    '''		"prompt_ms": p_eval_ms, "prompt_tokens": n_prompt,
		"ecriture_ms": eval_ms, "tokens_ecrits": n_ecrits,
	}''',
    '''		"prompt_ms": p_eval_ms, "prompt_tokens": n_prompt,
		"ecriture_ms": eval_ms, "tokens_ecrits": n_ecrits,
		# v48.1g — LA TAILLE DU PROMPT, A COTE DU DELTA. `prompt_tokens` est le nombre de tokens
		# REELLEMENT decodes (remis a zero a chaque generation) : 2 quand le cache a tout servi,
		# 2045 quand tout a ete relu. Il ne dit donc rien de la LONGUEUR du prompt, donc rien de
		# la place qui reste pour ecrire. Sans cette mesure, aucun ratio caracteres/token n'est
		# etablissable sur cette machine (ni tokenizer Gemma, ni source llama.cpp) et tout calcul
		# de budget reste une estimation.
		"prompt_chars": str(v.get("prompt", "")).length(),
	}''',
    "la taille du prompt",
)

p2.write_text(t2, encoding="utf-8")
print("v48.1g applique : l'issue ecrit a plein regime, la narration injectee est bornee a 480")
print("caracteres (fin conservee), et la taille du prompt entre dans les metriques.")
