# EHR Blockchain — 3-VM Distributed Deployment Execution Plan

> **Date:** February 2026  
> **Branch:** `feature/chaincode-validation`  
> **Goal:** Deploy Hyperledger Fabric across 3 Azure VMs and collect distributed CRUD metrics  
> **Constraint:** Student account — minimize spend, destroy after each session

---

## 1. Architecture Decision: Docker Swarm Overlay — Validated

### Why Docker Swarm (not manual compose splitting or Kubernetes)

**Docker Swarm overlay networking** is the correct approach for this project. Here's why:

| Criterion | Docker Swarm | Manual Compose Split | Kubernetes |
|-----------|-------------|---------------------|------------|
| Complexity | Medium | High (rewrite compose, manage TLS certs across hosts manually) | Very High |
| Fabric compatibility | ✅ Well-documented in Fabric community | ✅ Works but fragile | ✅ Production standard but overkill |
| Cost | Same 3 VMs | Same 3 VMs | Needs AKS cluster (~$70+/mo) |
| Academic validity | ✅ Real multi-host network | ✅ Real multi-host network | ✅ But hides network details |
| Your existing compose files | Reusable with minor changes (network driver) | Must be split into 3 separate files | Must be rewritten as manifests |

**Fabric's official documentation says:** "The test network is not configured to connect to other running Fabric nodes" and recommends the [Deploying a production network](https://hyperledger-fabric.readthedocs.io/en/release-2.4/deployment_guide_overview.html) guide for multi-host. However, the test-network compose files work with Docker Swarm overlay because the containers resolve each other by DNS name (e.g., `orderer.example.com`, `peer0.org1.example.com`) — Swarm's overlay network provides exactly this cross-host DNS resolution.

**How it works:**
1. VM1 (orderer) initializes Docker Swarm as manager
2. VM2 (org1) and VM3 (org2) join the swarm as workers
3. An overlay network `fabric_test` is created across all 3 VMs
4. Each container is deployed on its designated VM using placement constraints
5. Containers communicate via the overlay network as if they were on the same host — but traffic actually crosses the Azure VNet between subnets

**What we're measuring:** Same CRUD operations, same `peer chaincode invoke/query` commands. But now endorsement requests, ordering, and block delivery traverse real network hops between VMs on different subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24). This gives you the **distributed latency comparison** vs your local results.

---

## 2. Pending Fixes (DO BEFORE deployment)

These are accumulated issues from previous sessions. Must be resolved before deploying.

### 2.1 cloud-init.yml — Logging

**Problem:** When cloud-init fails, there's no way to see where it stopped.  
**Fix:** Add as the **first runcmd**:
```yaml
- exec > /var/log/cloud-init-ehr.log 2>&1
```

### 2.2 cloud-init.yml — Go Version

**Problem:** `go.mod` requires Go 1.22.7 (toolchain 1.23.1). Cloud-init installs Go 1.18.10. Chaincode won't compile.  
**Fix:** Change Go install in cloud-init to match the local version:
```yaml
- wget https://go.dev/dl/go1.22.7.linux-amd64.tar.gz
```

### 2.3 cloud-init.yml — Fabric Version

**Problem:** Local Fabric is v2.5.10 (confirmed via `peer version`). Cloud-init installs 2.4.9. Version mismatch with local results.  
**Fix:** Align cloud-init with local:  
```yaml
- curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.10 1.5.12
```
> **Note:** The Fabric install script version (2.5.10) must match what the local `peer` binary reports to make local vs cloud metrics comparable. CA version 1.5.12 is the latest stable for Fabric 2.5.x.

### 2.4 NSG — Docker Swarm Ports

**Problem:** Current NSG rules only allow ports 22, 7050, 7051, 5984. Docker Swarm requires additional ports.  
**Fix:** Add to network NSG:
- TCP 2377 (Swarm management)
- TCP/UDP 7946 (Node communication)  
- UDP 4789 (Overlay network — VXLAN)
- TCP 9051 (Org2 peer port — currently missing)

