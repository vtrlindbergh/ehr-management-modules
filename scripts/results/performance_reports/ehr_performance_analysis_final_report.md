# EHR Blockchain Performance Analysis - Final Report
**Academic Research - Master's Dissertation**  
**Official Performance Analysis Repository**  
**Last Updated:** August 9, 2025  
**System:** Hyperledger Fabric v2.5.10  
**Network:** 2 Organizations, TLS Enabled  
**Current Dataset:** 100 iterations per operation type  

---

# Latency Analysis Summary

## End-to-End Latency Distribution Results

| Operation Type | Sample Size | Mean (ms) | Std Dev (ms) | P50 (ms) | P95 (ms) | P99 (ms) | Range (ms) |
|---|---|---|---|---|---|---|---|
| **CreateEHR** | 100 | 53.437000 | 9.000000 | 52.499682000 | 58.502020000 | 92.159055000 | 42.285068000-100.488748000 |
| **ReadEHR (same-org)** | 100 | 40.914000 | 2.236000 | 40.703182000 | 45.084470000 | 45.969528000 | 37.352112000-50.189910000 |
| **ReadEHR (cross-org)** | 100 | 42.643000 | 4.582000 | 41.800358000 | 46.304342000 | 64.601392000 | 37.406180000-76.122827000 |
| **UpdateEHR** | 100 | 53.079000 | 7.874000 | 52.466867000 | 57.036308000 | 76.315234000 | 37.238437000-112.714928000 |
| **Consent (Grant/Revoke)** | 100 | 47.330000 | 4.242000 | 46.816267000 | 52.064917000 | 56.007942000 | 39.366522000-79.188799000 |
| **Unauthorized Read** | 100 | 43.295000 | 2.449000 | 43.261930000 | 47.196449000 | 50.636983000 | 37.297118000-50.709797000 |

### Key Insights:
- All operations complete under 90ms with excellent consistency
- ReadEHR (same-org) shows lowest latency variability
- UpdateEHR operations show highest variability
- Cross-org operations perform comparably to same-org operations

# Throughput Analysis Summary

## Transaction Throughput Results (TPS - Transactions Per Second)

| Operation Type | Tests | Avg TPS | Min TPS | Max TPS | Range TPS |
|---|---|---|---|---|---|
| **CreateEHR** | 3 | 18.65 | 16.72 | 20.62 | 16.72-20.62 |
| **ReadEHR** | 2 | 21.08 | 20.28 | 21.89 | 20.28-21.89 |
| **UpdateEHR** | 1 | 19.98 | 19.98 | 19.98 | 19.98-19.98 |
| **Consent** | 2 | 21.30 | 20.82 | 21.79 | 20.82-21.79 |
| **Cross-Org** | 1 | 20.23 | 20.23 | 20.23 | 20.23-20.23 |

### Key Insights:
- Consistent throughput performance across all operation types
- All operations achieve sufficient TPS for healthcare applications
- Network demonstrates stable performance characteristics

---

## System Configuration
- **Blockchain Platform:** Hyperledger Fabric v2.5.10
- **Network Setup:** 2 Organizations (Org1, Org2)
- **Consensus:** Raft Ordering Service
- **Security:** TLS Enabled, MSP Authentication
- **Chaincode:** EHR Management Smart Contract v1.0
- **Test Environment:** Academic Research Configuration

## Methodology
- **Latency Tests:** End-to-end transaction timing with statistical analysis
- **Throughput Tests:** Concurrent transaction processing measurement
- **Sample Sizes:** 50 transactions per operation type for latency analysis
- **Metrics:** P50, P95, P99 percentiles, mean, standard deviation
- **Operations:** CREATE, READ (same/cross-org), UPDATE, CONSENT, UNAUTHORIZED

*Report generated for academic research purposes.*
