# EHR Management Performance Testing

This directory contains comprehensive performance testing scripts for the EHR Management System with enhanced cross-organizational authorization.

## Updated Scripts with Authorization Logic

All performance tests have been updated to work with our enhanced authorization model:
- **Creator Authorization**: Organizations can access EHRs they create
- **Consent-based Authorization**: Cross-organizational access with patient consent

## 🎯 NEW: Comprehensive Latency Analysis Framework

**Academic-Quality End-to-End Latency Analysis** for dissertation research with robust statistical analysis across all EHR operations.

### Quick Start: Complete Analysis

```bash
# Run comprehensive latency analysis (all operations, n=50 samples each)
./latency_analysis.sh

# Generate automated summary report
./generate_summary_report.sh
```

### Latency Analysis Results (Latest)

| Operation Type | Mean (ms) | P50 (ms) | P95 (ms) | P99 (ms) | Sample Size |
|---------------|-----------|----------|----------|----------|-------------|
| **CreateEHR** | 47.52 | 46.01 | 56.66 | 60.78 | 50 |
| **ReadEHR (same-org)** | 45.22 | 43.80 | 53.95 | 57.89 | 50 |
| **ReadEHR (cross-org)** | 49.01 | 47.32 | 58.12 | 62.45 | 50 |
| **UpdateEHR** | 50.81 | 49.15 | 60.23 | 65.12 | 50 |
| **GrantConsent** | 48.40 | 46.89 | 57.89 | 61.23 | 50 |
| **RevokeConsent** | 48.35 | 47.01 | 58.45 | 62.11 | 50 |
| **Unauthorized Access** | 44.60 | 43.21 | 52.89 | 56.78 | 50 |

### Statistical Analysis Features

- **Percentile Distribution**: P50 (median), P95, P99 for latency distribution analysis
- **Robust Sample Sizes**: n=50 samples per operation type for statistical significance
- **End-to-End Measurement**: Complete chaincode invocation timing including network latency
- **Operation Coverage**: All 7 EHR operation types including unauthorized access scenarios
- **Cross-Organizational Validation**: Separate analysis for same-org vs cross-org operations
- **Automated Reporting**: CSV and Markdown outputs for academic publication

### Latency Analysis Scripts

#### `latency_analysis.sh` - Core Analysis Framework
```bash
# Full comprehensive analysis (recommended)
./latency_analysis.sh

# Individual operation analysis
./latency_analysis.sh create     # CreateEHR latency
./latency_analysis.sh read       # ReadEHR same-org latency  
./latency_analysis.sh read_cross # ReadEHR cross-org latency
./latency_analysis.sh update     # UpdateEHR latency
./latency_analysis.sh consent    # GrantConsent latency
./latency_analysis.sh revoke     # RevokeConsent latency
./latency_analysis.sh unauthorized # Unauthorized access latency
```

**Key Features:**
- **Precision Timing**: Nanosecond-precision measurement using `date +%s.%N`
- **Statistical Analysis**: Automatic calculation of mean, median, P95, P99, standard deviation
- **CSV Output**: Machine-readable results in `../results/latency_analysis/`
- **Operation Isolation**: Each test uses unique patient IDs to avoid conflicts
- **Authorization Validation**: Tests both successful and unauthorized access scenarios

#### `generate_summary_report.sh` - Automated Reporting
```bash
# Generate summary report from latest test results
./generate_summary_report.sh

# Output formats:
# - CSV: ../results/performance_summary_YYYYMMDD_HHMMSS.csv
# - Markdown: ../results/performance_summary_YYYYMMDD_HHMMSS.md
```

**Report Features:**
- **Latest Data Selection**: Automatically finds most recent test results by timestamp
- **Multi-Format Output**: Both CSV (for analysis) and Markdown (for documentation)
- **Data Accuracy Verification**: Exact pattern matching ensures correct file selection
- **Academic Quality**: Formatted for dissertation/research publication

### Technical Implementation

#### Latency Measurement Methodology
```bash
# Precision timing implementation
start_time=$(date +%s.%N)
peer chaincode invoke [operation]
end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc)
```

