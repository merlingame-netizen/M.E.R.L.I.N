#!/usr/bin/env python3
"""Pilotage de la VM Oracle SANS SSH, via l'API (Instance Agent "Run Command").

C'est le script que l'agent Claude execute LUI-MEME depuis son environnement des que
~/.oci/config + la cle API existent (le port 22 sortant est bloque cote reseau, mais
l'API HTTPS d'Oracle passe — verifie). Aucune dependance a une cle SSH.

  python3 agent_takeover.py --check          # inventaire seul (rien n'est modifie)
  python3 agent_takeover.py                  # trouve la VM -> demarre si besoin ->
                                             # active le plugin Run Command si besoin ->
                                             # execute up.sh SUR la VM -> imprime URL+token
  python3 agent_takeover.py --cmd 'uptime'   # commande arbitraire sur la VM (debug)

Sortie sensible (token/URL) : imprimee uniquement, jamais ecrite dans le depot.
Les identifiants durables (OCIDs, IP) sont ecrits dans infra/fleet/fleet.local.yaml
(gitignore) pour ne plus jamais revivre la panne "aucun identifiant note".
"""
from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

import oci
from oci.compute_instance_agent import ComputeInstanceAgentClient, PluginClient
from oci.compute_instance_agent import models as am
from oci.core import ComputeClient, VirtualNetworkClient
from oci.core import models as cm
from oci.identity import IdentityClient

REPO = Path(__file__).resolve().parents[3] if (Path(__file__).resolve().parents[3] / "project.godot").exists() \
    else Path(__file__).resolve().parents[2]
RAW_UP = "https://raw.githubusercontent.com/merlingame-netizen/M.E.R.L.I.N/main/infra/oracle/studio/up.sh"
PLUGIN = "Compute Instance Run Command"


def say(msg: str) -> None:
    print(msg, flush=True)


def find_instance(identity: IdentityClient, compute: ComputeClient, tenancy: str):
    """Premiere instance non terminee : racine d'abord, puis sous-compartiments."""
    comps = [tenancy]
    try:
        comps += [c.id for c in oci.pagination.list_call_get_all_results(
            identity.list_compartments, tenancy,
            compartment_id_in_subtree=True, access_level="ACCESSIBLE").data
            if c.lifecycle_state == "ACTIVE"]
    except Exception as e:
        say(f"  (sous-compartiments illisibles : {e.__class__.__name__})")
    for comp in comps:
        try:
            for inst in compute.list_instances(comp).data:
                if inst.lifecycle_state != "TERMINATED":
                    return comp, inst
        except Exception:
            continue
    return None, None


def public_ip(compute: ComputeClient, vnet: VirtualNetworkClient, comp: str, inst) -> str:
    for att in compute.list_vnic_attachments(comp, instance_id=inst.id).data:
        try:
            ip = vnet.get_vnic(att.vnic_id).data.public_ip
            if ip:
                return ip
        except Exception:
            continue
    return ""


def ensure_running(compute: ComputeClient, inst) -> object:
    if inst.lifecycle_state == "RUNNING":
        return inst
    say(f"  Etat {inst.lifecycle_state} -> demarrage...")
    compute.instance_action(inst.id, "START")
    for _ in range(60):  # ~5 min
        time.sleep(5)
        inst = compute.get_instance(inst.id).data
        if inst.lifecycle_state == "RUNNING":
            say("  RUNNING")
            return inst
    raise SystemExit("[ECHEC] la VM ne demarre pas (5 min)")


def ensure_plugin(plugins: PluginClient, compute: ComputeClient, comp: str, inst) -> None:
    try:
        st = plugins.get_instance_agent_plugin(inst.id, comp, PLUGIN).data.status
        say(f"  Plugin Run Command : {st}")
        if st == "RUNNING":
            return
    except Exception:
        say("  Plugin Run Command : etat inconnu")
    # tentative d'activation via update_instance (prend quelques minutes cote agent)
    say("  Activation du plugin via l'API...")
    try:
        compute.update_instance(inst.id, cm.UpdateInstanceDetails(
            agent_config=cm.UpdateInstanceAgentConfigDetails(plugins_config=[
                cm.InstanceAgentPluginConfigDetails(name=PLUGIN, desired_state="ENABLED")])))
    except Exception as e:
        say(f"  (update_instance refuse : {e.__class__.__name__} — activer dans la console : "
            "Instance > Oracle Cloud Agent)")
        return
    for _ in range(36):  # ~6 min
        time.sleep(10)
        try:
            if plugins.get_instance_agent_plugin(inst.id, comp, PLUGIN).data.status == "RUNNING":
                say("  Plugin actif")
                return
        except Exception:
            pass
    say("  [!] plugin toujours pas RUNNING — la commande risque de rester en attente")


