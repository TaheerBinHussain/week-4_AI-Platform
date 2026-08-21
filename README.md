# Sovereign AI Platform

Welcome to the Sovereign AI Platform, a self-hosted, scalable, GitOps-driven AI ecosystem running entirely on your own infrastructure (single-node kind cluster).

## Prerequisites
Before you begin, ensure you have the following installed:
- Docker
- kind (Kubernetes IN Docker)
- kubectl
- helm
- flux CLI
- argocd CLI
- vault CLI
- jq
- curl

## Hardware Requirements
This platform requires a moderately powerful host to run all components effectively.
- **CPU:** 8 cores minimum (12+ recommended)
- **RAM:** 16GB minimum (32GB recommended for large local LLMs)
- **Disk:** 50GB minimum free space (SSD/NVMe highly recommended)

## Quick-Start
To get a running cluster quickly, execute these 5 commands from the repository root:

```bash
kind create cluster --config kind-config.yaml
./scripts/bootstrap.sh
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n security --timeout=300s
kubectl apply -k bootstrap/flux-system/
flux get kustomizations --watch
```

## Full Bootstrap Sequence
The `scripts/bootstrap.sh` handles the initial setup, ensuring the kind cluster is created and core foundational tools (like Flux and MetalLB) are initialized.
1. The script validates prerequisites.
2. Creates the kind cluster.
3. Pre-loads necessary images if caching is configured.
4. Bootstraps Flux CD via the Git repository.
5. Applies the initial Vault configuration and External Secrets Operator setup.

## Accessing the Platform

### /etc/hosts Configuration
Add the following entries to your `/etc/hosts` file. Adjust the IP to match your MetalLB LoadBalancer IP range (e.g., `172.18.100.10` or `172.18.100.11` based on Traefik/NGINX assignments).

```text
# Sovereign AI Platform
172.18.100.10 chat.sovereign.internal
172.18.100.10 flowise.sovereign.internal
172.18.100.11 n8n.sovereign.internal
172.18.100.11 argocd.sovereign.internal
172.18.100.11 grafana.sovereign.internal
172.18.100.11 langfuse.sovereign.internal
```

### Hostnames & Ingress
- **Open WebUI (Chat):** http://chat.sovereign.internal
- **Flowise:** http://flowise.sovereign.internal
- **n8n:** http://n8n.sovereign.internal
- **ArgoCD:** http://argocd.sovereign.internal
- **Grafana:** http://grafana.sovereign.internal
- **LangFuse:** http://langfuse.sovereign.internal

## Architecture Overview
This platform employs a dual-GitOps strategy (Flux CD + ArgoCD), dual-Ingress (Traefik + NGINX), and dual-Storage (Longhorn + OpenEBS) architecture to provide enterprise-grade capabilities on a local kind cluster.

For deep-dive documentation on components, networking, and data flows, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Day-2 Operations
For ongoing management, secret rotation, adding applications, and checking status, refer to the [Runbook](docs/runbook.md).

## Disaster Recovery
For instructions on backups, DR drills, and total loss recovery, refer to the [Disaster Recovery Guide](docs/disaster-recovery.md).

## Namespaces

| Namespace | Purpose |
|---|---|
| `ai-platform` | Hosts user-facing product apps (Open WebUI, Flowise, n8n, LangFuse, Ollama). Managed by ArgoCD. |
| `ai-data` | Hosts stateful data backing services (Postgres, Redis, MinIO, Qdrant). Managed by ArgoCD. |
| `security` | Hosts Vault, External Secrets Operator, and cert-manager. Managed by Flux CD. |
| `platform-infra` | Hosts Ingress controllers (Traefik, NGINX), Storage engines (Longhorn, OpenEBS). Managed by Flux CD. |
| `observability` | Hosts monitoring stack (kube-prometheus-stack, Loki, Tempo, OTel Collector). Managed by Flux CD. |
| `argocd` | Hosts ArgoCD components. Managed by Flux CD. |
| `flux-system` | Hosts Flux CD controllers. Bootstrapped manually/via script. |

## Troubleshooting

### Top 5 Common Issues

1. **Vault is sealed:** 
   *Symptom:* Pods in `ai-data` and `ai-platform` are stuck in `ContainerCreating` or failing due to missing secrets.
   *Fix:* Run `vault operator unseal` with your unseal keys.
2. **Insufficient RAM:**
   *Symptom:* Ollama pods crash with OOMKilled when loading a model.
   *Fix:* Increase Docker memory allocation (if using Docker Desktop) or scale down other workloads.
3. **Storage Provisioning Failure:**
   *Symptom:* PVCs remain in `Pending` state.
   *Fix:* Check if Longhorn/OpenEBS pods are running in `platform-infra`. Check for disk space issues on the host.
4. **Ingress Not Routing:**
   *Symptom:* Browser cannot reach `chat.sovereign.internal`.
   *Fix:* Verify `/etc/hosts` matches the MetalLB IP (`kubectl get svc -n platform-infra`).
5. **GitOps Sync Conflicts:**
   *Symptom:* Resources rapidly updating/flickering.
   *Fix:* Ensure ArgoCD and Flux CD are not managing the same namespace. Check boundary rules (Flux = infra, Argo = apps).
