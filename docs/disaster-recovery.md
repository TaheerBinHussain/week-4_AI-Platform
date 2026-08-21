# Disaster Recovery Guide

## Backup Architecture Overview
The Sovereign AI Platform employs a tiered backup strategy focused on data resilience:
1. **Longhorn Snapshots & Backups:** Stateful applications requiring high durability (like Postgres) use Longhorn storage. Longhorn takes scheduled volume snapshots and offloads backups to the internal **MinIO** object storage cluster.
2. **MinIO Offsite Sync (Conceptual):** In a production scenario, MinIO buckets would be mirrored to an offsite S3-compatible provider (e.g., AWS S3, Cloudflare R2).
3. **GitOps State:** All cluster configuration, infrastructure definitions, and application manifests are stored in the Git repository. The cluster state is essentially stateless and ephemeral outside of the PV data.
4. **Secret State:** Vault is the source of truth for secrets. Vault storage itself (using a PVC) must be backed up, and unseal keys must be securely stored offline by operators.

## Postgres Restore Procedure
If the Postgres database is corrupted or lost, follow these steps to restore from a Longhorn backup stored in MinIO:

1. **Scale down the application:**
   ```bash
   kubectl scale deployment postgres -n ai-data --replicas=0
   ```
2. **Access Longhorn UI:**
   ```bash
   kubectl port-forward svc/longhorn-frontend -n platform-infra 8000:80
   ```
3. **Initiate Restore in UI:**
   - Go to `http://localhost:8000`.
   - Navigate to the **Backup** tab.
   - Locate the relevant Postgres volume backup.
   - Click **Restore** and define a new volume name (e.g., `postgres-restored`).
4. **Create PV and PVC from restored volume:**
   - In Longhorn UI, go to **Volumes**, select `postgres-restored`.
   - Click **Create PV/PVC**. Assign it to namespace `ai-data` with the name expected by the workload (e.g., `data-postgres-0`).
   *Note: You may need to delete the existing PVC first.*
5. **Scale application back up:**
   ```bash
   kubectl scale deployment postgres -n ai-data --replicas=1
   ```

## DR Drill Template
Use this template to record Disaster Recovery testing exercises.

| Drill Date | Component Failed | Detection Time | TTR (Time to Restore) | Steps Taken & Notes |
| :--- | :--- | :--- | :--- | :--- |
| YYYY-MM-DD | Example: Open WebUI Pod | 10:00 AM | 5 mins | Deleted pod, ReplicaSet recreated it. |
| YYYY-MM-DD | | | | |

## Cluster Total Loss Procedure
In the event the entire kind cluster node is lost or unrecoverable, follow this complete rebuild procedure:

1. **Re-provision Hardware & Prerequisites:** Ensure the new host has Docker, kind, and required CLIs installed.
2. **Create New Cluster:**
   ```bash
   kind create cluster --config kind-config.yaml
   ```
3. **Bootstrap FluxCD:**
   ```bash
   flux bootstrap github \
     --owner=$GITHUB_USER \
     --repository=sovereign-ai-platform \
     --branch=main \
     --path=kubernetes/clusters/production \
     --personal
   ```
4. **Wait for Infrastructure Sync:** Monitor FluxCD logs until `platform-infra`, `security`, and `observability` namespaces are provisioned.
5. **Unseal Vault (CRITICAL STEP):**
   Vault will start in a sealed state. You MUST have the unseal keys from the original deployment.
   ```bash
   kubectl exec -it -n security vault-0 -- sh
   vault operator unseal <KEY_1>
   vault operator unseal <KEY_2>
   vault operator unseal <KEY_3>
   ```
6. **Restore Data Volumes (Longhorn):**
   - Wait for Longhorn to provision.
   - Attach the external backup target (MinIO or external S3) in Longhorn settings.
   - Use the Longhorn UI to restore PVs for Postgres, Qdrant (if backed up), etc.
   - Recreate the PVCs with the exact names required by the workloads.
7. **Wait for ArgoCD Sync:**
   Once secrets are available (via ESO pulling from Vault) and PVCs are restored, ArgoCD will automatically deploy and stabilize the `ai-data` and `ai-platform` applications.

## Verification Steps After Restore
- [ ] Check Vault unseal status (`vault status`).
- [ ] Verify External Secrets are synced (`kubectl get externalsecrets -A`).
- [ ] Verify all PVCs are Bound (`kubectl get pvc -A`).
- [ ] Run a test chat query in Open WebUI to confirm Ollama and Postgres connectivity.
- [ ] Upload a test document in n8n/Flowise to verify Qdrant and MinIO functionality.
- [ ] Check Grafana Loki for error spikes.
