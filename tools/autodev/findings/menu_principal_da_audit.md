# Menu Principal — DA Audit (2026-03-20)

## Screenshot: tools/autodev/captures/menu_principal_real.png

## Problemes identifies

### CRITICAL
1. **Textes non traduits** — MENU_NEW_GAME, MENU_CONTINUE, MENU_OPTIONS
   Cause: translations.csv manquant (erreur connue dans baseline)
   Fix: fallback hardcoded dans le code OU créer translations.csv

### HIGH  
2. **CRT scanlines trop fortes** — réduisent lisibilité
   Fix: crt_static.gdshader intensity 0.3→0.1
3. **Contraste insuffisant** — MENU_OPTIONS presque invisible
   Fix: augmenter alpha des labels non-sélectionnés

### MEDIUM
4. **Date en breton incohérente** — "Gwener, 20 Meurzh" n'apporte rien
   Fix: retirer la date, garder seulement l'heure (00:34)
5. **Boutons taille inégale** — NEW_GAME a un fond, pas les autres
   Fix: uniformiser les StyleBox pour les 3 boutons

### LOW
6. **Ornements celtiques** — ASCII trop discrets
   Fix: utiliser des caractères Unicode ou des sprites

## Status: OPEN