#### Statistical Analysis Functions
```bash
calculate_percentile() {
    local data=("$@")
    local percentile=$1
    # Advanced percentile calculation with interpolation
    # Returns exact percentile values for distribution analysis
}

calculate_stats() {
    # Calculates: mean, median, P95, P99, standard deviation
    # Outputs both human-readable and CSV formats
}
```

#### Cross-Organizational Test Design
- **Same-Org Operations**: Org1 creates and accesses own EHRs (creator authorization)
- **Cross-Org Operations**: Org1 creates, grants consent, Org2 accesses (consent-based authorization)
- **Unauthorized Tests**: Org2 attempts access without consent (security validation)

### File Structure: Latency Analysis
```
scripts/performance/
├── latency_analysis.sh          # Core latency analysis framework
├── generate_summary_report.sh   # Automated report generation
├── ehr_operations.sh           # EHR operation utility functions
└── config.sh                  # Environment configuration

scripts/results/
├── latency_analysis/           # Raw latency test data
│   ├── latency_stats_create_YYYYMMDD_HHMMSS.csv
│   ├── latency_stats_read_YYYYMMDD_HHMMSS.csv
│   ├── latency_stats_read_cross_YYYYMMDD_HHMMSS.csv
│   ├── latency_stats_update_YYYYMMDD_HHMMSS.csv
│   ├── latency_stats_consent_YYYYMMDD_HHMMSS.csv
│   ├── latency_stats_revoke_YYYYMMDD_HHMMSS.csv
│   └── latency_stats_unauthorized_YYYYMMDD_HHMMSS.csv
├── throughput_analysis/        # Raw throughput test data
│   └── throughput_test_YYYYMMDD_HHMMSS.csv
├── performance_reports/        # Organized summary reports
│   ├── performance_summary_YYYYMMDD_HHMMSS.csv    # Machine-readable
│   └── performance_summary_YYYYMMDD_HHMMSS.md     # Human-readable
└── parallel_YYYYMMDD_HHMMSS/   # Parallel test results
```

### Data Accuracy Guarantees

The automated reporting system provides **verified data accuracy**:

1. **Exact Pattern Matching**: Uses `latency_stats_${operation}_[0-9]*.csv` to avoid file conflicts
2. **Latest File Selection**: `sort | tail -1` ensures most recent timestamp
3. **Precise CSV Parsing**: Uses `grep "^Mean,"` with exact field extraction  
4. **Error Handling**: Returns "N/A" if files don't exist
5. **No Data Manipulation**: All values are direct passthrough from generated CSV files
6. **Consistent Results**: Same values every time, no arbitrary selection

**Verification Example:**
```bash
# Manual verification
ls ../results/latency_analysis/latency_stats_read_*.csv | sort | tail -1
# ../results/latency_analysis/latency_stats_read_20250809_180246.csv

# Extracted mean matches exactly
grep "^Mean," ../results/latency_analysis/latency_stats_read_20250809_180246.csv
# Mean,45.216000
```

### Academic Research Applications

This framework is designed for **Master's dissertation research** and provides:

- **Statistical Rigor**: Large sample sizes (n=50) with comprehensive percentile analysis
- **Reproducible Results**: Standardized methodology with exact timing measurements
- **Publication-Ready Data**: CSV and Markdown formats for academic papers
- **Cross-Organizational Analysis**: Separate metrics for same-org vs cross-org operations
- **Security Validation**: Latency analysis includes unauthorized access scenarios
- **Automated Processing**: Eliminates manual data collection errors

## Available Test Types

### Individual Operation Tests
- `create` - Test EHR creation throughput (Org1 creates EHRs)
- `read` - Test EHR read throughput (Org1 reads own EHRs)
- `update` - Test EHR update throughput (Org1 updates own EHRs)
- `delete` - Test EHR deletion throughput (Org1 deletes own EHRs)
- `consent` - Test consent granting throughput (Org1 grants consent to Org2)

### Cross-Organizational Tests
- `cross_org` - Test cross-organizational access (Org1 creates, Org2 reads with consent)
- `full_cycle` - Complete CRUD cycle testing (CREATE→CONSENT→READ→UPDATE per patient)
- `all` - Run all test types separately with dedicated iterations each

### Test Type Comparison: `all` vs `full_cycle`

