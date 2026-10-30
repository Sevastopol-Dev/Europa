.PHONY: health scan lint test rotate clean opa-test

opa-test:
	@echo "[*] Generating Terraform execution plan..."
	terraform -chdir=infra/local_test plan -out=tfplan.binary
	
	@echo "[*] Converting Terraform plan to JSON..."
	terraform -chdir=infra/local_test show -json tfplan.binary > tfplan.json
	
	@echo "[*] Evaluating OPA Rego guardrails against execution plan..."
	opa eval --data policies/europa_identity_guard.rego --input infra/local_test/tfplan.json "data.europa.security.allow"

health: ## Check Docker Endpoint Health
	@curl -s http://localhost:4566/_localstack/health | grep -E "(available|running)"

scan: ## Run Trivy vulnerability scan on IaC
	@docker run --rm -v $(PWD):/src aquasec/trivy:latest config /src --severity HIGH,CRITICAL

lint: ## Run Python linters and TFLint
	ruff check src/
	ruff format --check src/
	tflint --chdir=infra/local_test/
	tflint --chdir=infra/dev

test: ## Run identity guardian and OPA policy audit
	python3 src/identity_guardian.py
	opa eval -i infra/local_test/identity_contract.auto.tfvars.json -d policies/europa_identity_guard.rego "data.europa.security.deny"

rotate: ## Execute MTD epoch rotation sequence
	python3 src/europa_rotator.py

clean: ## Purge local cache and generated tfvars artifacts
	find . -type d -name "__pycache__" -exec rm -rf {} +
	rm -f infra/local_test/*.tfvars.json
