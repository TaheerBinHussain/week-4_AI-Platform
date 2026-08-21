#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${YELLOW}1. Waiting for Vault pod to be running...${NC}"
kubectl wait -n security --for=condition=ready pod --selector=app.kubernetes.io/name=vault --timeout=120s || true
# Wait a few more seconds just in case
sleep 5

echo -e "${YELLOW}2. Port-forwarding Vault...${NC}"
kubectl port-forward -n security svc/vault 8200:8200 &
VAULT_PF_PID=$!
trap "kill $VAULT_PF_PID" EXIT
sleep 5 # Wait for port-forward to establish

export VAULT_ADDR="http://127.0.0.1:8200"

echo -e "${YELLOW}3. Checking Vault status...${NC}"
if vault status -format=json | jq -e '.initialized' >/dev/null; then
  echo -e "${GREEN}Vault is already initialized.${NC}"
else
  echo -e "${YELLOW}4. Initializing Vault...${NC}"
  vault operator init -key-shares=5 -key-threshold=3 > /tmp/vault-init-output.txt
  
  echo -e "${RED}========================================================================${NC}"
  echo -e "${RED}BIG WARNING: SAVE THESE UNSEAL KEYS NOW.${NC}"
  echo -e "${RED}They will not be shown again. Store in 1Password or print and lock away.${NC}"
  echo -e "${RED}========================================================================${NC}"
  cat /tmp/vault-init-output.txt
  
  echo -e "${YELLOW}6. Unsealing Vault...${NC}"
  UNSEAL_KEY_1=$(grep "Unseal Key 1:" /tmp/vault-init-output.txt | awk '{print $4}')
  UNSEAL_KEY_2=$(grep "Unseal Key 2:" /tmp/vault-init-output.txt | awk '{print $4}')
  UNSEAL_KEY_3=$(grep "Unseal Key 3:" /tmp/vault-init-output.txt | awk '{print $4}')
  
  vault operator unseal "$UNSEAL_KEY_1"
  vault operator unseal "$UNSEAL_KEY_2"
  vault operator unseal "$UNSEAL_KEY_3"
fi

echo -e "${YELLOW}7. Logging in with root token...${NC}"
if [ -f /tmp/vault-init-output.txt ]; then
  ROOT_TOKEN=$(grep "Initial Root Token:" /tmp/vault-init-output.txt | awk '{print $4}')
  vault login "$ROOT_TOKEN"
fi

echo -e "${YELLOW}8. Enabling KV v2 secrets engine...${NC}"
vault secrets enable -path=secret kv-v2 || echo "KV engine already enabled"

echo -e "${YELLOW}9. Creating Vault policies...${NC}"
for policy_file in security/vault/policies/*.hcl; do
  if [ -f "$policy_file" ]; then
    policy_name=$(basename "$policy_file" .hcl)
    vault policy write "$policy_name" "$policy_file"
  fi
done

echo -e "${YELLOW}10. Enabling Kubernetes auth method...${NC}"
vault auth enable kubernetes || echo "Kubernetes auth already enabled"

echo -e "${YELLOW}11. Configuring Kubernetes auth...${NC}"
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc"

echo -e "${YELLOW}12. Creating roles for service accounts...${NC}"
vault write auth/kubernetes/role/ai-data \
    bound_service_account_names="*" \
    bound_service_account_namespaces="ai-data" \
    policies="ai-data-policy" \
    ttl=24h
vault write auth/kubernetes/role/ai-platform \
    bound_service_account_names="*" \
    bound_service_account_namespaces="ai-platform" \
    policies="ai-platform-policy" \
    ttl=24h

echo -e "${YELLOW}13. Populating initial secrets...${NC}"
gen_secret() {
  head -c "$1" /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c "$1"
}

vault kv put -mount=secret ai-data/postgres username=postgres password=$(gen_secret 32)
vault kv put -mount=secret ai-data/redis password=$(gen_secret 32)
vault kv put -mount=secret ai-data/minio rootUser=minio rootPassword=$(gen_secret 32)
vault kv put -mount=secret ai-data/qdrant apiKey=$(gen_secret 32)

vault kv put -mount=secret ai-platform/n8n encryptionKey=$(gen_secret 32) basicAuthPassword=$(gen_secret 16)
vault kv put -mount=secret ai-platform/langfuse secretKey=$(gen_secret 64) salt=$(gen_secret 32)
vault kv put -mount=secret ai-platform/flowise passphrase=$(gen_secret 32)

echo -e "${YELLOW}14. Paths created:${NC}"
vault kv list -mount=secret ai-data/
vault kv list -mount=secret ai-platform/

echo -e "${GREEN}Vault init complete! Run scripts/smoke-test.sh to verify ExternalSecrets are syncing.${NC}"
