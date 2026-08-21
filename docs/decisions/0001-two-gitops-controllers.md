# ADR 0001: Two GitOps Controllers (ArgoCD + FluxCD)

## Status
Accepted

## Context
The Sovereign AI Platform requires a robust GitOps workflow to manage both foundational infrastructure (Ingress, Storage, Security) and higher-level AI applications (Ollama, Flowise, WebUI). 

Two dominant GitOps operators exist in the Kubernetes ecosystem: **FluxCD** and **ArgoCD**.
- **ArgoCD** excels at application-level delivery. It provides a rich UI, granular sync visibility, ApplicationSets for templating, and is highly developer-friendly.
- **FluxCD** excels at infrastructure bootstrapping. It natively supports advanced Kustomization CRDs, HelmRelease resource management, `dependsOn` execution ordering, and operates efficiently without requiring a UI, making it ideal for cluster zero-to-one scenarios.

Using a single controller for everything often leads to compromises: using ArgoCD for core infrastructure can cause bootstrap chicken-and-egg problems, while using Flux for user-facing applications lacks the visual observability developers appreciate.

## Decision
We will employ a **Dual GitOps Controller** architecture.
- **FluxCD** will manage all core infrastructure.
- **ArgoCD** will manage all product applications and stateful data services.

## Boundary Rule
To prevent conflicts and ensure a clear separation of concerns, the following strict boundary rule is enforced:
- **FluxCD** strictly owns the namespaces: `flux-system`, `argocd`, `security`, `platform-infra`, `observability`.
- **ArgoCD** strictly owns the namespaces: `ai-platform`, `ai-data`.

No resource shall be managed by both controllers. FluxCD will deploy ArgoCD itself.

## Consequences
**Positive:**
- Infrastructure components can leverage Flux's strict dependency ordering (`dependsOn`), ensuring Storage and Ingress exist before Observability.
- Developers managing AI workloads get the benefit of ArgoCD's intuitive UI to monitor application health and sync status.
- Prevents the 'ArgoCD managing ArgoCD' bootstrap paradox.

**Negative:**
- Increased operational complexity by maintaining two distinct GitOps toolchains.
- Administrators must understand both Flux (`Kustomization`, `HelmRelease`) and ArgoCD (`Application`, `ApplicationSet`) custom resources.
- Slightly higher resource footprint running both controllers on a single-node cluster.
