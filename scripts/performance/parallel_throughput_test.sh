#!/bin/bash

# =============================================================================
# Parallel Throughput Testing Script
# Academic Project - Master's Dissertation
# Tests EHR system parallel throughput using multiple concurrent processes
# Optimized for 8-core systems with cross-organizational stress testing
# =============================================================================

# Source required utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/ehr_operations.sh"

# Initialize Fabric environment
print_info "Setting up Fabric environment for parallel testing..."
setup_org1_env

# Test parameters
TOTAL_ITERATIONS=${1:-200}  # Total iterations across all parallel processes
PARALLEL_PROCESSES=${2:-8}  # Number of parallel processes (default: 8 for 8-core)
TEST_TYPE=${3:-"cross_org"}  # Focuses on cross_org by default for stress testing
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="${RESULTS_DIR}/parallel_${TIMESTAMP}"
SUMMARY_FILE="${OUTPUT_DIR}/parallel_summary_${TIMESTAMP}.csv"

# Function to display usage
show_usage() {
    echo "Usage: $0 [total_iterations] [parallel_processes] [test_type]"
    echo ""
    echo "Parameters:"
    echo "  total_iterations    Total iterations across all processes (default: 200)"
    echo "  parallel_processes  Number of concurrent processes (default: 8)"
    echo "  test_type          Type of test to run (default: cross_org)"
    echo ""
    echo "Test Types:"
    echo "  cross_org   Cross-organizational access (recommended for stress testing)"
    echo "  create      EHR creation throughput"
    echo "  read        EHR read throughput"
    echo "  consent     Consent granting throughput"
    echo ""
    echo "Examples:"
    echo "  $0 400 8 cross_org    # 400 total iterations, 8 parallel processes"
    echo "  $0 200 4 cross_org    # 200 total iterations, 4 parallel processes"
    echo "  $0 100 8 read         # 100 read operations, 8 parallel processes"
    echo ""
    echo "System Requirements:"
    echo "  - Multi-core CPU (recommended: 8+ cores)"
    echo "  - Sufficient memory for concurrent Fabric clients"
    echo "  - Hyperledger Fabric network with EHR chaincode deployed"
}

# Function to setup shared test data for parallel access
setup_shared_test_data() {
    local num_patients=$1
    print_info "Setting up shared test data for parallel access (${num_patients} patients)..."
    
    # Switch to Org1 to create base data
    setup_org1_env
    
    for i in $(seq 1 $num_patients); do
        local patient_id="${TEST_PATIENT_ID_PREFIX}$(printf "%06d" $i)"
        print_info "Creating shared patient ${i}/${num_patients}: ${patient_id}"
        
        # Create EHR as Org1
        create_ehr "${patient_id}" "Parallel Test Patient ${i}" > /dev/null 2>&1
        local create_result=$?
        
        if [ $create_result -eq 0 ]; then
            # Grant consent to Org2 for cross-org access
            grant_consent "${patient_id}" "[\"org2admin\"]" > /dev/null 2>&1
            local consent_result=$?
            
            if [ $consent_result -ne 0 ]; then
                print_warning "Failed to grant consent for patient ${patient_id}"
            fi
        else
            print_warning "Failed to create EHR for patient ${patient_id}"
        fi
    done
    
    print_success "Shared test data setup completed!"
}

