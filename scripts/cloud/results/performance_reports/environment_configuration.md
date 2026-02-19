# Cloud Environment Configuration Documentation
**Academic Research - Master's Dissertation**
**Generated:** 2026-02-19 18:59:37 UTC

## Cloud Infrastructure

**Provider:** Microsoft Azure  
**Region:** northcentralus  
**VM Size:** Standard_B1ms (1 vCPU, 2 GB RAM per VM)  
**Total VMs:** 3  
**Networking:** Docker Swarm overlay (`fabric_test`)

### VM Layout

| Role | Private IP | Subnet | Services |
|------|-----------|--------|----------|
| Orderer VM | 10.0.1.4 | 10.0.1.0/24 | Orderer, TLS CA |
| Org1 VM | 10.0.2.4 | 10.0.2.0/24 | Peer0-Org1, CLI, Org1 CA |
| Org2 VM | 10.0.3.4 | 10.0.3.0/24 | Peer0-Org2, Org2 CA |

## System Environment

**Operating System:**
- Platform: Linux
- Kernel: 6.8.0-1044-azure
- Architecture: x86_64
- Hostname: vm-ehr-blockchain-org1-dev

**Hardware Configuration (per VM):**
- VM Size: Standard_B1ms
- vCPUs: 1
- RAM: 2 GB
- CPU Cores (this node): 1
- Total Memory (this node): 1.9Gi
- Available Memory: 1.1Gi
- System Load:  0.00, 0.22, 0.55

**User Environment:**
- User: azureuser
- Working Directory: /opt/hyperledger/cloud-performance
- Shell: $SHELL

## Blockchain Configuration

**Hyperledger Fabric Network:**
- Fabric Version: v2.5.10
- CA Version: v1.5.12
- Go Version: 1.22.7
- Network Topology: 2 Organizations across 3 VMs
- Consensus Algorithm: Raft Ordering Service
- Security Features: TLS Enabled, MSP Authentication
- Chaincode: EHR Management Smart Contract v2.0 (ehrCC)
- Channel: mychannel

**Network Components:**
- Organizations: 2 (Org1, Org2)
- Peers per Organization: 1
- Ordering Service: Raft-based (single orderer node)
- Certificate Authorities: 3 (Orderer CA, Org1 CA, Org2 CA)
- Channels: 1 (mychannel)
- Docker Swarm Overlay: `fabric_test`

## File Structure and Locations

**Test Scripts:**
- Location: `scripts/cloud/performance/`
- Configuration: `scripts/cloud/performance/config.sh`
- Main Scripts:
  - `cloud_latency_analysis.sh` - End-to-end latency measurement
  - `cloud_throughput_test.sh` - Throughput benchmarking
  - `cloud_scaling_test.sh` - Scaling analysis (1-8 workers)
  - `cloud_generate_summary_report.sh` - Report generation

**Result Data:**
- Location: `scripts/cloud/results/`
- Latency Data: `scripts/cloud/results/latency_analysis/`
- Throughput Data: `scripts/cloud/results/throughput_analysis/`
- Parallel Data: `scripts/cloud/results/parallel_analysis/`
- Final Reports: `scripts/cloud/results/performance_reports/`

## Test Execution Standards

**Academic Rigor:**
- Statistical Significance: 500 iterations per operation
- Latency Analysis: P50, P95, P99 percentile characterization
- Throughput Measurement: Concurrent transaction processing evaluation
- Scaling Analysis: 1-8 worker parallel processing assessment

**Reproducibility Measures:**
- Automated test execution with documented parameters
- Timestamped result files with complete metadata
- Version-controlled configuration and scripts
- Comprehensive environment documentation

**Data Quality Assurance:**
- Pre-test environment validation
- Post-test result verification
- Automated data source validation
- Statistical validity checks

## Execution Commands

**Individual Tests:**
```bash
# Latency Analysis (500 iterations, all operations)
bash cloud_latency_analysis.sh 500 all

# Throughput Testing (500 iterations, all operations)
bash cloud_throughput_test.sh 500 all

# Scaling Analysis (800 base iterations, cross-org)
bash cloud_scaling_test.sh 800 cross_org

# Generate Performance Summary Report
bash cloud_generate_summary_report.sh --format both
```

---

*This documentation provides complete cloud environment context for academic research reproducibility and peer review validation.*
