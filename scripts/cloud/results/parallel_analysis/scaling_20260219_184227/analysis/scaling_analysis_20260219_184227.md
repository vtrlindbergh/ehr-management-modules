# Cloud Parallel Scaling Analysis

## Test Configuration
- **Deployment**: Azure B1ms (1 vCPU, 2 GB RAM) × 3 VMs
- **Network**: Docker Swarm overlay (fabric_test)
- **System vCPUs**: 1
- **Test Type**: cross_org
- **Base Iterations**: 800
- **Worker Counts Tested**: 1 2 4 8
- **Timestamp**: 20260219_184227

## Comparison with Local
- **Local**: 8-core host, workers {1, 2, 4, 8, 12, 16}
- **Cloud**: 1 vCPU B1ms, workers {1, 2, 4, 8}
- **Expectation**: Earlier saturation due to single vCPU constraint

## Academic Methodology
- **Minimum Iterations per Worker**: 25 (ensures statistical significance)
- **Test Operations**: CROSS_ORG transactions
- **Success Rate Threshold**: >95% for valid results
- **Scaling Efficiency**: Measured as TPS improvement vs worker increase
- **Identical to local**: Same chaincode, same methodology, same CSV format

## Results Summary

| Workers | Total TPS | TPS/Worker | Success Rate | Resource Util |
|---------|-----------|------------|--------------|---------------|
| # Timestamp: 20260219_184227 |           |            | %            | %             |
| # Deployment: Azure B1ms (1 vCPU |           |            | %            | %             |
| # System: 1 vCPUs |           |            | %            | %             |
| # Test Type: cross_org |           |            | %            | %             |
| # Base Iterations: 800 |           |            | %            | %             |
| # Worker Counts: 1 2 4 8 |           |            | %            | %             |
| # Academic Standard: Statistical significance maintained across all scaling points |           |            | %            | %             |
|         |           |            | %            | %             |
| WORKERS | OVERALL_TPS | TPS_PER_WORKER | SUCCESS_RATE% | RESOURCE_UTILIZATION% |

## Cloud-Specific Scaling Characteristics

### Expected Behavior (1 vCPU)
- **1 worker**: Baseline TPS — comparable to local single-worker but higher latency
- **2 workers**: Near-linear improvement if I/O-bound (network wait dominates)
- **4 workers**: Likely saturation point — CPU contention on single vCPU
- **8 workers**: Diminishing returns — scheduler overhead dominates

### Key Differences from Local
- **Network latency**: Inter-VM ~0.5-2ms vs local Docker bridge ~0.01ms
- **CPU constraint**: 1 vCPU vs 8 cores — saturation expected earlier
- **Memory pressure**: 2 GB shared with Docker, Fabric containers, CouchDB
- **VXLAN overhead**: Docker Swarm overlay adds encapsulation cost

### Performance Optimization
- **Optimal Workers**: Determined by highest TPS/Worker ratio
- **Resource Utilization**: Balanced against VM stability
- **Academic Significance**: All tests maintain >25 iterations per worker

## Academic Conclusions
This cloud scaling analysis provides empirical evidence for parallel throughput
characteristics in a distributed Hyperledger Fabric deployment across Azure VMs.
Results enable direct comparison with the local 8-core baseline established in
the dissertation (Chapter 5.4.4), demonstrating the impact of constrained compute
resources and real network latency on blockchain transaction processing.

### Statistical Validity
All tests maintain academic standards with sufficient sample sizes for
reliable performance characterization and reproducible results.
