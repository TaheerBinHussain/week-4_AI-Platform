# ADR 0003: Two Storage Engines (Longhorn + OpenEBS LocalPV)

## Status
Accepted

## Context
Running stateful workloads in Kubernetes requires a reliable Container Storage Interface (CSI) driver. The platform hosts different types of stateful data:
1. **High-Durability Data:** Critical data that must survive pod rescheduling, node failures (in a multi-node setup), and requires backup/restore capabilities (e.g., PostgreSQL databases, MinIO blob storage).
2. **Ephemeral/Rebuildable Data:** Data that requires very high I/O performance but can tolerate loss because it is either a cache or can be rebuilt from source (e.g., Redis queues, Qdrant vector embeddings rebuilt from MinIO documents).

## Decision
We will deploy **Two Storage Engines** to cater to these different needs:

1. **Longhorn (`StorageClass: longhorn-replicated`):**
   - **Target:** PostgreSQL, MinIO.
   - **Reasoning:** Provides block storage with snapshots, scheduling, and backup to S3/MinIO capabilities. Ensures data durability.
   - **Single-Node Adaptation:** Because this is a single-node `kind` cluster, Longhorn's replication factor will be explicitly set to `1`. While this negates node-level high availability, it retains the vital snapshot and backup functionalities.

2. **OpenEBS LocalPV (`StorageClass: openebs-local-nvme`):**
   - **Target:** Qdrant, Redis.
   - **Reasoning:** Provisions volumes directly on the host's local disk (Hostpath/NVMe). Bypasses network replication overhead, providing near bare-metal I/O performance, which is critical for vector database search operations.

## Consequences
**Positive:**
- Workloads get storage tailored to their specific I/O and durability profiles.
- Heavy vector searches (Qdrant) will not be bottlenecked by Longhorn's replication layer overhead.
- Critical relational data (Postgres) benefits from automated snapshots and backups.

**Negative:**
- Increased complexity in managing two distinct CSI drivers.
- OpenEBS LocalPV volumes are strictly node-pinned; if the node is lost, the data is lost (acceptable per our rebuildable data definition, but requires automated recovery pipelines to be robust).
