# Day-2 Operations Runbook

## 1. Adding a New Application (App-of-Apps)
Product applications are managed by ArgoCD via the App-of-Apps pattern.
1. Create a new directory for your app under `kubernetes/apps/ai-platform/my-new-app/`.
2. Add your Kubernetes manifests or a Helm `Chart.yaml`/`values.yaml` in that directory.
3. Update the `kubernetes/apps/app-of-apps/templates/ai-platform-apps.yaml` to include an ArgoCD `Application` resource pointing to your new directory.
4. Commit and push to Git.
5. ArgoCD will automatically detect the new `Application` definition and sync your new app.

## 2. Rotating a Secret
Secrets are managed by HashiCorp Vault and synced to Kubernetes via External Secrets Operator (ESO).
1. Authenticate to Vault using the Vault CLI: `vault login`.
2. Update the secret in Vault: 
   ```bash
   vault kv put secret/data/ai-data/postgres password="new-secure-password"
   ```
3. ESO is configured to auto-refresh secrets based on the `refreshInterval` defined in the `ExternalSecret` custom resource (default is usually 1h). 
4. To force an immediate rotation, you can delete the corresponding Kubernetes secret:
   ```bash
   kubectl delete secret postgres-credentials -n ai-data
   ```
   ESO will immediately recreate it with the new value from Vault.
5. Restart the pods using the secret (e.g., `kubectl rollout restart deployment postgres -n ai-data`).

## 3. Upgrading a Helm Chart (FluxCD)
Infrastructure components are managed by FluxCD via `HelmRelease` objects.
1. Locate the `HelmRelease` YAML file (e.g., `kubernetes/infrastructure/observability/kube-prometheus-stack/helmrelease.yaml`).
2. Edit the `spec.chart.spec.version` to the new target version.
3. Commit and push to Git.
4. FluxCD's source controller will pull the change, and the helm controller will automatically upgrade the release.
5. Monitor the upgrade: `flux get helmreleases -n observability --watch`.

## 4. Scaling Ollama Manually
If KEDA is disabled or you need to manually intervene:
```bash
kubectl scale deployment ollama -n ai-platform --replicas=3
```
*Note: Ensure your single node has sufficient CPU/RAM resources before scaling heavy workloads like Ollama.*

## 5. Accessing ArgoCD UI
ArgoCD is exposed via Traefik Ingress.
- **Via Ingress:** Navigate to `http://argocd.sovereign.internal` (ensure `/etc/hosts` is configured).
- **Via Port-Forward (Fallback):**
  ```bash
  kubectl port-forward svc/argocd-server -n argocd 8080:80
  ```
  Then access `http://localhost:8080`.
- **Credentials:** Retrieve the initial admin password:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```

## 6. Viewing Logs in Grafana/Loki
1. Access Grafana at `http://grafana.sovereign.internal`.
2. Go to **Explore** (compass icon on the left menu).
3. Select **Loki** from the data source dropdown.
4. Use the LogQL query builder (e.g., `{namespace="ai-platform", app="ollama"}`) to view logs.

## 7. Viewing Traces in Grafana/Tempo
1. Access Grafana at `http://grafana.sovereign.internal`.
2. Go to **Explore**.
3. Select **Tempo** from the data source dropdown.
4. Enter a Trace ID or search by service/operation to view distributed traces spanning Open WebUI, LangFuse, and Ollama.

## 8. Triggering a Longhorn Backup Manually
Longhorn is configured to back up to MinIO.
1. Port-forward the Longhorn UI:
   ```bash
   kubectl port-forward svc/longhorn-frontend -n platform-infra 8000:80
   ```
2. Access `http://localhost:8000`.
3. Navigate to **Volumes**, select the volume (e.g., the Postgres PVC).
4. Click **Create Backup**. The backup will be sent to the configured MinIO S3 bucket.

## 9. Checking KEDA ScaledObject Status
To verify if autoscaling is working:
```bash
kubectl get scaledobjects -A
```
To view detailed metrics and status for a specific ScaledObject:
```bash
kubectl describe scaledobject ollama-scaler -n ai-platform
```
Check the `Conditions` section at the bottom of the output to ensure metrics are being collected successfully.
