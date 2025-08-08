#!/bin/bash

# =============================================================================
# Configuration file for EHR Management Performance Testing
# Academic Project - Master's Dissertation
# =============================================================================

# Network Configuration
export TEST_NETWORK_PATH="../../../test-network"
export CHANNEL_NAME="mychannel"
export CHAINCODE_NAME="ehrCC"
export ORDERER_ENDPOINT="localhost:7050"

# Peer Configuration
export PEER0_ORG1_ENDPOINT="localhost:7051"
export PEER0_ORG2_ENDPOINT="localhost:9051"

# Test Configuration
export DEFAULT_TEST_ITERATIONS=100
export DEFAULT_CONCURRENT_CLIENTS=5
export TEST_PATIENT_ID_PREFIX="TEST_P"

# Output Configuration
export RESULTS_DIR="../results"
export LOG_DIR="../logs"

# Colors for output formatting
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_RED='\033[0;31m'
export COLOR_BLUE='\033[0;34m'
export COLOR_NC='\033[0m' # No Color

# Utility function to print colored messages
print_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_NC} $1"
}

print_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_NC} $1"
}

print_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_NC} $1"
}

print_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $1"
}

# Function to check if test network is running
check_network_status() {
    print_info "Checking Hyperledger Fabric test network status..."
    
    # Check if Docker containers are running
    if ! docker ps --format "table {{.Names}}" | grep -q "peer0.org1.example.com"; then
        print_warning "Test network may not be running. Please ensure the network is up."
        return 1
    fi
    
    if ! docker ps --format "table {{.Names}}" | grep -q "orderer.example.com"; then
        print_warning "Orderer may not be running. Please ensure the network is up."
        return 1
    fi
    
    print_success "Test network appears to be running"
    return 0
}

# Function to setup Fabric environment
setup_fabric_environment() {
    # Load environment variables from .env file
    if [[ -f "${SCRIPT_DIR}/../.env" ]]; then
        source "${SCRIPT_DIR}/../.env"
        print_success "Environment variables loaded from .env file"
    else
        print_error "Environment file not found. Please run network_setup.sh first."
        return 1
    fi
    
    # Setup Org1 environment by default
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE="${TEST_NETWORK_PATH}/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem"
    export CORE_PEER_MSPCONFIGPATH="${TEST_NETWORK_PATH}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp"
    export CORE_PEER_ADDRESS="localhost:7051"
    
    # Set up peer TLS certificates for performance scripts
    export PEER0_ORG1_TLS_ROOTCERT="${TEST_NETWORK_PATH}/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem"
    export PEER0_ORG2_TLS_ROOTCERT="${TEST_NETWORK_PATH}/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem"
    
    # Add fabric binaries to PATH
    export PATH="/home/vitor/dev/fabric-samples/bin:$PATH"
    
    print_success "Fabric environment configured for Org1"
}

# Function to create required directories
create_output_directories() {
    print_info "Creating output directories..."
    
    cd "$(dirname "$0")" || exit 1
    
    mkdir -p "${RESULTS_DIR}" "${LOG_DIR}"
    
    print_success "Output directories created"
}
