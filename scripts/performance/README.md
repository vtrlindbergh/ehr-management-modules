# EHR Management Performance Testing

This directory contains performance testing scripts for the EHR Management smart contract system, developed as part of a master's dissertation on blockchain-based healthcare data management.

## Overview

The testing framework provides automated throughput and latency measurements for EHR operations using Hyperledger Fabric. It follows academic best practices with clean, modular code and comprehensive logging.

## Prerequisites

1. **Hyperledger Fabric Test Network**: Must be running with the EHR chaincode deployed
2. **Required Tools**: 
   - `peer` CLI tool (Fabric binaries)
   - `bc` calculator for floating-point arithmetic
   - Standard Unix tools (curl, date, etc.)

## Setup

1. **Start the Fabric Test Network** (from test-network directory):
   ```bash
   cd ../../test-network
   ./network.sh up createChannel -ca
   ./network.sh deployCC -ccn ehrCC -ccp ../ehr-management-modules -ccl go -ccv 1.0
   ```

2. **Verify Network Status**:
   ```bash
   # The scripts will automatically check network status
   # Manual verification:
   curl -s http://localhost:7050  # Should connect to orderer
   ```

## Scripts

### Configuration (`config.sh`)
- Central configuration for all performance tests
- Network endpoints, paths, and test parameters
- Utility functions for colored output and environment setup

### EHR Operations (`ehr_operations.sh`)
- Core functions for EHR CRUD operations
- FHIR-compliant data generation
- Latency measurement for each operation
- Error handling and status reporting

### Throughput Testing (`throughput_test.sh`)
- Main throughput testing script
- Supports multiple test types: create, read, update, delete, full_cycle
- Generates CSV results with detailed metrics
- Automated TPS (Transactions Per Second) calculation

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
