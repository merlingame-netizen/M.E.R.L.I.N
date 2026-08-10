#!/usr/bin/env python3
"""Creation de la VM A1 par l'agent, via l'API OCI (sans console, sans Cloud Shell).

Reutilise le reseau existant (VCN/subnet du terraform), lance VM.Standard.A1.Flex
4 OCPU / 24 GB (allocation Always Free — 0 EUR meme en PAYG), Ubuntu 22.04 aarch64,
avec le cloud-init du depot (gzip) et le plugin Run Command ACTIVE des la creation
(c'est notre canal de pilotage : le port 22 sortant est bloque cote agent).

  python3 agent_launch.py --user-data /tmp/cloudinit.yaml \
      --ssh-pub /root/.ssh/merlin_oracle.pub [--ocpus 4 --mem 24] [--dry-run]

En cas de OutOfHostCapacity sur 4/24, retente puis retombe sur 2/12 (signale).
"""
from __future__ import annotations

import argparse
import base64
import gzip
import sys
import time
from pathlib import Path

import oci
from oci.core import ComputeClient, VirtualNetworkClient
from oci.core import models as cm

NAME = "merlin-arm-a1"
SHAPE = "VM.Standard.A1.Flex"


def say(m: str) -> None:
    print(m, flush=True)


def newest_ubuntu_arm(compute: ComputeClient, ten: str) -> cm.Image:
    imgs = oci.pagination.list_call_get_all_results(
        compute.list_images, ten,
        operating_system="Canonical Ubuntu", operating_system_version="22.04",
        shape=SHAPE, sort_by="TIMECREATED", sort_order="DESC").data
    if not imgs:
        raise SystemExit("[ECHEC] aucune image Ubuntu 22.04 aarch64 pour A1")
    return imgs[0]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--user-data", required=True)
    ap.add_argument("--ssh-pub", required=True)
    ap.add_argument("--ocpus", type=float, default=4)
    ap.add_argument("--mem", type=float, default=24)
    ap.add_argument("--boot-gb", type=int, default=100)
    ap.add_argument("--attempts", type=int, default=3)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    cfg = oci.config.from_file()
    ten = cfg["tenancy"]
    compute = ComputeClient(cfg)
    vnet = VirtualNetworkClient(cfg)
    idc = oci.identity.IdentityClient(cfg)

    ad = idc.list_availability_domains(ten).data[0].name
    subnets = [s for s in vnet.list_subnets(ten).data if s.lifecycle_state == "AVAILABLE"]
    if not subnets:
        raise SystemExit("[ECHEC] aucun subnet — le reseau terraform a disparu ?")
    subnet = subnets[0]
    img = newest_ubuntu_arm(compute, ten)
    raw = Path(a.user_data).read_bytes()
    user_data = base64.b64encode(gzip.compress(raw)).decode()
    ssh_pub = Path(a.ssh_pub).read_text().strip()

    say(f"AD      : {ad}")
    say(f"Subnet  : {subnet.display_name} ({subnet.cidr_block})")
    say(f"Image   : {img.display_name}")
    say(f"Shape   : {SHAPE} {a.ocpus:g} OCPU / {a.mem:g} GB, boot {a.boot_gb} GB")
    say(f"user_data: {len(raw)} o -> {len(user_data)} o (gzip+b64)")
    if a.dry_run:
        say("--dry-run : rien n'a ete cree.")
        return 0

    def details(ocpus: float, mem: float) -> cm.LaunchInstanceDetails:
        return cm.LaunchInstanceDetails(
            availability_domain=ad,
            compartment_id=ten,
            display_name=NAME,
            shape=SHAPE,
            shape_config=cm.LaunchInstanceShapeConfigDetails(ocpus=ocpus, memory_in_gbs=mem),
            source_details=cm.InstanceSourceViaImageDetails(
                image_id=img.id, boot_volume_size_in_gbs=a.boot_gb),
            create_vnic_details=cm.CreateVnicDetails(
                subnet_id=subnet.id, assign_public_ip=True,
                hostname_label=NAME.replace("-", "")[:16]),
            metadata={"ssh_authorized_keys": ssh_pub, "user_data": user_data},
            agent_config=cm.LaunchInstanceAgentConfigDetails(
                is_monitoring_disabled=False, is_management_disabled=False,
                plugins_config=[cm.InstanceAgentPluginConfigDetails(
                    name="Compute Instance Run Command", desired_state="ENABLED")]))

    plans = [(a.ocpus, a.mem)] * a.attempts + [(2.0, 12.0)] * 2
    inst = None
    for i, (oc, mem) in enumerate(plans, 1):
        say(f"==> Lancement {oc:g}/{mem:g} (essai {i}/{len(plans)})...")
        try:
            inst = compute.launch_instance(details(oc, mem)).data
            say(f"    accepte : {inst.id}")
            break
        except oci.exceptions.ServiceError as e:
            say(f"    refus {e.status} {e.code}: {str(e.message)[:120]}")
            if e.code in ("LimitExceeded", "QuotaExceeded"):
                say("    -> limite de service : a lever dans la console (Governance > Limits)")
                return 1
            time.sleep(20)
    if inst is None:
        say("[ECHEC] pas de capacite A1 (meme en 2/12).")
        return 1

    say("==> Attente RUNNING (jusqu'a 10 min)...")
    for _ in range(60):
        time.sleep(10)
        cur = compute.get_instance(inst.id).data
        if cur.lifecycle_state == "RUNNING":
            say("    RUNNING")
            break
        if cur.lifecycle_state in ("TERMINATED", "TERMINATING"):
            say(f"[ECHEC] instance {cur.lifecycle_state}")
            return 1
    ip = ""
    for att in compute.list_vnic_attachments(ten, instance_id=inst.id).data:
        v = vnet.get_vnic(att.vnic_id).data
        if v.public_ip:
            ip = v.public_ip
            break
    say("")
    say("=== VM CREEE ===")
    say(f"  OCID : {inst.id}")
    say(f"  IP   : {ip}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
