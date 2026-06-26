class_name MerlinTween
extends RefCounted
## v10.17 (track Motion) — Helper de tween MANAGÉ (inspiré du TweenNode de KoBeWi).
## Centralise l'idiome répété ~15× dans le code : « tuer le tween précédent de cette
## propriété avant d'en créer un nouveau » (sinon deux tweens se battent sur la même cible).
##
## Conception (meilleure que la leash-node : zéro enfant ajouté à l'arbre, donc rien à
## filtrer dans les boucles get_children) : le tween précédent est mémorisé en META sur le
## node lui-même, indexé par une CLÉ logique (plusieurs tweens distincts par node possibles).
## - Stockage par meta → meurt avec le node (zéro fuite, zéro réutilisation d'instance_id).
## - `node.create_tween()` est déjà auto-tué par Godot à la sortie de l'arbre → l'auto-kill
##   sur exit est GRATUIT ; MerlinTween n'ajoute QUE le kill-du-précédent-de-même-clé.
##
## Usage :
##   _tw = MerlinTween.retween(self, "typewriter")          # remplace if _tw: _tw.kill(); _tw = create_tween()
##   _pulse = MerlinTween.retween_looping(node, "pulse")    # boucle lifecycle-safe (recettes float_bob…)
##   MerlinTween.kill_for(self, "typewriter")               # remplace if _tw and _tw.is_valid(): _tw.kill()
##
## Classe STATIQUE pure (zéro état global, zéro autoload) — même discipline que MerlinProse/MerlinJson.

const _META_PREFIX: String = "_mtween_"


## Tue le tween précédent de (node, key) puis renvoie un tween NEUF lié au node (donc
## auto-tué à la sortie de l'arbre par Godot). `key` permet plusieurs tweens simultanés sur
## un même node (ex. "typewriter" et "breathe" sur le même label sans se tuer mutuellement).
static func retween(node: Node, key: String = "default") -> Tween:
	kill_for(node, key)
	var t: Tween = node.create_tween()
	node.set_meta(_META_PREFIX + key, t)
	return t


## Comme retween mais en boucle (.set_loops()) — pour les animations idle/respiration
## (float_bob, pulse) qui ne doivent JAMAIS survivre à leur node ni s'empiler.
static func retween_looping(node: Node, key: String = "loop") -> Tween:
	return retween(node, key).set_loops()


## Tue le tween managé de (node, key) s'il existe et est valide. Idempotent — sûr à appeler
## même si aucun tween n'a été créé (remplace le boilerplate `if _tw and _tw.is_valid(): _tw.kill()`).
static func kill_for(node: Node, key: String = "default") -> void:
	if node == null or not is_instance_valid(node):
		return
	var mk: String = _META_PREFIX + key
	if node.has_meta(mk):
		var prev: Variant = node.get_meta(mk)
		if prev is Tween and (prev as Tween).is_valid():
			(prev as Tween).kill()
		node.remove_meta(mk)
