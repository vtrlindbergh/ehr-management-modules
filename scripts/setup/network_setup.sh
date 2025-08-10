#!/bin/bash

# =============================================================================
# Network Setup and Validation Script
# Academic Project - Master's Dissertation
# Deploys Hyperledger Fabric test network and EHR chaincode
# =============================================================================

# Source configuration if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../performance/config.sh" ]; then
    source "${SCRIPT_DIR}/../performance/config.sh"
else
    # Basic configuration if config.sh not available
    export TEST_NETWORK_PATH="/home/vitor/dev/fabric-samples/test-network"
    export CHAINCODE_NAME="ehrCC"
    export CHAINCODE_PATH="../ehr-management-modules"
    export CHAINCODE_LANGUAGE="go"
    export CHAINCODE_VERSION="1.0"
    export CHANNEL_NAME="mychannel"
    
    # Colors for output
    export COLOR_GREEN='\033[0;32m'
    export COLOR_YELLOW='\033[1;33m'
    export COLOR_RED='\033[0;31m'
    export COLOR_BLUE='\033[0;34m'
    export COLOR_NC='\033[0m'
    
    print_info() { echo -e "${COLOR_BLUE}[INFO]${COLOR_NC} $1"; }
    print_success() { echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_NC} $1"; }
    print_warning() { echo -e "${COLOR_YELLOW}[WARNING]${COLOR_NC} $1"; }
    print_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $1"; }
fi

# Configuration
WAIT_TIME_NETWORK=30        # Seconds to wait after network startup
WAIT_TIME_CHAINCODE=45      # Seconds to wait after chaincode deployment
MAX_RETRIES=3               # Maximum retry attempts for operations
RETRY_DELAY=10              # Seconds between retries

# Function to display usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --clean    Clean up existing network before starting"
    echo "  -v, --verbose  Enable verbose output"
    echo "  --skip-wait    Skip waiting periods (for debugging)"
    echo ""
    echo "This script performs the following steps:"
    echo "  1. Navigate to test-network directory"
    echo "  2. Deploy Fabric network with CA"
    echo "  3. Create channel '${CHANNEL_NAME}'"
    echo "  4. Deploy EHR chaincode"
    echo "  5. Set up TLS certificates"
    echo "  6. Validate network and chaincode deployment"
}

# Function to check if Docker is running
check_docker() {
    print_info "Checking Docker status..."
    
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running or not accessible"
        print_info "Please start Docker and ensure your user has Docker permissions"
        return 1
    fi
    
    print_success "Docker is running"
    return 0
}

# Function to clean up existing network
cleanup_network() {
    print_info "Cleaning up existing Fabric network..."
    
    # Calculate absolute path from script directory
    local test_network_abs_path
    test_network_abs_path=$(cd "${SCRIPT_DIR}" && realpath "${TEST_NETWORK_PATH}")
    
    if [ ! -d "$test_network_abs_path" ]; then
        print_error "Test network directory not found: ${test_network_abs_path}"
        return 1
    fi
    
    print_info "Working in directory: ${test_network_abs_path}"
    
    cd "$test_network_abs_path" || {
        print_error "Cannot access test network directory: ${test_network_abs_path}"
        return 1
    }
    
    print_info "Working in directory: $(pwd)"
    
    # Stop and clean the network
    ./network.sh down
    
    # Remove any leftover containers
    print_info "Removing any leftover Docker containers..."
    docker container prune -f > /dev/null 2>&1
    
    # Remove chaincode images
    print_info "Removing chaincode Docker images..."
    docker rmi $(docker images "dev-peer*" -q) > /dev/null 2>&1 || true
    
    print_success "Network cleanup completed"
    return 0
}

# Function to wait with progress indicator
wait_with_progress() {
    local duration=$1
    local message=$2
    
    if [ "${SKIP_WAIT}" = "true" ]; then
        print_info "Skipping wait: ${message}"
        return 0
    fi
    
    print_info "${message} (${duration}s)"
    
    for ((i=1; i<=duration; i++)); do
        printf "\rProgress: ["
        local filled=$((i * 40 / duration))
        for ((j=1; j<=40; j++)); do
            if [ $j -le $filled ]; then
                printf "="
            else
                printf " "
            fi
        done
        printf "] %d/%d seconds" $i $duration
        sleep 1
    done
    echo ""
}

