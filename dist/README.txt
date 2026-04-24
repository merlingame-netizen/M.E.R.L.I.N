M.E.R.L.I.N. - Le Jeu des Oghams
=================================

LANCEMENT :
  Double-clique sur MERLIN.exe

NOUVEAUTES v4 (Tout en .tscn natif Godot) :
- Toutes les scenes ont ete reconstruites avec des nodes natifs Godot
  (au lieu d'etre buildees procedurale via script)
- 7 materiaux PS1 reutilisables (.tres) :
  ps1_stone / wood_dark / wood_warm / iron / tapestry /
  parchment / grass / foliage
- Shader PS1 amplifie : vertex snapping en clip space, affine texture
  mapping, 32-level color quantization, 4x4 Bayer dithering, vertex
  lighting only (pas de specular ni de shadows)

MENU 3DPC (ex 2D, maintenant FPS exterieur) :
- Tu spawn dehors devant la cabane de Merlin
- Foret de pins low-poly autour
- Sentier de pierres menant a la porte
- Lumiere lunaire bleue + lueur ambree de la porte
- Vise la porte + E = entrer dans le cabin
- Vise la pierre dressee + E = quitter

CABIN HUB (FPS interieur):
- 4 murs + plafond + sol en bois sombre
- Feu de cheminee (lumiere chaude OmniLight)
- Cauldron en fer (sphere PS1)
- Tapisserie rouge sang sur le mur arriere
- Carte murale (parchemin) sur le mur gauche
- Porte de sortie sur le mur avant
- Table en bois + 4 pieds
- 4 poutres de plafond
- Tapis rouge sur le sol
- Crosshair central + hint d'interaction

CONTROLES :
  WASD        marcher
  Souris      regarder
  E / Espace  interagir
  Echap       liberer la souris

TAILLE : ~165 MB
