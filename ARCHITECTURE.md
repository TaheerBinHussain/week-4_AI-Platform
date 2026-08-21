# Architecture Overview

## Namespaces and Purpose

1. **flux-system**: Houses FluxCD controllers (source, kustomize, helm). This is the root of the GitOps hierarchy.
2. **argocd**: Houses ArgoCD components (server, repo-server, application-controller). Manages the product side of GitOps.
3. **security**: Contains HashiCorp Vault, External Secrets Operator (ESO), and cert-manager. Provides the foundational trust and secret management layer.
4. **platform-infra**: Provides networking and storage. Contains Traefik, NGINX Ingress, MetalLB, Longhorn, and OpenEBS LocalPV.
5. **observability**: Contains the metrics, logs, and traces stack: kube-prometheus-stack (Grafana, Prometheus), Loki, Tempo, and OpenTelemetry Collector.
6. **ai-data**: Houses the stateful backing services for AI: PostgreSQL, Redis, MinIO, and Qdrant.
7. **ai-platform**: Contains the product applications: Open WebUI, Ollama, n8n, Flowise, and LangFuse.

## Component Overview

- **Vault**: Manages secrets. Connects to ESO. Port 8200.
- **External Secrets Operator (ESO)**: Syncs secrets from Vault into native K8s Secrets.
- **cert-manager**: Issues self-signed/local certificates for TLS.
- **Traefik**: Ingress controller for administrative and internal UI routes (ArgoCD, Grafana, n8n). Port 80/443.
- **NGINX Ingress**: Ingress controller for user-facing applications (Open WebUI, Flowise). Port 80/443.
- **MetalLB**: Provides LoadBalancer IPs in the 172.18.100.10-172.18.100.50 range.
- **Longhorn**: Distributed block storage for high-durability workloads (Postgres, MinIO).
- **OpenEBS LocalPV**: Local NVMe storage for fast, rebuildable workloads (Qdrant, Redis).
- **Prometheus/Grafana**: Metrics collection and visualization.
- **Loki/Tempo**: Log aggregation and distributed tracing.
- **PostgreSQL**: Relational database. Port 5432.
- **Redis**: Caching and background job queuing. Port 6379.
- **MinIO**: S3-compatible object storage for documents, backups, and artifacts. Port 9000.
- **Qdrant**: Vector database for AI embeddings. Port 6333.
- **Open WebUI**: User interface for chat. Connects to Ollama, Postgres.
- **Ollama**: Local LLM execution engine running models like llama3.2:1b and phi3:mini. Port 11434.
- **n8n**: Workflow automation. Connects to Postgres, Redis, Flowise.
- **Flowise**: UI for building LangChain workflows. Connects to Postgres, Qdrant.
- **LangFuse**: LLM observability and analytics. Connects to Postgres, ClickHouse/Redis.

## Data Flows

### Chat Request Flow
1. User sends a message via browser to `chat.sovereign.internal` (NGINX Ingress).
2. NGINX routes traffic to **Open WebUI**.
3. Open WebUI stores chat history in **PostgreSQL**.
4. Open WebUI sends the prompt to **Ollama** API (`http://ollama.ai-platform.svc.cluster.local:11434`).
5. Ollama processes the LLM inference on CPU and streams the response back.
6. Open WebUI asynchronously sends tracing/usage metrics to **LangFuse**.

### Secret Management Flow
1. Administrator writes a secret into **Vault** (e.g., path `secret/data/ai-data/postgres`).
2. **ESO** (`SecretStore` configured to use Vault token/AppRole) queries Vault.
3. **ESO** creates a native Kubernetes `Secret` named `postgres-credentials` in the `ai-data` namespace.
4. The **PostgreSQL** Pod mounts the `Secret` as environment variables (`POSTGRES_PASSWORD`).

### Document Ingestion Flow
1. User uploads a PDF via an **n8n** webhook.
2. n8n stores the raw file temporarily or long-term in **MinIO**.
3. n8n triggers a **Flowise** API endpoint, passing the document reference.
4. Flowise reads the document, chunks it, and calls the embedding model (via Ollama).
5. Flowise inserts the resulting embeddings into **Qdrant** for vector similarity search.

## Boundaries

### GitOps Boundary (ArgoCD vs FluxCD)
- **FluxCD** owns **Infrastructure**. It manages namespaces `flux-system`, `argocd`, `security`, `platform-infra`, and `observability` using `Kustomization` and `HelmRelease` resources. It guarantees the foundation is present.
- **ArgoCD** owns **Applications & Data**. It manages namespaces `ai-data` and `ai-platform` using `Application` and `ApplicationSet` resources. It provides a UI for developers to monitor application sync status.

### Storage Boundary
- **Longhorn** (`StorageClass: longhorn-replicated` with 1 replica for single-node): Used for data that *must not be lost*, such as Postgres databases and MinIO object stores.
- **OpenEBS LocalPV** (`StorageClass: openebs-local-nvme`): Used for ephemeral data, cache, or rebuildable data, such as Redis queues and Qdrant vectors (which can be rebuilt by re-running the ingestion pipeline).

### Ingress Routing Boundary
- **Traefik**: Serves administrative and developer endpoints (`argocd.sovereign.internal`, `grafana.sovereign.internal`, `n8n.sovereign.internal`). Used for its native middleware, basic auth, and dashboard.
- **NGINX Ingress**: Serves end-user applications (`chat.sovereign.internal`, `flowise.sovereign.internal`). Used for its widespread annotation support and potential future WAF integration.

## Network Policy Summary
- Default deny-all policy in `ai-data` and `ai-platform`.
- `ai-platform` pods can communicate with `ai-data` pods on specific ports (5432, 6379, 9000, 6333).
- `ai-platform` pods can communicate with each other (e.g., Open WebUI -> Ollama).
- `ingress-nginx` namespace (in `platform-infra`) can access `Open WebUI` and `Flowise` in `ai-platform`.
- `traefik` namespace can access `n8n`, `ArgoCD`, `Grafana`.
- `observability` namespace can scrape metrics from all namespaces.
