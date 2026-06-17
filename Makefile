SHELL := /bin/bash
ENV   ?= staging

.PHONY: bootstrap init plan apply destroy deploy rollback health fmt validate clean

bootstrap:
	@echo "==> Bootstrapping remote state infrastructure"
	@bash scripts/bootstrap.sh

init:
	@echo "==> Initialising Terraform for environment: $(ENV)"
	terraform -chdir=terraform/environments/$(ENV) init \
		-backend-config="bucket=$(TF_STATE_BUCKET)" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="dynamodb_table=$(TF_LOCK_TABLE)"

fmt:
	@echo "==> Formatting Terraform files"
	terraform fmt -recursive terraform/

validate: init
	@echo "==> Validating Terraform for environment: $(ENV)"
	terraform -chdir=terraform/environments/$(ENV) validate

plan: init
	@echo "==> Planning Terraform for environment: $(ENV)"
	terraform -chdir=terraform/environments/$(ENV) plan \
		-var="aws_account_id=$(AWS_ACCOUNT_ID)" \
		-var="github_org=$(GITHUB_ORG)" \
		-var="tf_state_bucket=$(TF_STATE_BUCKET)" \
		-var="tf_lock_table=$(TF_LOCK_TABLE)"

apply: init
	@echo "==> Applying Terraform for environment: $(ENV)"
	terraform -chdir=terraform/environments/$(ENV) apply -auto-approve \
		-var="aws_account_id=$(AWS_ACCOUNT_ID)" \
		-var="github_org=$(GITHUB_ORG)" \
		-var="tf_state_bucket=$(TF_STATE_BUCKET)" \
		-var="tf_lock_table=$(TF_LOCK_TABLE)"

destroy:
	@echo "==> Destroying infrastructure for environment: $(ENV)"
	ENV=$(ENV) bash scripts/destroy.sh

deploy:
	@echo "==> Deploying k8s manifests for environment: $(ENV)"
	aws eks update-kubeconfig --region $(AWS_REGION) --name cloud-platform-$(ENV)
	kustomize build k8s/overlays/$(ENV) | kubectl apply -f -
	kubectl rollout status deployment/cloud-platform-app -n cloud-platform --timeout=300s

rollback:
	@echo "==> Rolling back deployment for environment: $(ENV)"
	aws eks update-kubeconfig --region $(AWS_REGION) --name cloud-platform-$(ENV)
	kubectl rollout undo deployment/cloud-platform-app -n cloud-platform
	kubectl rollout status deployment/cloud-platform-app -n cloud-platform --timeout=300s

health:
	@echo "==> Running health check for environment: $(ENV)"
	aws eks update-kubeconfig --region $(AWS_REGION) --name cloud-platform-$(ENV)
	bash scripts/health-check.sh $(ENV)

clean:
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null; true
	@find . -name "*.tfplan" -delete 2>/dev/null; true
	@echo "Cleaned up local Terraform files"
