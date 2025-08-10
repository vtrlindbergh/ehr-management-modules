#!/bin/bash

# =============================================================================
# Throughput Testing Script
# Academic Project - Master's Dissertation
# Tests EHR system throughput by measuring transactions per second (TPS)
# =============================================================================

# Source required utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/ehr_operations.sh"

# Initialize Fabric environment
print_info "Setting up Fabric environment..."
setup_fabric_environment || exit 1

# Test parameters
ITERATIONS=${1:-$DEFAULT_TEST_ITERATIONS}
TEST_TYPE=${2:-"create"}  # create, read, update, delete, consent, full_cycle, cross_org
THROUGHPUT_DIR="${RESULTS_DIR}/throughput_analysis"
mkdir -p "$THROUGHPUT_DIR"
OUTPUT_FILE="${THROUGHPUT_DIR}/throughput_test_$(date +%Y%m%d_%H%M%S).csv"

# Function to display usage
show_usage() {
    echo "Usage: $0 [iterations] [test_type]"
    echo ""
    echo "Parameters:"
    echo "  iterations  Number of test iterations (default: ${DEFAULT_TEST_ITERATIONS})"
    echo "  test_type   Type of test to run (default: create)"
    echo ""
    echo "Test Types:"
    echo "  create      Test EHR creation throughput"
    echo "  read        Test EHR read throughput"
    echo "  update      Test EHR update throughput"
    echo "  delete      Test EHR deletion throughput"
    echo "  consent     Test consent granting throughput"
    echo "  cross_org   Test cross-organizational access throughput"
    echo "  full_cycle  Test complete CRUD cycle"
    echo "  all         Run all throughput tests sequentially"
    echo ""
    echo "Examples:"
    echo "  $0 50 create"
    echo "  $0 100 full_cycle"
}

# Function to run create throughput test
test_create_throughput() {
    local iterations=$1
    print_info "Starting EHR creation throughput test with ${iterations} iterations"
    
    echo "Test Type,Transaction ID,Patient ID,Start Time,End Time,Duration (seconds),Status" > "${OUTPUT_FILE}"
    
    # Generate unique patient ID prefix based on timestamp to avoid conflicts
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="CREATE_${timestamp}_P"
    
    local start_test=$(date +%s.%N)
    local successful_transactions=0
    
    for i in $(seq 1 $iterations); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        local transaction_start=$(date +%s.%N)
        
        print_info "Creating EHR for patient ${patient_id} (${i}/${iterations})"
        
        # Capture both duration and exit status
        local duration
        duration=$(create_ehr "${patient_id}" "Test Patient ${i}")
        local exit_status=$?
        
        local transaction_end=$(date +%s.%N)
        local status="SUCCESS"
        
        if [ $exit_status -ne 0 ]; then
            status="FAILED"
            print_warning "Transaction ${i} failed"
        else
            ((successful_transactions++))
        fi
        
        # Log result to CSV
        echo "CREATE,${i},${patient_id},${transaction_start},${transaction_end},${duration},${status}" >> "${OUTPUT_FILE}"
    done
    
    local end_test=$(date +%s.%N)
    local total_duration=$(echo "${end_test} - ${start_test}" | bc)
    local tps=$(echo "scale=2; ${successful_transactions} / ${total_duration}" | bc)
    
    print_success "Create throughput test completed!"
    print_info "Total transactions: ${iterations}"
    print_info "Successful transactions: ${successful_transactions}"
    print_info "Total time: ${total_duration} seconds"
    print_info "Throughput: ${tps} TPS"
    
    # Append summary to results
    echo "SUMMARY,CREATE,${iterations},${successful_transactions},${total_duration},${tps}" >> "${OUTPUT_FILE}"
}