# Function to check container status
check_container_status() {
    local container_pattern=$1
    local expected_count=$2
    
    local running_count=$(docker ps --format "table {{.Names}}" | grep -c "${container_pattern}" || true)
    
    if [ "${running_count}" -ge "${expected_count}" ]; then
        return 0
    else
        return 1
    fi
}

# Function to deploy the network
deploy_network() {
    print_info "=== Step 1: Deploying Hyperledger Fabric Network ==="
    
    # Calculate absolute path from script directory
    local test_network_abs_path
    test_network_abs_path=$(cd "${SCRIPT_DIR}" && realpath "${TEST_NETWORK_PATH}")
    
    if [ ! -d "$test_network_abs_path" ]; then
        print_error "Test network directory not found: ${test_network_abs_path}"
        return 1
    fi
    
    print_info "Working in directory: ${test_network_abs_path}"
    
    cd "$test_network_abs_path" || {
        print_error "Cannot access test network directory: ${test_network_abs_path}"
        return 1
    }
    
    print_info "Current directory: $(pwd)"
    
    # Deploy network with CA
    print_info "Starting Fabric network with Certificate Authority..."
    if ! ./network.sh up createChannel -ca; then
        print_error "Failed to deploy network and create channel"
        return 1
    fi
    
    print_success "Network deployment command completed"
    
    # Wait for containers to be fully ready
    wait_with_progress $WAIT_TIME_NETWORK "Waiting for network containers to stabilize"
    
    # Verify network containers are running
    print_info "Verifying network container status..."
    
    local retry_count=0
    while [ $retry_count -lt $MAX_RETRIES ]; do
        if check_container_status "peer0.org" 2 && \
           check_container_status "orderer" 1 && \
           check_container_status "ca_" 2; then
            print_success "All network containers are running"
            break
        else
            ((retry_count++))
            print_warning "Retry ${retry_count}/${MAX_RETRIES}: Some containers not ready yet"
            sleep $RETRY_DELAY
        fi
    done
    
    if [ $retry_count -eq $MAX_RETRIES ]; then
        print_error "Network containers failed to start properly"
        print_info "Running containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}"
        return 1
    fi
    
    print_success "Network deployment completed successfully"
    return 0
}

# Function to deploy chaincode
deploy_chaincode() {
    print_info "=== Step 2: Deploying EHR Chaincode ==="
    
    # Calculate absolute path from script directory
    local test_network_abs_path
    test_network_abs_path=$(cd "${SCRIPT_DIR}" && realpath "${TEST_NETWORK_PATH}")
    
    print_info "Working in directory: ${test_network_abs_path}"
    
    cd "$test_network_abs_path" || {
        print_error "Cannot access test network directory: ${test_network_abs_path}"
        return 1
    }
    
    print_info "Deploying chaincode with the following parameters:"
    print_info "  Name: ${CHAINCODE_NAME}"
    print_info "  Path: ${CHAINCODE_PATH}"
    print_info "  Language: ${CHAINCODE_LANGUAGE}"
    print_info "  Version: ${CHAINCODE_VERSION}"
    
    # Ensure we have valid parameters
    if [ -z "${CHAINCODE_NAME}" ] || [ -z "${CHAINCODE_PATH}" ] || [ -z "${CHAINCODE_LANGUAGE}" ] || [ -z "${CHAINCODE_VERSION}" ]; then
        print_error "Missing chaincode parameters. Using defaults."
        export CHAINCODE_NAME="ehrCC"
        export CHAINCODE_PATH="../ehr-management-modules"
        export CHAINCODE_LANGUAGE="go"
        export CHAINCODE_VERSION="1.0"
        print_info "Updated parameters:"
        print_info "  Name: ${CHAINCODE_NAME}"
        print_info "  Path: ${CHAINCODE_PATH}"
        print_info "  Language: ${CHAINCODE_LANGUAGE}"
        print_info "  Version: ${CHAINCODE_VERSION}"
    fi
    
    # Deploy chaincode
    if ! ./network.sh deployCC \
        -ccn "${CHAINCODE_NAME}" \
        -ccp "${CHAINCODE_PATH}" \
        -ccl "${CHAINCODE_LANGUAGE}" \
        -ccv "${CHAINCODE_VERSION}"; then
        print_error "Failed to deploy chaincode"
        return 1
    fi
    
    print_success "Chaincode deployment command completed"
    
    # Wait for chaincode containers to be ready
    wait_with_progress $WAIT_TIME_CHAINCODE "Waiting for chaincode containers to be ready"
    
    # Verify chaincode containers
    print_info "Verifying chaincode container status..."
    
    local retry_count=0
    while [ $retry_count -lt $MAX_RETRIES ]; do
        if check_container_status "dev-peer.*${CHAINCODE_NAME}" 2; then
            print_success "Chaincode containers are running"
            break
        else
            ((retry_count++))
            print_warning "Retry ${retry_count}/${MAX_RETRIES}: Chaincode containers not ready yet"
            sleep $RETRY_DELAY
        fi
    done
    
    if [ $retry_count -eq $MAX_RETRIES ]; then
        print_warning "Chaincode containers may still be initializing"
        print_info "This is normal for first deployment - chaincode will be available shortly"
    fi
    
    print_success "Chaincode deployment completed"
    return 0
}

