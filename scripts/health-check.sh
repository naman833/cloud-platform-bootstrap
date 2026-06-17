#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-staging}"
MAX_RETRIES=10
RETRY_INTERVAL=15
HEALTH_PATH="${HEALTH_CHECK_PATH:-/health}"

echo "==> Running health check for environment: ${ENV}"

LB_HOSTNAME=$(kubectl get svc cloud-platform-app \
  -n cloud-platform \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "${LB_HOSTNAME}" ]; then
  echo "ERROR: Could not retrieve load balancer hostname for environment ${ENV}"
  exit 1
fi

URL="http://${LB_HOSTNAME}${HEALTH_PATH}"
echo "==> Health check URL: ${URL}"

for i in $(seq 1 "${MAX_RETRIES}"); do
  echo "    Attempt ${i}/${MAX_RETRIES}..."
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${URL}" || echo "000")

  if [ "${HTTP_CODE}" = "200" ]; then
    echo "==> Health check passed (HTTP ${HTTP_CODE})"
    exit 0
  fi

  echo "    HTTP ${HTTP_CODE} — retrying in ${RETRY_INTERVAL}s"
  sleep "${RETRY_INTERVAL}"
done

echo "ERROR: Health check failed after ${MAX_RETRIES} attempts against ${URL}"
exit 1
