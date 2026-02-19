# EHR Blockchain Cloud Performance Testing

> **Deployment:** 3 Azure VMs, Docker Swarm overlay network  
> **Purpose:** Collect distributed QoS metrics for local vs cloud comparison  
> **Methodology:** Identical to `scripts/performance/` — same chaincode, same operations, same CSV format

## Cloud Architecture

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  VM1 (Orderer)   │     │  VM2 (Org1)      │     │  VM3 (Org2)      │
│  10.0.1.4        │     │  10.0.2.4        │     │  10.0.3.4        │
│  ─────────────── │     │  ─────────────── │     │  ─────────────── │
│  orderer:7050    │     │  peer0.org1:7051 │     │  peer0.org2:9051 │
│  Swarm Manager   │     │  Swarm Worker    │     │  Swarm Worker    │
│  Subnet: /24     │     │  Subnet: /24     │     │  Subnet: /24     │
└────────┬─────────┘     └────────┬─────────┘     └────────┬─────────┘
         │                        │                        │
         └────────────────────────┴────────────────────────┘
                    Azure VNet 10.0.0.0/16
                    Docker Swarm Overlay (fabric_test)
```

## What's Different from Local

| Aspect | Local (`scripts/performance/`) | Cloud (`scripts/cloud/performance/`) |
|--------|-------------------------------|--------------------------------------|
| Orderer address | `localhost:7050` | `10.0.1.4:7050` |
| Org1 peer address | `localhost:7051` | `10.0.2.4:7051` |
| Org2 peer address | `localhost:9051` | `10.0.3.4:9051` |
| TLS hostname override | Not needed | `--ordererTLSHostnameOverride orderer.example.com` |
| Crypto material path | `~/dev/fabric-samples/test-network/organizations/` | `/opt/hyperledger/organizations/` |
| Fabric config path | `~/dev/fabric-samples/config/` | `/opt/hyperledger/peercfg/` |
| Network type | Docker bridge (single host) | Docker Swarm overlay (3 VMs, VXLAN) |
| Patient ID prefix | `TEST_P` | `CLOUD_P` |
| Results directory | `scripts/results/` | `scripts/cloud/results/` |
| VM resources | Multi-core laptop | Standard_B1ms (1 vCPU, 2 GB RAM) |

## What's Identical

- **Chaincode:** ehrCC v2.0 (same Go code, same FHIR data model)
- **Operations:** CreateEHR, ReadEHR, UpdateEHR, GrantConsent, RevokeConsent
- **CSV format:** Same column headers, same SUMMARY line format
- **Statistical analysis:** Same percentile calculations (P50, P95, P99)
- **Test methodology:** Same iteration counts, same patient ID cycling
- **Measurement precision:** `date +%s.%N` nanosecond timing

## Quick Start

SSH into the **Org1 VM** (10.0.2.4) and run:

```bash
# 1. Set up environment
export PATH=/usr/local/go/bin:/opt/hyperledger/fabric-samples/bin:$PATH
export FABRIC_CFG_PATH=/opt/hyperledger/peercfg

# 2. Navigate to cloud performance scripts
cd /path/to/ehr-management-modules/scripts/cloud/performance

# 3. Make scripts executable
chmod +x *.sh

# 4. Quick validation (5 iterations)
./cloud_latency_analysis.sh 5 create

# 5. Full latency analysis (100 iterations per operation)
./cloud_latency_analysis.sh 100 all

# 6. Throughput testing (100 iterations)
./cloud_throughput_test.sh 100 all

# 7. Parallel testing (200 iterations, 4 workers)
./cloud_parallel_test.sh 200 4 cross_org

# 8. Generate summary report
./cloud_generate_summary_report.sh
```

## Scripts

### `config.sh` — Cloud Configuration
Cloud-specific environment variables: VM IPs, paths, deployment metadata.

```bash
source config.sh
echo "Orderer: ${ORDERER_ENDPOINT}"    # → 10.0.1.4:7050
echo "Org1: ${PEER0_ORG1_ENDPOINT}"    # → 10.0.2.4:7051
echo "Org2: ${PEER0_ORG2_ENDPOINT}"    # → 10.0.3.4:9051
```

### `ehr_operations.sh` — Cloud CRUD Operations
Same functions as local, but all `peer chaincode invoke` commands include:
- `--ordererTLSHostnameOverride orderer.example.com`
- Cloud VM IP endpoints instead of localhost

### `cloud_latency_analysis.sh` — Latency Testing
```bash
# Individual operation
./cloud_latency_analysis.sh 100 create
./cloud_latency_analysis.sh 100 read
./cloud_latency_analysis.sh 100 read_cross
./cloud_latency_analysis.sh 100 update
./cloud_latency_analysis.sh 100 consent
./cloud_latency_analysis.sh 100 unauthorized

# All operations
./cloud_latency_analysis.sh 100 all
```

### `cloud_throughput_test.sh` — Throughput Testing
```bash
./cloud_throughput_test.sh 100 create
./cloud_throughput_test.sh 100 read
./cloud_throughput_test.sh 100 cross_org
./cloud_throughput_test.sh 100 all
```

### `cloud_parallel_test.sh` — Parallel Scaling
```bash
# Recommended for cloud VMs (fewer cores than local)
./cloud_parallel_test.sh 200 4 cross_org    # 4 workers
./cloud_parallel_test.sh 100 2 cross_org    # 2 workers (conservative)
./cloud_parallel_test.sh 400 8 all          # Full suite
```

### `cloud_generate_summary_report.sh` — Report Generation
```bash
# Full report (Markdown + CSV)
./cloud_generate_summary_report.sh

