#!/usr/bin/env python3
"""Free-tier guard for the Oracle deployment.

Fails (exit 1) if a Terraform plan would create/modify resources outside the
Oracle Cloud *Always Free* limits. Run it on a saved plan BEFORE `terraform apply`.

Always Free limits enforced here:
  - ARM A1 (VM.Standard.A1.Flex): total <= 4 OCPU and <= 24 GB RAM
  - AMD micro (VM.Standard.E2.1.Micro): <= 2 instances
  - Only those two compute shapes are allowed (anything else = billable)
  - Block storage (boot + block volumes): total <= 200 GB

Usage:
  terraform plan -out=tfplan
  python3 freetier-guard.py tfplan
"""
import json
import subprocess
import sys

LIMIT_A1_OCPU = 4
LIMIT_A1_MEM_GB = 24
LIMIT_BLOCK_GB = 200
LIMIT_MICRO = 2
FREE_SHAPES = {"VM.Standard.A1.Flex", "VM.Standard.E2.1.Micro"}


def _first(block):
    """Terraform JSON renders nested blocks as lists; normalize to a dict."""
    if isinstance(block, list):
        return block[0] if block else {}
    if isinstance(block, dict):
        return block
    return {}


def load_plan(path):
    out = subprocess.check_output(["terraform", "show", "-json", path], text=True)
    return json.loads(out)


def main():
    plan_file = sys.argv[1] if len(sys.argv) > 1 else "tfplan"
    plan = load_plan(plan_file)

    errors = []
    a1_ocpu = 0.0
    a1_mem = 0.0
    micro = 0
    storage = 0.0

    for rc in plan.get("resource_changes", []):
        actions = rc.get("change", {}).get("actions", [])
        if "create" not in actions and "update" not in actions:
            continue
        after = rc["change"].get("after") or {}
        t = rc.get("type")

        if t == "oci_core_instance":
            shape = after.get("shape")
            if shape not in FREE_SHAPES:
                errors.append(
                    f"instance '{rc['name']}' uses shape '{shape}' which is NOT Always-Free "
                    f"(allowed: {', '.join(sorted(FREE_SHAPES))})"
                )
            sc = _first(after.get("shape_config"))
            if shape == "VM.Standard.A1.Flex":
                a1_ocpu += float(sc.get("ocpus") or 0)
                a1_mem += float(sc.get("memory_in_gbs") or 0)
            elif shape == "VM.Standard.E2.1.Micro":
                micro += 1
            sd = _first(after.get("source_details"))
            storage += float(sd.get("boot_volume_size_in_gbs") or 0)

        elif t == "oci_core_volume":
            storage += float(after.get("size_in_gbs") or 0)

    if a1_ocpu > LIMIT_A1_OCPU:
        errors.append(f"A1 OCPUs {a1_ocpu:g} exceed free limit of {LIMIT_A1_OCPU}")
    if a1_mem > LIMIT_A1_MEM_GB:
        errors.append(f"A1 memory {a1_mem:g} GB exceeds free limit of {LIMIT_A1_MEM_GB} GB")
    if micro > LIMIT_MICRO:
        errors.append(f"{micro} micro instances exceed free limit of {LIMIT_MICRO}")
    if storage > LIMIT_BLOCK_GB:
        errors.append(f"block storage {storage:g} GB exceeds free limit of {LIMIT_BLOCK_GB} GB")

    print("Free-tier guard summary:")
    print(f"  A1 compute    : {a1_ocpu:g} OCPU / {a1_mem:g} GB   (limit {LIMIT_A1_OCPU} / {LIMIT_A1_MEM_GB})")
    print(f"  Micro instances: {micro}                  (limit {LIMIT_MICRO})")
    print(f"  Block storage : {storage:g} GB              (limit {LIMIT_BLOCK_GB})")

    if errors:
        print("\n❌ FREE-TIER GUARD FAILED — apply blocked:")
        for e in errors:
            print(f"   - {e}")
        sys.exit(1)

    print("\n✅ OK: plan stays within Oracle Always Free limits.")


if __name__ == "__main__":
    main()
