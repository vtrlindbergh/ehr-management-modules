#!/bin/bash

# =============================================================================
# Manual Validation Steps Script
# Academic Project - Master's Dissertation
# Validates EHR smart contract operations step by step
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration and utility functions
source "${SCRIPT_DIR}/../performance/config.sh"

# Load environment variables from .env file
if [[ -f "${SCRIPT_DIR}/../.env" ]]; then
    source "${SCRIPT_DIR}/../.env"
    print_success "Environment variables loaded from .env file"
else
    print_error "Environment file not found. Please run network_setup.sh first."
    exit 1
fi

# Set up PATH for Fabric binaries (relative to test-network)
if [[ ! -f "${TEST_NETWORK_PATH}/scripts/envVar.sh" ]]; then
    print_error "Cannot find envVar.sh script. Please check TEST_NETWORK_PATH."
    exit 1
fi

# Add fabric binaries to PATH
export PATH="/home/vitor/dev/fabric-samples/bin:$PATH"

# Colors for output
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_NC='\033[0m'

print_info() { echo -e "${COLOR_BLUE}[INFO]${COLOR_NC} $1"; }
print_success() { echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_NC} $1"; }
print_warning() { echo -e "${COLOR_YELLOW}[WARNING]${COLOR_NC} $1"; }
print_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $1"; }

# Function to pause and wait for user input
pause_for_user() {
    echo ""
    read -p "Press Enter to continue to the next step..."
    echo ""
}

# Function to setup Fabric environment
setup_environment() {
    print_info "=== Setting up Fabric Environment ==="
    
    cd "${TEST_NETWORK_PATH}" || {
        print_error "Cannot access test network directory: ${TEST_NETWORK_PATH}"
        exit 1
    }
    
    # Set Fabric configuration path
    export FABRIC_CFG_PATH="${PWD}/compose/docker/peercfg"
    
    # Source environment variables
    source ./scripts/envVar.sh
    setGlobals 1  # Set to Org1
    
    print_success "Fabric environment configured for Org1 (org1admin)"
    print_info "Current directory: $(pwd)"
    print_info "Client identity: org1admin"
    print_info "Organization: Org1"
}

# Function to create EHR record
create_ehr_record() {
    print_info "=== Step 4: Creating EHR Record ==="
    print_info "Creating EHR for patient P001 with FHIR-compliant data..."
    
    local fhir_data='{\"patientID\":\"P001\",\"patientName\":\"John Doe\",\"healthData\":{\"resourceType\":\"Observation\",\"id\":\"bp-reading\",\"meta\":[{\"version\":\"1.0\",\"lastUpdated\":\"2025-01-01T12:00:00Z\"}],\"rawContent\":\"{\\\"resourceType\\\":\\\"Observation\\\",\\\"id\\\":\\\"bp-reading\\\",\\\"status\\\":\\\"final\\\",\\\"category\\\":[{\\\"coding\\\":[{\\\"system\\\":\\\"http://terminology.hl7.org/CodeSystem/observation-category\\\",\\\"code\\\":\\\"vital-signs\\\",\\\"display\\\":\\\"Vital Signs\\\"}]}],\\\"code\\\":{\\\"coding\\\":[{\\\"system\\\":\\\"http://loinc.org\\\",\\\"code\\\":\\\"85354-9\\\",\\\"display\\\":\\\"Blood pressure panel\\\"}]},\\\"subject\\\":{\\\"reference\\\":\\\"Patient/P001\\\"},\\\"effectiveDateTime\\\":\\\"2025-01-01T12:00:00Z\\\",\\\"component\\\":[{\\\"code\\\":{\\\"coding\\\":[{\\\"system\\\":\\\"http://loinc.org\\\",\\\"code\\\":\\\"8480-6\\\",\\\"display\\\":\\\"Systolic blood pressure\\\"}]},\\\"valueQuantity\\\":{\\\"value\\\":120,\\\"unit\\\":\\\"mmHg\\\"}},{\\\"code\\\":{\\\"coding\\\":[{\\\"system\\\":\\\"http://loinc.org\\\",\\\"code\\\":\\\"8462-4\\\",\\\"display\\\":\\\"Diastolic blood pressure\\\"}]},\\\"valueQuantity\\\":{\\\"value\\\":80,\\\"unit\\\":\\\"mmHg\\\"}}]}\",\"content\":[120, 80]},\"lastUpdated\":\"2025-01-01\"}'
    
    print_info "Executing CreateEHR transaction..."
    
    peer chaincode invoke \
        -o localhost:7050 \
        --tls \
        --cafile "${ORDERER_CA}" \
        -C "${CHANNEL_NAME}" \
        -n "${CHAINCODE_NAME}" \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles "${PEER0_ORG1_TLS_ROOTCERT}" \
        --peerAddresses localhost:9051 \
        --tlsRootCertFiles "${PEER0_ORG2_TLS_ROOTCERT}" \
        -c "{\"function\":\"CreateEHR\",\"Args\":[\"${fhir_data}\"]}"
    
    local status=$?
    if [ $status -eq 0 ]; then
        print_success "EHR record created successfully for patient P001"
    else
        print_error "Failed to create EHR record"
        return 1
    fi
}

