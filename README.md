# EHR Management System on Hyperledger Fabric

A blockchain-based Electronic Health Record (EHR) management system built on Hyperledger Fabric. This chaincode application enables secure sharing and management of patient health records while maintaining consent controls across multiple healthcare organizations.

## Overview

This project implements a production-ready chaincode solution for managing Electronic Health Records on the Hyperledger Fabric blockchain platform. The system provides secure methods for healthcare providers to access patient data with proper authorization, featuring cross-organizational consent management and comprehensive performance testing capabilities.

**Key Academic Features:**
- **Cross-organizational data sharing** with consent-based authorization
- **FHIR-compliant** data structures for healthcare interoperability  
- **Comprehensive performance testing** framework for academic research
- **Statistical analysis tools** for latency and throughput evaluation

## Features

- **EHR Management**: Create, read, update, and delete electronic health records
- **Cross-Organizational Consent**: Patient-controlled access across healthcare organizations
- **Dual Authorization Model**: Creator-based and consent-based access patterns
- **Identity Management**: MSP-based authentication and certificate validation
- **Performance Testing**: Academic-grade testing framework with statistical analysis
- **FHIR Compliance**: Standard healthcare data interchange format support

## Project Structure

```
ehr-management-modules/
├── ehrManagement.go              # Main chaincode entry point
├── chaincode/                    # Core smart contract implementation
│   ├── smartcontract.go         # Main contract facade
│   ├── models/                  # Data models (EHR, Consent, FHIR)
│   ├── services/                # Business logic services
│   │   ├── ehr_service.go       # EHR CRUD operations
│   │   ├── consent_service.go   # Consent management
│   │   └── auth/                # Authentication services
│   ├── utils/                   # Helper utilities
│   └── mocks/                   # Test mocks for unit testing
├── scripts/                     # Performance testing framework
│   ├── setup/                   # Network setup and testing scripts
│   └── performance/             # Academic performance analysis tools
└── vendor/                      # Go module dependencies
```

## Getting Started

### Prerequisites

