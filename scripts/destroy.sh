#!/usr/bin/env bash
set -euo pipefail

: "${ENV:?ENV must be set (dev|test|staging|production)}"
: "${AWS_REGION:?AWS_REGION must be set}"
: "${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID must be set}"
: "${TF_STATE_BUCKET:?TF_STATE_BUCKET must be set}"
: "${TF_LOCK_TABLE:?TF_LOCK_TABLE must be set}"
: "${GITHUB_ORG:=naman833}"

echo "==> WARNING: This will destroy ALL infrastructure in environment: ${ENV}"
echo "    Press CTRL+C within 10 seconds to cancel..."
sleep 10

TF_DIR="terraform/environments/${ENV}"

echo "==> Terraform init"
terraform -chdir="${TF_DIR}" init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=${TF_LOCK_TABLE}"

echo "==> Terraform destroy"
terraform -chdir="${TF_DIR}" destroy -auto-approve \
  -var="aws_account_id=${AWS_ACCOUNT_ID}" \
  -var="github_org=${GITHUB_ORG}" \
  -var="tf_state_bucket=${TF_STATE_BUCKET}" \
  -var="tf_lock_table=${TF_LOCK_TABLE}"

echo "==> Destroy complete for environment: ${ENV}"
