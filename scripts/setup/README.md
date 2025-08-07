# Network Setup and Validation Scripts

This directory contains scripts for setting up the Hyperledger Fabric test network and validating the EHR smart contract functionality.

## Scripts Overview

### 1. `network_setup.sh` - Network Infrastructure Setup

**Purpose**: Deploys the complete Hyperledger Fabric infrastructure with the EHR chaincode.

**What it does**:
- Deploys Fabric test network with Certificate Authority
- Creates the `mychannel` channel
- Deploys the EHR chaincode (`ehrCC`)
- Sets up TLS certificates for secure communication
- Configures the Fabric CLI environment
- Validates the deployment
- Saves environment variables for later use

**Usage**:
```bash
cd scripts/setup
./network_setup.sh [options]
```

**Options**:
- `-h, --help`: Show help message
- `-c, --clean`: Clean up existing network before starting
- `-v, --verbose`: Enable verbose output
- `--skip-wait`: Skip waiting periods (for debugging)

**Example**:
```bash
# Clean deployment (recommended for testing)
./network_setup.sh --clean

# Quick deployment without waiting
./network_setup.sh --skip-wait
```

### 2. `manual_validation.sh` - Smart Contract Validation

**Purpose**: Validates all EHR smart contract operations step by step.

**What it validates**:
- Step 4: Create EHR record with FHIR-compliant data
- Step 5: Grant consent for access control
- Step 6: Read EHR record (with consent validation)
- Step 7: Update EHR record
- Step 8: Delete EHR record

**Usage**:
```bash
cd scripts/setup
./manual_validation.sh [options]
```

**Options**:
- `-h, --help`: Show help message
- `-a, --auto`: Run all steps automatically without pausing
- `-s, --step N`: Run only step N (4-8)

**Examples**:
```bash
# Interactive validation (recommended for first time)
./manual_validation.sh

# Automatic validation (for testing)
./manual_validation.sh --auto

# Test only reading functionality
./manual_validation.sh --step 6
```

## Prerequisites

1. **Docker and Docker Compose**: Must be installed and running
2. **Hyperledger Fabric Binaries**: Must be in PATH
3. **Test Network**: Must be accessible at `../../test-network/`
4. **EHR Chaincode**: Must be available at `../ehr-management-modules/`

## Workflow

### Complete Setup and Validation

```bash
# 1. Deploy the network infrastructure
cd scripts/setup
./network_setup.sh --clean

# 2. Validate smart contract operations
./manual_validation.sh --auto
```

### Development Workflow

```bash
# Quick network restart (during development)
./network_setup.sh --clean --skip-wait

# Test specific functionality
./manual_validation.sh --step 6  # Test read operation
```

## Generated Files

### `.env` File
The network setup script creates a `.env` file in the scripts directory containing:
- TLS certificate paths
- Network configuration
- Chaincode details

This file is automatically loaded by other scripts.

### Logs and Debugging
- Container status is displayed during setup
- Failed operations show detailed error messages
- Use `--verbose` flag for detailed execution logs

## Timing Considerations

The scripts include proper timing considerations:

**Network Setup**:
- 30 seconds wait after network deployment
- 45 seconds wait after chaincode deployment
- Container health checks with retries

**Why These Delays?**:
- Docker containers need time to initialize
- Chaincode compilation and instantiation takes time
- TLS certificate generation requires network stabilization

## Troubleshooting

### Common Issues

1. **"Docker is not running"**
   ```bash
   sudo systemctl start docker
   ```

2. **"Cannot access test network directory"**
   - Verify the test-network path in config
   - Ensure you're running from the correct directory

3. **"Chaincode deployment failed"**
   - Check if the chaincode compiles: `cd chaincode && go mod tidy`
   - Verify the chaincode path is correct

4. **"Permission denied"**
   ```bash
   chmod +x scripts/setup/*.sh
   ```

### Debugging Commands

```bash
# Check container status
docker ps

# View container logs
docker logs peer0.org1.example.com

# Clean everything
./network_setup.sh --clean
docker system prune -a
```

## Academic Context

These scripts are designed for academic validation of:

1. **Network Deployment**: Proving the infrastructure can be reliably set up
2. **CRUD Operations**: Validating all smart contract functions work correctly
3. **Access Control**: Demonstrating consent-based access works
4. **FHIR Compliance**: Using industry-standard healthcare data formats
5. **Reproducibility**: Ensuring experiments can be repeated reliably

## Integration with Performance Testing

After successful validation:

1. **Environment is Ready**: Network and chaincode are deployed
2. **Environment Variables Set**: All paths and certificates configured
3. **Performance Scripts Can Run**: Throughput testing can begin immediately

## Next Steps

After running these scripts successfully:

1. ✅ **Network Infrastructure**: Deployed and validated
2. ✅ **Smart Contract**: All operations working
3. 🚀 **Ready for Performance Testing**: Run throughput and latency scripts

```bash
# Move to performance testing
cd ../performance
./throughput_test.sh 100 create
```

---

**Academic Project**: Master's Dissertation on Blockchain-based EHR Management  
**Technology Stack**: Hyperledger Fabric, Go Smart Contracts, HL7 FHIR  
**Purpose**: Infrastructure validation for scalability research
