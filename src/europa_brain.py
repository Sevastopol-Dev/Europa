import hashlib
import ipaddress
import json
import os
import random
import time


def generate_europa_topology(parent_cidr, master_salt, epoch, roles):
    # 1. Calculate Parity Shift (Even = Blue / Odd = Green) to support Zero-Downtime Blue/Green
    is_even_epoch = int(epoch) % 2 == 0
    active_color = "BLUE" if is_even_epoch else "GREEN"

    # 2. Derive Cryptographic Epoch Seed & Honeytoken Salt
    raw_data = f"{master_salt}:{epoch}".encode()
    seed_int = int.from_bytes(hashlib.sha256(raw_data).digest()[:8], "big")
    honeytoken_hash = hashlib.sha256(
        f"{master_salt}:honeytoken:{epoch}".encode()
    ).hexdigest()[:16]

    # 3. Slice parent CIDR into /24 subnet blocks
    subnets = list(ipaddress.ip_network(parent_cidr).subnets(new_prefix=24))

    # 4. Deterministic shuffle using cryptographic PRNG seed
    rng = random.Random(seed_int)
    shuffled_subnets = subnets.copy()
    rng.shuffle(shuffled_subnets)

    # 5. Map architectural roles to shuffled blocks
    allocations = {role: str(shuffled_subnets[i]) for i, role in enumerate(roles)}

    # 5.5 GUARD CLAUSE: (Anti-Collision)
    allocated_cidrs = list(allocations.values())
    unique_cidrs = set(allocated_cidrs)

    if len(allocated_cidrs) != len(unique_cidrs):
        raise AssertionError(
            f"CRITICAL MTD FAILURE: Subnet collision detected"
            f"Allocated CIDRs contain duplicates: {allocations}"
        )

    # 6. Export state contract directly for Terraform local_test folder
    output_path = "infra/local_test/europa_topology.auto.tfvars.json"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    tf_payload = {
        "epoch_id": int(epoch),
        "active_color": active_color,
        "active_honeytoken_trap": f"eur_trap_{honeytoken_hash}",
        "europa_active_topology": allocations,
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(tf_payload, f, indent=4)

    return tf_payload


# --- Execution ---

if __name__ == "__main__":
    current_timestamp = time.time()
    epoch_time_id = int(current_timestamp // (27 * 60))

    contract = generate_europa_topology(
        parent_cidr="10.199.0.0/16",
        master_salt="Europa_Master_Salt_Key_9921",
        epoch=str(epoch_time_id),
        roles=[
            "perimeter_ingress_alpha",
            "perimeter_ingress_beta",
            "deception_honeytoken_tier",
            "internal_routing_gateway",
        ],
    )

    print(
        f"[+] Europa Dual-VPC Topology Generated (Epoch {contract['epoch_id']} | Plane: {contract['active_color']}):"
    )
    print(f"    - Active Honeytoken Trap     -> {contract['active_honeytoken_trap']}")
    for role, cidr in contract["europa_active_topology"].items():
        print(f"    - {role:<30} -> {cidr}")
