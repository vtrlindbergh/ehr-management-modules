#!/bin/bash

# =============================================================================
# Throughput Testing Script — CLOUD VERSION
# Academic Project - Master's Dissertation
#
# Adapted from scripts/performance/throughput_test.sh for distributed
# cloud deployment across 3 Azure VMs with Docker Swarm overlay network.
#
# SAME test logic, SAME CSV format, SAME TPS calculation methodology.
# Only infrastructure changes: transactions cross real Azure VNet subnets.
#
# Run this script FROM the Org1 VM (10.0.2.4 / 20.88.52.252)
# =============================================================================

# Source cloud utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/ehr_operations.sh"

# Initialize Fabric environment
print_info "Setting up Cloud Fabric environment..."
setup_fabric_environment || exit 1

# Test parameters
ITERATIONS=${1:-$DEFAULT_TEST_ITERATIONS}
TEST_TYPE=${2:-"create"}
THROUGHPUT_DIR="${RESULTS_DIR}/throughput_analysis"
mkdir -p "$THROUGHPUT_DIR"
OUTPUT_FILE="${THROUGHPUT_DIR}/throughput_test_$(date +%Y%m%d_%H%M%S).csv"

# Function to display usage
show_usage() {
    echo "Usage: $0 [iterations] [test_type]"
    echo ""
    echo "Cloud Throughput Testing — Distributed 3-VM Deployment"
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
    echo "Cloud Environment:"
    echo "  Orderer:  ${ORDERER_VM_IP}:7050  (VM1)"
    echo "  Org1:     ${ORG1_VM_IP}:7051     (VM2 — run scripts here)"
    echo "  Org2:     ${ORG2_VM_IP}:9051     (VM3)"
}

# =============================================================================
# Throughput Test Functions (same logic as local, sources cloud config)
# =============================================================================

test_create_throughput() {
    local iterations=$1
    print_info "Starting EHR creation throughput test with ${iterations} iterations (CLOUD)"

    echo "Test Type,Transaction ID,Patient ID,Start Time,End Time,Duration (seconds),Status" > "${OUTPUT_FILE}"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="CLOUD_CREATE_${timestamp}_P"

    local start_test=$(date +%s.%N)
    local successful_transactions=0

    for i in $(seq 1 $iterations); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        local transaction_start=$(date +%s.%N)

        print_info "Creating EHR for patient ${patient_id} (${i}/${iterations})"

        local duration
        duration=$(create_ehr "${patient_id}" "Cloud Test Patient ${i}")
        local exit_status=$?

        local transaction_end=$(date +%s.%N)
        local status="SUCCESS"

        if [ $exit_status -ne 0 ]; then
            status="FAILED"
            print_warning "Transaction ${i} failed"
        else
            ((successful_transactions++))
        fi

        echo "CREATE,${i},${patient_id},${transaction_start},${transaction_end},${duration},${status}" >> "${OUTPUT_FILE}"
    done

    local end_test=$(date +%s.%N)
    local total_duration=$(echo "${end_test} - ${start_test}" | bc)
    local tps=$(echo "scale=2; ${successful_transactions} / ${total_duration}" | bc)

    print_success "Create throughput test completed! (CLOUD)"
    print_info "Total transactions: ${iterations}"
    print_info "Successful transactions: ${successful_transactions}"
    print_info "Total time: ${total_duration} seconds"
    print_info "Throughput: ${tps} TPS"

    echo "SUMMARY,CREATE,${iterations},${successful_transactions},${total_duration},${tps}" >> "${OUTPUT_FILE}"
}

test_read_throughput() {
    local iterations=$1
    print_info "Starting EHR read throughput test with ${iterations} iterations (CLOUD)"

    echo "Test Type,Transaction ID,Patient ID,Start Time,End Time,Duration (seconds),Status" > "${OUTPUT_FILE}"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="CLOUD_READ_${timestamp}_P"

    print_info "Setting up test data..."
    for i in $(seq 1 10); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        create_ehr "${patient_id}" "Cloud Setup Patient ${i}" > /dev/null 2>&1
        grant_consent "${patient_id}" > /dev/null 2>&1
    done

    local start_test=$(date +%s.%N)
    local successful_transactions=0

    for i in $(seq 1 $iterations); do
        local patient_index=$(( (i - 1) % 10 + 1 ))
        local patient_id="${unique_prefix}$(printf "%06d" $patient_index)"
        local transaction_start=$(date +%s.%N)

        print_info "Reading EHR for patient ${patient_id} (${i}/${iterations})"

        local duration
        if [ $i -le 3 ]; then
            duration=$(read_ehr "${patient_id}" "true")
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

    print_success "Read throughput test completed! (CLOUD)"
    print_info "Total transactions: ${iterations}"
    print_info "Successful transactions: ${successful_transactions}"
    print_info "Total time: ${total_duration} seconds"
    print_info "Throughput: ${tps} TPS"

    echo "SUMMARY,READ,${iterations},${successful_transactions},${total_duration},${tps}" >> "${OUTPUT_FILE}"
}

