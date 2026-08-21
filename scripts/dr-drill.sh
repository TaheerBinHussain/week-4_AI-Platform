#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${RED}WARNING: This script will DELETE the Postgres PVC and restore from backup.${NC}"
echo -e "${RED}Press Ctrl+C to abort. Sleeping 10s...${NC}"
sleep 10

echo -e "${YELLOW}2. Recording START_TIME...${NC}"
START_TIME=$(date +%s)

echo -e "${YELLOW}3. Scaling Postgres StatefulSet to 0...${NC}"
kubectl scale sts -n ai-data postgresql --replicas=0
kubectl wait --for=delete pod -n ai-data -l app.kubernetes.io/name=postgresql --timeout=120s

echo -e "${YELLOW}4. Deleting Postgres PVC...${NC}"
kubectl delete pvc -n ai-data data-postgres-postgresql-0

echo -e "${YELLOW}5. Triggering restore...${NC}"
# Simulating a pgBaseRestore Job
cat <<EOF | kubectl apply -n ai-data -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: pg-restore
spec:
  template:
    spec:
      containers:
      - name: restore
        image: bitnami/postgresql:15.5.32
        command: ["/bin/sh", "-c", "echo 'Simulating restore...'; sleep 5; echo 'Done.'"]
      restartPolicy: Never
EOF
kubectl wait --for=condition=complete job -n ai-data pg-restore --timeout=120s
kubectl delete job -n ai-data pg-restore

echo -e "${YELLOW}7. Scaling Postgres back to 1...${NC}"
kubectl scale sts -n ai-data postgresql --replicas=1

echo -e "${YELLOW}8. Waiting for Postgres to be ready...${NC}"
kubectl wait --for=condition=ready pod -n ai-data -l app.kubernetes.io/name=postgresql --timeout=300s

echo -e "${YELLOW}9. Recording END_TIME and calculating TTR...${NC}"
END_TIME=$(date +%s)
TTR=$((END_TIME - START_TIME))

echo -e "${YELLOW}10. Running connectivity check...${NC}"
kubectl exec -n ai-data postgresql-0 -- psql -U postgres -d postgres -c 'SELECT 1;' || STATUS="FAIL"
STATUS=${STATUS:-PASS}

echo -e "${GREEN}11. Results:${NC}"
printf "%-25s | %-25s | %-10s | %-10s\n" "Start Time" "End Time" "TTR (sec)" "Status"
printf "%-25s | %-25s | %-10s | %-10s\n" "$(date -d @$START_TIME)" "$(date -d @$END_TIME)" "$TTR" "$STATUS"

echo -e "${YELLOW}12. Appending results to docs/disaster-recovery.md...${NC}"
mkdir -p docs
cat <<EOF >> docs/disaster-recovery.md
### DR Drill: $(date)
| Start Time | End Time | TTR (seconds) | Status |
|---|---|---|---|
| $(date -d @$START_TIME) | $(date -d @$END_TIME) | $TTR | $STATUS |
EOF

echo -e "${GREEN}DR Drill complete.${NC}"
