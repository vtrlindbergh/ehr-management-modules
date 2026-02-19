# EHR Blockchain Cloud Performance Analysis Summary
**Academic Research - Master's Dissertation**
**Generated:** Thu 19 Feb 2026 18:59:37 UTC
**System:** Hyperledger Fabric v2.5.10
**Deployment:** 3 Azure VMs (Standard_B1ms), Docker Swarm overlay
**Network:** 2 Organizations, TLS Enabled
**Report Version:** Cloud Performance Analysis

---

## Executive Summary

This comprehensive performance analysis provides empirical evaluation of Hyperledger Fabric blockchain
performance characteristics for Electronic Health Record (EHR) management systems deployed across a
distributed cloud infrastructure (3 Azure VMs with Docker Swarm). The analysis encompasses latency
distribution, throughput capabilities, and parallel scaling behavior under academic research standards.

**Key Performance Indicators:**
- **Latency Analysis**: End-to-end transaction confirmation timing with statistical distribution
- **Throughput Analysis**: Concurrent transaction processing capabilities
- **Parallel Scaling**: Multi-worker performance scaling (1-8 concurrent workers)

**Cloud Infrastructure:**
- **Provider:** Microsoft Azure (northcentralus)
- **VM Size:** Standard_B1ms (1 vCPU, 2 GB RAM)
- **Network:** Docker Swarm overlay across 3 VMs

**Academic Standards:**
- Statistical significance with 500 iterations per test configuration
- P50, P95, P99 percentile analysis for latency characterization
- Scaling efficiency calculations for parallel processing evaluation
- Reproducible methodology for peer review and validation

---

**Network:** Orderer (10.0.1.4) | Org1 (10.0.2.4) | Org2 (10.0.3.4)

---

# Latency Analysis Summary (Cloud)

## End-to-End Latency Distribution Results — Distributed Deployment

| Operation Type | Sample Size | Mean (ms) | Std Dev (ms) | P50 (ms) | P95 (ms) | P99 (ms) | Range (ms) |
|---|---|---|---|---|---|---|---|
| **CreateEHR** | 500 | 117.439000 | 6.000000 | 116.553421000 | 127.812721000 | 135.218879000 | 106.571693000-150.971522000 |
| **ReadEHR (same-org)** | 500 | 86.744000 | 2.828000 | 86.369644000 | 91.147444000 | 98.741118000 | 81.176709000-117.740575000 |
| **ReadEHR (cross-org)** | 500 | 74.528000 | 3.000000 | 73.991762000 | 79.507341000 | 87.268932000 | 69.412292000-103.015833000 |
| **UpdateEHR** | 500 | 115.968000 | 5.656000 | 114.896585000 | 127.286801000 | 134.138266000 | 106.215734000-142.180262000 |
| **Consent (Grant/Revoke)** | 500 | 114.633000 | 12.165000 | 111.942713000 | 141.124176000 | 160.092554000 | 98.357025000-193.977462000 |
| **Unauthorized Read** | 500 | 75.625000 | 4.123000 | 74.648370000 | 86.027877000 | 90.227226000 | 69.383178000-97.516687000 |

### Key Insights (Cloud):
- Latency includes real network hops between Azure VMs across subnets
- Docker Swarm overlay (VXLAN) adds encapsulation overhead vs local Docker bridge
- Cross-org operations traverse VM boundaries (Org1 VM → Org2 VM)
- Orderer communication crosses subnet (10.0.2.x → 10.0.1.x)

# Throughput Analysis Summary (Cloud)

## Transaction Throughput Results — Distributed Deployment

| Operation Type | Sample Size | TPS | Duration (s) | Deployment |
|---|---|---|---|---|
| **CreateEHR** | 500 | 8.06 | 62.03 | Cloud (3 VMs) |
| **ReadEHR** | 500 | 10.47 | 47.75 | Cloud (3 VMs) |
| **UpdateEHR** | 500 | 8.31 | 60.16 | Cloud (3 VMs) |
| **Consent** | 500 | 8.26 | 60.53 | Cloud (3 VMs) |
| **Cross-Org** | 500 | 12.14 | 41.18 | Cloud (3 VMs) |

### Key Insights (Cloud):
- TPS reflects real distributed network overhead (inter-VM communication)
- Endorsement requests cross Azure VNet subnets between VMs
- Block delivery from orderer traverses separate subnet
- Direct comparison with local results reveals distributed deployment cost


# Parallel Scaling Analysis (Cloud)

## Scaling Performance — Distributed Deployment (Standard_B1ms)

| Workers | Test Type | Total Transactions | Success Rate | Total TPS | TPS/Worker | Duration (s) |
|---------|-----------|-------------------|--------------|-----------|------------|-------------|
| 1       | CROSS_ORG | 100               | 100.00%      | 9.41      | 9.41       | 10.624364723 |
| 2       | CROSS_ORG | 200               | 100.00%      | 9.58      | 4.79       | 20.856489414 |
| 4       | CROSS_ORG | 400               | 100.00%      | 9.41      | 2.35       | 42.507271585 |
| 8       | CROSS_ORG | 800               | 100.00%      | 9.26      | 1.15       | 86.377935012 |

### Cloud Scaling Analysis Insights

#### Cloud-Specific Characteristics
- **VM Resources**: Standard_B1ms (1 vCPU, 2 GB RAM per VM)
- **Network**: Docker Swarm overlay with VXLAN encapsulation across Azure VNet
- **Parallelism Limit**: Fewer vCPUs than local machine limits scaling ceiling
- **I/O Bound**: Blockchain consensus is network-bound, not CPU-bound

#### Comparison with Local Results
- Cloud parallel scaling is expected to plateau at fewer workers (VM resource limits)
- Network latency between VMs adds constant overhead to each transaction
- Swarm overlay adds ~1-2ms per packet compared to local Docker bridge
- Cross-org operations show more latency variance due to inter-VM hops

---

## Cloud System Configuration
- **Blockchain Platform:** Hyperledger Fabric v2.5.10
- **Certificate Authority:** v1.5.12
- **Go Version:** 1.22.7
- **Network Setup:** 2 Organizations (Org1, Org2) across 3 Azure VMs
- **Consensus:** Raft Ordering Service
- **Security:** TLS Enabled, MSP Authentication
- **Chaincode:** ehrCC v2.0 (sequence 2), Go, FHIR-based EHR model
- **Channel:** mychannel

## Azure Infrastructure
- **VM Size:** Standard_B1ms (1 vCPU, 2 GB RAM)
- **Region:** northcentralus
- **Network:** Docker Swarm overlay (fabric_test)
- **VNet:** 10.0.0.0/16 with 3 subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
- **Orderer VM:** 10.0.1.4 (10.0.1.0/24)
- **Org1 VM:** 10.0.2.4 (10.0.2.0/24)
- **Org2 VM:** 10.0.3.4 (10.0.3.0/24)

## Methodology
- **Same chaincode, same operations, same measurement methodology as local**
- **Only infrastructure changed:** local Docker → 3-VM Docker Swarm
- **Latency Tests:** End-to-end transaction timing with nanosecond precision
- **Throughput Tests:** Concurrent transaction processing measurement
- **Metrics:** P50, P95, P99 percentiles, mean, standard deviation
- **Operations:** CREATE, READ (same/cross-org), UPDATE, CONSENT, UNAUTHORIZED

*Report generated for academic research — local vs cloud comparison.*