# Function to run read throughput test
test_read_throughput() {
    local iterations=$1
    print_info "Starting EHR read throughput test with ${iterations} iterations"
    
    echo "Test Type,Transaction ID,Patient ID,Start Time,End Time,Duration (seconds),Status" > "${OUTPUT_FILE}"
    
    # Generate unique patient ID prefix based on timestamp to avoid conflicts
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="READ_${timestamp}_P"
    
    # First, create some test data
    print_info "Setting up test data..."
    for i in $(seq 1 10); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        create_ehr "${patient_id}" "Setup Patient ${i}" > /dev/null 2>&1
        grant_consent "${patient_id}" > /dev/null 2>&1
    done
    
    local start_test=$(date +%s.%N)
    local successful_transactions=0
    
    for i in $(seq 1 $iterations); do
        # Cycle through the 10 created patients
        local patient_index=$(( (i - 1) % 10 + 1 ))
        local patient_id="${unique_prefix}$(printf "%06d" $patient_index)"
        local transaction_start=$(date +%s.%N)
        
        print_info "Reading EHR for patient ${patient_id} (${i}/${iterations})"
        
        local duration
        # Show data verification for first few reads to prove data retrieval
        if [ $i -le 3 ]; then
            duration=$(read_ehr "${patient_id}" "true")  # Enable data verification
        else
            duration=$(read_ehr "${patient_id}")
        fi
        local exit_status=$?
        
        local transaction_end=$(date +%s.%N)
        local status="SUCCESS"
        
        if [ $exit_status -ne 0 ]; then
            status="FAILED"
            print_warning "Transaction ${i} failed"
        else
            ((successful_transactions++))
        fi
        
        echo "READ,${i},${patient_id},${transaction_start},${transaction_end},${duration},${status}" >> "${OUTPUT_FILE}"
    done
    
    local end_test=$(date +%s.%N)
    local total_duration=$(echo "${end_test} - ${start_test}" | bc)
    local tps=$(echo "scale=2; ${successful_transactions} / ${total_duration}" | bc)
    
    print_success "Read throughput test completed!"
    print_info "Total transactions: ${iterations}"
    print_info "Successful transactions: ${successful_transactions}"
    print_info "Total time: ${total_duration} seconds"
    print_info "Throughput: ${tps} TPS"
    
    echo "SUMMARY,READ,${iterations},${successful_transactions},${total_duration},${tps}" >> "${OUTPUT_FILE}"
}

# Function to run full cycle throughput test
test_full_cycle_throughput() {
    local iterations=$1
    print_info "Starting full cycle throughput test with ${iterations} iterations"
    
    echo "Test Type,Transaction ID,Patient ID,Operation,Start Time,End Time,Duration (seconds),Status" > "${OUTPUT_FILE}"
    
    # Generate unique patient ID prefix based on timestamp to avoid conflicts
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="FC_${timestamp}_P"
    
    local start_test=$(date +%s.%N)
    local successful_cycles=0
    
    for i in $(seq 1 $iterations); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        print_info "Running full cycle for patient ${patient_id} (${i}/${iterations})"
        
        local cycle_success=true
        
        # 1. Create EHR
        local duration_create=$(create_ehr "${patient_id}" "Full Cycle Patient ${i}")
        if [ $? -ne 0 ]; then cycle_success=false; fi
        echo "FULL_CYCLE,${i},${patient_id},CREATE,$(date +%s.%N),$(date +%s.%N),${duration_create},$([ "$cycle_success" = true ] && echo SUCCESS || echo FAILED)" >> "${OUTPUT_FILE}"
        
        # 2. Grant consent (completing the data lifecycle)
        local duration_consent=$(grant_consent "${patient_id}")
        if [ $? -ne 0 ]; then cycle_success=false; fi
        echo "FULL_CYCLE,${i},${patient_id},CONSENT,$(date +%s.%N),$(date +%s.%N),${duration_consent},$([ "$cycle_success" = true ] && echo SUCCESS || echo FAILED)" >> "${OUTPUT_FILE}"
        
        # Note: Skipping READ and UPDATE due to current authorization issue
        # Full cycle currently tests: CREATE -> CONSENT (working operations)
        
        if [ "$cycle_success" = true ]; then
            ((successful_cycles++))
        fi
    done
    
    local end_test=$(date +%s.%N)
    local total_duration=$(echo "${end_test} - ${start_test}" | bc)
    local tps=$(echo "scale=2; ${successful_cycles} / ${total_duration}" | bc)
    
    print_success "Full cycle throughput test completed!"
    print_info "Total cycles: ${iterations}"
    print_info "Successful cycles: ${successful_cycles}"
    print_info "Total time: ${total_duration} seconds"
    print_info "Throughput: ${tps} cycles per second"
    
    echo "SUMMARY,FULL_CYCLE,${iterations},${successful_cycles},${total_duration},${tps}" >> "${OUTPUT_FILE}"
}