### 2.5 Compute — VM Sizing for Distributed

**Problem:** Org1/Org2 VMs use `Standard_B1s` (1 vCPU, 1 GB RAM). Running a Fabric peer + chaincode containers on 1 GB RAM will likely OOM.  
**Fix:** Upgrade all 3 VMs to `Standard_B2s` (2 vCPU, 4 GB RAM) for distributed mode. Cost impact: ~$15/mo more, but prevents failures.

---

## 3. What We Will NOT Change

- **`scripts/performance/`** — All local test scripts stay untouched  
- **`scripts/setup/`** — Local network setup and CRUD test scripts stay untouched  
- **`scripts/results/`** — Local results stay untouched  
- **`chaincode/`** — No chaincode changes  
- **Existing Terraform modules** — We extend, not rewrite  

---

## 4. New Files to Create

All cloud-specific scripts go in a NEW directory: `scripts/cloud/`

```
scripts/cloud/
├── config.sh                    # Cloud-specific config (VM IPs, remote paths, swarm settings)
├── setup/
│   ├── init_swarm.sh            # Initialize Docker Swarm on orderer VM, generate join tokens
│   ├── join_swarm.sh            # Join worker VMs to swarm 
│   ├── deploy_network.sh        # Deploy Fabric containers across swarm
│   ├── generate_crypto.sh       # Generate crypto material (on orderer VM, distribute to workers)
│   └── validate_network.sh      # Verify all containers running, channel created, chaincode deployed
├── performance/
│   ├── cloud_latency_analysis.sh      # Same metrics as local, adapted for remote peers
│   ├── cloud_throughput_test.sh       # Same metrics as local, adapted for remote peers
│   ├── cloud_parallel_test.sh         # Same metrics as local, adapted for remote peers
│   └── cloud_scaling_test.sh          # Same metrics as local, adapted for remote peers
├── compose/
│   ├── docker-compose-orderer.yml     # Orderer container + CA (deployed on VM1)
│   ├── docker-compose-org1.yml        # Org1 peer + CA (deployed on VM2)
│   ├── docker-compose-org2.yml        # Org2 peer + CA (deployed on VM3)
│   └── docker-stack-fabric.yml        # Single stack file for Swarm deployment (alternative)
├── results/                           # Cloud-specific results (same CSV format as local)
│   ├── latency_analysis/
│   ├── throughput_analysis/
│   └── parallel_analysis/
└── teardown.sh                        # Clean shutdown of swarm and containers
```

### Key design principle for cloud performance scripts:
- **Same CSV output format** as local scripts (so reports can compare directly)
- **Same test logic** (same CRUD operations, same iteration counts, same patient ID patterns)
- **Different config source:** `scripts/cloud/config.sh` points to VM private IPs instead of localhost
- Peer addresses change from `localhost:7051` / `localhost:9051` to `10.0.2.4:7051` / `10.0.3.4:9051` (actual VM IPs)
- Orderer changes from `localhost:7050` to `10.0.1.4:7050`

---

## 5. Execution Phases

### Phase 0 — Fix Cloud-Init & Terraform (estimated: 1 hour)

| Step | Action | Files Changed |
|------|--------|---------------|
| 0.1 | Add logging to cloud-init (first runcmd) | `infra/modules/compute/scripts/cloud-init.yml` |
| 0.2 | Fix Go version to 1.22.7 | `infra/modules/compute/scripts/cloud-init.yml` |
| 0.3 | Fix Fabric version to 2.5.10 | `infra/modules/compute/scripts/cloud-init.yml` |
| 0.4 | Add Docker Swarm ports to NSG | `infra/modules/network/main.tf` |
| 0.5 | Add Org2 peer port (9051) to NSG | `infra/modules/network/main.tf` |
| 0.6 | Upgrade B1s to B2s for distributed mode | `infra/modules/compute/main.tf` |
| 0.7 | Set `deployment_mode = "distributed"` | `infra/environments/dev/terraform.tfvars` |
| 0.8 | Commit fixes to branch | Git |