**System Requirements:**
- **Operating System**: Linux (Ubuntu 20.04+ recommended) or macOS
- **Go**: Version 1.19+ ([Download](https://golang.org/dl/))
- **Docker**: Version 20.10+ ([Installation Guide](https://docs.docker.com/get-docker/))
- **Docker Compose**: Version 2.0+ (included with Docker Desktop)
- **Git**: For repository management
- **curl**: For downloading Hyperledger Fabric binaries

**Hardware Requirements (Minimum):**
- **CPU**: 4 cores (8 cores recommended for performance testing)
- **Memory**: 8 GB RAM (16 GB recommended)
- **Storage**: 20 GB free disk space
- **Network**: Stable internet connection for Docker image downloads

### Step 1: Hyperledger Fabric Test Network Setup

This project requires the Hyperledger Fabric test network. Follow these steps for a complete reproducible setup:

#### 1.1 Download Fabric Samples and Binaries

```bash
# Create workspace directory
mkdir -p ~/fabric-workspace
cd ~/fabric-workspace

# Download Fabric samples, binaries, and Docker images
curl -sSLO https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh && chmod +x install-fabric.sh
./install-fabric.sh docker samples binary

# Verify installation
cd fabric-samples
./bin/fabric-ca-client version
./bin/peer version
```

#### 1.2 Set Environment Variables

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
# Hyperledger Fabric Environment
export FABRIC_HOME=~/fabric-workspace/fabric-samples
export PATH=$FABRIC_HOME/bin:$PATH
export FABRIC_CFG_PATH=$FABRIC_HOME/config
```

Reload your shell:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

#### 1.3 Start the Test Network

```bash
cd $FABRIC_HOME/test-network

# Clean any existing network
./network.sh down

# Start the network with Certificate Authorities
./network.sh up createChannel -ca -c mychannel

# Verify network is running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Expected Output:**
```
NAMES                          STATUS          PORTS
peer0.org2.example.com        Up 30 seconds   0.0.0.0:9051->9051/tcp, :::9051->9051/tcp, 7051/tcp
peer0.org1.example.com        Up 30 seconds   0.0.0.0:7051->7051/tcp, :::7051->7051/tcp
orderer.example.com           Up 30 seconds   0.0.0.0:7050->7050/tcp, :::7050->7050/tcp
ca_org2                       Up 30 seconds   0.0.0.0:8054->7054/tcp, :::8054->7054/tcp
ca_org1                       Up 30 seconds   0.0.0.0:7054->7054/tcp, :::7054->7054/tcp
```

### Step 2: EHR Chaincode Installation

#### 2.1 Clone and Setup Project

```bash
# Navigate to chaincode directory in fabric-samples
cd $FABRIC_HOME/chaincode

# Clone the EHR management project
git clone https://github.com/vtrlindbergh/ehr-management-modules.git
cd ehr-management-modules

# Install Go dependencies
go mod download
go mod tidy

# Verify build
go build -v ./...
```

#### 2.2 Deploy Chaincode to Test Network

```bash
# Return to test network directory
cd $FABRIC_HOME/test-network

# Set chaincode path
export CC_SRC_PATH=../chaincode/ehr-management-modules

# Package the chaincode
./network.sh deployCC -ccn ehrmanagement -ccp $CC_SRC_PATH -ccl go

# Verify deployment
peer chaincode query -C mychannel -n ehrmanagement -c '{"function":"ReadEHR","Args":["test"]}'
```

**Expected Response:**
```json
Error: EHR with ID test does not exist
```
This error confirms the chaincode is deployed and responding correctly.

### Step 3: Environment Configuration

#### 3.1 Set Fabric Environment Variables

```bash
# Set environment for Org1
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=$FABRIC_HOME/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$FABRIC_HOME/test-network/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
```

#### 3.2 Test Basic Functionality

```bash
# Test EHR creation (should succeed)
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile $FABRIC_HOME/test-network/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C mychannel -n ehrmanagement --peerAddresses localhost:7051 --tlsRootCertFiles $FABRIC_HOME/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses localhost:9051 --tlsRootCertFiles $FABRIC_HOME/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"function":"CreateEHR","Args":["patient001","John Doe","{\"resourceType\":\"Patient\",\"id\":\"patient001\",\"name\":[{\"given\":[\"John\"],\"family\":\"Doe\"}]}"]}'

# Test EHR reading (should succeed for creator)
peer chaincode query -C mychannel -n ehrmanagement -c '{"function":"ReadEHR","Args":["patient001"]}'
```

### Installation

### Step 4: Performance Testing Setup

The project includes comprehensive performance testing tools for academic research:

```bash
# Navigate to the cloned EHR project
cd $FABRIC_HOME/chaincode/ehr-management-modules

# Make performance scripts executable
chmod +x scripts/setup/*.sh
chmod +x scripts/performance/*.sh

# Run network setup validation
./scripts/setup/test_crud_operations.sh

# Run comprehensive performance tests (500 iterations each)
cd scripts/performance
./latency_analysis.sh 500
./throughput_test.sh 500 8 create
./scaling_test.sh 500 cross_org

# Generate academic-quality performance report
./generate_summary_report.sh
```

For detailed performance testing documentation, see [`scripts/performance/README.md`](scripts/performance/README.md).

## Reproducibility Guidelines

### Environment Consistency

1. **Docker Image Versions**: The project uses specific Fabric Docker image versions for consistency:
   ```bash
   # Verify Docker images
   docker images hyperledger/fabric-*
   ```

2. **Go Module Dependencies**: All dependencies are pinned in `go.mod`:
   ```bash
   # Verify dependencies
   go mod verify
   go list -m all
   ```

3. **Network Configuration**: Test network uses fixed ports and configurations:
   - Org1 Peer: `localhost:7051`
   - Org2 Peer: `localhost:9051`  
   - Orderer: `localhost:7050`
   - Org1 CA: `localhost:7054`
   - Org2 CA: `localhost:8054`

### Testing Reproducibility

1. **Clean Environment**: Always start with a clean network:
   ```bash
   cd $FABRIC_HOME/test-network
   ./network.sh down
   docker system prune -f
   ./network.sh up createChannel -ca -c mychannel
   ```

2. **Deterministic Test Data**: Performance tests use seeded random generation:
   ```bash
   # Set random seed for reproducible test data
   export EHR_TEST_SEED=12345
   ```

3. **Performance Test Consistency**: 
   - Always run tests with the same iteration counts
   - Use consistent hardware configurations
   - Document system specifications in test reports

### Deployment Verification

Run the complete verification suite to ensure proper setup:

```bash
# Navigate to setup scripts
cd $FABRIC_HOME/chaincode/ehr-management-modules/scripts/setup

# Run comprehensive network and chaincode validation
./test_crud_operations.sh
./test_cross_org_workflow.sh

# Expected output: All tests should pass with "✅ SUCCESS" indicators
```

## Testing

The project includes comprehensive testing at multiple levels:

### Unit Testing

```bash
# Run all unit tests with coverage
go test ./chaincode/... -v -cover

# Generate detailed coverage report
go test ./chaincode/... -coverprofile=coverage.out
go tool cover -html=coverage.out -o coverage.html
```

### Integration Testing

```bash
# Validate CRUD operations
./scripts/setup/test_crud_operations.sh

# Test cross-organizational workflows
./scripts/setup/test_cross_org_workflow.sh
```

### Performance Testing

```bash
# Academic-grade performance analysis
cd scripts/performance

# Comprehensive latency analysis (500 samples per operation)
./latency_analysis.sh 500

# Throughput testing across all operations
./throughput_test.sh 500 8 create
./throughput_test.sh 500 8 read  
./throughput_test.sh 500 8 update
./throughput_test.sh 500 8 cross_org

# Parallel scaling analysis (1-16 workers)
./scaling_test.sh 500 cross_org

# Generate academic research report
./generate_summary_report.sh
```

**Expected Performance Baselines** (2-org network, TLS enabled):
- **Latency**: 65-87ms mean, <175ms P99
- **Throughput**: 10-13 TPS per operation
- **Scaling**: Linear efficiency up to 4 workers, plateau at 8+ workers

For detailed testing documentation, see:
- [`scripts/setup/README.md`](scripts/setup/README.md) - Network setup and validation
- [`scripts/performance/README.md`](scripts/performance/README.md) - Performance testing framework

## Usage

### Basic Operations

Once deployed, the chaincode exposes the following functions:

#### EHR Management
```bash
# Create a new EHR (requires Org1 or Org2 identity)
peer chaincode invoke ... -c '{"function":"CreateEHR","Args":["patient001","John Doe","<FHIR_JSON>"]}'

# Read EHR (creator or authorized provider)
peer chaincode query -c '{"function":"ReadEHR","Args":["patient001"]}'

# Update existing EHR (creator only)
peer chaincode invoke ... -c '{"function":"UpdateEHR","Args":["patient001","<UPDATED_FHIR_JSON>"]}'

# Delete EHR (creator only)  
peer chaincode invoke ... -c '{"function":"DeleteEHR","Args":["patient001"]}'
```

#### Consent Management
```bash
# Grant consent for cross-org access
peer chaincode invoke ... -c '{"function":"GrantConsent","Args":["patient001","[\"Org2MSP\"]"]}'

# Read consent status
peer chaincode query -c '{"function":"ReadConsent","Args":["patient001"]}'

# Revoke consent
peer chaincode invoke ... -c '{"function":"RevokeConsent","Args":["patient001","[\"Org2MSP\"]"]}'
```

### Cross-Organizational Workflow Example

```bash
# Step 1: Org1 creates EHR
export CORE_PEER_LOCALMSPID="Org1MSP"
# ... set Org1 environment variables ...
peer chaincode invoke ... -c '{"function":"CreateEHR","Args":["patient001","John Doe","<FHIR_JSON>"]}'

# Step 2: Org1 grants consent to Org2
peer chaincode invoke ... -c '{"function":"GrantConsent","Args":["patient001","[\"Org2MSP\"]"]}'

# Step 3: Org2 can now read the EHR
export CORE_PEER_LOCALMSPID="Org2MSP"
# ... set Org2 environment variables ...
peer chaincode query -c '{"function":"ReadEHR","Args":["patient001"]}'
```

### FHIR Compliance

The system accepts FHIR R4 compliant JSON resources:

```json
{
  "resourceType": "Patient",
  "id": "patient001",
  "name": [
    {
      "given": ["John"],
      "family": "Doe"
    }
  ],
  "gender": "male",
  "birthDate": "1990-01-01"
}
```

## Architecture

### Authorization Model

The system implements a dual authorization model:

1. **Creator Authorization**: Organizations can always access EHRs they created
2. **Consent-based Authorization**: Cross-organizational access requires explicit patient consent

### Security Features

- **MSP Identity Validation**: Uses Hyperledger Fabric's Membership Service Provider
- **Certificate-based Authentication**: X.509 certificate validation
- **Consent Management**: Patient-controlled access permissions
- **Audit Trail**: Immutable blockchain transaction history

### Performance Characteristics

Based on academic performance testing (500-iteration samples):

| Metric | Value | Context |
|--------|-------|---------|
| **Average Latency** | 65-87ms | End-to-end transaction confirmation |
| **Throughput** | 10-13 TPS | Concurrent transaction processing |
| **P99 Latency** | <175ms | 99th percentile response time |
| **Cross-org Overhead** | Minimal | <5ms additional latency |
| **Scaling Efficiency** | 80% @ 2 workers | Linear scaling up to system core count |

## Troubleshooting

### Common Issues

1. **Chaincode deployment fails**:
   ```bash
   # Check network status
   docker ps
   # Restart network if needed
   cd $FABRIC_HOME/test-network
   ./network.sh down && ./network.sh up createChannel -ca -c mychannel
   ```

2. **Permission denied errors**:
   ```bash
   # Verify MSP environment variables
   echo $CORE_PEER_LOCALMSPID
   echo $CORE_PEER_MSPCONFIGPATH
   ```

3. **Performance test failures**:
   ```bash
   # Check chaincode is responding
   peer chaincode query -C mychannel -n ehrmanagement -c '{"function":"ReadEHR","Args":["test"]}'
   # Should return "EHR with ID test does not exist" error (expected)
   ```

### Network Reset

For a complete clean restart:

```bash
cd $FABRIC_HOME/test-network
./network.sh down
docker system prune -f
./network.sh up createChannel -ca -c mychannel
# Redeploy chaincode
./network.sh deployCC -ccn ehrmanagement -ccp ../chaincode/ehr-management-modules -ccl go
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests (`go test ./chaincode/... -v`)
4. Commit changes (`git commit -m 'Add amazing feature'`)
5. Push to branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## Academic Research

This project was developed for academic research in blockchain-based healthcare systems. Key research contributions:

- **Cross-organizational EHR sharing** with consent management
- **Performance analysis** of blockchain EHR systems
- **FHIR compliance** in blockchain environments
- **Empirical evaluation** of Hyperledger Fabric for healthcare

### Citation

If you use this project in academic research, please cite:

```bibtex
@misc{ehr-blockchain-2025,
  title={Blockchain-based Electronic Health Record Management with Cross-organizational Consent},
  author={[Vitor Lindbergh]},
  year={2025},
  publisher={GitHub},
  url={https://github.com/vtrlindbergh/ehr-management-modules}
}
```

## Academic Use

This project was developed for academic research purposes. For licensing and usage permissions, please contact the author.