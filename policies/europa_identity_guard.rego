package europa.security

default allow = false

allow if {
    count(deny) == 0
}

# Rule 1: Deny if missing a valid 'epoch_id' in plan variables
deny contains msg if {
    not input.variables.epoch_id.value
    msg := "CRITICAL: Identity contract is missing a valid 'epoch_id'."
}

# Rule 2: Deny if the ephemeral IAM policy condition contains a past or expired Unix timestamp
deny contains msg if {
    policy_doc := input.variables.ephemeral_pipeline_policy.value
    epoch_time := policy_doc.Statement[_].Condition.NumericLessThan["aws:EpochTime"]
    
    expired_threshold := 1700000000 # Baseline modern floor (approx. Jan 2024)
    epoch_time < expired_threshold
    
    msg := sprintf("CRITICAL: Ephemeral JIT policy contains an expired historical timestamp (EpochTime: %v). Temporal drift intercepted!", [epoch_time])
}

# Rule 3: Ensure strict SCP enforcement is toggled on
deny contains msg if {
    scp_val := object.get(input.variables, "enforce_strict_scp", {"value": true}).value
    scp_val != true
    msg := "COMPLIANCE: Strict Service Control Policies (SCPs) must be enabled for all active epochs."
}

# Rule 4: Enforce that the OOB Management Subnet (10.199.255.0/28) is always present in the execution plan
deny contains msg if {
    subnets := [rc |
        rc := input.resource_changes[_]
        rc.type == "aws_subnet"
        rc.mode == "managed"
    ]
    
    oob_match := [rc |
        rc := subnets[_]
        rc.change.after.cidr_block == "10.199.255.0/28"
    ]
    
    count(oob_match) == 0
    msg := "SECURITY VIOLATION: OOB Management Subnet must remain immutable at '10.199.255.0/28'. Lockout prevention rule triggered."
}

# Rule 5: Enforce that a valid non-negative epoch_id is supplied
deny contains msg if {
    epoch := input.variables.epoch_id.value
    epoch < 0
    msg := "CRITICAL: Identity contract has an invalid negative 'epoch_id'."
}