# Specific sections
./cloud_generate_summary_report.sh --latency-only
./cloud_generate_summary_report.sh --throughput-only
./cloud_generate_summary_report.sh --parallel-only
```

## Results Directory Structure

```
scripts/cloud/results/
├── latency_analysis/
│   ├── latency_raw_create_YYYYMMDD_HHMMSS.csv       # Raw per-transaction data
│   ├── latency_stats_create_YYYYMMDD_HHMMSS.csv      # Statistical summary
│   ├── latency_raw_read_YYYYMMDD_HHMMSS.csv
│   ├── latency_stats_read_YYYYMMDD_HHMMSS.csv
│   ├── latency_raw_read_cross_YYYYMMDD_HHMMSS.csv
│   ├── latency_stats_read_cross_YYYYMMDD_HHMMSS.csv
│   ├── latency_raw_update_YYYYMMDD_HHMMSS.csv
│   ├── latency_stats_update_YYYYMMDD_HHMMSS.csv
│   ├── latency_raw_consent_YYYYMMDD_HHMMSS.csv
│   ├── latency_stats_consent_YYYYMMDD_HHMMSS.csv
│   ├── latency_raw_unauthorized_YYYYMMDD_HHMMSS.csv
│   └── latency_stats_unauthorized_YYYYMMDD_HHMMSS.csv
├── throughput_analysis/
│   ├── throughput_test_YYYYMMDD_HHMMSS.csv
│   ├── throughput_create_YYYYMMDD_HHMMSS.csv
│   ├── throughput_read_YYYYMMDD_HHMMSS.csv
│   └── throughput_cross_org_YYYYMMDD_HHMMSS.csv
├── parallel_analysis/
│   └── parallel_YYYYMMDD_HHMMSS/
│       ├── parallel_summary_YYYYMMDD_HHMMSS.csv
│       ├── raw_data/
│       │   ├── worker_1_cross_org_YYYYMMDD_HHMMSS.csv
│       │   ├── worker_2_cross_org_YYYYMMDD_HHMMSS.csv
│       │   └── ...
│       └── analysis/
│           └── cross_org_analysis_YYYYMMDD_HHMMSS.txt
└── performance_reports/
    ├── cloud_performance_summary_YYYYMMDD_HHMMSS.md
    └── cloud_performance_summary_YYYYMMDD_HHMMSS.csv
```

## CSV Format Compatibility

Cloud scripts produce CSVs in the **exact same format** as local scripts:

### Latency Stats CSV
```csv
Metric,Value_Seconds,Value_Milliseconds
Count,100,100
Minimum,0.041234,41.234
Maximum,0.098765,98.765
Mean,0.065432,65.432
Standard_Deviation,0.012345,12.345
P50_Median,0.063210,63.210
P95,0.089012,89.012
P99,0.095678,95.678
```

### Throughput CSV
```csv
Test Type,Transaction ID,Patient ID,Start Time,End Time,Duration (seconds),Status
CREATE,1,CLOUD_CREATE_20260219_P000001,1740000000.123,1740000000.456,0.333,SUCCESS
...
SUMMARY,CREATE,100,98,30.45,3.22
```

This format compatibility enables direct local vs cloud comparison in Phase 5.

## Recommended Test Execution Order

1. **Validate** (small runs to confirm network is working):
   ```bash
   ./cloud_latency_analysis.sh 5 create
   ./cloud_throughput_test.sh 5 create
   ```

2. **Latency Analysis** (main data collection):
   ```bash
   ./cloud_latency_analysis.sh 100 all
   ```

3. **Throughput Analysis**:
   ```bash
   ./cloud_throughput_test.sh 100 all
   ```

4. **Parallel Scaling** (resource-intensive, run last):
   ```bash
   ./cloud_parallel_test.sh 100 2 cross_org
   ./cloud_parallel_test.sh 200 4 cross_org
   ```

5. **Generate Reports**:
   ```bash
   ./cloud_generate_summary_report.sh
   ```

6. **Download results** to local machine:
   ```bash
   # From local machine
   scp -r azureuser@20.88.52.252:/path/to/scripts/cloud/results/ ./scripts/cloud/results/
   ```

## Cloud-Specific Considerations

### VM Resource Constraints
- **B1ms VMs**: 1 vCPU, 2 GB RAM — parallel tests should use fewer workers (2-4)
- **Docker Swarm overhead**: Swarm management + overlay network consumes memory
- **Fabric containers**: Peer + CouchDB + chaincode container per org VM

### Network Characteristics
- **Inter-subnet latency**: ~0.5-2ms between Azure subnets (vs ~0.01ms local Docker bridge)
- **VXLAN encapsulation**: Docker Swarm overlay adds packet overhead
- **Consistent overhead**: Latency increase is consistent, maintaining comparison validity

### Cost Management
- Run all tests in a single session to minimize Azure charges
- `terraform destroy` immediately after collecting results
- Results are timestamped — download before destroying VMs

---

**Academic Project Context**: Master's Dissertation — Local vs Cloud Blockchain QoS Comparison  
**Technology Stack**: Hyperledger Fabric 2.5.10, Go, Bash, Docker Swarm, Azure VMs  
**Testing Approach**: Identical methodology across deployment environments for fair comparison