| Aspect | `full_cycle` | `all` |
|--------|-------------|-------|
| **Approach** | Integrated workflow per patient | Separate operation testing |
| **Iterations** | 100 complete workflows | 100 iterations per operation type |
| **Operations** | CREATE→CONSENT→READ→UPDATE | 6 separate tests (CREATE, READ, UPDATE, etc.) |
| **Use Case** | End-to-end workflow validation | Individual operation analysis |
| **Academic Value** | Workflow performance | Operation-specific metrics |
| **Output** | ~5-6 cycles/sec | Separate latency/TPS per operation |

## Performance Results Summary

Recent test results with enhanced authorization:

| Test Type | Typical TPS | Description |
|-----------|-------------|-------------|
| CREATE | ~18-19 TPS | EHR creation with creator tracking |
| READ | ~20 TPS | Same-org EHR access (creator authorization) |
| UPDATE | ~17-18 TPS | Same-org EHR updates |
| DELETE | ~20 TPS | Same-org EHR deletion |
| CONSENT | ~18-19 TPS | Consent granting for cross-org access |
| CROSS_ORG | ~15-19 TPS | **Cross-organizational EHR access** |
| FULL_CYCLE | ~5-6 cycles/sec | Complete workflow including all operations |

## Parallel Performance Testing

**NEW**: Multi-core parallel testing capabilities for stress testing and scalability validation.

### Parallel Performance Results

| Configuration | Total TPS | Performance Gain | Workers |
|---------------|-----------|------------------|---------|
| **Single-threaded** | ~19 TPS | Baseline | 1 |
| **4 parallel workers** | 55.28 TPS | **2.9x improvement** | 4 |
| **8 parallel workers** | 68.40 TPS | **3.6x improvement** | 8 |

### Parallel Test Types
- `parallel_throughput_test.sh` - Multi-worker parallel testing
- `demo_parallel_performance.sh` - Comprehensive parallel testing demo

### Usage Examples
```bash
# 8-core stress test with cross-org operations
./parallel_throughput_test.sh 400 8 cross_org

# 4-worker parallel test
./parallel_throughput_test.sh 200 4 cross_org

# Run comprehensive parallel demo
./demo_parallel_performance.sh
```

### Key Benefits
- **Scalability Validation**: Tests real multi-org concurrent access
- **System Stress Testing**: Validates performance under parallel load  
- **Resource Utilization**: Effectively uses multi-core systems
- **Healthcare Realism**: Simulates multiple hospitals accessing data simultaneously

### Scaling Analysis
- **Linear scaling up to 4 workers**: Nearly 3x improvement
- **Diminishing returns beyond 4 workers**: Still significant gains but efficiency decreases
- **All transactions successful**: 100% success rate even under high parallel load
- **Authorization maintained**: Every transaction validates cross-org consent

## Cross-Organizational Test Details

The `cross_org` test is specifically designed to measure the performance of **real healthcare data sharing scenarios** between organizations. This test validates our enhanced authorization model with actual cross-organizational workflows.

### Test Architecture

The test simulates this realistic healthcare scenario:
- **Hospital A (Org1)**: Creates patient EHR records and owns the data
- **Hospital B (Org2)**: Needs to access Hospital A's patient data with consent
- **Patient Consent**: Required bridge for Hospital B to access Hospital A's records

### Phase 1: Setup (One-time Initialization)

```bash
# 1. Switch to Org1 environment (Hospital A)
setup_org1_env

# 2. Create 10 test EHR records
for i in $(seq 1 10); do
    patient_id="TEST_P000001" to "TEST_P000010"
    create_ehr "${patient_id}" "Cross-Org Patient ${i}"  # createdBy = "Org1MSP"
    
    # 3. Grant consent to Org2 (Hospital B)
    grant_consent "${patient_id}" "[\"Org2MSP\"]"
done
```

**What happens in setup:**
- Org1 creates 10 EHR records (becomes the "creator" with `createdBy = "Org1MSP"`)
- Org1 grants consent for each patient to "Org2MSP" 
- This simulates Hospital A creating patient records and obtaining patient consent for Hospital B

### Phase 2: Performance Testing Iterations

```bash
for i in $(seq 1 $iterations); do
    # 4. Calculate which patient to use (cycles through 10 patients)
    patient_index=$(( (i - 1) % 10 + 1 ))  # Cycles: 1,2,3...10,1,2,3...
    patient_id="TEST_P$(printf "%06d" $patient_index)"
    
    # 5. Switch to Org2 environment (Hospital B)
    setup_org2_env
    
    # 6. Attempt cross-org read of Org1's EHR record
    duration=$(read_ehr "${patient_id}")  # Tests consent-based authorization
done
```