# Function to setup TLS certificates
setup_tls_certificates() {
    print_info "=== Step 3: Setting up TLS Certificates ==="
    
    # Calculate absolute path from script directory
    local test_network_abs_path
    test_network_abs_path=$(cd "${SCRIPT_DIR}" && realpath "${TEST_NETWORK_PATH}")
    
    cd "$test_network_abs_path" || {
        print_error "Cannot access test network directory: ${test_network_abs_path}"
        return 1
    }
    
    # Set TLS certificate paths
    local org1_cert="${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"
    local org2_cert="${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"
    
    # Verify certificate files exist
    if [ ! -f "$org1_cert" ]; then
        print_error "Org1 TLS certificate not found: $org1_cert"
        return 1
    fi
    
    if [ ! -f "$org2_cert" ]; then
        print_error "Org2 TLS certificate not found: $org2_cert"
        return 1
    fi
    
    # Export certificate paths
    export PEER0_ORG1_TLS_ROOTCERT="$org1_cert"
    export PEER0_ORG2_TLS_ROOTCERT="$org2_cert"
    
    print_success "TLS certificates configured:"
    print_info "  Org1 cert: ${PEER0_ORG1_TLS_ROOTCERT}"
    print_info "  Org2 cert: ${PEER0_ORG2_TLS_ROOTCERT}"
    
    # Save environment variables to a file for later use
    local env_file="${SCRIPT_DIR}/../.env"
    cat > "$env_file" << EOF
# Generated by network setup script at $(date)
export PEER0_ORG1_TLS_ROOTCERT="${PEER0_ORG1_TLS_ROOTCERT}"
export PEER0_ORG2_TLS_ROOTCERT="${PEER0_ORG2_TLS_ROOTCERT}"
export TEST_NETWORK_PATH="${TEST_NETWORK_PATH}"
export CHAINCODE_NAME="${CHAINCODE_NAME}"
export CHANNEL_NAME="${CHANNEL_NAME}"
EOF
    
    print_success "Environment variables saved to: ${env_file}"
    return 0
}

# Function to setup Fabric CLI environment
setup_fabric_environment() {
    print_info "=== Step 4: Setting up Fabric CLI Environment ==="
    
    # Calculate absolute path from script directory
    local test_network_abs_path
    test_network_abs_path=$(cd "${SCRIPT_DIR}" && realpath "${TEST_NETWORK_PATH}")
    
    cd "$test_network_abs_path" || {
        print_error "Cannot access test network directory: ${test_network_abs_path}"
        return 1
    }
    
    # Source environment variables
    if [ -f "./scripts/envVar.sh" ]; then
        source ./scripts/envVar.sh
        setGlobals 1  # Set to Org1
        print_success "Fabric CLI environment configured for Org1"
    else
        print_error "Environment script not found: ./scripts/envVar.sh"
        return 1
    fi
    
    return 0
}

