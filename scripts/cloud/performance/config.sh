#!/bin/bash

# =============================================================================
# Configuration file for Cloud EHR Management Performance Testing
# Academic Project - Master's Dissertation
# 
# CLOUD DEPLOYMENT: 3 Azure VMs with Docker Swarm overlay network
# This script mirrors scripts/performance/config.sh but targets the
# distributed cloud environment instead of localhost.
#
# Run these scripts FROM the Org1 VM (20.88.52.252 / 10.0.2.4)
# =============================================================================

# =============================================================================
# Cloud VM Configuration
# =============================================================================

# VM Private IPs (Azure VNet 10.0.0.0/16)
export ORDERER_VM_IP="10.0.1.4"    # VM1 — orderer (Swarm manager)
export ORG1_VM_IP="10.0.2.4"       # VM2 — peer0.org1 (Swarm worker)
export ORG2_VM_IP="10.0.3.4"       # VM3 — peer0.org2 (Swarm worker)

# VM Public IPs (for SSH access — NOT used by peer CLI)
export ORDERER_VM_PUBLIC="135.232.180.24"
export ORG1_VM_PUBLIC="20.88.52.252"
export ORG2_VM_PUBLIC="130.131.55.125"

# =============================================================================
# Network Configuration — Cloud Paths
# =============================================================================

# Base path on all VMs (cloud-init mounts data disk here)
export CLOUD_BASE_PATH="/opt/hyperledger"
export ORGANIZATIONS_PATH="${CLOUD_BASE_PATH}/organizations"
export FABRIC_CFG_PATH="${CLOUD_BASE_PATH}/peercfg"
export CHANNEL_NAME="mychannel"
export CHAINCODE_NAME="ehrCC"

# Orderer endpoint — crosses VNet to VM1's subnet (10.0.1.0/24)
export ORDERER_ENDPOINT="${ORDERER_VM_IP}:7050"
export ORDERER_CA="${ORGANIZATIONS_PATH}/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

# CRITICAL: TLS hostname override required when addressing orderer by IP
# The TLS certificate is issued to orderer.example.com, not to 10.0.1.4
export ORDERER_TLS_HOSTNAME_OVERRIDE="orderer.example.com"

# Peer Configuration — Cloud VM private IPs
# Org1 peer is on VM2 (10.0.2.4), Org2 peer is on VM3 (10.0.3.4)
export PEER0_ORG1_ENDPOINT="${ORG1_VM_IP}:7051"
export PEER0_ORG2_ENDPOINT="${ORG2_VM_IP}:9051"

# TLS Certificate paths (same structure on all VMs, distributed via SCP)
export PEER0_ORG1_TLS_ROOTCERT="${ORGANIZATIONS_PATH}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"
export PEER0_ORG2_TLS_ROOTCERT="${ORGANIZATIONS_PATH}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"

# =============================================================================
# Test Configuration
# =============================================================================

export DEFAULT_TEST_ITERATIONS=100
export DEFAULT_CONCURRENT_CLIENTS=5
export TEST_PATIENT_ID_PREFIX="CLOUD_P"

# =============================================================================
# Output Configuration — Cloud-specific results directory
# =============================================================================

export RESULTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../results"
export LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../logs"

# =============================================================================
# Deployment Metadata — Recorded in reports for traceability
# =============================================================================

export DEPLOYMENT_TYPE="cloud"
export VM_SIZE="Standard_B1ms"
export VM_VCPUS=1
export VM_RAM_GB=2
export AZURE_REGION="northcentralus"
export SWARM_OVERLAY_NETWORK="fabric_test"
export FABRIC_VERSION="2.5.10"
export CA_VERSION="1.5.12"
export GO_VERSION="1.22.7"

# =============================================================================
# Colors for output formatting (same as local)
# =============================================================================

export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_RED='\033[0;31m'
export COLOR_BLUE='\033[0;34m'
export COLOR_NC='\033[0m'

# =============================================================================
# Utility functions (same as local)
# =============================================================================

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

print_header() {
    echo -e "\n${COLOR_BLUE}=====================================${COLOR_NC}"
    echo -e "${COLOR_BLUE}$1${COLOR_NC}"
    echo -e "${COLOR_BLUE}=====================================${COLOR_NC}\n"
}

# =============================================================================
# Cloud-specific: Check network connectivity to all VMs
# =============================================================================

check_network_status() {
    print_info "Checking cloud Hyperledger Fabric network status..."

    local all_ok=true

    # Check connectivity to orderer VM
    if ! ping -c 1 -W 2 "${ORDERER_VM_IP}" > /dev/null 2>&1; then
        print_warning "Cannot reach orderer VM at ${ORDERER_VM_IP}"
        all_ok=false
    fi

    # Check connectivity to Org2 VM
    if ! ping -c 1 -W 2 "${ORG2_VM_IP}" > /dev/null 2>&1; then
        print_warning "Cannot reach Org2 VM at ${ORG2_VM_IP}"
        all_ok=false
    fi

    # Check if peer binary is available
    if ! command -v peer &> /dev/null; then
        print_warning "Fabric 'peer' binary not found in PATH"
        print_info "Ensure PATH includes: ${CLOUD_BASE_PATH}/fabric-samples/bin"
        all_ok=false
    fi

    # Check if Docker containers are running (swarm services)
    if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "fabric"; then
        print_success "Docker Fabric containers detected"
    else
        print_warning "No Fabric containers detected via 'docker ps'. Services may be running on other swarm nodes."
    fi

    if [ "$all_ok" = true ]; then
        print_success "Cloud network connectivity verified"
        return 0
    else
        print_warning "Some connectivity checks failed — review warnings above"
        return 1
    fi
}

# =============================================================================
# Cloud-specific: Setup Fabric environment with cloud paths
# =============================================================================

setup_fabric_environment() {
    # Add Fabric binaries to PATH
    export PATH="${CLOUD_BASE_PATH}/fabric-samples/bin:/usr/local/go/bin:${PATH}"
    export FABRIC_CFG_PATH="${CLOUD_BASE_PATH}/peercfg"

    # Setup Org1 environment by default (scripts run from Org1 VM)
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE="${ORGANIZATIONS_PATH}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"
    export CORE_PEER_MSPCONFIGPATH="${ORGANIZATIONS_PATH}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp"
    export CORE_PEER_ADDRESS="localhost:7051"

    print_success "Cloud Fabric environment configured for Org1"
}

# =============================================================================
# Cloud-specific: Create output directories
# =============================================================================

create_output_directories() {
    print_info "Creating cloud output directories..."

    mkdir -p "${RESULTS_DIR}/latency_analysis"
    mkdir -p "${RESULTS_DIR}/throughput_analysis"
    mkdir -p "${RESULTS_DIR}/parallel_analysis"
    mkdir -p "${RESULTS_DIR}/performance_reports"
    mkdir -p "${LOG_DIR}"

    print_success "Cloud output directories created"
}
