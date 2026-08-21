# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-08-21

### Completed (Day 1)
- Initialized Git repository structure.
- Created local Kubernetes cluster via `kind` configuration.
- Installed FluxCD CLI and bootstrapped the initial GitOps repository.
- Configured MetalLB for local LoadBalancer IP provisioning (172.18.100.10-172.18.100.50).

### Completed (Day 2)
- Added foundational infrastructure HelmReleases via Flux (Traefik, NGINX Ingress).
- Deployed HashiCorp Vault for secret management.
- Integrated External Secrets Operator (ESO) with Vault.
- Provisioned StorageClasses (Longhorn, OpenEBS LocalPV).

### Completed (Day 3)
- Deployed ArgoCD to manage the application layer.
- Set up observability stack (kube-prometheus-stack, Loki, Tempo, OTel Collector).
- Established network policies for baseline security.

### Completed (Day 4)
- Deployed stateful data services (PostgreSQL, Redis, MinIO, Qdrant) via ArgoCD.
- Configured PVCs matching the two-storage-engine architecture.
- Verified External Secrets injecting credentials into stateful workloads.

### Completed (Day 5)
- Deployed AI Platform applications (Open WebUI, Ollama, n8n, Flowise, LangFuse).
- Configured Ollama with local LLM models (llama3.2:1b, phi3:mini) for CPU inference.
- Validated Ingress routing (Traefik for internal, NGINX for external).

### Completed (Day 6)
- Finalized architecture and platform documentation (README, Architecture, ADRs, Runbook).
- Implemented and documented Disaster Recovery procedures.
- Conducted full platform end-to-end testing (Chat request -> Model inference -> Observability tracing).
