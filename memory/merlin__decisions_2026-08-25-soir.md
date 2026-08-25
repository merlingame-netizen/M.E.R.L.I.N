# MERLIN — décisions du 25/08 (soir, heure de Paris)

## Le pont SSH vers la VM : construit, instructif, et bloqué

Maxime : « peut-on donner un accès API depuis Oracle pour que tu puisses ingérer cette
commande ? » → pont `vm-run` (workflow Actions + clé dans le coffre GitHub, jamais dans le
chat). Cinq tentatives, chacune ayant appris quelque chose de définitif :

| # | Symptôme | Leçon |
|---|----------|-------|
| 001 | `ubuntu` : Permission denied | **La VM RÉPOND** — sshd actif. Le silence de 19 h venait des AGENTS, pas d'une panne. Diagnostic « VM morte / OOM » : FAUX. |
| 002 | ocarun refusé malgré clé posée | `ocarun` = compte de service, `/usr/sbin/nologin`, home `/var/lib/ocarun`. **Il ne recevra JAMAIS de SSH**, quelle que soit la clé. Clé intacte, permissions parfaites : mauvaise cible. |
| 003 | clé d'origine refusée | — |
| 004 | `error in libcrypto` | Le pont dissèque désormais les refus : corps PKCS#1 RSA-2048 complet (25 lignes) **sans ses lignes BEGIN/END**. Un refus muet ne dit rien ; un refus qui publie type, empreinte et **clé publique dérivée** résout. |
| 005 | clé valide, serveur refuse | `2048 SHA256:rveJrOlz… (RSA)` lue et proposée — mais **cette clé n'est installée sur aucun compte de l'instance**. |

**Verdict : `SUDO=non`.** `ocarun` ne peut ni se connecter, ni écrire chez `opc`. Aucune voie
n'ouvre SSH depuis la VM elle-même. Le pont reste **en place et inerte** : le jour où une clé
sera installée pour `opc` (recréation d'instance, ou console série), il fonctionnera sans
rien changer. Sa clé publique à installer est publiée dans
`infra/vm-run/resultats/cmd-005-reveil.txt`.

## Ce que ça ne coûte PAS : la boucle autonome n'a jamais eu besoin de SSH

```
moi → push GitHub (dépôt PUBLIC, tirable sans identifiant)
    → tools-autosync tire l'outillage      (cron, */15)
    → le Courrier exécute les jobs          (cron, */2)
    → résultats par ntfy, que je lis
```

Le seul maillon cassé le 2026-08-24 à 20:45Z, c'est **le cron**. Une seule Run Command le
remet en marche (`infra/vm-run/RELANCE-CRON.sh`) et la boucle redevient autonome. SSH aurait
été un confort de diagnostic, pas la condition de l'autonomie.

## Leçons d'outillage

- **Run Command tronque l'affichage vers ~2 Ko.** Trois diagnostics ont été perdus à la même
  coupure avant que je ne le comprenne. Toute commande destinée à Run Command doit tenir en
  quelques lignes étiquetées (A, B, C…), jamais en sections verbeuses.
- **Cloud Shell est en mode FIPS** : `ssh-keygen -t ed25519` refuse (« not allowed in FIPS
  mode »). RSA-4096 passe.
- **Une clé privée collée à la souris perd ses lignes BEGIN/END** : le corps était intact,
  seules les deux lignes d'encadrement manquaient. Toujours `Ctrl+A` dans un éditeur.
- **Le dépôt est PUBLIC** (j'écrivais « privé » dans le README du pont : faux, corrigé). Le
  sujet ntfy y est donc lisible par tous ; la discipline de sortie (ne jamais imprimer un
  fichier d'identifiants) n'est pas une précaution de style, c'est la seule barrière.
- **Deux comptes GitHub** : `merlingame-netizen` (propriétaire du dépôt) et
  `MaximeBABONNEAU` (qui possède un fork, renommé « MERLIN » — piège à confusion : il est 167
  commits en retard et sert au suivi de prix de vols).
