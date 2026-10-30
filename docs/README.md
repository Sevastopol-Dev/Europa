# Project Europa: Comprehensive Architectural & Threat Modeling Guide

---

## 1. Project Europa Architecture (README)

### Executive Summary
**Project Europa** is an automated, cryptographically driven **Moving Target Defense (MTD)** and **Deception-as-Code (DaC)** cloud infrastructure framework. It addresses a fundamental flaw in modern static enterprise architectures: the permanence of target surfaces. By programmatically mutating IP subnet allocations, rotating active Blue/Green VPC planes via monotonic epochs, executing dynamic route state transitions via `europa_rotator.py`, and deploying real-time identity guardrails, Project Europa forces attackers into an asymmetric disadvantage, invalidating reconnaissance and intercepting lateral movement.

### Core Architectural Pillars
*   **Moving Target Defense (MTD) Engine**: Periodically shifts internal network topologies, subnet CIDRs, and routing paths via cryptographic epoch mutations and active plane shifting orchestrators (`europa_rotator.py`).
*   **Policy-as-Code (PaC) Gatekeeper**: Intercepts all Terraform execution plans using Open Policy Agent (OPA/Rego) to enforce strict temporal, topological, and immutable OOB network boundaries before deployment.
*   **Tier 0 Hybrid Identity Isolation**: Integrates local Active Directory (AD FS, Entra Connect) with cloud-native Microsoft Entra ID and Just-In-Time (JIT) Privileged Identity Management (PIM).
*   **Deception Engineering Platform**: Deploys isolated canary S3 buckets, honeytoken trap subnets, and KMS-encrypted tripwires that have zero legitimate user ingress, ensuring any interaction is an immediate high-fidelity Indicator of Compromise (IOC).

### Repository Structure
```text
project-europa/
├── .github/
│   └── workflows/
│       └── ci_cd.yml                 # Automated DevSecOps pipeline (Lint, Checkov, OPA, Terraform)
├── infra/
│   ├── local_test/                   # Ephemeral validation environment
│   └── modules/
│       ├── identity/                 # Tier 0 IAM, canary buckets, and JIT roles
│       └── network/                  # Transit Gateway, dual VPCs, and dynamic subnetting
├── policies/
│   └── europa_identity_guard.rego    # OPA guardrails (Temporal drift, OOB locks, epoch validation)
└── src/
    ├── europa_brain.py               # Epoch state generation and contract compiler
    ├── europa_rotator.py             # Active MTD plane rotation & Transit Gateway route state orchestrator
    └── identity_guardian.py          # Identity mapping and policy attachment controller
```

### Component Breakdown: MTD Orchestration Scripts
1. **`src/europa_brain.py`**: Computes the cryptographic epoch hash, derives dynamic `/24` subnet CIDR ranges for network tiers, and writes the authoritative `europa_contract.auto.tfvars.json` pre-flight state contract.
2. **`src/europa_rotator.py`**: Handles active/standby plane switching logic. Executes the live traffic handoff at the Transit Gateway level during epoch mutations, updating target VPC attachments and draining legacy Blue/Green routing paths without dropping connections.
3. **`src/identity_guardian.py`**: Evaluates temporal bounds for JIT execution policies, generates short-lived IAM attachment policies, and injects canary honeytoken credentials into active deception traps.

---

## 2. Threat Model (STRIDE Methodology)

The threat model for Project Europa evaluates risks across hybrid identity integration, ephemeral infrastructure generation, and automated deployment pipelines.

| Threat Category | Threat Vector / Attack Scenario | Impact | Project Europa Mitigation Strategy |
| :--- | :--- | :--- | :--- |
| **Spoofing** | **Token Forgery & Session Hijacking**: Adversaries steal SAML tokens or manipulate AD FS token-signing certificates to impersonate administrative identities across hybrid boundaries. | High | Enforced **Phishing-Resistant MFA (FIDO2)** and **Hybrid JIT PIM**, invalidating long-lived static credentials and detecting anomalous federation trust modifications. |
| **Tampering** | **Pipeline Contract Poisoning**: Attackers modify pre-flight `auto.tfvars` state contracts in a pull request to inject unauthorized CIDR blocks or widen IAM permissions. | Critical | **OPA Policy-as-Code Gate**: Evaluates all planned infrastructure states against immutable Rego rules (`europa_identity_guard.rego`), blocking any non-compliant deployment instantly. |
| **Repudiation** | **Unlogged Administrative Elevation**: An operator or compromised service account elevates privileges without audit trails. | Medium | **Tier 0 Isolation & CloudWatch Telemetry**: All administrative actions are routed through immutable OOB management subnets and tracked via centralized logging. |
| **Information Disclosure** | **Network & Resource Enumeration**: External or low-privileged actors map internal microservices and database topologies during reconnaissance phases. | High | **Moving Target Defense (MTD)**: Dynamic cryptographic shuffling of subnet assignments via `europa_brain.py` and plane rotations via `europa_rotator.py` constantly invalidate attacker reconnaissance. |
| **Denial of Service** | **Resource Starvation / Infrastructure Flooding**: Attackers saturate active ingress endpoints or exhaust transit gateway connections. | Medium | **Dual-VPC Blue/Green Plane Isolation**: Traffic can be dynamically shifted via `europa_rotator.py` to fresh standby routing planes while isolating degraded segments. |
| **Elevation of Privilege** | **On-Premises to Cloud Takeover (Hybrid Escalation)**: Compromise of local Active Directory leads to synchronized escalation into Microsoft Entra ID Global Admin roles. | Critical | **Strict Tier 0 Boundaries**: Separation of synchronization agents, hard isolation of AD FS/Entra Connect servers, and automated drift detection on synchronized object attributes. |

---

## 3. Architectural Tradeoffs

Every defensive design choice involves engineering compromises. Project Europa explicitly balances security assurance against operational complexity and performance overhead.

### Tradeoff 1: Moving Target Defense vs. Operational Complexity
*   **The Benefit**: Drastically increases the attacker's cost by breaking hardcoded IP dependencies, scanning scripts, and static exploit payloads.
*   **The Cost**: Debugging network connectivity, inspecting distributed traces, and handling ephemeral infrastructure states becomes more complex for engineering teams accustomed to static environments.
*   **Mitigation**: Fully automate epoch generation and plane rotation orchestrations via `europa_brain.py` and `europa_rotator.py` within the CI/CD pipeline, abstracting manual network reconfiguration away from operators.

### Tradeoff 2: Strict OPA Policy Gates vs. Deployment Velocity
*   **The Benefit**: Absolute elimination of drift, unauthorized privilege expansions, and historical timestamp violations before code ever hits an API.
*   **The Cost**: Introduces strict validation friction. If a developer needs an urgent hotfix that violates an existing Rego guardrail, the pipeline hard-stops until the policy or contract is adjusted.
*   **Mitigation**: Treat Rego policies as code with their own tested pull request workflows, ensuring guardrails evolve safely alongside engineering requirements.

### Tradeoff 3: Hybrid Tier 0 Isolation vs. Integration Overhead
*   **The Benefit**: Prevents lateral movement from corporate workstations (Tier 2) or standard servers (Tier 1) into domain controllers and cloud identity management planes (Tier 0).
*   **The Cost**: Requires rigorous administrative partitioning, dedicated jump hosts, and strict management of trust relationships, which can slow down daily IT administration.
*   **Mitigation**: Enforce Just-In-Time (JIT) access through Privileged Identity Management (PIM) managed by `identity_guardian.py` so administrators only possess elevated capabilities when explicitly needed and audited.