### Phase 1 — Deploy 3 VMs & Validate Base Setup (estimated: 30 min)

| Step | Action |
|------|--------|
| 1.1 | `terraform apply` — deploy 3 VMs |
| 1.2 | SSH into each VM, verify cloud-init completed (check `/var/log/cloud-init-ehr.log`) |
| 1.3 | Verify on each VM: Docker running, Go 1.22.7, Fabric binaries in PATH |
| 1.4 | Note the 3 private IPs (orderer: 10.0.1.x, org1: 10.0.2.x, org2: 10.0.3.x) |
| 1.5 | Test VM-to-VM connectivity: `ping` between private IPs |

### Phase 2 — Initialize Docker Swarm (estimated: 30 min)

| Step | Action | Where |
|------|--------|-------|
| 2.1 | Initialize swarm on orderer VM: `docker swarm init --advertise-addr <orderer-private-ip>` | VM1 (orderer) |
| 2.2 | Get worker join token | VM1 |
| 2.3 | Join org1 VM to swarm: `docker swarm join --token <token> <orderer-ip>:2377` | VM2 (org1) |
| 2.4 | Join org2 VM to swarm: `docker swarm join --token <token> <orderer-ip>:2377` | VM3 (org2) |
| 2.5 | Create overlay network: `docker network create --driver overlay --attachable fabric_test` | VM1 |
| 2.6 | Verify: `docker node ls` shows 3 nodes | VM1 |
| 2.7 | Label nodes for placement: `docker node update --label-add role=orderer <node-id>` | VM1 |

### Phase 3 — Deploy Fabric Network Across Swarm (estimated: 1-2 hours)

This is the most complex phase. Two approaches (we pick one):

**Approach A — Docker Stack Deploy (recommended for simplicity):**
- Create a single `docker-stack-fabric.yml` that includes all services (orderer, peer0.org1, peer0.org2, 3 CAs)
- Use placement constraints to pin each container to its node
- Deploy with `docker stack deploy -c docker-stack-fabric.yml fabric`
- Crypto material must be pre-generated and distributed to all VMs

**Approach B — Individual compose per VM:**
- Run `docker compose up` separately on each VM
- All containers join the same overlay network
- More control, but more manual coordination

| Step | Action | Where |
|------|--------|-------|
| 3.1 | Generate all crypto material (using `cryptogen` or CAs) | VM1 (orderer) |
| 3.2 | Distribute crypto material to VM2 and VM3 via `scp` | VM1 → VM2, VM3 |
| 3.3 | Deploy Fabric containers (stack or individual compose) | VM1 (swarm manager) |
| 3.4 | Wait for all containers to be running | All VMs |
| 3.5 | Create channel: `peer channel create` from VM2/VM3 (or CLI container) | VM1 or VM2 |
| 3.6 | Join peers to channel | VM2, VM3 |
| 3.7 | Deploy EHR chaincode (install on both peers, approve, commit) | VM2, VM3 |
| 3.8 | Validate: run a simple CreateEHR + ReadEHR | VM2 |

### Phase 4 — Create Cloud Performance Scripts (estimated: 2-3 hours)

| Step | Action |
|------|--------|
| 4.1 | Create `scripts/cloud/config.sh` with VM IPs, remote paths, cloud-specific settings |
| 4.2 | Copy and adapt `latency_analysis.sh` → `cloud_latency_analysis.sh` (change endpoints) |
| 4.3 | Copy and adapt `throughput_test.sh` → `cloud_throughput_test.sh` |
| 4.4 | Copy and adapt `parallel_test.sh` → `cloud_parallel_test.sh` |
| 4.5 | Test each script with small iteration count (5-10) to validate |
| 4.6 | Run full test suite (100+ iterations per operation type) |
| 4.7 | Collect results to `scripts/cloud/results/` |

