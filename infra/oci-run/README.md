# Le pont OCI — je pilote la VM et la Run Command moi-même

Le pont SSH (vm-run) est resté inerte : `ocarun` en nologin, `opc` sans clé, pas de sudo.
Celui-ci passe par **l'API d'Oracle** — le même mécanisme que le bouton « Run Command » de la
console, plus le pilotage de l'instance (START/STOP). La clé API vit dans le coffre GitHub,
jamais dans la conversation.

## Bootstrap (5 minutes, une seule fois — par Maxime)

### 1. Créer la clé API dans la console Oracle
1. https://cloud.oracle.com → avatar en haut à droite → **Mon profil** (My profile)
2. Menu de gauche → **Clés d'API** (API keys) → **Ajouter une clé d'API**
3. « **Générer une paire de clés d'API** » → **Télécharger la clé privée** (fichier `.pem`)
   → **Ajouter**
4. Un encart « **Aperçu du fichier de configuration** » s'affiche : il contient `user=`,
   `fingerprint=`, `tenancy=`, `region=`. **Garde-le ouvert**, tout va dans les secrets.

### 2. Poser les 6 secrets GitHub
https://github.com/merlingame-netizen/M.E.R.L.I.N/settings/secrets/actions → New repository secret :

| Nom | Valeur |
|---|---|
| `OCI_USER_OCID` | la ligne `user=` de l'aperçu (commence par `ocid1.user.`) |
| `OCI_TENANCY_OCID` | la ligne `tenancy=` (commence par `ocid1.tenancy.`) |
| `OCI_FINGERPRINT` | la ligne `fingerprint=` (aa:bb:cc:…) |
| `OCI_REGION` | la ligne `region=` (`eu-paris-1`) |
| `OCI_PRIVATE_KEY` | tout le contenu du fichier `.pem` téléchargé (Ctrl+A dans le Bloc-notes) |
| `OCI_INSTANCE_OCID` | page de l'instance `merlin-arm-a1` → champ **OCID** → bouton *Copier* (commence par `ocid1.instance.`) |

### 3. Dire « posé » dans la conversation
Je pousse une commande de test et le pont démarre.

## Comment ça marche ensuite
- Je pousse `infra/oci-run/cmd-NNN-nom.sh` → la VM l'exécute (compte `ocarun`, comme la console) ;
  la sortie revient commitée dans `resultats/` (tronquée ~2 Ko par Oracle — les gros retours
  passent par ntfy depuis le script, comme le Courrier l'a toujours fait).
- Je pousse `infra/oci-run/action-NNN.txt` contenant `START`, `STOP` ou `RESET` → l'instance
  obéit. **C'est le trou que SSH ne comblait pas : rallumer une VM éteinte.**
- Une commande = une exécution (marqueur `resultats/<nom>.txt`, contrat du Courrier).

## Sécurité, dit clairement
- La clé API donne accès à **tout le compte Oracle** (c'est la clé de TON utilisateur).
  Elle ne quitte jamais le coffre GitHub ; le workflow n'exerce que deux opérations (Run
  Command sur UNE instance, action d'instance). Quiconque peut pousser sur cette branche peut
  exécuter ces deux opérations — aujourd'hui : toi et le canal de cette session, tout est
  commité donc audité.
- **Révocation en un geste** : console → Mon profil → Clés d'API → supprimer. Le pont meurt
  instantanément.
- Discipline de sortie inchangée : dépôt public → les scripts n'impriment jamais un fichier
  d'identifiants.
""