# Function to run a single parallel worker process
run_parallel_worker() {
    local worker_id=$1
    local iterations_per_worker=$2
    local test_type=$3
    local shared_patients=$4
    local worker_output="${OUTPUT_DIR}/worker_${worker_id}_${TIMESTAMP}.csv"
    
    echo "Test Type,Worker ID,Transaction ID,Patient ID,Operation,Start Time,End Time,Duration (seconds),Status" > "${worker_output}"
    
    print_info "Worker ${worker_id}: Starting ${iterations_per_worker} iterations of ${test_type}"
    
    local successful_transactions=0
    local worker_start=$(date +%s.%N)
    
    for i in $(seq 1 $iterations_per_worker); do
        local global_transaction_id=$(( (worker_id - 1) * iterations_per_worker + i ))
        
        # Generate patient ID based on test type
        local patient_id
        if [ "$shared_patients" -gt 0 ]; then
            local patient_index=$(( (global_transaction_id - 1) % shared_patients + 1 ))
            patient_id="${TEST_PATIENT_ID_PREFIX}$(printf "%06d" $patient_index)"
        else
            # For create tests, use unique patient IDs
            patient_id="${TEST_PATIENT_ID_PREFIX}$(printf "%06d" $global_transaction_id)"
        fi
        
        local transaction_start=$(date +%s.%N)
        local duration
        local exit_status
        local status="SUCCESS"
        
        case "$test_type" in
            "cross_org")
                # Switch to Org2 for cross-org access
                setup_org2_env > /dev/null 2>&1
                duration=$(read_ehr "${patient_id}" 2>/dev/null)
                exit_status=$?
                ;;
            "read")
                # Stay as Org1 for same-org read
                setup_org1_env > /dev/null 2>&1
                duration=$(read_ehr "${patient_id}" 2>/dev/null)
                exit_status=$?
                ;;
            "create")
                # Create unique patients for each worker to avoid conflicts
                local unique_patient_id="${TEST_PATIENT_ID_PREFIX}W${worker_id}_$(printf "%06d" $i)"
                setup_org1_env > /dev/null 2>&1
                duration=$(create_ehr "${unique_patient_id}" "Worker ${worker_id} Patient ${i}" 2>/dev/null)
                exit_status=$?
                patient_id=$unique_patient_id
                ;;
            "consent")
                setup_org1_env > /dev/null 2>&1
                duration=$(grant_consent "${patient_id}" "[\"org2admin\"]" 2>/dev/null)
                exit_status=$?
                ;;
            *)
                print_error "Worker ${worker_id}: Unknown test type: ${test_type}"
                exit 1
                ;;
        esac
        
        local transaction_end=$(date +%s.%N)
        
        if [ $exit_status -ne 0 ]; then
            status="FAILED"
        else
            ((successful_transactions++))
        fi
        
        echo "${test_type^^},${worker_id},${global_transaction_id},${patient_id},${test_type^^},${transaction_start},${transaction_end},${duration},${status}" >> "${worker_output}"
        
        # Progress indicator every 10 transactions
        if [ $((i % 10)) -eq 0 ]; then
            print_info "Worker ${worker_id}: Completed ${i}/${iterations_per_worker} transactions"
        fi
    done
    
    local worker_end=$(date +%s.%N)
    local worker_duration=$(echo "${worker_end} - ${worker_start}" | bc)
    local worker_tps=$(echo "scale=2; ${successful_transactions} / ${worker_duration}" | bc)
    
    # Write worker summary
    echo "WORKER_SUMMARY,${worker_id},${iterations_per_worker},${successful_transactions},${worker_duration},${worker_tps}" >> "${worker_output}"
    
    print_success "Worker ${worker_id}: Completed ${successful_transactions}/${iterations_per_worker} transactions (${worker_tps} TPS)"
}

# Function to aggregate results from all workers
aggregate_results() {
    print_info "Aggregating results from ${PARALLEL_PROCESSES} workers..."
    
    echo "Summary Type,Total Processes,Total Iterations,Total Successful,Total Duration,Total TPS,Avg TPS per Worker" > "${SUMMARY_FILE}"
    
    local total_successful=0
    local total_transactions=0
    local min_duration=999999
    local max_duration=0
    local worker_tps_sum=0
    
    # Process each worker's results
    for worker_id in $(seq 1 $PARALLEL_PROCESSES); do
        local worker_file="${OUTPUT_DIR}/worker_${worker_id}_${TIMESTAMP}.csv"
        
        if [ -f "$worker_file" ]; then
            # Extract worker summary line
            local worker_summary=$(grep "WORKER_SUMMARY" "$worker_file")
            if [ -n "$worker_summary" ]; then
                local worker_successful=$(echo "$worker_summary" | cut -d',' -f4)
                local worker_iterations=$(echo "$worker_summary" | cut -d',' -f3)
                local worker_duration=$(echo "$worker_summary" | cut -d',' -f5)
                local worker_tps=$(echo "$worker_summary" | cut -d',' -f6)
                
                total_successful=$((total_successful + worker_successful))
                total_transactions=$((total_transactions + worker_iterations))
                worker_tps_sum=$(echo "${worker_tps_sum} + ${worker_tps}" | bc)
                
                # Track min/max duration for parallel execution analysis
                if (( $(echo "${worker_duration} < ${min_duration}" | bc -l) )); then
                    min_duration=$worker_duration
                fi
                if (( $(echo "${worker_duration} > ${max_duration}" | bc -l) )); then
                    max_duration=$worker_duration
                fi
            fi
        fi
    done
    
    # Calculate aggregate metrics
    local avg_worker_tps=$(echo "scale=2; ${worker_tps_sum} / ${PARALLEL_PROCESSES}" | bc)
    local total_tps=$(echo "scale=2; ${total_successful} / ${max_duration}" | bc)  # Based on longest worker
    
    # Write summary
    echo "PARALLEL_SUMMARY,${PARALLEL_PROCESSES},${total_transactions},${total_successful},${max_duration},${total_tps},${avg_worker_tps}" >> "${SUMMARY_FILE}"
    
    # Create consolidated results file
    local consolidated_file="${OUTPUT_DIR}/consolidated_results_${TIMESTAMP}.csv"
    echo "Test Type,Worker ID,Transaction ID,Patient ID,Operation,Start Time,End Time,Duration (seconds),Status" > "${consolidated_file}"
    
    for worker_id in $(seq 1 $PARALLEL_PROCESSES); do
        local worker_file="${OUTPUT_DIR}/worker_${worker_id}_${TIMESTAMP}.csv"
        if [ -f "$worker_file" ]; then
            # Skip header and summary lines
            tail -n +2 "$worker_file" | grep -v "WORKER_SUMMARY" >> "$consolidated_file"
        fi
    done
    
    print_success "Results aggregated successfully!"
    print_info "Total transactions: ${total_transactions}"
    print_info "Successful transactions: ${total_successful}"
    print_info "Parallel processes: ${PARALLEL_PROCESSES}"
    print_info "Total throughput: ${total_tps} TPS"
    print_info "Average TPS per worker: ${avg_worker_tps} TPS"
    print_info "Results saved to: ${OUTPUT_DIR}/"
}

