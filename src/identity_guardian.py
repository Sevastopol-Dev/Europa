#!/usr/bin/env python3
"""
Project Europa: Identity & State Guardian
Author: Sevastopol
Description: Enforces ephemeral least-privilege IAM policies, detects shadow resources,
             and generates dynamic identity contracts to prevent privilege drift.
"""

import hashlib
import json
import os
import sys
import time

import botocore.exceptions


class IdentityGuardian:
    def __init__(self, epoch_id: int, master_salt: str):
        self.epoch_id = epoch_id
        self.master_salt = master_salt

    def generate_ephemeral_role_policy(self, service_name: str) -> dict:
        """Generates a strictly scoped, time-bound least-privilege IAM policy."""
        policy_fingerprint = hashlib.sha256(
            f"{self.master_salt}:{service_name}:{self.epoch_id}".encode()
        ).hexdigest()[:12]

        return {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Sid": f"EuropaJITAccess-{policy_fingerprint}",
                    "Effect": "Allow",
                    "Action": ["s3:GetObject", "s3:PutObject"],
                    "Resource": [f"arn:aws:s3:::europa-secure-vault-{self.epoch_id}/*"],
                    "Condition": {
                        "NumericLessThan": {
                            "aws:EpochTime": int(
                                os.getenv("EPOCH_EXPIRATION", "1800000000")
                            )
                        }
                    },
                }
            ],
        }

    def audit_shadow_resources(
        self, active_resources: list, registered_inventory: list
    ) -> list:
        """Identifies orphaned or shadow resources lacking proper governance tags."""
        orphans = []
        registered_set = set(registered_inventory)

        for resource in active_resources:
            if resource not in registered_set:
                orphans.append(
                    {
                        "resource_id": resource,
                        "status": "SHADOW_ORPHANED_DETECTED",
                        "action": "SCHEDULED_FOR_PURGE",
                    }
                )
        return orphans

    def export_identity_contract(
        self, output_path: str = "infra/local_test/europa_contract.auto.tfvars.json"
    ) -> None:
        """Exports unified ephemeral IAM and topology guardrails to a single Terraform variables file."""

        # Load topology file if it exists to merge them cleanly
        topo_path = "infra/local_test/europa_contract.auto.tfvars.json"
        contract = {}
        if os.path.exists(topo_path):
            with open(topo_path, "r", encoding="utf-8") as f:
                contract = json.load(f)

        # Update with identity contract properties
        contract.update(
            {
                "epoch_id": self.epoch_id,
                "enforce_strict_scp": True,
                "ephemeral_pipeline_policy": self.generate_ephemeral_role_policy(
                    "ci_pipeline"
                ),
                "quarantine_honeybucket": f"europa-canary-trap-{self.epoch_id}",
            }
        )

        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(contract, f, indent=4)

        print(
            f"[Identity Guardian] Epoch {self.epoch_id} unified guardrails compiled -> {output_path}"
        )


if __name__ == "__main__":
    try:
        # Align epoch calculation with europa_brain.py (27-minute sliding epoch window)
        current_timestamp = time.time()
        dynamic_epoch_id = int(current_timestamp // (27 * 60))

        guardian = IdentityGuardian(
            epoch_id=dynamic_epoch_id, master_salt="Europa_Master_Salt_Key_9921"
        )
        guardian.export_identity_contract()
    except botocore.exceptions.ClientError as err:
        print(f"[ERROR] Identity guardian execution failed: {err}", file=sys.stderr)
        sys.exit(1)
