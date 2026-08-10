#!/usr/bin/env python3
"""Chasse a la capacite A1 (Paris) : poll le rapport officiel, lance DES que disponible.

Le launch a l'aveugle se fait throttler (429) et echoue en OUT_OF_HOST_CAPACITY ;
le rapport de capacite est une API de LECTURE qu'on peut interroger sereinement.

  nohup python3 capacity_hunt.py > /tmp/a1-hunt.log 2>&1 &

Des qu'une taille passe AVAILABLE : agent_launch.py est execute (2/12 prioritaire,
1/6 en repli), l'OCID + IP sont logges, et la boucle s'arrete. Jitter anti-throttle,
resume clair a chaque tour.
"""
from __future__ import annotations

import random
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import oci
from oci.core import models as cm

HERE = Path(__file__).resolve().parent
COMBOS = [(2, 12), (1, 6)]           # (ocpus, mem) par ordre de preference
PERIOD = 300                          # 5 min de base
MAX_HOURS = 48


def say(m: str) -> None:
    print(f"[{datetime.now():%H:%M:%S}] {m}", flush=True)


def main() -> int:
    cfg = oci.config.from_file()
    ten = cfg["tenancy"]
    compute = oci.core.ComputeClient(cfg)
    ad = oci.identity.IdentityClient(cfg).list_availability_domains(ten).data[0].name
    say(f"Chasse demarree — {ad}, combos {COMBOS}, periode ~{PERIOD}s, max {MAX_HOURS}h")
    deadline = time.time() + MAX_HOURS * 3600
    tour = 0
    while time.time() < deadline:
        tour += 1
        try:
            rep = compute.create_compute_capacity_report(
                cm.CreateComputeCapacityReportDetails(
                    compartment_id=ten, availability_domain=ad,
                    shape_availabilities=[
                        cm.CreateCapacityReportShapeAvailabilityDetails(
                            instance_shape="VM.Standard.A1.Flex",
                            instance_shape_config=cm.CapacityReportInstanceShapeConfig(
                                ocpus=o, memory_in_gbs=m))
                        for o, m in COMBOS])).data
            status = {(s.instance_shape_config.ocpus, s.instance_shape_config.memory_in_gbs):
                      s.availability_status for s in rep.shape_availabilities}
            line = "  ".join(f"{int(o)}/{int(m)}:{st}" for (o, m), st in status.items())
            say(f"tour {tour}: {line}")
            for (o, m) in COMBOS:
                if status.get((float(o), float(m))) == "AVAILABLE":
                    say(f">>> CAPACITE DISPONIBLE {o}/{m} — lancement !")
                    r = subprocess.run(
                        [sys.executable, str(HERE / "agent_launch.py"),
                         "--user-data", "/tmp/cloudinit.yaml",
                         "--ssh-pub", "/root/.ssh/merlin_oracle.pub",
                         "--ocpus", str(o), "--mem", str(m), "--attempts", "2"],
                        capture_output=True, text=True, timeout=1200)
                    say(r.stdout[-1500:])
                    if r.returncode == 0:
                        say(">>> VM CREEE — chasse terminee. Prochaine etape : agent_takeover.py")
                        return 0
                    say(f">>> lancement rate (rc={r.returncode}) — on continue la chasse")
        except Exception as e:
            say(f"tour {tour}: erreur {type(e).__name__}: {str(e)[:120]}")
        time.sleep(PERIOD + random.randint(0, 60))
    say("Deadline atteinte sans capacite.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
