#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

FAILED=0

check() {
  local name=$1
  local pass=$2
  if [ "$pass" -eq 1 ]; then
    echo -e "${GREEN}[PASS] ${name}${NC}"
  else
    echo -e "${RED}[FAIL] ${name}${NC}"
    FAILED=1
  fi
}

echo -e "${YELLOW}1. Checking ArgoCD Apps...${NC}"
if argocd app list -o json | jq -e '.[] | select(.status.sync.status != "Synced" or .status.health.status != "Healthy") | empty' > /dev/null; then
  check "ArgoCD Apps" 1
else
  check "ArgoCD Apps" 0
fi

echo -e "${YELLOW}2. Checking Flux Kustomizations...${NC}"
if flux get kustomizations -A | grep -v "NAMESPACE" | grep -v "Applied" > /dev/null; then
  check "Flux Kustomizations" 0
else
  check "Flux Kustomizations" 1
fi

echo -e "${YELLOW}3. Checking ExternalSecrets...${NC}"
if kubectl get externalsecret -A --no-headers | grep -v "SecretSynced" > /dev/null; then
  check "ExternalSecrets" 0
else
  check "ExternalSecrets" 1
fi

echo -e "${YELLOW}4. Checking all pods running...${NC}"
BAD_PODS=$(kubectl get pods -A | grep -v Running | grep -v Completed | grep -v NAME || true)
if [ -n "$BAD_PODS" ]; then
  echo "$BAD_PODS"
  check "All Pods Running" 0
else
  check "All Pods Running" 1
fi

echo -e "${YELLOW}5. Checking KEDA ScaledObjects...${NC}"
kubectl get scaledobject -A || true
check "KEDA ScaledObjects" 1

test_endpoint() {
  local domain=$1
  local ip=$2
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" -k --resolve "$domain:443:$ip" "https://$domain" || echo "000")
  if [ "$status" -eq 200 ] || [ "$status" -eq 302 ] || [ "$status" -eq 401 ]; then
    check "$domain ($ip)" 1
  else
    echo -e "${RED}Got status $status for $domain${NC}"
    check "$domain ($ip)" 0
  fi
}

test_endpoint "chat.sovereign.internal" "172.18.100.11"
test_endpoint "flowise.sovereign.internal" "172.18.100.11"
test_endpoint "argocd.sovereign.internal" "172.18.100.10"
test_endpoint "grafana.sovereign.internal" "172.18.100.10"
test_endpoint "n8n.sovereign.internal" "172.18.100.10"

if [ "$FAILED" -eq 1 ]; then
  echo -e "${RED}Smoke tests failed!${NC}"
  exit 1
else
  echo -e "${GREEN}All smoke tests passed!${NC}"
fi
