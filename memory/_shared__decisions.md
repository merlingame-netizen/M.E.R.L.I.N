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