test_update_throughput() {
    local iterations=$1
    print_info "Starting EHR update throughput test with ${iterations} iterations (CLOUD)"

    echo "Test Type,Transaction ID,Patient ID,Start Time,End Time,Duration (seconds),Status" > "${OUTPUT_FILE}"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="CLOUD_UPDATE_${timestamp}_P"

    print_info "Setting up test data..."
    setup_org1_env
    for i in $(seq 1 10); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        create_ehr "${patient_id}" "Cloud Update Test Patient ${i}" > /dev/null 2>&1
    done

    local start_test=$(date +%s.%N)
    local successful_transactions=0

    for i in $(seq 1 $iterations); do
        local patient_index=$(( (i - 1) % 10 + 1 ))
        local patient_id="${unique_prefix}$(printf "%06d" $patient_index)"
        local transaction_start=$(date +%s.%N)

        print_info "Updating EHR for patient ${patient_id} (${i}/${iterations})"

        local duration
        duration=$(update_ehr "${patient_id}" "Cloud Updated Patient ${i}")
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

    print_success "Update throughput test completed! (CLOUD)"
    print_info "Total transactions: ${iterations}"
    print_info "Successful transactions: ${successful_transactions}"
    print_info "Total time: ${total_duration} seconds"
    print_info "Throughput: ${tps} TPS"

    echo "SUMMARY,UPDATE,${iterations},${successful_transactions},${total_duration},${tps}" >> "${OUTPUT_FILE}"
}

test_delete_throughput() {
    local iterations=$1
    print_info "Starting EHR delete throughput test with ${iterations} iterations (CLOUD)"

    echo "Test Type,Transaction ID,Patient ID,Start Time,End Time,Duration (seconds),Status" > "${OUTPUT_FILE}"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="CLOUD_DELETE_${timestamp}_P"

    print_info "Setting up test data..."
    setup_org1_env
    for i in $(seq 1 $iterations); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        create_ehr "${patient_id}" "Cloud Delete Test Patient ${i}" > /dev/null 2>&1
    done

    local start_test=$(date +%s.%N)
    local successful_transactions=0

    for i in $(seq 1 $iterations); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
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

    print_success "Delete throughput test completed! (CLOUD)"
    print_info "Total transactions: ${iterations}"
    print_info "Successful transactions: ${successful_transactions}"
    print_info "Total time: ${total_duration} seconds"
    print_info "Throughput: ${tps} TPS"

    echo "SUMMARY,DELETE,${iterations},${successful_transactions},${total_duration},${tps}" >> "${OUTPUT_FILE}"
}

test_consent_throughput() {
    local iterations=$1
    print_info "Starting consent granting throughput test with ${iterations} iterations (CLOUD)"

    echo "Test Type,Transaction ID,Patient ID,Start Time,End Time,Duration (seconds),Status" > "${OUTPUT_FILE}"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="CLOUD_CONSENT_${timestamp}_P"

    print_info "Setting up test data..."
    setup_org1_env
    for i in $(seq 1 10); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        create_ehr "${patient_id}" "Cloud Consent Test Patient ${i}" > /dev/null 2>&1
    done

    local start_test=$(date +%s.%N)
    local successful_transactions=0

    for i in $(seq 1 $iterations); do
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

    print_success "Consent granting test completed! (CLOUD)"
    print_info "Total transactions: ${iterations}"
    print_info "Successful transactions: ${successful_transactions}"
    print_info "Total time: ${total_duration} seconds"
    print_info "Throughput: ${tps} TPS"

    echo "SUMMARY,CONSENT,${iterations},${successful_transactions},${total_duration},${tps}" >> "${OUTPUT_FILE}"
}