### Authorization Flow Per Iteration

Each iteration tests the **complete cross-organizational authorization flow**:

1. **Context Switch**: Script switches from Org1 to Org2 environment (MSP identity change)
2. **Authorization Check**: Smart contract validates:
   - Is Org2 the creator? → **NO** (Org1 created it, `createdBy = "Org1MSP"`)
   - Does Org2 have consent? → **YES** (consent was granted: `authorizedUsers: ["Org2MSP"]`)
3. **Access Granted**: Org2 successfully reads Org1's EHR data via consent-based authorization
4. **Performance Measurement**: Duration of cross-org operation recorded

### Patient Cycling Mechanism

**Iteration Examples (25 iterations):**
```
Iteration 1:  Patient TEST_P000001 (1-1)%10+1 = 1
Iteration 2:  Patient TEST_P000002 (2-1)%10+1 = 2
...
Iteration 10: Patient TEST_P000010 (10-1)%10+1 = 10
Iteration 11: Patient TEST_P000001 (11-1)%10+1 = 1  ← cycles back
Iteration 12: Patient TEST_P000002 (12-1)%10+1 = 2
...
Iteration 25: Patient TEST_P000005 (25-1)%10+1 = 5
```

**Benefits of Cycling:**
- **Realistic Workload**: Simulates Hospital B accessing multiple Hospital A patients
- **Performance Focus**: Setup is done once; testing focuses on pure cross-org read performance
- **Authorization Validation**: Every iteration validates the consent-based access path
- **Scalability Testing**: Tests cross-org security at scale

### Real Healthcare Mapping

This maps to real healthcare scenarios:
```
Day 1: Hospital A creates patient records + obtains consent for Hospital B
Day 2-N: Hospital B accesses those records multiple times
         (consultations, follow-ups, specialist referrals, etc.)
```

The test measures the "Day 2-N" operations - the actual cross-organizational data sharing that occurs in healthcare networks.

### Sample Cross-Org Output

```csv
Test Type,Transaction ID,Patient ID,Operation,Start Time,End Time,Duration (seconds),Status
CROSS_ORG,1,TEST_P000001,READ,1754683575.515644421,1754683575.560657433,.041157494,SUCCESS
CROSS_ORG,2,TEST_P000002,READ,1754683575.562075451,1754683575.614553847,.048226725,SUCCESS
CROSS_ORG,11,TEST_P000001,READ,1754683575.662075451,1754683575.714553847,.052478396,SUCCESS
```

Notice patient TEST_P000001 appears in iterations 1 and 11, demonstrating the cycling behavior.

**Key Insight**: This design provides realistic performance metrics for **actual healthcare interoperability scenarios** rather than just infrastructure testing.

## Enhanced Authorization Model

The performance tests validate our dual authorization model that supports both same-org and cross-org access:

### Authorization Paths

**Path 1: Creator Authorization (Same-Org Access)**
```
Org1 creates EHR → createdBy = "Org1MSP" → Org1 can access automatically
```
- No additional consent needed
- Fast access for the creating organization
- Tested by: `create`, `read`, `update`, `delete` test types

**Path 2: Consent-Based Authorization (Cross-Org Access)**
```
Org1 creates EHR → Patient grants consent to Org2 → Org2 can access with consent
```
- Requires explicit patient consent
- Enables healthcare interoperability
- Tested by: `cross_org`, `consent` test types

### Smart Contract Authorization Logic

```go
func IsProviderAuthorized(clientMSP string, ehr *EHR, consentRecords []Consent) bool {
    // Path 1: Check if client is the creator
    if ehr.CreatedBy == clientMSP {
        return true  // Creator authorization
    }
    
    // Path 2: Check consent records
    for _, consent := range consentRecords {
        if consent.PatientID == ehr.PatientID {
            for _, authorizedUser := range consent.AuthorizedUsers {
                if authorizedUser == clientMSP {
                    return true  // Consent-based authorization
                }
            }
        }
    }
    return false
}
```

### Performance Test Validation

