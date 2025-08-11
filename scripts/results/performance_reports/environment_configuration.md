# Environment Configuration Documentation
**Academic Research - Master's Dissertation**  
**Generated:** 2025-08-11 09:21:55 -03

## 🖥️ System Environment

**Operating System:**
- Platform: Linux
- Kernel: 6.8.0-65-generic
- Architecture: x86_64
- Hostname: ubuntu-22

**Hardware Configuration:**
- CPU Cores: 8
- Total Memory: 15Gi
- Available Memory: 10Gi
- System Load:  0,28, 0,46, 0,47

**User Environment:**
- User: vitor
- Working Directory: /home/vitor/dev/fabric-samples/ehr-management-modules/scripts/performance
- Shell: /bin/bash
- PATH: /home/vitor/.local/bin:/home/vitor/.nvm/versions/node/v18.20.2/bin:/home/vitor/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/snap/bin:/opt/spark/bin:/opt/spark/sbin:/usr/local/go/bin:/home/vitor/.vscode/extensions/ms-python.debugpy-2025.10.0-linux-x64/bundled/scripts/noConfigScripts:/home/vitor/.config/Code/User/globalStorage/github.copilot-chat/debugCommand:/opt/spark/bin:/opt/spark/sbin:/usr/local/go/bin

## 🔗 Blockchain Configuration

**Hyperledger Fabric Network:**
- Version: v2.5.10
- Network Topology: 2 Organizations (Org1, Org2)
- Consensus Algorithm: Raft Ordering Service
- Security Features: TLS Enabled, MSP Authentication
- Chaincode: EHR Management Smart Contract v1.0

**Network Components:**
- Organizations: 2 (Org1, Org2)
- Peers per Organization: 1
- Ordering Service: Raft-based
- Certificate Authorities: 2 (CA for each org)
- Channels: 1 (mychannel)

## 📁 File Structure and Locations

**Test Scripts:**
- Location: `scripts/performance/`
- Configuration: `scripts/performance/config.sh`
- Main Scripts: 
  - `latency_analysis.sh` - End-to-end latency measurement
  - `throughput_test.sh` - Throughput benchmarking
  - `parallel_test.sh` - Parallel worker testing
  - `scaling_test.sh` - Scaling analysis (1-16 workers)
  - `generate_summary_report.sh` - Report generation

**Result Data:**
- Location: `scripts/results/`
- Latency Data: `scripts/results/latency_analysis/`
- Throughput Data: `scripts/results/throughput_analysis/`
- Parallel Data: `scripts/results/parallel_analysis/`
- Final Reports: `scripts/results/performance_reports/`

## 🔬 Test Execution Standards

**Academic Rigor:**
- Statistical Significance: Minimum 25 iterations per configuration
- Latency Analysis: P50, P95, P99 percentile characterization
- Throughput Measurement: Concurrent transaction processing evaluation
- Scaling Analysis: 1-16 worker parallel processing assessment

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

## 🚀 Execution Commands

**Individual Tests:**
```bash
# Latency Analysis (100 iterations, create operations)
./latency_analysis.sh 100 create

# Throughput Testing (400 iterations, 8 concurrent workers)
./parallel_test.sh 400 8 cross_org

# Comprehensive Scaling Analysis (800 base iterations)
./scaling_test.sh 800 cross_org

# Generate Performance Summary Report
./generate_summary_report.sh --format both
```

**Report Generation:**
```bash
# Generate comprehensive report (all tests)
./generate_summary_report.sh

# Generate specific test reports
./generate_summary_report.sh --latency-only
./generate_summary_report.sh --throughput-only  
./generate_summary_report.sh --parallel-only

# Specify output format
./generate_summary_report.sh --format md
./generate_summary_report.sh --format csv
```

---

*This documentation provides complete environment context for academic research reproducibility and peer review validation.*