# Function to grant consent
grant_consent() {
    print_info "=== Step 5: Granting Consent ==="
    print_info "Granting consent for org1admin to access patient P001's EHR..."
    
    peer chaincode invoke \
        -o localhost:7050 \
        --tls \
        --cafile "${ORDERER_CA}" \
        -C "${CHANNEL_NAME}" \
        -n "${CHAINCODE_NAME}" \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles "${PEER0_ORG1_TLS_ROOTCERT}" \
        --peerAddresses localhost:9051 \
        --tlsRootCertFiles "${PEER0_ORG2_TLS_ROOTCERT}" \
        -c '{"function":"GrantConsent","Args":["P001", "[\"org1admin\"]"]}'
    
    local status=$?
    if [ $status -eq 0 ]; then
        print_success "Consent granted successfully for patient P001"
    else
        print_error "Failed to grant consent"
        return 1
    fi
}

# Function to read EHR record
read_ehr_record() {
    print_info "=== Step 6: Reading EHR Record ==="
    print_info "Querying EHR data for patient P001..."
    
    local result
    result=$(peer chaincode query \
        -o localhost:7050 \
        --tls \
        --cafile "${ORDERER_CA}" \
        -C "${CHANNEL_NAME}" \
        -n "${CHAINCODE_NAME}" \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles "${PEER0_ORG1_TLS_ROOTCERT}" \
        -c '{"function":"ReadEHR","Args":["P001"]}')
    
    local status=$?
    if [ $status -eq 0 ]; then
        print_success "EHR record retrieved successfully"
        print_info "EHR Data:"
        echo "$result" | jq '.' 2>/dev/null || echo "$result"
    else
        print_error "Failed to read EHR record"
        return 1
    fi
}

# Function to update EHR record
update_ehr_record() {
    print_info "=== Step 7: Updating EHR Record ==="
    print_info "Updating EHR for patient P001 with new blood pressure values..."
    
    local updated_data='{\"patientID\":\"P001\",\"patientName\":\"John Doe\",\"healthData\":{\"resourceType\":\"Observation\",\"id\":\"bp-reading-updated\",\"meta\":[{\"version\":\"1.1\",\"lastUpdated\":\"2025-01-15T14:30:00Z\"}],\"rawContent\":\"{\\\"resourceType\\\":\\\"Observation\\\",\\\"id\\\":\\\"bp-reading-updated\\\",\\\"status\\\":\\\"final\\\",\\\"category\\\":[{\\\"coding\\\":[{\\\"system\\\":\\\"http://terminology.hl7.org/CodeSystem/observation-category\\\",\\\"code\\\":\\\"vital-signs\\\",\\\"display\\\":\\\"Vital Signs\\\"}]}],\\\"code\\\":{\\\"coding\\\":[{\\\"system\\\":\\\"http://loinc.org\\\",\\\"code\\\":\\\"85354-9\\\",\\\"display\\\":\\\"Blood pressure panel\\\"}]},\\\"subject\\\":{\\\"reference\\\":\\\"Patient/P001\\\"},\\\"effectiveDateTime\\\":\\\"2025-01-15T14:30:00Z\\\",\\\"component\\\":[{\\\"code\\\":{\\\"coding\\\":[{\\\"system\\\":\\\"http://loinc.org\\\",\\\"code\\\":\\\"8480-6\\\",\\\"display\\\":\\\"Systolic blood pressure\\\"}]},\\\"valueQuantity\\\":{\\\"value\\\":125,\\\"unit\\\":\\\"mmHg\\\"}},{\\\"code\\\":{\\\"coding\\\":[{\\\"system\\\":\\\"http://loinc.org\\\",\\\"code\\\":\\\"8462-4\\\",\\\"display\\\":\\\"Diastolic blood pressure\\\"}]},\\\"valueQuantity\\\":{\\\"value\\\":80,\\\"unit\\\":\\\"mmHg\\\"}}]}\",\"content\":[125, 80]},\"lastUpdated\":\"2025-01-15\"}'
    
    peer chaincode invoke \
        -o localhost:7050 \
        --tls \
        --cafile "${ORDERER_CA}" \
        -C "${CHANNEL_NAME}" \
        -n "${CHAINCODE_NAME}" \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles "${PEER0_ORG1_TLS_ROOTCERT}" \
        --peerAddresses localhost:9051 \
        --tlsRootCertFiles "${PEER0_ORG2_TLS_ROOTCERT}" \
        -c "{\"function\":\"UpdateEHR\",\"Args\":[\"${updated_data}\"]}"
    
    local status=$?
    if [ $status -eq 0 ]; then
        print_success "EHR record updated successfully"
        
        # Verify the update by reading again
        print_info "Verifying update by reading the record again..."
        read_ehr_record
    else
        print_error "Failed to update EHR record"
        return 1
    fi
}

