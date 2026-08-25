# Le pont vm-run — exécuter sur la VM sans clé dans le chat

**Pourquoi.** La session de pilotage n'a aucun identifiant vers la VM (le conteneur est
éphémère — `~/.oci` a déjà été perdu ainsi), et la règle est absolue depuis l'incident de la
clé API Oracle : **aucun secret ne transite par la conversation, jamais**. Le pont déplace le
problème là où il est propre : la clé vit dans le coffre à secrets du dépôt GitHub, le
workflow l'utilise, la session ne la voit jamais — elle ne fait que pousser des commandes et
lire des résultats commités.

**Sécurité, dit clairement :**
- Quiconque peut pousser `cmd-*.sh` sur cette branche peut exécuter des commandes sur la VM
  sous l'utilisateur du pont. Le dépôt est privé ; les écrivains sont Maxime et le canal de la
  session. Chaque commande ET chaque sortie sont commitées : audit complet dans l'historique.
- **Révocation en un geste** : supprimer le secret `VM_SSH_KEY` (ou retirer la ligne de
  `authorized_keys` sur la VM). Le pont redevient inerte.
- Dédiée, pas recyclée : génère une paire NEUVE pour ce pont — jamais ta clé personnelle.
- Discipline de sortie : les résultats sont commités dans le dépôt — les commandes ne doivent
  jamais imprimer un fichier d'identifiants (même règle que la liaison ntfy du Courrier).

## Bootstrap (3 gestes, une seule fois — par Maxime)

1. **Générer la paire dédiée** (sur ton poste ou dans Cloud Shell) :
   ```bash
   ssh-keygen -t ed25519 -f merlin-pont -N "" -C "pont-github-vm"
   ```
2. **Autoriser la clé publique sur la VM** — une Run Command (console OCI, exécutée root) :
   ```bash
   install -d -m 700 -o ubuntu -g ubuntu /home/ubuntu/.ssh
   echo 'COLLE_ICI_LE_CONTENU_DE_merlin-pont.pub' >> /home/ubuntu/.ssh/authorized_keys
   chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys && chmod 600 /home/ubuntu/.ssh/authorized_keys
   ```
   (Si l'utilisateur du dépôt n'est pas `ubuntu`, remplace-le, et pose le secret `VM_USER`.)
3. **Poser les secrets** — GitHub > dépôt M.E.R.L.I.N > Settings > Secrets and variables >
   Actions > New repository secret :
   - `VM_SSH_KEY` = contenu du fichier **privé** `merlin-pont` (intégral, avec BEGIN/END)
   - `VM_HOST` = `141.253.124.75` (facultatif, c'est le défaut)
   - `VM_USER` = `ubuntu` (facultatif, c'est le défaut)

Puis dis-le dans la conversation : la première commande (`cmd-001`, diagnostic + réveil du
Courrier) part aussitôt, et la sortie complète revient commitée dans `resultats/`.

## Contrat d'exécution
- Le workflow exécute **la dernière** `cmd-*.sh` (tri par nom) **une seule fois** : la
  présence de `resultats/<nom>.txt` vaut marqueur « fait » (même contrat que le Courrier).
- Budget 80 min par commande (timeout SSH 4800 s), keepalive activé.
- VM injoignable = résultat commité avec l'erreur SSH : le pont sert aussi de sonde de vie.
- Le pont ne rallume PAS une instance éteinte — ça reste le bouton Start de la console.

## Variante écartée (pour mémoire)
Un utilisateur IAM dédié + clé API + `oci instance-agent command create` ferait pareil côté
Oracle, mais : 5 secrets au lieu d'un, l'agent tronque la sortie inline (~2 Ko — notre
diagnostic ne tient pas), et le détour Object Storage ajoute de l'infra. SSH : un secret,
sortie complète. Si un jour il faut aussi **démarrer** l'instance à distance, c'est LA raison
de repasser par IAM (politique restreinte à `instance start` sur cette seule instance).
