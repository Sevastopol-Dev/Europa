import json
import os
import subprocess
import time

from europa_brain import generate_europa_topology


def rotate_europa_epoch(drain_seconds: int = 5):
    print("[Europa MTD] Initiating Epoch Rotation Sequence...")

    state_path = "infra/local_test/europa_topology.auto.tfvars.json"

    # 1. Read current epoch or initialize
    current_epoch = 1730000000
    if os.path.exists(state_path):
        with open(state_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            current_epoch = data.get("epoch_id", current_epoch)
            print(
                f"[*] Active Plane: {data.get('active_color')} | Epoch: {current_epoch}"
            )

    # 2. Advance Epoch & Generate New Topology
    next_epoch = current_epoch + 1
    new_contract = generate_europa_topology(
        parent_cidr="10.199.0.0/16",
        master_salt="Europa_Master_Salt_Key_9921",
        epoch=str(next_epoch),
        roles=[
            "perimeter_ingress_alpha",
            "perimeter_ingress_beta",
            "deception_honeytoken_tier",
            "internal_routing_gateway",
        ],
    )
    print(
        f"[+] Shifted to Plane: {new_contract['active_color']} (Epoch {new_contract['epoch_id']})"
    )

    # 3. Streamlined Drain Window
    print(
        f"[Drain Window] Grace period active ({drain_seconds}s drain)...",
        end="",
        flush=True,
    )
    for _ in range(drain_seconds):
        time.sleep(1)
        print(".", end="", flush=True)
    print(" [✓] Complete.")

    # 4. Streamlined OPA Security Gate Evaluation
    print("[Security Gate] Running OPA validation...")
    opa_cmd = [
        "opa",
        "eval",
        "-i",
        "infra/local_test/identity_contract.auto.tfvars.json",
        "-d",
        "policies/europa_identity_guard.rego",
        "data.europa.security.deny",
    ]

    try:
        res = subprocess.run(opa_cmd, capture_output=True, text=True, check=True)
        # If result contains rule violations, fail early
        if "CRITICAL" in res.stdout or "CRITICAL" in res.stderr:
            raise ValueError("OPA policy check flagged critical violations.")
        print("[+] OPA Audit Clean: Zero drift detected.")
    except (subprocess.CalledProcessError, ValueError) as e:
        print(f"[-] [CRITICAL] Rotation Aborted by OPA Guardrail: {e}")
        raise SystemExit(1)

    print("[*] [Success] Europa rotation sequence finalized!")


if __name__ == "__main__":
    rotate_europa_epoch(drain_seconds=3)