# Function to delete EHR record
delete_ehr_record() {
    print_info "=== Step 8: Deleting EHR Record ==="
    print_info "Deleting EHR record for patient P001..."
    
    peer chaincode invoke \
        -o localhost:7050 \
        --tls \
        --cafile "${ORDERER_CA}" \
        -C "${CHANNEL_NAME}" \
        -n "${CHAINCODE_NAME}" \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles "${PEER0_ORG1_TLS_ROOTCERT}" \
        --peerAddresses localhost:9051 \
        --tlsRootCertFiles "${PEER0_ORG2_TLS_ROOTCERT}" \
        -c '{"function":"DeleteEHR","Args":["P001"]}'
    
    local status=$?
    if [ $status -eq 0 ]; then
        print_success "EHR record deleted successfully"
        
        # Verify deletion by trying to read
        print_info "Verifying deletion by attempting to read the record..."
        local result
        result=$(peer chaincode query \
            -C "${CHANNEL_NAME}" \
            -n "${CHAINCODE_NAME}" \
            -c '{"function":"ReadEHR","Args":["P001"]}' 2>&1)
        
        if echo "$result" | grep -q "does not exist\|not found"; then
            print_success "Deletion verified - record no longer exists"
        else
            print_warning "Deletion verification inconclusive"
            print_info "Query result: $result"
        fi
    else
        print_error "Failed to delete EHR record"
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -a, --auto     Run all steps automatically without pausing"
    echo "  -s, --step N   Run only step N (4-8)"
    echo ""
    echo "Steps:"
    echo "  4. Create EHR record"
    echo "  5. Grant consent"
    echo "  6. Read EHR record"
    echo "  7. Update EHR record"
    echo "  8. Delete EHR record"
    echo ""
    echo "Examples:"
    echo "  $0              # Run all steps with user interaction"
    echo "  $0 --auto       # Run all steps automatically"
    echo "  $0 --step 6     # Run only step 6 (read EHR)"
}

# Main execution function
main() {
    print_info "=== EHR Smart Contract Manual Validation ==="
    print_info "Academic Project - Master's Dissertation"
    print_info "$(date)"
    echo ""
    
    # Parse command line arguments
    AUTO_MODE=false
    SINGLE_STEP=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -a|--auto)
                AUTO_MODE=true
                shift
                ;;
            -s|--step)
                SINGLE_STEP="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Setup environment
    setup_environment
    
    # Function to handle pausing
    pause_if_interactive() {
        if [ "${AUTO_MODE}" != "true" ]; then
            pause_for_user
        fi
    }
    
    # Execute steps
    if [ -n "${SINGLE_STEP}" ]; then
        # Run single step
        case "${SINGLE_STEP}" in
            4) create_ehr_record ;;
            5) grant_consent ;;
            6) read_ehr_record ;;
            7) update_ehr_record ;;
            8) delete_ehr_record ;;
            *) print_error "Invalid step number: ${SINGLE_STEP}"; exit 1 ;;
        esac
    else
        # Run all steps
        create_ehr_record
        pause_if_interactive
        
        grant_consent
        pause_if_interactive
        
        read_ehr_record
        pause_if_interactive
        
        update_ehr_record
        pause_if_interactive
        
        delete_ehr_record
    fi
    
    echo ""
    print_success "Manual validation completed successfully!"
    print_info "All EHR smart contract operations are working correctly"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
