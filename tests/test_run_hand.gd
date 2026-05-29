extends RefCounted
## Unit Tests — MerlinRun, mécanique de main (play_and_discard).
## La carte jouée doit être remplacée À SON INDEX (slot libéré), pas ajoutée en bout de
## main — sinon la repioche file à droite de l'éventail (demande user 2026-05-27).

const MerlinRunScript = preload("res://scripts/game/merlin_run.gd")


func test_play_refills_freed_slot_in_place() -> bool:
	var run: Node = MerlinRunScript.new()
	var c0: MerlinCard = MerlinCard.make("a", "A", ["Sens"], "")
	var c1: MerlinCard = MerlinCard.make("b", "B", ["Force"], "")
	var c2: MerlinCard = MerlinCard.make("c", "C", ["Ruse"], "")
	var c3: MerlinCard = MerlinCard.make("d", "D", ["Verbe"], "")
	var c4: MerlinCard = MerlinCard.make("e", "E", ["Nature"], "")
	var nxt: MerlinCard = MerlinCard.make("z", "Z", ["Savoir"], "")
	run.hand = [c0, c1, c2, c3, c4]   # main pleine (HAND_SIZE = 5)
	run.deck = [nxt]                  # pop_back() → nxt
	run.discard = []
	run.play_and_discard([c2])        # joue la carte du MILIEU (index 2)
	var ok: bool = true
	if run.hand.size() != 5:
		push_error("Main attendue de taille 5, obtenu %d" % run.hand.size())
		ok = false
	elif run.hand[2] != nxt:
		var got: String = (run.hand[2].card_name if run.hand[2] != null else "null")
		push_error("La repioche doit prendre le slot 2 ; obtenu '%s' (attendu 'Z')" % got)
		ok = false
	elif not run.discard.has(c2):
		push_error("La carte jouée doit être défaussée")
		ok = false
	run.free()
	return ok


func test_play_refills_first_slot_in_place() -> bool:
	var run: Node = MerlinRunScript.new()
	var c0: MerlinCard = MerlinCard.make("a", "A", ["Sens"], "")
	var c1: MerlinCard = MerlinCard.make("b", "B", ["Force"], "")
	var c2: MerlinCard = MerlinCard.make("c", "C", ["Ruse"], "")
	var c3: MerlinCard = MerlinCard.make("d", "D", ["Verbe"], "")
	var c4: MerlinCard = MerlinCard.make("e", "E", ["Nature"], "")
	var nxt: MerlinCard = MerlinCard.make("z", "Z", ["Savoir"], "")
	run.hand = [c0, c1, c2, c3, c4]
	run.deck = [nxt]
	run.discard = []
	run.play_and_discard([c0])        # joue la PREMIÈRE carte (index 0)
	var ok: bool = true
	if run.hand[0] != nxt:
		var got: String = (run.hand[0].card_name if run.hand[0] != null else "null")
		push_error("La repioche doit prendre le slot 0 ; obtenu '%s' (attendu 'Z')" % got)
		ok = false
	run.free()
	return ok


func test_play_multi_card_combo_refills_each_slot() -> bool:
	# Combo réel (1 principale + modificateurs) : chaque slot joué est remplacé en place,
	# les slots non joués restent intacts. Robuste à l'ordre de pioche (deck pop_back).
	var run: Node = MerlinRunScript.new()
	var c0: MerlinCard = MerlinCard.make("a", "A", ["Sens"], "")
	var c1: MerlinCard = MerlinCard.make("b", "B", ["Force"], "")
	var c2: MerlinCard = MerlinCard.make("c", "C", ["Ruse"], "")
	var c3: MerlinCard = MerlinCard.make("d", "D", ["Verbe"], "")
	var c4: MerlinCard = MerlinCard.make("e", "E", ["Nature"], "")
	var z1: MerlinCard = MerlinCard.make("z1", "Z1", ["Savoir"], "")
	var z2: MerlinCard = MerlinCard.make("z2", "Z2", ["Mémoire"], "")
	run.hand = [c0, c1, c2, c3, c4]
	run.deck = [z1, z2]
	run.discard = []
	run.play_and_discard([c1, c3])    # joue les slots 1 et 3
	var ok: bool = true
	var draws: Array = [z1, z2]
	if run.hand.size() != 5:
		push_error("Main attendue de taille 5, obtenu %d" % run.hand.size())
		ok = false
	elif run.hand[0] != c0 or run.hand[2] != c2 or run.hand[4] != c4:
		push_error("Les slots non joués (0,2,4) doivent rester intacts")
		ok = false
	elif not draws.has(run.hand[1]) or not draws.has(run.hand[3]) or run.hand[1] == run.hand[3]:
		push_error("Les slots 1 et 3 doivent recevoir deux repioches distinctes")
		ok = false
	elif not run.discard.has(c1) or not run.discard.has(c3):
		push_error("Les deux cartes jouées doivent être défaussées")
		ok = false
	run.free()
	return ok