- **Same-Org Tests**: Validate creator authorization path performance
- **Cross-Org Tests**: Validate consent-based authorization path performance
- **Security**: Every access attempt goes through proper authorization checks
- **Scalability**: Authorization logic performs well under load (15-20 TPS)

## Usage

### Basic Throughput Test
```bash
cd scripts/performance
./throughput_test.sh [iterations] [test_type]
```

### Examples

**Test EHR Creation (100 iterations):**
```bash
./throughput_test.sh 100 create
```

**Test Full CRUD Cycle (50 iterations):**
```bash
./throughput_test.sh 50 full_cycle
```

**Test Read Operations (200 iterations):**
```bash
./throughput_test.sh 200 read
```

### Test Types

- `create`: Test EHR creation throughput
- `read`: Test EHR read throughput (with consent validation)
- `update`: Test EHR update throughput
- `delete`: Test EHR deletion throughput
- `consent`: Test consent granting throughput
- `full_cycle`: Test complete CRUD cycle (Create → Grant Consent → Read → Update)

## Output

### Results Directory (`../results/`)
- CSV files with timestamp: `throughput_test_YYYYMMDD_HHMMSS.csv`
- Contains per-transaction and summary metrics
- Columns: Test Type, Transaction ID, Patient ID, Start Time, End Time, Duration, Status

### Sample CSV Output
```csv
Test Type,Transaction ID,Patient ID,Start Time,End Time,Duration (seconds),Status
CREATE,1,TEST_P000001,1704067200.123,1704067200.456,0.333,SUCCESS
CREATE,2,TEST_P000002,1704067200.500,1704067200.789,0.289,SUCCESS
SUMMARY,CREATE,100,98,30.45,3.22
```

### Logs Directory (`../logs/`)
- Detailed execution logs
- Error reporting and debugging information

## Academic Context

This testing framework is designed to validate the scalability claims of the EHR management architecture:

1. **Interoperability**: Uses HL7 FHIR-compliant JSON structures
2. **Scalability**: Measures throughput under increasing load
3. **Performance**: Tracks latency for different operations
4. **Reliability**: Records success/failure rates

## Data Format

### FHIR Compliance
The system generates HL7 FHIR-compliant Observation resources for blood pressure readings:

```json
{
  "resourceType": "Observation",
  "id": "bp-reading-P001",
  "status": "final",
  "category": [{"coding": [{"system": "http://terminology.hl7.org/CodeSystem/observation-category", "code": "vital-signs"}]}],
  "code": {"coding": [{"system": "http://loinc.org", "code": "85354-9", "display": "Blood pressure panel"}]},
  "subject": {"reference": "Patient/P001"},
  "effectiveDateTime": "2025-01-01T12:00:00Z",
  "component": [
    {"code": {"coding": [{"system": "http://loinc.org", "code": "8480-6"}]}, "valueQuantity": {"value": 120, "unit": "mmHg"}},
    {"code": {"coding": [{"system": "http://loinc.org", "code": "8462-4"}]}, "valueQuantity": {"value": 80, "unit": "mmHg"}}
  ]
}
```

## Troubleshooting

### Common Issues

1. **Network Not Running**:
   ```
   ERROR: Test network may not be running
   Solution: Start the test network as described in Setup
   ```

2. **Permission Denied**:
   ```
   bash: ./throughput_test.sh: Permission denied
   Solution: chmod +x scripts/performance/*.sh
   ```

3. **Environment Variables Not Set**:
   ```
   ERROR: Cannot access test network directory
   Solution: Verify TEST_NETWORK_PATH in config.sh
   ```

### Debugging
- Check network logs: `docker logs peer0.org1.example.com`
- Verify chaincode deployment: `peer chaincode query -C mychannel -n ehrCC -c '{"Args":["GetAllEHRs"]}'`
- Test manual operations following the validation steps in project documentation

## Future Enhancements

- Concurrent client testing (multiple Fabric identities)
- Latency distribution analysis
- Memory and CPU usage monitoring
- Integration with CouchDB state database
- FHIR resource validation with external tools

---

**Academic Project Context**: Master's Dissertation on Blockchain-based EHR Management  
**Technology Stack**: Hyperledger Fabric, Go, Bash, HL7 FHIR  
**Testing Approach**: Academic benchmarking for scalability validation
