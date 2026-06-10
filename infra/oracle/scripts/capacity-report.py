#!/usr/bin/env python3
"""Query OCI's Compute Capacity Report API for Always-Free shapes.

Much smarter than blind launch retries: asks Oracle directly, per shape and
fault domain, whether capacity is AVAILABLE or OUT_OF_HOST_CAPACITY.

Auth is read from terraform/terraform.tfvars (same credentials Terraform uses).
Requires the OCI Python SDK:  pip install oci  (or in a venv).

Usage:
  python3 capacity-report.py            # full table, exit 0 if anything available
  python3 capacity-report.py --best     # print best available option as
                                        # "shape|ocpus|mem" (or "NONE"), for scripting
Priority for --best: A1 4/24 > A1 2/12 > A1 1/6 > E2.1.Micro.
"""
import re
import sys
from pathlib import Path

import oci

TFVARS = Path(__file__).resolve().parent.parent / "terraform" / "terraform.tfvars"

# (shape, ocpus, mem) — order = preference for --best
SHAPES = [
    ("VM.Standard.A1.Flex", 4.0, 24.0),
    ("VM.Standard.A1.Flex", 2.0, 12.0),
    ("VM.Standard.A1.Flex", 1.0, 6.0),
    ("VM.Standard.E2.1.Micro", None, None),
]


def load_config():
    text = TFVARS.read_text()

    def grab(key):
        m = re.search(rf'^{key}\s*=\s*"([^"]+)"', text, re.M)
        if not m:
            sys.exit(f"missing '{key}' in {TFVARS}")
        return m.group(1)

    return {
        "user": grab("user_ocid"),
        "key_file": grab("private_key_path"),
        "fingerprint": grab("fingerprint"),
        "tenancy": grab("tenancy_ocid"),
        "region": grab("region"),
    }


def check(compute, tenancy, ad, shape, ocpus, mem, fd=None):
    sa = oci.core.models.CreateCapacityReportShapeAvailabilityDetails(
        instance_shape=shape, fault_domain=fd
    )
    if ocpus is not None:
        sa.instance_shape_config = oci.core.models.CapacityReportInstanceShapeConfig(
            ocpus=ocpus, memory_in_gbs=mem
        )
    try:
        report = compute.create_compute_capacity_report(
            oci.core.models.CreateComputeCapacityReportDetails(
                compartment_id=tenancy,
                availability_domain=ad,
                shape_availabilities=[sa],
            )
        ).data
        return report.shape_availabilities[0].availability_status
    except oci.exceptions.ServiceError as e:
        return f"ERROR {e.status}: {e.code}"


def main():
    best_mode = "--best" in sys.argv
    cfg = load_config()
    oci.config.validate_config(cfg)
    identity = oci.identity.IdentityClient(cfg)
    compute = oci.core.ComputeClient(cfg)
    tenancy = cfg["tenancy"]

    ads = [ad.name for ad in identity.list_availability_domains(tenancy).data]

    if best_mode:
        for ad in ads:
            for shape, ocpus, mem in SHAPES:
                if check(compute, tenancy, ad, shape, ocpus, mem) == "AVAILABLE":
                    o = "" if ocpus is None else f"{ocpus:g}"
                    m = "" if mem is None else f"{mem:g}"
                    print(f"{shape}|{o}|{m}")
                    return 0
        print("NONE")
        return 1

    any_avail = False
    print(f"Availability domains in {cfg['region']}: {ads}\n")
    for ad in ads:
        fds = [fd.name for fd in identity.list_fault_domains(tenancy, ad).data]
        for shape, ocpus, mem in SHAPES:
            label = shape if ocpus is None else f"{shape} ({ocpus:g} OCPU/{mem:g}GB)"
            for fd in fds + [None]:
                status = check(compute, tenancy, ad, shape, ocpus, mem, fd)
                if status == "AVAILABLE":
                    any_avail = True
                mark = "OK " if status == "AVAILABLE" else "-- "
                print(f"{mark}{ad} | {fd or 'ANY-FD':<16} | {label:<40} | {status}")
        print()
    return 0 if any_avail else 1


if __name__ == "__main__":
    sys.exit(main())