test_cross_org_throughput() {
    local iterations=$1
    print_info "Starting cross-organizational access throughput test with ${iterations} iterations (CLOUD)"

    echo "Test Type,Transaction ID,Patient ID,Operation,Start Time,End Time,Duration (seconds),Status" > "${OUTPUT_FILE}"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="CLOUD_CROSSORG_${timestamp}_P"

    print_info "Setting up test data (Org1 creates EHRs)..."
    setup_org1_env
    for i in $(seq 1 10); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        create_ehr "${patient_id}" "Cloud Cross-Org Patient ${i}" > /dev/null 2>&1
        grant_consent "${patient_id}" "[\"org2admin\"]" > /dev/null 2>&1
    done

    local start_test=$(date +%s.%N)
    local successful_transactions=0

    for i in $(seq 1 $iterations); do
        local patient_index=$(( (i - 1) % 10 + 1 ))
        local patient_id="${unique_prefix}$(printf "%06d" $patient_index)"
        local transaction_start=$(date +%s.%N)

        print_info "Org2 reading Org1's EHR for patient ${patient_id} (${i}/${iterations})"

        setup_org2_env
        local duration
        if [ $i -le 2 ]; then
            duration=$(read_ehr "${patient_id}" "true")
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

    print_success "Cross-organizational access test completed! (CLOUD)"
    print_info "Total transactions: ${iterations}"
    print_info "Successful transactions: ${successful_transactions}"
    print_info "Total time: ${total_duration} seconds"
    print_info "Throughput: ${tps} TPS"

    echo "SUMMARY,CROSS_ORG,${iterations},${successful_transactions},${total_duration},${tps}" >> "${OUTPUT_FILE}"
}

test_full_cycle_throughput() {
    local iterations=$1
    print_info "Starting full cycle throughput test with ${iterations} iterations (CLOUD)"

    echo "Test Type,Transaction ID,Patient ID,Operation,Start Time,End Time,Duration (seconds),Status" > "${OUTPUT_FILE}"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="CLOUD_FC_${timestamp}_P"

    local start_test=$(date +%s.%N)
    local successful_cycles=0

    for i in $(seq 1 $iterations); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        print_info "Running full cycle for patient ${patient_id} (${i}/${iterations})"

        local cycle_success=true

        local duration_create=$(create_ehr "${patient_id}" "Cloud Full Cycle Patient ${i}")
        if [ $? -ne 0 ]; then cycle_success=false; fi
        echo "FULL_CYCLE,${i},${patient_id},CREATE,$(date +%s.%N),$(date +%s.%N),${duration_create},$([ "$cycle_success" = true ] && echo SUCCESS || echo FAILED)" >> "${OUTPUT_FILE}"

        local duration_consent=$(grant_consent "${patient_id}")
        if [ $? -ne 0 ]; then cycle_success=false; fi
        echo "FULL_CYCLE,${i},${patient_id},CONSENT,$(date +%s.%N),$(date +%s.%N),${duration_consent},$([ "$cycle_success" = true ] && echo SUCCESS || echo FAILED)" >> "${OUTPUT_FILE}"

        if [ "$cycle_success" = true ]; then
            ((successful_cycles++))
        fi
    done

    local end_test=$(date +%s.%N)
    local total_duration=$(echo "${end_test} - ${start_test}" | bc)
    local tps=$(echo "scale=2; ${successful_cycles} / ${total_duration}" | bc)

    print_success "Full cycle throughput test completed! (CLOUD)"
    print_info "Total cycles: ${iterations}"
    print_info "Successful cycles: ${successful_cycles}"
    print_info "Total time: ${total_duration} seconds"
    print_info "Throughput: ${tps} cycles per second"

    echo "SUMMARY,FULL_CYCLE,${iterations},${successful_cycles},${total_duration},${tps}" >> "${OUTPUT_FILE}"
}

test_all_throughput() {
    local iterations=$1
    print_info "Starting COMPREHENSIVE Throughput Analysis — All Operation Types (CLOUD)"
    print_info "Base iterations per operation: ${iterations}"

    local operations=("create" "read" "update" "consent" "cross_org" "full_cycle")

    for operation in "${operations[@]}"; do
        print_info "Running ${operation} throughput test..."

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

    print_success "COMPREHENSIVE Throughput Analysis completed for all operation types! (CLOUD)"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    print_header "Cloud EHR Throughput Testing"
    print_info "Deployment: 3 Azure VMs (${VM_SIZE}), Docker Swarm overlay"
    print_info "Test Type: ${TEST_TYPE}"
    print_info "Iterations: ${ITERATIONS}"
    print_info "Orderer: ${ORDERER_ENDPOINT} | Org1: ${PEER0_ORG1_ENDPOINT} | Org2: ${PEER0_ORG2_ENDPOINT}"
    print_info "Results will be saved to: ${OUTPUT_FILE}"
    echo ""

    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi

    if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]] || [ "$ITERATIONS" -lt 1 ]; then
        print_error "Invalid number of iterations: ${ITERATIONS}"
        show_usage
        exit 1
    fi

    create_output_directories
    setup_org1_env

    if ! check_network_status; then
        print_error "Cloud network status check failed"
        exit 1
    fi

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

    print_success "Cloud throughput testing completed successfully!"
    print_info "Results saved to: ${OUTPUT_FILE}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
