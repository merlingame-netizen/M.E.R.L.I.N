extends SceneTree
## Épreuve de la progression : la mort est une menace réelle et RARE.
##
##     godot --headless --path . --script res://tools/tests/test_progression.gd
##     MERLIN_GRILLE=1 …    imprime aussi la grille des réglages (plus long)
##     MERLIN_N_RUNS=100 …  essai rapide
##
## POURQUOI ELLE EXISTE. Sur p74, un joueur qui couvre un tag ne jetait plus le dé après le beat 7
## (16 gestes sur 20 « sans jet », Climax compris), finissait à 10 d'intégrité sur 10 et sans une
## éclatante ; le bot qui ne couvre pas mourait une fois sur cinq. Maxime a tranché (06/09) : une
## traversée sur dix, environ, doit se finir mal pour un joueur attentif.
##
## CE QU'ELLE FAIT. Elle joue des traversées avec le VRAI moteur (MerlinResolution.resolve) et la
## VRAIE forme de quête (build_quest_beats : 8 à 25 beats), sur TROIS GRAINES (une seule graine
## publiait le haut d'un tirage : 8,8 % là où la moyenne était 6,4). Elle modèle :
##   - la progression : un point de talent par réussite, deux par éclatante ; après une réussite
##     hors Climax, UN draft — le nœud de talent (s'il y a deux points) ou une greffe au jet, jamais
##     les deux ; la maîtrise par usage (3 → +1, 6 → +2) ; une greffe au jet vaut +1 ;
##   - la nature des scènes : un tag Monde requis (Rituel…) sur 30 % des beats, comme dans p74
##     (6 sur 20), qui monte la nature d'un tier — partiel −3, corruption même sur réussite ;
##   - la corruption, comptée à part : une fin « corrompue » à CORRUPTION_CAP n'est pas une mort ;
##   - l'archétype « p74 », la couverture MESURÉE du bot couvrant : 0 tag une fois sur dix, 2 tags une
##     fois sur dix, 1 sinon ; et l'« aveugle » : 0 tag, 1 une fois sur trois.
## Ce qu'elle ne modélise pas, et dans quel sens : la synergie (+1), les greffes heal, la conversion
## de main et le Coup de Pouce rendent la mort PLUS RARE ; la bascule Dilemme → Épreuve après un
## revers la rend PLUS FRÉQUENTE. Le chiffre est un ordre de grandeur, pas une promesse : la nuit du
## bot couvrant (désormais aveugle au dé) le confronte au vrai jeu.

const N_RUNS_DEFAUT: int = 300   # par graine ; trois graines → 900 traversées par série (~25 ms chacune)
const GRAINES: Array = [20260907, 20260908, 20260909]
const GRAFT_P: float = 0.35       # après une réussite sans nœud de talent, une greffe au jet ~une fois sur trois
const TALENT_P: float = 0.5       # au draft, le nœud de talent est pris une fois sur deux quand il est offert
const MONDE_P: float = 0.30       # part des beats dont un tag requis est de famille Monde (p74 : 6/20)
const CIBLE_MIN: float = 4.0      # % de morts, archétype p74 : une sur dix visée ; mesuré 6,1 ± 1,6 le 07/09, la borne basse laisse la marge du tirage
const CIBLE_MAX: float = 15.0

var _rates: int = 0
var _n_runs: int = N_RUNS_DEFAUT
var _scenario: GDScript = null