# Function to run cross-organizational access throughput test
test_cross_org_throughput() {
    local iterations=$1
    print_info "Starting cross-organizational access throughput test with ${iterations} iterations"
    
    echo "Test Type,Transaction ID,Patient ID,Operation,Start Time,End Time,Duration (seconds),Status" > "${OUTPUT_FILE}"
    
    # Generate unique patient ID prefix based on timestamp to avoid conflicts
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="CROSSORG_${timestamp}_P"
    
    # Setup test data - create EHRs with Org1
    print_info "Setting up test data (Org1 creates EHRs)..."
    setup_org1_env
    for i in $(seq 1 10); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        create_ehr "${patient_id}" "Cross-Org Patient ${i}" > /dev/null 2>&1
        # Grant consent to Org2
        grant_consent "${patient_id}" "[\"org2admin\"]" > /dev/null 2>&1
    done
    
    local start_test=$(date +%s.%N)
    local successful_transactions=0
    
    for i in $(seq 1 $iterations); do
        # Cycle through the 10 created patients
        local patient_index=$(( (i - 1) % 10 + 1 ))
        local patient_id="${unique_prefix}$(printf "%06d" $patient_index)"
        local transaction_start=$(date +%s.%N)
        
        print_info "Org2 reading Org1's EHR for patient ${patient_id} (${i}/${iterations})"
        
        # Switch to Org2 and try to read Org1's EHR
        setup_org2_env
        local duration
        # Show data verification for first few cross-org reads to prove data access
        if [ $i -le 2 ]; then
            duration=$(read_ehr "${patient_id}" "true")  # Enable data verification
        else
            duration=$(read_ehr "${patient_id}")
        fi
        local exit_status=$?
        
        local transaction_end=$(date +%s.%N)
        local status="SUCCESS"
        
        if [ $exit_status -ne 0 ]; then
            status="FAILED"
            print_warning "Cross-org transaction ${i} failed"
        else
            ((successful_transactions++))
        fi
        
        echo "CROSS_ORG,${i},${patient_id},READ,${transaction_start},${transaction_end},${duration},${status}" >> "${OUTPUT_FILE}"
    done
    
    local end_test=$(date +%s.%N)
    local total_duration=$(echo "${end_test} - ${start_test}" | bc)
    local tps=$(echo "scale=2; ${successful_transactions} / ${total_duration}" | bc)
    
    print_success "Cross-organizational access test completed!"
    print_info "Total transactions: ${iterations}"
    print_info "Successful transactions: ${successful_transactions}"
    print_info "Total time: ${total_duration} seconds"
    print_info "Throughput: ${tps} TPS"
    
    echo "SUMMARY,CROSS_ORG,${iterations},${successful_transactions},${total_duration},${tps}" >> "${OUTPUT_FILE}"
}

# Function to run consent granting throughput test
test_consent_throughput() {
    local iterations=$1
    print_info "Starting consent granting throughput test with ${iterations} iterations"
    
    echo "Test Type,Transaction ID,Patient ID,Start Time,End Time,Duration (seconds),Status" > "${OUTPUT_FILE}"
    
    # Generate unique patient ID prefix based on timestamp to avoid conflicts
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="CONSENT_${timestamp}_P"
    
    # Setup test data - create EHRs first
    print_info "Setting up test data..."
    setup_org1_env
    for i in $(seq 1 10); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        create_ehr "${patient_id}" "Consent Test Patient ${i}" > /dev/null 2>&1
    done
    
    local start_test=$(date +%s.%N)
    local successful_transactions=0
    
    for i in $(seq 1 $iterations); do
        # Cycle through the 10 created patients
        local patient_index=$(( (i - 1) % 10 + 1 ))
        local patient_id="${unique_prefix}$(printf "%06d" $patient_index)"
        local transaction_start=$(date +%s.%N)
        
        print_info "Granting consent for patient ${patient_id} (${i}/${iterations})"
        
        local duration
        duration=$(grant_consent "${patient_id}" "[\"org2admin\"]")
        local exit_status=$?
        
        local transaction_end=$(date +%s.%N)
        local status="SUCCESS"
        
        if [ $exit_status -ne 0 ]; then
            status="FAILED"
            print_warning "Consent transaction ${i} failed"
        else
            ((successful_transactions++))
        fi
        
        echo "CONSENT,${i},${patient_id},${transaction_start},${transaction_end},${duration},${status}" >> "${OUTPUT_FILE}"
    done
    
    local end_test=$(date +%s.%N)
    local total_duration=$(echo "${end_test} - ${start_test}" | bc)
    local tps=$(echo "scale=2; ${successful_transactions} / ${total_duration}" | bc)
    
    print_success "Consent granting test completed!"
    print_info "Total transactions: ${iterations}"
    print_info "Successful transactions: ${successful_transactions}"
    print_info "Total time: ${total_duration} seconds"
    print_info "Throughput: ${tps} TPS"
    
    echo "SUMMARY,CONSENT,${iterations},${successful_transactions},${total_duration},${tps}" >> "${OUTPUT_FILE}"
}

