#!/usr/bin/env bash
# A executer DANS LE CLOUD SHELL Oracle. Trouve la VM A1 via le CLI oci (deja authentifie
# dans le Cloud Shell), saute dessus en SSH, y lance up.sh, et rapporte URL + token.
#
#   curl -fsSL https://raw.githubusercontent.com/merlingame-netizen/M.E.R.L.I.N/main/infra/oracle/studio/from-cloudshell.sh | bash
#
# Mode diagnostic seul (n'installe rien, imprime juste l'inventaire) :
#   ... | bash -s -- --check
set -euo pipefail
CHECK_ONLY="${1:-}"
RAW=https://raw.githubusercontent.com/merlingame-netizen/M.E.R.L.I.N/main/infra/oracle/studio/up.sh
say() { printf '%s\n' "$*"; }

say ""
say "=============================================="
say " MERLIN : Cloud Shell -> VM A1"
say "=============================================="

command -v oci >/dev/null 2>&1 || { say "[ECHEC] CLI 'oci' absent : ce script s'execute DANS le Cloud Shell Oracle."; exit 1; }
TEN="${OCI_TENANCY:-}"
[ -n "$TEN" ] || TEN="$(oci iam compartment list --access-level ACCESSIBLE --compartment-id-in-subtree true \
                        --query 'data[0]."compartment-id"' --raw-output 2>/dev/null || true)"
[ -n "$TEN" ] || { say "[ECHEC] tenancy introuvable (variable OCI_TENANCY vide)."; exit 1; }
say "Tenancy OCID : $TEN"

# ── Inventaire des instances (tenancy + compartiments) ──────────────────────
say "==> Recherche des instances..."
LIST="$(oci compute instance list -c "$TEN" --all \
        --query 'data[?"lifecycle-state"!=`TERMINATED`].{n:"display-name",s:"lifecycle-state",id:id,shape:shape}' \
        --output json 2>/dev/null || echo '[]')"
COUNT="$(printf '%s' "$LIST" | python3 -c 'import json,sys;print(len(json.load(sys.stdin) or []))' 2>/dev/null || echo 0)"
if [ "$COUNT" = "0" ]; then
  say "  Aucune instance dans le compartiment racine. Recherche dans les sous-compartiments..."
  for C in $(oci iam compartment list --compartment-id "$TEN" --all --query 'data[].id' --raw-output 2>/dev/null | tr -d '[],"' ); do
    L="$(oci compute instance list -c "$C" --all --query 'data[?"lifecycle-state"!=`TERMINATED`].{n:"display-name",s:"lifecycle-state",id:id,shape:shape}' --output json 2>/dev/null || echo '[]')"
    N="$(printf '%s' "$L" | python3 -c 'import json,sys;print(len(json.load(sys.stdin) or []))' 2>/dev/null || echo 0)"
    [ "$N" != "0" ] && LIST="$L" && COUNT="$N" && TEN="$C" && break
  done
fi
[ "$COUNT" != "0" ] || { say "[ECHEC] aucune instance trouvee. La VM a-t-elle bien ete creee ?"; exit 1; }

printf '%s' "$LIST" | python3 -c '
import json,sys
for i in json.load(sys.stdin) or []:
    print("   - %-22s %-10s %s" % (i.get("n"), i.get("s"), i.get("shape")))'

ID="$(printf '%s' "$LIST" | python3 -c 'import json,sys; d=json.load(sys.stdin) or []; print((d[0] or {}).get("id",""))')"
STATE="$(printf '%s' "$LIST" | python3 -c 'import json,sys; d=json.load(sys.stdin) or []; print((d[0] or {}).get("s",""))')"
say "Instance OCID : $ID"

if [ "$STATE" != "RUNNING" ]; then
  say "  Instance a l'etat $STATE -> demarrage..."
  oci compute instance action --instance-id "$ID" --action START --wait-for-state RUNNING >/dev/null 2>&1 || true
fi

IP="$(oci compute instance list-vnics --instance-id "$ID" --query 'data[0]."public-ip"' --raw-output 2>/dev/null || true)"
[ -n "$IP" ] || { say "[ECHEC] pas d'IP publique sur cette instance."; exit 1; }
say "IP publique   : $IP"

# ── Cle SSH ─────────────────────────────────────────────────────────────────
KEY=""
for k in "$HOME/.ssh/merlin_oracle" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
  [ -f "$k" ] && KEY="$k" && break
done
if [ -z "$KEY" ]; then
  say ""
  say "[!] Aucune cle SSH dans le Cloud Shell ($HOME/.ssh)."
  say "    La VM n'accepte que la cle fournie a sa creation. Sans elle, il faut"
  say "    passer par la console serie (Instance > Console connection) pour en reinjecter une."
  exit 1
fi
say "Cle SSH       : $KEY"

say ""
say "--- A NOTER (evite un futur blocage) ---"
say "  Tenancy OCID  : $TEN"
say "  Instance OCID : $ID"
say "  IP publique   : $IP"
say "----------------------------------------"

if [ "$CHECK_ONLY" = "--check" ]; then
  say ""
  say "Mode diagnostic : rien n'a ete installe."
  exit 0
fi

# ── Saut sur la VM et mise en route du Studio ───────────────────────────────
say ""
say "==> Connexion a la VM et lancement du Studio (2-3 min la premiere fois)"
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -i "$KEY" "ubuntu@$IP" \
    "curl -fsSL $RAW | bash" || {
  say "[ECHEC] SSH ou deploiement. Essaie manuellement :"
  say "  ssh -i $KEY ubuntu@$IP"
  exit 1
}