func _verifier(nom: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s" % nom)
	else:
		_rates += 1
		print("  RATE  %s%s" % [nom, ("  — " + detail) if detail != "" else ""])


func _init() -> void:
	print("=== ÉPREUVE DE LA PROGRESSION : LA MORT RARE ===\n")
	var env_n: String = OS.get_environment("MERLIN_N_RUNS")
	if env_n != "":
		_n_runs = maxi(50, int(env_n))
	_scenario = load("res://scripts/llm/merlin_scenario.gd")
	print("traversées par série : %d (%d graines × %d)" % [_n_runs * GRAINES.size(), GRAINES.size(), _n_runs])
	var cap0: int = MerlinResolution.atouts_propres_cap
	var ec0: int = MerlinResolution.eclat_margin

	# ── HIER ET AUJOURD'HUI, à la longueur du jeu (8-25)
	print("\narchétype   règle        morts%  ±IC   corrompus%  sans-jet%  éclat%  climax-au-dé%  intég.fin  intég.min")
	var hier: Dictionary = {}
	var auj: Dictionary = {}
	for arch in ["p74", "aveugle"]:
		MerlinResolution.regle_plafond = false
		MerlinResolution.eclat_margin = MerlinResolution.ECLAT_MARGIN
		var h: Dictionary = _serie(arch)
		_ligne(arch, "hier", h)
		MerlinResolution.regle_plafond = true
		MerlinResolution.eclat_margin = ec0
		var a: Dictionary = _serie(arch)
		_ligne(arch, "aujourd'hui", a)
		if arch == "p74":
			hier = h
			auj = a

	# ── LA GRILLE, sur demande : quel plafond des atouts propres, quel seuil d'éclat ?
	if OS.get_environment("MERLIN_GRILLE") == "1":
		print("\ngrille (p74, 8-25 beats) — atouts propres ≤ cap, éclatante ≥ ec :")
		for cap in [0, 1, 2]:
			for ec in [8, 7]:
				MerlinResolution.atouts_propres_cap = cap
				MerlinResolution.eclat_margin = ec
				var r: Dictionary = _serie("p74")
				print("  cap=%d ec=%d  morts %5.1f%% ±%.1f  corrompus %4.1f%%  sans-jet %4.1f%%  éclat %4.1f%%  intég.fin %.1f" % [
					cap, ec, r["morts"], r["ic"], r["corrompus"], r["sans_jet"], r["eclat"], r["integ_fin"]])
		MerlinResolution.atouts_propres_cap = cap0
		MerlinResolution.eclat_margin = ec0

	# ── LA MONOTONIE : un tag de plus vaut toujours plus, sur une Épreuve aussi
	var c1: Dictionary = MerlinResolution.resolve(_requis(2, false), _geste(1, 2, false), [], 7, [], 2, 1, 0, "Epreuve", 0)
	var c2: Dictionary = MerlinResolution.resolve(_requis(2, false), _geste(2, 2, false), [], 7, [], 2, 1, 0, "Epreuve", 0)
	var cx: Dictionary = MerlinResolution.resolve(_requis(3, false), _geste(3, 3, false), [], 7, [], 3, 1, 0, "Climax", 0)

	# ── LE VERDICT, sur les réglages retenus dans le code
	print("\nréglages retenus : atouts_propres_cap=%d eclat_margin=%d\n" % [cap0, ec0])
	_verifier("hier, le joueur de p74 ne mourait presque jamais (la mesure reproduit p74)", hier["morts"] < 3.0,
		"%.1f %% de morts" % hier["morts"])
	_verifier("hier, le dé disparaissait (sans jet sur plus de la moitié des gestes)", hier["sans_jet"] > 50.0,
		"%.1f %%" % hier["sans_jet"])
	_verifier("aujourd'hui, la mort est rare mais réelle (%.0f à %.0f %%)" % [CIBLE_MIN, CIBLE_MAX],
		auj["morts"] >= CIBLE_MIN and auj["morts"] <= CIBLE_MAX, "%.1f %% ± %.1f" % [auj["morts"], auj["ic"]])
	_verifier("le Climax se joue toujours au dé", auj["climax_de"] >= 99.9, "%.1f %%" % auj["climax_de"])
	_verifier("le dé revient (sans jet sur un quart des gestes au plus)", auj["sans_jet"] <= 25.0, "%.1f %%" % auj["sans_jet"])
	_verifier("l'éclatante a une fenêtre (un geste sur quarante au moins)", auj["eclat"] >= 2.5, "%.1f %%" % auj["eclat"])
	_verifier("l'intégrité bouge (minimum moyen sous 7)", auj["integ_min"] < 7.0, "%.1f" % auj["integ_min"])
	_verifier("sur une Épreuve, deux tags valent plus qu'un à dé égal", int(c2["total"]) > int(c1["total"]),
		"%d contre %d" % [int(c2["total"]), int(c1["total"])])
	_verifier("sur une Épreuve, aucun geste n'est sûr", not bool(c1["geste_sur"]) and not bool(c2["geste_sur"]))
	_verifier("au Climax, même la couverture pleine jette le dé", not bool(cx["geste_sur"]) and int(cx["die"]) == 7)

	# ── 001 : LE PERDANT REÇOIT QUELQUE CHOSE (décision de Maxime, 08/09)
	print("\n001 — greffes %.2f par traversée (max %d) · nœuds %.2f (max %d) · points gagnés sur revers %.2f · drafts armés par un degré %d"
		% [auj["greffes"], int(auj["greffes_max"]), auj["noeuds"], int(auj["noeuds_max"]), auj["points_revers"], int(auj["drafts_degre"])])
	_verifier("le perdant gagne des points de talent (points sur revers > 0)", auj["points_revers"] > 0.0, "%.2f" % auj["points_revers"])
	_verifier("jamais plus de cinq greffes par traversée", int(auj["greffes_max"]) <= MerlinRun.MAX_GRAFTS_PER_RUN, "%d" % int(auj["greffes_max"]))
	_verifier("jamais plus de trois nœuds de talent par traversée", int(auj["noeuds_max"]) <= MerlinRun.TALENT_NODES_PER_RUN, "%d" % int(auj["noeuds_max"]))
	_verifier("aucun draft n'est armé par un degré", int(auj["drafts_degre"]) == 0, "%d" % int(auj["drafts_degre"]))
	# La règle elle-même, dans le moteur de run (pas la simulation) :
	var run: Node = load("res://scripts/game/merlin_run.gd").new()
	run.new_run({"title": "épreuve", "beats": [{"n": 1, "type": "Exploration"}, {"n": 2, "type": "Rencontre"}]})
	_verifier("une réussite en Exploration n'ouvre rien", not run.le_monde_offre("reussite", "Exploration"))
	_verifier("une éclatante non plus", not run.le_monde_offre("eclatante", "Epreuve"))
	_verifier("un partiel ouvre le monde", run.le_monde_offre("partiel", "Exploration"))
	_verifier("un échec aussi", run.le_monde_offre("echec", "Epreuve"))
	_verifier("la première Rencontre n'ouvre pas", not run.le_monde_offre("reussite", "Rencontre"))
	_verifier("la seconde Rencontre ouvre", run.le_monde_offre("reussite", "Rencontre"))
	var tp0: int = int(run.talent_points)
	run.gain_talent_points("echec")
	_verifier("un échec donne un point de talent", int(run.talent_points) == tp0 + 1)
	run.gain_talent_points("eclatante")
	_verifier("une éclatante en donne deux", int(run.talent_points) == tp0 + 3)
	run.talent_points = 10
	run.noeuds_pris = MerlinRun.TALENT_NODES_PER_RUN
	_verifier("trois nœuds pris : le nœud ne s'offre plus", not run.can_offer_talent_node())
	run.noeuds_pris = 0
	_verifier("… et revient sous le cap", run.can_offer_talent_node())

	print("\n%s (%d échec%s)" % ["ÉPREUVE PASSÉE" if _rates == 0 else "ÉPREUVE ÉCHOUÉE",
		_rates, "s" if _rates > 1 else ""])
	quit(1 if _rates > 0 else 0)


func _ligne(arch: String, regle: String, r: Dictionary) -> void:
	print("%-11s %-12s %5.1f  ±%.1f    %5.1f      %5.1f     %5.1f      %5.1f         %4.1f      %4.1f" % [
		arch, regle, r["morts"], r["ic"], r["corrompus"], r["sans_jet"], r["eclat"], r["climax_de"],
		r["integ_fin"], r["integ_min"]])


## Joue _n_runs traversées par graine et rend des pourcentages (toutes graines cumulées).
func _serie(arch: String) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var runs: int = 0
	var morts: int = 0
	var corrompus: int = 0
	var gestes: int = 0
	var sans_jet: int = 0
	var eclat: int = 0
	var climax_total: int = 0
	var climax_de: int = 0
	var integ_fin_sum: int = 0
	var integ_min_sum: int = 0
	var greffes_sum: int = 0
	var greffes_max: int = 0
	var noeuds_sum: int = 0
	var noeuds_max: int = 0
	var points_revers: int = 0
	var drafts_degre: int = 0
	for graine in GRAINES:
		rng.seed = int(graine)
		for i in _n_runs:
			runs += 1
			var n: int = rng.randi_range(8, 25)
			var beats: Array = _scenario.build_quest_beats("épreuve", "", n, rng)
			var integ: int = MerlinRun.START_INTEGRITE
			var integ_min: int = integ
			var corruption: int = 0
			var talent: int = 0
			var points: int = 0
			var usage: int = 0
			var greffes: int = 0
			var noeuds: int = 0
			var rencontres: int = 0
			for b in beats:
				var btype: String = str((b as Dictionary).get("type", "Exploration"))
				var diff: int = int((b as Dictionary).get("difficulte", 2))
				var req_n: int = 3 if diff == 3 else 2
				var monde: bool = rng.randf() < MONDE_P
				var couverts: int = _couverture(arch, req_n, rng)
				var mastery: int = 2 if usage >= 6 else (1 if usage >= 3 else 0)
				var res: Dictionary = MerlinResolution.resolve(
					_requis(req_n, monde), _geste(couverts, req_n, monde), [], MerlinResolution.roll_2d6(rng), [],
					diff, talent + mastery, greffes, btype, 0)
				gestes += 1
				var deg: String = str(res["degree"])
				if bool(res["geste_sur"]):
					sans_jet += 1
				if deg == MerlinResolution.ECLATANTE:
					eclat += 1
				if btype == "Climax":
					climax_total += 1
					if not bool(res["geste_sur"]):
						climax_de += 1
				integ = clampi(integ + int(res["integrite_delta"]), 0, MerlinRun.MAX_INTEGRITE)
				integ_min = mini(integ_min, integ)
				corruption = maxi(0, corruption + int(res["corruption_delta"]))
				usage += 1
				# 001 (08/09) — LE TALENT AU TEMPS : un point par beat joué, deux sur une éclatante.
				var revers: bool = deg == MerlinResolution.PARTIEL or deg == MerlinResolution.ECHEC
				points += MerlinRun.TALENT_GAIN_ECLATANTE if deg == MerlinResolution.ECLATANTE else MerlinRun.TALENT_GAIN_BEAT
				if revers:
					points_revers += 1
				# 001 — LE DRAFT AU MONDE : une Rencontre sur deux, ou après un revers ; jamais au Climax,
				# jamais parce qu'on a réussi. UN draft : le nœud de talent ou une greffe, jamais les deux.
				if btype == "Rencontre":
					rencontres += 1
				var offre: bool = (btype == "Rencontre" and rencontres % 2 == 0) or revers
				if offre and btype != "Climax":
					if not revers and btype != "Rencontre":
						drafts_degre += 1  # ne doit jamais arriver : c'est la règle d'hier
					if points >= MerlinRun.TALENT_COST and talent < MerlinRun.TALENT_CAP \
							and noeuds < MerlinRun.TALENT_NODES_PER_RUN and rng.randf() < TALENT_P:
						talent += 1
						points -= MerlinRun.TALENT_COST
						noeuds += 1
					elif greffes < MerlinRun.MAX_GRAFTS_PER_RUN and rng.randf() < GRAFT_P:
						greffes += 1
				if integ <= 0:
					morts += 1
					break
				if corruption >= MerlinRun.CORRUPTION_CAP:
					corrompus += 1
					break
			integ_fin_sum += integ
			integ_min_sum += integ_min
			greffes_sum += greffes
			greffes_max = maxi(greffes_max, greffes)
			noeuds_sum += noeuds
			noeuds_max = maxi(noeuds_max, noeuds)
	var p: float = float(morts) / maxi(runs, 1)
	return {
		"morts": 100.0 * p,
		"ic": 100.0 * 1.96 * sqrt(p * (1.0 - p) / maxi(runs, 1)),
		"corrompus": 100.0 * corrompus / maxi(runs, 1),
		"sans_jet": 100.0 * sans_jet / maxi(gestes, 1),
		"eclat": 100.0 * eclat / maxi(gestes, 1),
		"climax_de": 100.0 * climax_de / maxi(climax_total, 1),
		"integ_fin": float(integ_fin_sum) / maxi(runs, 1),
		"integ_min": float(integ_min_sum) / maxi(runs, 1),
		"greffes": float(greffes_sum) / maxi(runs, 1), "greffes_max": greffes_max,
		"noeuds": float(noeuds_sum) / maxi(runs, 1), "noeuds_max": noeuds_max,
		"points_revers": float(points_revers) / maxi(runs, 1), "drafts_degre": drafts_degre,
	}


## « p74 » : la couverture mesurée du bot couvrant sur vingt beats (0 : 2 fois, 2 : 2 fois, 1 sinon).
## « aveugle » : presque rien (les nuits du 05 et du 06/09 : covNone sur tous les partiels).
func _couverture(arch: String, req_n: int, rng: RandomNumberGenerator) -> int:
	if arch == "p74":
		var t: float = rng.randf()
		return mini(req_n, 0 if t < 0.10 else (2 if t < 0.20 else 1))
	return 1 if rng.randf() < 0.3 else 0


## Les tags requis : famille Corps, ou un tag Monde en tête (Rituel) qui monte la nature d'un tier.
func _requis(n: int, monde: bool) -> Array:
	var base: Array = ["Force", "Agilité", "Endurance"]
	if monde:
		base = ["Rituel", "Force", "Agilité"]
	return base.slice(0, n)


## L'action est OBSERVER (famille Perception, tag Sens) ; le trait porte les tags couverts, Commune.
## Pas de synergie modélisée (la famille Corps ne nourrit pas Perception) : elle rendrait la mort
## plus rare.
func _geste(couverts: int, req_n: int, monde: bool) -> Array:
	return [
		{"name": "OBSERVER", "family": "Perception", "tags": ["Sens"]},
		{"tags": _requis(req_n, monde).slice(0, couverts), "rarity": "Commune"},
	]
