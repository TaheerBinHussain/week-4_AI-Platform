#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Sovereign AI Platform Bootstrap...${NC}"

echo -e "${YELLOW}1. Checking prerequisites...${NC}"
for cmd in docker kind kubectl helm flux argocd vault jq curl; do
  if ! command -v $cmd &> /dev/null; then
    echo -e "${RED}Error: command '$cmd' could not be found. Please install it and try again.${NC}"
    exit 1
  fi
done
echo -e "${GREEN}All prerequisites found.${NC}"

echo -e "${YELLOW}2. Creating host directories...${NC}"
mkdir -p /tmp/sovereign-storage/longhorn
mkdir -p /tmp/sovereign-storage/openebs

echo -e "${YELLOW}3. Creating kind cluster...${NC}"
if kind get clusters | grep -q "^sovereign-ai$"; then
  echo -e "${YELLOW}Cluster 'sovereign-ai' already exists. Skipping creation.${NC}"
else
  kind create cluster --name sovereign-ai --config scripts/kind-cluster-config.yaml
fi

echo -e "${YELLOW}4. Waiting for cluster to be ready...${NC}"
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo -e "${YELLOW}5. Creating namespaces...${NC}"
for ns in ai-platform ai-data security platform-infra observability argocd flux-system; do
  kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f -
done

echo -e "${YELLOW}6. Installing MetalLB...${NC}"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kind-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.18.100.10-172.18.100.50
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kind-advertisement
  namespace: metallb-system
EOF

echo -e "${YELLOW}7. Bootstrapping FluxCD...${NC}"
if [ -z "${GITHUB_TOKEN:-}" ] || [ -z "${GITHUB_REPO:-}" ]; then
  echo -e "${YELLOW}Warning: GITHUB_TOKEN or GITHUB_REPO not set. Skipping Flux bootstrap.${NC}"
else
  flux bootstrap git \
    --url="https://github.com/${GITHUB_REPO}" \
    --branch=main \
    --path=flux/clusters/prod/ \
    --password="${GITHUB_TOKEN}" \
    --token-auth=true
fi

echo -e "${YELLOW}8. Installing ArgoCD...${NC}"
kubectl apply -n argocd -f argocd/install/argocd-install.yaml
kubectl wait --namespace argocd --for=condition=ready pod --selector=app.kubernetes.io/name=argocd-server --timeout=120s

echo -e "${YELLOW}9. Applying ArgoCD app-of-apps...${NC}"
kubectl apply -f argocd/app-of-apps.yaml

echo -e "${YELLOW}10. Required /etc/hosts entries...${NC}"
echo -e "${GREEN}Please add the following lines to your /etc/hosts file, mapping to your ingress or MetalLB IP:${NC}"
echo "172.18.100.10 chat.sovereign.internal"
echo "172.18.100.10 flowise.sovereign.internal"
echo "172.18.100.10 n8n.sovereign.internal"
echo "172.18.100.10 argocd.sovereign.internal"
echo "172.18.100.10 grafana.sovereign.internal"
echo "172.18.100.10 langfuse.sovereign.internal"

echo -e "${GREEN}Bootstrap complete! Run scripts/vault-init.sh next.${NC}"
