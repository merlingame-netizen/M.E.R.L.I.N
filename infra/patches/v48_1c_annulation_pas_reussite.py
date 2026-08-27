#!/usr/bin/env python3
"""Patch v48.1c — UNE GENERATION ANNULEE N'EST PAS UNE REUSSITE.

Trouve par la revue adversariale de l'autopsie v48.1, puis verifie ligne a ligne. C'est la
SECONDE cause des issues coupees, distincte de la saturation du contexte traitee en v48.1b —
et celle-ci explique precisement les coupures EN PLEIN MOT.

LA CHAINE, verifiee :

1. merlin_llm.cpp:410 — la boucle d'echantillonnage casse sur `if (!is_generating.load())
   break;`. Apres ce break, `error_msg` reste VIDE : le texte partiel deja ecrit est rendu
   comme un resultat NORMAL.
2. merlin_native.gd:676 — `cancel()` appelle `cancel_generation()` mais n'incremente PAS
   `v["id"]`. Le chemin du TIMEOUT, lui, l'incremente (l.567). Or c'est exactement `v["id"]`
   qui perime un callback : `_on_result` commence par `if gen_id != int(v["id"]): return`
   (l.593). Sans incrementation, le callback de la generation annulee est donc considere
   comme valide.
3. Consequence : le texte tronque traverse tout le chemin nominal — il devient `v["result"]`,
   il est rendu a l'appelant qui attend, et ses compteurs entrent dans `_last_metrics`, donc
   dans le champ `gen` du journal.
4. Et l'annulation n'est pas rare : `prefetch_resolution` PREEMPTE le Vif a CHAQUE pose de
   cartes (merlin_scenario.gd:20, 25, 2468).

C'est la meilleure explication de l'issue du beat 2 de p68 — « Vous faites reculer la vieille
Dame, sa parole vibrant dans l'etro » — coupee au milieu d'un mot, servie telle quelle au
joueur, et comptee comme une generation reussie de 15 tokens.

LE CORRECTIF, volontairement minimal. On ne touche NI a `busy`, NI a `v["id"]`, NI au cycle de
vie de la voie. Mettre `busy` a false des l'annulation serait tentant — le drain sortirait plus
vite — mais dangereux : le fil d'inference C++ tourne encore (une annulation ne prend qu'entre
deux tokens, et en pleine evaluation de prompt cela dure des dizaines de secondes, mesure a
p63), et liberer la voie trop tot lancerait une generation sur un moteur encore occupe. On se
contente donc de MARQUER la voie : le resultat qui reviendra sera converti en erreur avant
d'etre assaini, tout le reste du menage (busy, ready, partage des coeurs, metriques) se
deroulant exactement comme aujourd'hui.

L'erreur rendue est « annulee ». Elle est inoffensive pour la detection de moteur mort, qui ne
reagit qu'a « stuck » et « LLM disabled » (merlin_native.gd:353, 362). L'appelant retombe sur
son chemin d'erreur normal : au lieu de servir un demi-mot, il laisse la generation relancee
par la preemption ecrire l'issue entiere.
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return t.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_native.gd")
t = p.read_text(encoding="utf-8")

# ---------------------------------------------------------------- 1. le drapeau, dans les voies
t = exact(
    t,
    '''var _voies: Dictionary = {
	"conteur": {"busy": false, "label": "", "t0": 0, "prompt": "", "ready": false,
		"result": {}, "id": 0, "plein": false, "metrics": {}},
	"vif": {"busy": false, "label": "", "t0": 0, "prompt": "", "ready": false,
		"result": {}, "id": 0, "plein": false, "metrics": {}},
}''',
    '''# v48.1c — « annulee » : la voie a recu un cancel_generation() pendant que le moteur ecrivait.
# Le C++ casse alors sa boucle SANS poser d'erreur (merlin_llm.cpp:410), si bien que le texte
# partiel remontait comme une reussite. Le drapeau le dit ; _on_result en tire la consequence.
var _voies: Dictionary = {
	"conteur": {"busy": false, "label": "", "t0": 0, "prompt": "", "ready": false,
		"result": {}, "id": 0, "plein": false, "metrics": {}, "annulee": false},
	"vif": {"busy": false, "label": "", "t0": 0, "prompt": "", "ready": false,
		"result": {}, "id": 0, "plein": false, "metrics": {}, "annulee": false},
}''',
    "le drapeau dans les voies",
)

# ---------------------------------------------------------------- 2. cancel() marque la voie
t = exact(
    t,
    '''func cancel(cerveau: String = "") -> void:
	for c in (["conteur", "vif"] if cerveau == "" else [cerveau]):
		if not _voies.has(c):
			continue
		var m: Variant = _moteur_de(c)
		if m != null and _voies[c]["busy"]:
			m.cancel_generation()''',
    '''func cancel(cerveau: String = "") -> void:
	for c in (["conteur", "vif"] if cerveau == "" else [cerveau]):
		if not _voies.has(c):
			continue
		var m: Variant = _moteur_de(c)
		if m != null and _voies[c]["busy"]:
			# v48.1c — MARQUER avant d'annuler. Le C++ casse sa boucle sans poser d'erreur
			# (merlin_llm.cpp:410), et cancel() n'incremente pas v["id"] — contrairement au
			# timeout (l.567) — donc le callback n'etait pas perime et le demi-texte etait
			# servi comme une reussite. On ne touche ni a busy ni a l'id : le fil d'inference
			# tourne encore, liberer la voie ici lancerait une gen sur un moteur occupe.
			_voies[c]["annulee"] = true
			m.cancel_generation()''',
    "cancel marque la voie",
)

# ---------------------------------------------------------------- 3. depart : on repart propre
t = exact(
    t,
    '''	v["ready"] = false
	v["result"] = {}
	v["id"] = int(v["id"]) + 1''',
    '''	v["ready"] = false
	v["result"] = {}
	v["annulee"] = false  # v48.1c — nouvelle generation : l'annulation precedente est soldee
	v["id"] = int(v["id"]) + 1''',
    "depart propre",
)

# ---------------------------------------------------------------- 4. _on_result en tire la consequence
t = exact(
    t,
    '''	if v["ready"]:
		return  # double-poll → résultat déjà consommé
	var elapsed_ms: int = Time.get_ticks_msec() - int(v["t0"])''',
    '''	if v["ready"]:
		return  # double-poll → résultat déjà consommé
	# v48.1c — UNE ANNULATION N'EST PAS UNE REUSSITE. Le texte partiel qui remonte apres un
	# cancel_generation() n'a pas d'erreur attachee (le C++ casse sa boucle sans en poser) : sans
	# cette conversion, un demi-mot etait servi au joueur comme une prose finie, et ses compteurs
	# entraient dans _last_metrics — donc dans le journal, ou il ressemblait a une generation
	# normale. Le reste du menage (busy, ready, partage des coeurs, metriques) suit son cours.
	if bool(v.get("annulee", false)):
		v["annulee"] = false
		result = {"error": "annulee"}
	var elapsed_ms: int = Time.get_ticks_msec() - int(v["t0"])''',
    "la consequence dans _on_result",
)

p.write_text(t, encoding="utf-8")
print("v48.1c applique : une generation annulee rend desormais une erreur « annulee », plus un")
print("demi-texte presente comme une reussite. Ni busy ni v[\"id\"] ne sont touches : le cycle de")
print("vie de la voie est inchange.")