# Main execution function
main() {
    print_info "=== EHR Management Parallel Throughput Testing ==="
    print_info "Academic Project - Master's Dissertation"
    print_info "Test Type: ${TEST_TYPE}"
    print_info "Total Iterations: ${TOTAL_ITERATIONS}"
    print_info "Parallel Processes: ${PARALLEL_PROCESSES}"
    print_info "Results will be saved to: ${OUTPUT_DIR}/"
    echo ""
    
    # Check if help is requested
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # Validate inputs
    if ! [[ "$TOTAL_ITERATIONS" =~ ^[0-9]+$ ]] || [ "$TOTAL_ITERATIONS" -lt 1 ]; then
        print_error "Invalid number of total iterations: ${TOTAL_ITERATIONS}"
        show_usage
        exit 1
    fi
    
    if ! [[ "$PARALLEL_PROCESSES" =~ ^[0-9]+$ ]] || [ "$PARALLEL_PROCESSES" -lt 1 ] || [ "$PARALLEL_PROCESSES" -gt 16 ]; then
        print_error "Invalid number of parallel processes: ${PARALLEL_PROCESSES} (must be 1-16)"
        show_usage
        exit 1
    fi
    
    # Calculate iterations per worker
    local iterations_per_worker=$((TOTAL_ITERATIONS / PARALLEL_PROCESSES))
    local remaining_iterations=$((TOTAL_ITERATIONS % PARALLEL_PROCESSES))
    
    if [ $iterations_per_worker -lt 1 ]; then
        print_error "Too many parallel processes for the number of iterations"
        print_error "Each worker must have at least 1 iteration"
        exit 1
    fi
    
    print_info "Iterations per worker: ${iterations_per_worker} (${remaining_iterations} extra iterations for first workers)"
    
    # Setup environment
    mkdir -p "${OUTPUT_DIR}"
    setup_org1_env
    
    if ! check_network_status; then
        print_error "Network status check failed"
        exit 1
    fi
    
    # Setup shared test data for cross_org and read tests
    local shared_patients=50  # More patients for better distribution across workers
    if [[ "$TEST_TYPE" == "cross_org" || "$TEST_TYPE" == "read" || "$TEST_TYPE" == "consent" ]]; then
        setup_shared_test_data $shared_patients
    else
        shared_patients=0  # Not needed for create tests
    fi
    
    # Start parallel workers
    print_info "Starting ${PARALLEL_PROCESSES} parallel workers..."
    local worker_pids=()
    
    for worker_id in $(seq 1 $PARALLEL_PROCESSES); do
        local worker_iterations=$iterations_per_worker
        
        # Distribute remaining iterations to first workers
        if [ $worker_id -le $remaining_iterations ]; then
            worker_iterations=$((worker_iterations + 1))
        fi
        
        print_info "Starting worker ${worker_id} with ${worker_iterations} iterations..."
        
        # Run worker in background
        run_parallel_worker "$worker_id" "$worker_iterations" "$TEST_TYPE" "$shared_patients" &
        worker_pids+=($!)
    done
    
    # Wait for all workers to complete
    print_info "Waiting for all workers to complete..."
    local failed_workers=0
    
    for i in "${!worker_pids[@]}"; do
        local worker_id=$((i + 1))
        local pid=${worker_pids[$i]}
        
        wait $pid
        local worker_exit_code=$?
        
        if [ $worker_exit_code -ne 0 ]; then
            print_error "Worker ${worker_id} failed with exit code ${worker_exit_code}"
            ((failed_workers++))
        fi
    done
    
    if [ $failed_workers -gt 0 ]; then
        print_warning "${failed_workers} workers failed"
    fi
    
    # Aggregate and analyze results
    aggregate_results
    
    print_success "Parallel throughput testing completed!"
    print_info "Check ${OUTPUT_DIR}/ for detailed results"
    print_info "Summary: ${SUMMARY_FILE}"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