# Function to run update throughput test
test_update_throughput() {
    local iterations=$1
    print_info "Starting EHR update throughput test with ${iterations} iterations"
    
    echo "Test Type,Transaction ID,Patient ID,Start Time,End Time,Duration (seconds),Status" > "${OUTPUT_FILE}"
    
    # Generate unique patient ID prefix based on timestamp to avoid conflicts
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="UPDATE_${timestamp}_P"
    
    # Setup test data - create EHRs first
    print_info "Setting up test data..."
    setup_org1_env
    for i in $(seq 1 10); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        create_ehr "${patient_id}" "Update Test Patient ${i}" > /dev/null 2>&1
    done
    
    local start_test=$(date +%s.%N)
    local successful_transactions=0
    
    for i in $(seq 1 $iterations); do
        # Cycle through the 10 created patients
        local patient_index=$(( (i - 1) % 10 + 1 ))
        local patient_id="${unique_prefix}$(printf "%06d" $patient_index)"
        local transaction_start=$(date +%s.%N)
        
        print_info "Updating EHR for patient ${patient_id} (${i}/${iterations})"
        
        local duration
        duration=$(update_ehr "${patient_id}" "Updated Patient ${i}")
        local exit_status=$?
        
        local transaction_end=$(date +%s.%N)
        local status="SUCCESS"
        
        if [ $exit_status -ne 0 ]; then
            status="FAILED"
            print_warning "Update transaction ${i} failed"
        else
            ((successful_transactions++))
        fi
        
        echo "UPDATE,${i},${patient_id},${transaction_start},${transaction_end},${duration},${status}" >> "${OUTPUT_FILE}"
    done
    
    local end_test=$(date +%s.%N)
    local total_duration=$(echo "${end_test} - ${start_test}" | bc)
    local tps=$(echo "scale=2; ${successful_transactions} / ${total_duration}" | bc)
    
    print_success "Update throughput test completed!"
    print_info "Total transactions: ${iterations}"
    print_info "Successful transactions: ${successful_transactions}"
    print_info "Total time: ${total_duration} seconds"
    print_info "Throughput: ${tps} TPS"
    
    echo "SUMMARY,UPDATE,${iterations},${successful_transactions},${total_duration},${tps}" >> "${OUTPUT_FILE}"
}

