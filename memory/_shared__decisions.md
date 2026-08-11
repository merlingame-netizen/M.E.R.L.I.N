# _shared — Decisions

## 2026-06-15: Flotte cloud gratuite 24/7 déployée (GCP e2-micro + Cloudflare)
- **quoi** : flotte multi-cloud always-free opérationnelle — GCP e2-micro (VPS léger) +
  Cloudflare Worker/D1/Pages (API/SQLite/web sans carte). Oracle A1 (4/24) bâti mais en
  attente de capacité (« Out of host capacity »). Fly.io abandonné (carte obligatoire).
- **pourquoi** : héberger services / data / monitoring 24/7 à **0 €**, via un hub unique
  (`fleet serve`) + dispatcher à garde stricte qui ne dépasse jamais le quota free.

## 2026-06-15: AtelierIAIdrac sorti de Firebase vers la VM GCP gratuite
- **quoi** : backend maison Node (REST + WebSocket sur SQLite arbre type RTDB) + **shim
  Firebase-compat** (`firebase.database()/auth()/storage()`) → les 31 modules front restent
  inchangés, seul `index.html` change (`window.AIA_BACKEND` + `js/firebase-shim.js`). Données
  RTDB importées (15 root nodes) ; exposé via Cloudflare Tunnel (HTTPS/WSS, 0 port ouvert).
  Shim validé 15/15 (`infra/fleet/atelier/server/shimtest.js`).
- **pourquoi** : supprimer la dépendance Firebase, rester 100 % gratuit, garder le temps réel
  (chat / présence / livebattle+votes / activité / leaderboard).
- **pending** : (1) durcissement — l'endpoint tunnel est **ouvert sans auth serveur** (expose
  `accounts/*/passwordHash`) → ajouter un token partagé (server.js + shim) ; (2) URL **stable**
  (named tunnel au lieu de l'éphémère trycloudflare) ; (3) migration médias Storage ; (4) cleanup
  de la clé Firebase admin restée sur la VM (`rm ~/*firebase-adminsdk*.json`).

## 2026-08-10: VM Oracle perso — image Oracle Linux 9 obligatoire (pas Ubuntu)
- La VM A1 a été détruite (Ubuntu) et relancée en Oracle Linux 9.8 aarch64 (autorisation explicite Maxime).
- Pourquoi : l'agent Oracle des images Ubuntu (snap) N'EMBARQUE PAS le plugin « Compute Instance Run Command » (vérifié : 10 plugins listés, Run Command absent après 50 min + reboot). Sans SSH sortant depuis le sandbox Claude, Run Command est le SEUL canal de pilotage agent → Ubuntu = VM impilotable.
- Règle : toute VM OCI destinée à être pilotée par l'agent DOIT être Oracle Linux (utilisateur `opc`). `agent_launch.py --os oracle9` est le défaut.
- Provisioning : cloud-init minimal + `infra/oracle/studio/provision-ol9.sh` via Run Command (godot 4.6 arm64, node 20, ollama, repo, up.sh Studio+tunnel, pull Gemma en arrière-plan).

## 2026-08-11: Finalité de la VM Oracle (questionnaire Maxime, 9 réponses)
- **Usage n°1 : atelier de dév distant** — Godot + Claude + LLM tournent en continu
  sur la VM, Maxime pilote. Le jeu s'y joue, mais l'outillage prime sur le confort pur.
- **Accès** : Maxime + quelques testeurs (lien + identifiants). Pas public.
- **Appareils** : PC ET mobile à parts égales → tactile obligatoire (cibles ≥ 44 px,
  pas de survol, pas de scroll horizontal masquant des onglets).
- **Disponibilité** : 24/7, toujours prête (relance auto après reboot).
- **Écran de jeu** : adaptatif à la fenêtre, l'atelier reste visible autour
  (pas de mode plein écran par défaut).
- **Refonte demandée = navigation DU PORTAIL**, pas le menu du jeu.
- **Priorités UX** (dans l'ordre) : utilisable au doigt · état visible d'un coup d'œil ·
  épuré.
- **Lag** : déclaré RÉSOLU après optimisations (30 FPS, 960×540, compression 6→1,
  x11vnc -threads). Ne pas dégrader davantage sans nouvelle demande.
- **Non tranché** (defaults appliqués, réversibles) : plancher de qualité, allègement
  du rendu du jeu (→ non appliqué), agents supplémentaires, autonomie des agents,
  canal d'alerte, budget CPU nocturne.
- **Question ouverte majeure** : sort de `main` (170 commits, DA CRT périmée) face à
  `feat/practices-docs` (207 commits, le vrai jeu). Opération destructrice → jamais
  entreprise sans demande explicite.

## 2026-08-11: Chaîne autonome + interface enfantine (questionnaire 3 rounds, 11 réponses)
- **Autonomie** : auto sauf décisions stratégiques. Contenu validé auto-intégré au corpus ;
  balance/design/bugs/UX/DA/bible/gros diffs (>30 lignes) = cartes Décider.
- **Codeur** : LOCAL Gemma 4 (refus du cloud). e4b maintenant, 12b après extension disque.
  Le diff est décidé en amont (before/after) — application déterministe, périmètre
  data+constantes+patchs ≤30 lignes, worktree auto/nightly, smoke par patch.
- **Merge** : jamais automatique. Carte « Intégrer la nuit » = 1 tap = merge --no-ff + push.
- **Interface** : 3 onglets (Jouer/Décider/Santé) + engrenage Coulisses. Santé = 5 voyants
  géants dont la facture Oracle.
- **Cadence** : 24/7 sauf jeu ouvert, reprise +10 min. Alertes : digest 7h (sauf bloquant).
- **Playtest bot** : heuristiques déterministes d'abord (écran noir/figé/crash), captures
  jointes aux cartes ; jugement esthétique = humain. (v11.3 à faire)
- **PAYG IMPÉRATIF 0 €** : budget Oracle double alerte (ACTUAL 1 centime + FORECAST 50 %,
  2 emails), audit ressources = zéro payant (A1 plein free, 100/200 Go), montant non nul
  → carte Décider urgente + ntfy. Extension disque growfs = 0 € (volume déjà compté).