### Phase 5 — Collect Data & Destroy (estimated: 1 hour)

| Step | Action |
|------|--------|
| 5.1 | Download all CSV results from VMs to local `scripts/cloud/results/` |
| 5.2 | Run comparison: local results vs cloud results (same CSV format enables direct comparison) |
| 5.3 | `terraform destroy` — tear down all resources immediately |
| 5.4 | Commit cloud scripts and results to branch |
| 5.5 | Merge to main if everything looks good |

---

## 6. Cost Estimate

| Resource | Monthly Cost | With Auto-Shutdown (8h/day) |
|----------|-------------|---------------------------|
| 3x Standard_B2s VMs | ~$90/mo | ~$30/mo |
| 3x 64GB StandardSSD data disks | ~$15/mo | ~$15/mo |
| 3x Public IPs (Standard) | ~$10/mo | ~$10/mo |
| Network egress | ~$2/mo | ~$2/mo |
| **Total** | **~$117/mo** | **~$57/mo** |

**Realistic scenario:** You'll deploy for a few sessions (maybe 4-5 days total), not a full month. If you deploy, test, and destroy within 2-3 sessions of ~4 hours each:

**Estimated total cost: $5-15** (pay-per-hour billing + destroy after each session)

**Key discipline:** Always `terraform destroy` after each session. Never leave VMs running overnight.

---

## 7. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Docker Swarm overlay adds latency overhead vs native networking | Medium — could inflate metrics | Document the overhead; it's consistent across all tests so comparisons remain valid |
| Fabric test-network scripts assume single-host | High — `network.sh` won't work across VMs | We bypass `network.sh` and deploy containers directly via docker stack/compose |
| Crypto material distribution fails | Medium — TLS errors on peer-to-orderer comms | Generate once, distribute via SCP, verify paths before deploying containers |
| 1 GB RAM OOM on B1s | High — containers crash | Already mitigated: upgrading to B2s |
| Cloud-init fails again | Medium — delays testing | Mitigated: added logging redirect |
| Student account credit runs out | High — everything stops | Destroy after each session; monitor credit in Azure portal |

---

## 8. Success Criteria

The deployment is considered successful when:

1. ✅ 3 VMs deployed, Docker Swarm active with overlay network
2. ✅ Fabric network running: orderer on VM1, peer0.org1 on VM2, peer0.org2 on VM3
3. ✅ Channel created and both peers joined
4. ✅ EHR chaincode deployed and operational
5. ✅ `CreateEHR` from VM2 (Org1) succeeds
6. ✅ `GrantConsent` + cross-org `ReadEHR` from VM3 (Org2) succeeds
7. ✅ Cloud latency CSV collected with same format as local CSVs
8. ✅ Cloud throughput CSV collected with same format as local CSVs
9. ✅ All resources destroyed after testing

---

## 9. Comparison Framework (Local vs Cloud)

The final deliverable for the dissertation is a **side-by-side comparison table**:

| Metric | Local (Docker on laptop) | Cloud (3 VMs, Docker Swarm) | Delta |
|--------|-------------------------|---------------------------|-------|
| Create EHR mean latency | from existing CSVs | from new cloud CSVs | |
| Read EHR mean latency | from existing CSVs | from new cloud CSVs | |
| Cross-org read mean latency | from existing CSVs | from new cloud CSVs | |
| Create EHR P99 | from existing CSVs | from new cloud CSVs | |
| Throughput (TPS) | from existing CSVs | from new cloud CSVs | |
| Parallel scaling efficiency | from existing CSVs | from new cloud CSVs | |

Both scenarios use the **exact same chaincode, same operations, same measurement methodology**. Only the infrastructure changes.
