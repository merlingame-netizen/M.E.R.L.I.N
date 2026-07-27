extends SceneTree
## Probe SVG — verifie que le binaire Godot local embarque le module SVG (ThorVG)
## et que DPITexture (Godot 4.5, experimental) est disponible avec son color_map.
## Conditionne la Phase 6 du plan "Pipeline d'assets visuels".
##   Godot --headless --script res://tools/probe_svg.gd
##
## Sortie attendue si tout est present :
##   [SVG] load_svg_from_string err=0 (OK) size=64x64
##   [SVG] DPITexture: OUI (color_map present)
##   [SVG] VERDICT: MODULE_SVG=OUI

const SVG_SRC := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="#C9A24B"/><circle cx="32" cy="32" r="20" fill="#1E1A14"/></svg>'

func _init() -> void:
	var module_ok: bool = false

	# 1. Le module SVG est-il compile dans ce binaire ?
	var img: Image = Image.new()
	var err: int = img.load_svg_from_string(SVG_SRC, 1.0)
	if err == OK and img.get_width() > 0:
		module_ok = true
		print("[SVG] load_svg_from_string err=%d (OK) size=%dx%d" % [err, img.get_width(), img.get_height()])
		# Verifie que le rasteriseur produit bien la couleur canon GOLD au coin.
		var c: Color = img.get_pixel(2, 2)
		print("[SVG] pixel coin = %s (attendu ~#C9A24B)" % c.to_html(false))
	else:
		print("[SVG] load_svg_from_string ECHEC err=%d — module SVG ABSENT de ce build" % err)

	# 2. Mise a l'echelle : preuve que le vectoriel est scale-free.
	if module_ok:
		var big: Image = Image.new()
		if big.load_svg_from_string(SVG_SRC, 8.0) == OK:
			print("[SVG] scale=8.0 -> %dx%d (scale-free confirme)" % [big.get_width(), big.get_height()])

	# 3. DPITexture existe-t-il, et expose-t-il color_map ?
	if ClassDB.class_exists("DPITexture"):
		var has_map: bool = false
		for p in ClassDB.class_get_property_list("DPITexture"):
			if p.get("name", "") == "color_map":
				has_map = true
				break
		print("[SVG] DPITexture: OUI (color_map %s)" % ("present" if has_map else "ABSENT"))
	else:
		print("[SVG] DPITexture: NON (classe absente de ce build)")

	print("[SVG] VERDICT: MODULE_SVG=%s" % ("OUI" if module_ok else "NON"))
	quit(0 if module_ok else 1)
