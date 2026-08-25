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

1. **Générer la paire dédiée**, dans Cloud Shell (icône `>_` de la console OCI) :
   ```bash
   ssh-keygen -t rsa -b 4096 -f merlin-pont -N "" -C "pont-github-vm"
   cat merlin-pont.pub
   ```
   **RSA et pas ed25519** : Cloud Shell tourne en **mode FIPS**, qui refuse ed25519
   (« ED25519 keys are not allowed in FIPS mode », vécu 2026-08-25). RSA-4096 est accepté et
   convient parfaitement ici. La sortie de `cat` est UNE ligne `ssh-rsa AAAAB3Nza…` : c'est la
   clé PUBLIQUE, elle n'est pas secrète.
2. **Autoriser la clé publique sur la VM** — une Run Command (console OCI, exécutée root).
   L'utilisateur du dépôt est détecté tout seul, et son nom est affiché en sortie :
   ```bash
   U="$(ls /home | head -1)"; [ -n "$U" ] || U=ubuntu
   install -d -m 700 "/home/$U/.ssh"
   echo 'ssh-rsa AAAA...COLLE_TA_CLE_PUBLIQUE_ICI... pont-github-vm' >> "/home/$U/.ssh/authorized_keys"
   chown -R "$U:$U" "/home/$U/.ssh"
   chmod 600 "/home/$U/.ssh/authorized_keys"
   echo "cle posee pour l'utilisateur : $U"
   ```
3. **Poser les secrets** — GitHub > dépôt M.E.R.L.I.N > Settings > Secrets and variables >
   Actions > New repository secret :
   - `VM_SSH_KEY` = contenu du fichier **privé** (`cat merlin-pont`), intégral, BEGIN/END inclus
   - `VM_USER` = le nom affiché à l'étape 2, **seulement** s'il n'est pas `ubuntu`
   - `VM_HOST` = `141.253.124.75` (facultatif, c'est le défaut)

   Puis, dans Cloud Shell : `rm merlin-pont merlin-pont.pub` (la clé vit désormais dans le
   coffre, plus besoin d'une copie qui traîne).

Puis dis-le dans la conversation : la première commande (`cmd-001`, diagnostic + réveil du
Courrier) part aussitôt, et la sortie complète revient commitée dans `resultats/`.

## Contrat d'exécution
- Le workflow exécute **la dernière** `cmd-*.sh` (tri par nom) **une seule fois** : la
  présence de `resultats/<nom>.txt` vaut marqueur « fait » (même contrat que le Courrier).
- Budget 80 min par commande (timeout SSH 4800 s), keepalive activé.
- VM injoignable = résultat commité avec l'erreur SSH : le pont sert aussi de sonde de vie.
- Le pont ne rallume PAS une instance éteinte — ça reste le bouton Start de la console.

## Si l'étape 2 échoue (plan B)
Depuis Cloud Shell, si tu peux déjà joindre la VM en SSH :
```bash
ssh ubuntu@141.253.124.75 "install -d -m 700 ~/.ssh && echo '$(cat merlin-pont.pub)' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo pose"
```

## Variante écartée (pour mémoire)
Un utilisateur IAM dédié + clé API + `oci instance-agent command create` ferait pareil côté
Oracle, mais : 5 secrets au lieu d'un, l'agent tronque la sortie inline (~2 Ko — notre
diagnostic ne tient pas), et le détour Object Storage ajoute de l'infra. SSH : un secret,
sortie complète. Si un jour il faut aussi **démarrer** l'instance à distance, c'est LA raison
de repasser par IAM (politique restreinte à `instance start` sur cette seule instance).