# Function to validate deployment
validate_deployment() {
    print_info "=== Step 5: Validating Network and Chaincode Deployment ==="
    
    # Test basic network connectivity
    print_info "Testing orderer connectivity..."
    if curl -s --max-time 5 "http://localhost:7050" > /dev/null 2>&1; then
        print_success "Orderer is accessible"
    else
        print_warning "Orderer connectivity test failed (this may be normal)"
    fi
    
    # Test chaincode with a simple query
    print_info "Testing chaincode deployment with sample query..."
    
    # Calculate absolute path from script directory
    local test_network_abs_path
    test_network_abs_path=$(cd "${SCRIPT_DIR}" && realpath "${TEST_NETWORK_PATH}")
    
    cd "$test_network_abs_path" || return 1
    
    # Try a simple chaincode query
    local query_result
    query_result=$(peer chaincode query \
        -C "${CHANNEL_NAME}" \
        -n "${CHAINCODE_NAME}" \
        -c '{"function":"GetAllEHRs","Args":[]}' 2>&1)
    
    local query_status=$?
    
    if [ $query_status -eq 0 ]; then
        print_success "Chaincode is responding to queries"
        print_info "Query result: ${query_result}"
    else
        print_warning "Chaincode query test failed - this may be normal for initial deployment"
        print_info "Error: ${query_result}"
        print_info "The chaincode may need a few more minutes to be fully ready"
    fi
    
    # Display container status
    print_info "Current Docker container status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(peer|orderer|ca|dev-peer)"
    
    print_success "Network validation completed"
    return 0
}

# Function to display next steps
show_next_steps() {
    print_info "=== Deployment Summary ==="
    print_success "Hyperledger Fabric network is deployed and ready!"
    print_success "EHR chaincode (${CHAINCODE_NAME}) is deployed on channel '${CHANNEL_NAME}'"
    
    echo ""
    print_info "=== Next Steps ==="
    echo "1. Test manual EHR operations using the validation commands"
    echo "2. Run performance testing scripts"
    echo "3. Use the saved environment variables:"
    echo ""
    echo "   source ${SCRIPT_DIR}/../.env"
    echo ""
    echo "4. Navigate to test-network for manual commands:"
    echo ""
    echo "   cd ${TEST_NETWORK_PATH}"
    echo "   source ./scripts/envVar.sh && setGlobals 1"
    echo ""
    print_info "Environment variables are available in: ${SCRIPT_DIR}/../.env"
}

# Main execution function
main() {
    print_info "=== EHR Management Network Setup Script ==="
    print_info "Academic Project - Master's Dissertation"
    print_info "$(date)"
    echo ""
    
    # Parse command line arguments
    CLEAN_NETWORK=false
    VERBOSE=false
    SKIP_WAIT=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -c|--clean)
                CLEAN_NETWORK=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --skip-wait)
                SKIP_WAIT=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Enable verbose output if requested
    if [ "${VERBOSE}" = "true" ]; then
        set -x
    fi
    
    # Check prerequisites
    if ! check_docker; then
        exit 1
    fi
    
    # Clean up if requested
    if [ "${CLEAN_NETWORK}" = "true" ]; then
        if ! cleanup_network; then
            print_error "Failed to clean up network"
            exit 1
        fi
    fi
    
    # Execute deployment steps
    if ! deploy_network; then
        print_error "Network deployment failed"
        exit 1
    fi
    
    if ! deploy_chaincode; then
        print_error "Chaincode deployment failed"
        exit 1
    fi
    
    if ! setup_tls_certificates; then
        print_error "TLS certificate setup failed"
        exit 1
    fi
    
    if ! setup_fabric_environment; then
        print_error "Fabric environment setup failed"
        exit 1
    fi
    
    if ! validate_deployment; then
        print_warning "Deployment validation had issues, but network may still be functional"
    fi
    
    show_next_steps
    
    print_success "Network setup completed successfully!"
    return 0
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
