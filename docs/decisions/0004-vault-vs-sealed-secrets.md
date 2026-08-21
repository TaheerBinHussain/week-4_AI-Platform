# ADR 0004: Vault + ESO vs Sealed Secrets

## Status
Accepted

## Context
A fully GitOps-driven platform must handle secrets securely. Secrets cannot be stored in plaintext in the Git repository. The two primary patterns for Kubernetes secret management in GitOps are:
1. **Sealed Secrets (Bitnami):** Encrypts secrets locally; the encrypted custom resource is stored in Git. The cluster decrypts it into a standard K8s Secret.
2. **External Secrets Management:** Secrets are stored in a centralized, secure vault (e.g., HashiCorp Vault) and synchronized into K8s at runtime via an operator.

While Sealed Secrets is very GitOps-friendly, it has drawbacks:
- Secrets are still technically in Git (though encrypted).
- Difficult to implement automated secret rotation.
- Lacks a robust audit trail of who accessed or changed a secret.
- Sharing secrets across multiple clusters requires copying the sealed manifests.

## Decision
We will use **HashiCorp Vault** combined with the **External Secrets Operator (ESO)**.

- **Vault** acts as the single source of truth for all sensitive material. It provides dynamic secrets, fine-grained access policies, comprehensive audit trails, and easy rotation capabilities.
- **ESO** is chosen over Vault Agent Injector sidecars because it maintains a cleaner separation of concerns. ESO syncs Vault secrets into native Kubernetes `Secret` objects, meaning application pods do not need Vault-aware sidecars, reducing overhead and maintaining compatibility with off-the-shelf Helm charts that expect standard K8s Secrets.

## Consequences
**Positive:**
- High security posture with a centralized secret backend.
- Enables future capabilities like dynamic database credential generation.
- Clean application pods without sidecar injection overhead.
- Auditability of secret access.

**Negative:**
- Vault introduces the "unseal problem." If the Vault pod restarts, it is sealed by default and requires manual operator intervention (providing unseal keys) before ESO can sync secrets. This is a known operational burden, mitigated by documenting the unseal procedure explicitly in the platform runbook.
- Higher initial setup complexity compared to simply running `kubeseal`.