def run_command(agent: ComputeInstanceAgentClient, comp: str, instance_id: str,
                script: str, timeout_s: int, label: str) -> tuple[str, str, int]:
    det = am.CreateInstanceAgentCommandDetails(
        compartment_id=comp,
        execution_time_out_in_seconds=timeout_s,
        display_name=label,
        target=am.InstanceAgentCommandTarget(instance_id=instance_id),
        content=am.InstanceAgentCommandContent(
            source=am.InstanceAgentCommandSourceViaTextDetails(source_type="TEXT", text=script),
            output=am.InstanceAgentCommandOutputViaTextDetails(output_type="TEXT")))
    cmd = agent.create_instance_agent_command(det).data
    say(f"  Commande envoyee ({cmd.id.split('.')[-1][:12]}...), attente (max {timeout_s}s)...")
    deadline = time.time() + timeout_s + 120
    last = ""
    while time.time() < deadline:
        time.sleep(10)
        ex = agent.get_instance_agent_command_execution(cmd.id, instance_id).data
        if ex.lifecycle_state != last:
            say(f"    {ex.delivery_state} / {ex.lifecycle_state}")
            last = ex.lifecycle_state
        if ex.lifecycle_state in ("SUCCEEDED", "FAILED", "TIMED_OUT", "CANCELED"):
            out = getattr(ex.content, "text", "") or ""
            code = getattr(ex.content, "exit_code", None)
            return ex.lifecycle_state, out, (code if code is not None else -1)
    return "TIMED_OUT", "", -1


def save_local_inventory(tenancy: str, comp: str, inst, ip: str) -> None:
    f = REPO / "infra" / "fleet" / "fleet.local.yaml"
    try:
        text = f.read_text() if f.exists() else "targets: []\n"
        block = ("\n# --- Oracle A1 (ecrit par agent_takeover.py, fichier gitignore) ---\n"
                 f"# tenancy_ocid:  {tenancy}\n"
                 f"# compartment:   {comp}\n"
                 f"# instance_ocid: {inst.id}\n"
                 f"# instance_name: {inst.display_name} ({inst.shape})\n"
                 f"# public_ip:     {ip}\n")
        if inst.id not in text:
            f.write_text(text + block)
            say(f"  Identifiants notes dans {f} (gitignore)")
    except Exception as e:
        say(f"  (inventaire local non ecrit : {e})")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="inventaire seul, aucune action")
    ap.add_argument("--cmd", default="", help="commande shell arbitraire au lieu de up.sh")
    ap.add_argument("--profile", default="DEFAULT")
    ap.add_argument("--timeout", type=int, default=1800)
    a = ap.parse_args()

    cfg = oci.config.from_file(profile_name=a.profile)
    tenancy = cfg["tenancy"]
    say(f"Tenancy : {tenancy[:40]}...  region {cfg.get('region')}")
    identity = IdentityClient(cfg)
    compute = ComputeClient(cfg)
    vnet = VirtualNetworkClient(cfg)

    comp, inst = find_instance(identity, compute, tenancy)
    if inst is None:
        say("[ECHEC] aucune instance trouvee sur la tenancy")
        return 1
    ip = public_ip(compute, vnet, comp, inst)
    say(f"Instance : {inst.display_name}  [{inst.lifecycle_state}]  {inst.shape}")
    say(f"  OCID : {inst.id}")
    say(f"  IP   : {ip or '(aucune IP publique)'}")
    save_local_inventory(tenancy, comp, inst, ip)

    if a.check:
        say("\nMode --check : rien n'a ete modifie.")
        return 0

    inst = ensure_running(compute, inst)
    plugins = PluginClient(cfg)
    ensure_plugin(plugins, compute, comp, inst)
    agent = ComputeInstanceAgentClient(cfg)

    if a.cmd:
        payload = f"#!/bin/bash\n{a.cmd}\n"
        label = "merlin-debug"
    else:
        # Execute up.sh en tant qu'ubuntu (repo + services chez ubuntu) ; ocarun a sudo.
        payload = (
            "#!/bin/bash\n"
            "set -o pipefail\n"
            f"sudo -n -u ubuntu -H bash -c 'curl -fsSL {RAW_UP} | bash' "
            "> /tmp/merlin-up.log 2>&1\n"
            "rc=$?\n"
            "echo \"== exit $rc ==\"\n"
            "grep -E 'URL   :|Token :|User  :|PRET|ECHEC' /tmp/merlin-up.log\n"
            "echo '--- tail ---'\n"
            "tail -c 1200 /tmp/merlin-up.log\n")
        label = "merlin-studio-up"

    state, out, code = run_command(agent, comp, inst.id, payload, a.timeout, label)
    say(f"\n=== Run Command : {state} (exit {code}) ===")
    say(out.strip() or "(aucune sortie texte)")
    return 0 if state == "SUCCEEDED" else 1


if __name__ == "__main__":
    sys.exit(main())
