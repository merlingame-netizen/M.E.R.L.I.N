#!/usr/bin/env bash
# ETAPE 2 (2e essai) — pourquoi sshd refuse-t-il la cle du pont ?
#
# A COLLER DANS UNE RUN COMMAND (console OCI), en remplacant la ligne CLE ci-dessous par ta
# cle publique. Elle s'execute sous `ocarun`, sans sudo.
#
# Constat du 1er essai : la cle EST dans /var/lib/ocarun/.ssh/authorized_keys (1 ligne), et
# sshd refuse quand meme. `ocarun` est un compte de SERVICE (home dans /var/lib, pas /home) :
# trois causes possibles, ce script les departage toutes et repare ce qu'il peut.
#   1. shell de connexion interdit (nologin) -> aucune cle ne marchera jamais pour ce compte
#   2. StrictModes : home ou .ssh aux mauvaises permissions/proprietaire -> reparable ici
#   3. sshd_config restreint (AllowUsers opc) -> il faut passer par opc
# Et si sudo est disponible, on installe AUSSI la cle pour opc, le compte d'administration.

CLE='ssh-rsa AAAA...COLLE_TA_CLE_PUBLIQUE_ICI... pont-github-vm'

echo "===== 1. QUI SUIS-JE ====="
id
echo "home=$HOME"
getent passwd "$(whoami)"
echo "-- shell de connexion (nologin/false = SSH IMPOSSIBLE pour ce compte) --"
getent passwd "$(whoami)" | cut -d: -f7

echo "===== 2. PERMISSIONS (sshd en StrictModes les exige strictes) ====="
ls -ld "$HOME" "$HOME/.ssh" "$HOME/.ssh/authorized_keys" 2>&1

echo "===== 3. LA CLE EST-ELLE INTACTE ? ====="
# On n'imprime QUE le debut et la fin de chaque ligne : jamais la cle entiere.
awk '{printf "ligne %d : %d caracteres | debut=%s | fin=%s\n", NR, length($0), substr($0,1,12), substr($0,length($0)-15)}' \
    "$HOME/.ssh/authorized_keys" 2>&1
echo "(attendu pour du RSA-4096 : UNE ligne, ~740 caracteres, debut=ssh-rsa AAAA, fin=pont-github-vm)"

echo "===== 4. REPARATION DES PERMISSIONS (cause 2) ====="
chmod 700 "$HOME/.ssh" 2>&1 && echo ".ssh -> 700"
chmod 600 "$HOME/.ssh/authorized_keys" 2>&1 && echo "authorized_keys -> 600"
chmod g-w,o-w "$HOME" 2>&1 && echo "home : ecriture groupe/autres retiree"
ls -ld "$HOME" "$HOME/.ssh" "$HOME/.ssh/authorized_keys"

echo "===== 5. SUDO DISPONIBLE ? ====="
if sudo -n true 2>/dev/null; then
    echo "sudo : OUI"
    echo "-- restrictions sshd --"
    sudo -n grep -Ei '^[[:space:]]*(AllowUsers|DenyUsers|PubkeyAuthentication|StrictModes|AuthorizedKeysFile|UsePAM)' /etc/ssh/sshd_config 2>&1 | head
    echo "-- pourquoi le refus ? (journal sshd) --"
    sudo -n journalctl -u sshd -n 60 --no-pager 2>/dev/null \
      | grep -iE "ocarun|invalid user|denied|authorized_keys|bad ownership|not allowed" | tail -8
    echo "-- installation de la cle pour opc (compte d'administration) --"
    sudo -n install -d -m 700 -o opc -g opc /home/opc/.ssh 2>&1
    if ! sudo -n grep -qF "pont-github-vm" /home/opc/.ssh/authorized_keys 2>/dev/null; then
        echo "$CLE" | sudo -n tee -a /home/opc/.ssh/authorized_keys >/dev/null 2>&1 \
          && echo "cle ajoutee pour opc" || echo "echec de l'ajout pour opc"
    else
        echo "cle deja presente pour opc"
    fi
    sudo -n chown opc:opc /home/opc/.ssh/authorized_keys 2>&1
    sudo -n chmod 600 /home/opc/.ssh/authorized_keys 2>&1
    sudo -n ls -ld /home/opc/.ssh /home/opc/.ssh/authorized_keys 2>&1
else
    echo "sudo : NON — impossible d'installer la cle pour opc depuis ce compte,"
    echo "       ni de lire sshd_config ou le journal sshd."
fi

echo "===== 6. RESUME ====="
echo "shell ocarun : $(getent passwd "$(whoami)" | cut -d: -f7)"
echo "sudo         : $(sudo -n true 2>/dev/null && echo oui || echo non)"
echo "depot        : $(ls -d "$HOME/workspace/M.E.R.L.I.N" 2>/dev/null || echo ABSENT)"
echo "===== fin ====="
