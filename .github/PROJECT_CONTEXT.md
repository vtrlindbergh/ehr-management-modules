# EHR Blockchain - Project Context for AI Sessions

> **Purpose**: Resume context in new chat windows. Feed this file to the AI at session start.
> **Last updated**: 2026-02-19 (Phase 3 complete)

## Project Goal
Master's dissertation: compare local vs cloud Hyperledger Fabric performance for EHR CRUD operations.
Identical chaincode and methodology, different deployment targets.

## Repository
- **Remote**: `git@github.com-vtr:vtrlindbergh/ehr-management-modules.git`
- **Branch**: `feature/phase1-distributed-deployment`
- **Latest commit**: `cf89142` — Phase 3: Deploy Fabric network across Docker Swarm
- **SSH config**: uses `Host github.com-vtr` with `~/.ssh/id_ed25519_vtr`

## Tech Stack
- Hyperledger Fabric **2.5.10**, CA **1.5.12**
- Go **1.22.7**, Docker Swarm, Terraform (Azure)
- Chaincode: `ehrCC` v2.0 (sequence 2), Go, FHIR-based EHR model
- Channel: `mychannel`, Raft consensus (single orderer)

## Azure Infrastructure (Live)
3x Standard_B1ms (1 vCPU, 2 GB RAM), North Central US, 4-core student quota.

| Role | Public IP | Private IP | Subnet |
|------|-----------|-----------|--------|
| orderer (Swarm manager) | 135.232.180.24 | 10.0.1.4 | 10.0.1.0/24 |
| org1 (Swarm worker) | 20.88.52.252 | 10.0.2.4 | 10.0.2.0/24 |
| org2 (Swarm worker) | 130.131.55.125 | 10.0.3.4 | 10.0.3.0/24 |

- VNet: 10.0.0.0/16, 32 GB data disks mounted at `/opt/hyperledger`
- Docker overlay network: `fabric_test` (attachable)
- NSG ports: SSH(22), Orderer(7050,7053), Peer(7051,9051), CouchDB(5984), Swarm(2377,7946,4789)

## Key Files
| File | Purpose |
|------|---------|
| `chaincode/services/auth/auth_service.go` | Auth — falls back to GetID() for cryptogen certs |
| `chaincode/services/ehr_service.go` | EHR CRUD operations |
| `chaincode/services/consent_service.go` | Consent management |
| `chaincode/models/models.go` | EHR + Consent + FHIR models |
| `scripts/cloud/compose/docker-stack-fabric.yml` | Swarm stack (3 services, placement constraints) |
| `scripts/cloud/setup/configtx.yaml` | Channel config (2 orgs, Raft) |
| `scripts/cloud/setup/deploy_network.sh` | Full deployment automation (11 steps) |
| `scripts/performance/` | Local performance test scripts |
| `infra/` | Terraform modules (compute, network, storage) |
| `EXECUTION_PLAN.md` | 5-phase execution plan |

## Chaincode Lifecycle (current state on cluster)
- **Name**: ehrCC, **Version**: 2.0, **Sequence**: 2
- **Package ID**: `ehrCC_2.0:84af46e5f2d606b74ee6ae346710d4ac1bf6bfdac660dbf06bdf15db4f99b275`
- Installed + approved on both Org1 and Org2, committed to channel
- CreateEHR tested OK (status:200), ReadEHR returns JSON with FHIR data
- Auth fix: `GetClientIdentity()` uses `GetID()` fallback since cryptogen certs lack `hf.EnrollmentID`

## Peer CLI Environment (copy-paste reference)
```bash
# Org1 (on 20.88.52.252)
export PATH=/usr/local/go/bin:/opt/hyperledger/fabric-samples/bin:$PATH
export FABRIC_CFG_PATH=/opt/hyperledger/peercfg
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/hyperledger/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/opt/hyperledger/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
export ORDERER_CA=/opt/hyperledger/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# Org2 (on 130.131.55.125) — same but Org2MSP, localhost:9051, org2 paths
```

## Execution Plan Progress
| Phase | Status |
|-------|--------|
| 0 — Fix versions & configs | ✅ Done |
| 1 — Deploy 3 Azure VMs | ✅ Done |
| 2 — Docker Swarm cluster | ✅ Done |
| 3 — Deploy Fabric network | ✅ Done |
| 4 — Adapt & run cloud performance scripts | ⬜ Next |
| 5 — Collect data & destroy infra | ⬜ Pending |

## Phase 4 — What's Next
Adapt the local performance scripts (`scripts/performance/`) for cloud execution.
These scripts test: latency, throughput, parallel operations, scaling.
They need to be modified to target the cloud VMs instead of localhost.
The same CRUD operations and methodology used locally must be replicated for a fair comparison.

## Known Issues / Gotchas
- Azure Student subscription: max 4 `standardBSFamily` vCPUs in northcentralus
- `cloud-init` write_files chown fails (azureuser not created yet) — cosmetic, runcmd works fine
- `GOFLAGS=-buildvcs=false` needed for `peer lifecycle chaincode package` (git ownership mismatch)
- Swarm service names cannot contain dots — use hyphens + network aliases
- `--ordererTLSHostnameOverride orderer.example.com` required when addressing orderer by IP