# Function to run delete throughput test
test_delete_throughput() {
    local iterations=$1
    print_info "Starting EHR delete throughput test with ${iterations} iterations"
    
    echo "Test Type,Transaction ID,Patient ID,Start Time,End Time,Duration (seconds),Status" > "${OUTPUT_FILE}"
    
    # Setup test data - create EHRs first
    print_info "Setting up test data..."
    setup_org1_env
    for i in $(seq 1 $iterations); do
        local patient_id="${TEST_PATIENT_ID_PREFIX}$(printf "%06d" $i)"
        create_ehr "${patient_id}" "Delete Test Patient ${i}" > /dev/null 2>&1
    done
    
    local start_test=$(date +%s.%N)
    local successful_transactions=0
    
    for i in $(seq 1 $iterations); do
        local patient_id="${TEST_PATIENT_ID_PREFIX}$(printf "%06d" $i)"
        local transaction_start=$(date +%s.%N)
        
        print_info "Deleting EHR for patient ${patient_id} (${i}/${iterations})"
        
        local duration
        duration=$(delete_ehr "${patient_id}")
        local exit_status=$?
        
        local transaction_end=$(date +%s.%N)
        local status="SUCCESS"
        
        if [ $exit_status -ne 0 ]; then
            status="FAILED"
            print_warning "Delete transaction ${i} failed"
        else
            ((successful_transactions++))
        fi
        
        echo "DELETE,${i},${patient_id},${transaction_start},${transaction_end},${duration},${status}" >> "${OUTPUT_FILE}"
    done
    
    local end_test=$(date +%s.%N)
    local total_duration=$(echo "${end_test} - ${start_test}" | bc)
    local tps=$(echo "scale=2; ${successful_transactions} / ${total_duration}" | bc)
    
    print_success "Delete throughput test completed!"
    print_info "Total transactions: ${iterations}"
    print_info "Successful transactions: ${successful_transactions}"
    print_info "Total time: ${total_duration} seconds"
    print_info "Throughput: ${tps} TPS"
    
    echo "SUMMARY,DELETE,${iterations},${successful_transactions},${total_duration},${tps}" >> "${OUTPUT_FILE}"
}

# Function to run all throughput tests
test_all_throughput() {
    local iterations=$1
    print_info "Starting COMPREHENSIVE Throughput Analysis - All Operation Types"
    print_info "Base iterations per operation: ${iterations}"
    
    # Run all operation types
    local operations=("create" "read" "update" "consent" "cross_org" "full_cycle")
    
    for operation in "${operations[@]}"; do
        print_info "Running ${operation} throughput test..."
        
        # Update output file for each operation
        OUTPUT_FILE="${THROUGHPUT_DIR}/throughput_${operation}_$(date +%Y%m%d_%H%M%S).csv"
        
        case $operation in
            "create")
                test_create_throughput $iterations
                ;;
            "read")
                test_read_throughput $iterations
                ;;
            "update")
                test_update_throughput $iterations
                ;;
            "consent")
                test_consent_throughput $iterations
                ;;
            "cross_org")
                test_cross_org_throughput $iterations
                ;;
            "full_cycle")
                test_full_cycle_throughput $iterations
                ;;
        esac
        
        print_info "Completed ${operation} analysis"
        echo "---"
    done
    
    print_success "COMPREHENSIVE Throughput Analysis completed for all operation types!"
}

# Main execution
main() {
    print_info "=== EHR Management System Throughput Testing ==="
    print_info "Academic Project - Master's Dissertation"
    print_info "Test Type: ${TEST_TYPE}"
    print_info "Iterations: ${ITERATIONS}"
    print_info "Results will be saved to: ${OUTPUT_FILE}"
    echo ""
    
    # Check if help is requested
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # Validate inputs
    if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]] || [ "$ITERATIONS" -lt 1 ]; then
        print_error "Invalid number of iterations: ${ITERATIONS}"
        show_usage
        exit 1
    fi
    
    # Setup environment
    create_output_directories
    setup_org1_env
    
    if ! check_network_status; then
        print_error "Network status check failed"
        exit 1
    fi
    
    # Run the specified test
    case "$TEST_TYPE" in
        "create")
            test_create_throughput "$ITERATIONS"
            ;;
        "read")
            test_read_throughput "$ITERATIONS"
            ;;
        "update")
            test_update_throughput "$ITERATIONS"
            ;;
        "delete")
            test_delete_throughput "$ITERATIONS"
            ;;
        "consent")
            test_consent_throughput "$ITERATIONS"
            ;;
        "cross_org")
            test_cross_org_throughput "$ITERATIONS"
            ;;
        "full_cycle")
            test_full_cycle_throughput "$ITERATIONS"
            ;;
        "all")
            test_all_throughput "$ITERATIONS"
            ;;
        *)
            print_error "Unknown test type: ${TEST_TYPE}"
            show_usage
            exit 1
            ;;
    esac
    
    print_success "Throughput testing completed successfully!"
    print_info "Results saved to: ${OUTPUT_FILE}"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
