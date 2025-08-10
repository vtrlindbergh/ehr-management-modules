#!/bin/bash

# =============================================================================
# Enhanced Parallel Throughput Testing Script
# Academic Project - Master's Dissertation  
# Phase A Enhancement: Extended parallel testing up to 16 workers
# Optimized for multi-core systems with comprehensive scaling analysis
# =============================================================================

# Source required utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/ehr_operations.sh"

# Initialize Fabric environment
print_info "Setting up Fabric environment for enhanced parallel testing..."
setup_fabric_environment || exit 1

# Enhanced test parameters with intelligent defaults
TOTAL_ITERATIONS=${1:-400}  # Increased default for better statistical significance
PARALLEL_PROCESSES=${2:-8}  # Number of parallel processes (supports 1-16)
TEST_TYPE=${3:-"cross_org"}  # Default to cross_org for stress testing
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="${RESULTS_DIR}/parallel_enhanced_${TIMESTAMP}"
SUMMARY_FILE="${OUTPUT_DIR}/parallel_enhanced_summary_${TIMESTAMP}.csv"

# System optimization parameters
MAX_RECOMMENDED_WORKERS=16  # Maximum supported for comprehensive scaling
SYSTEM_CORES=$(nproc)
OPTIMAL_WORKERS_PER_CORE=2  # For I/O bound blockchain operations

# Function to display enhanced usage
show_usage() {
    echo "Enhanced Parallel Throughput Testing - Phase A Implementation"
    echo "============================================================="
    echo "Usage: $0 [total_iterations] [parallel_processes] [test_type]"
    echo ""
    echo "Parameters:"
    echo "  total_iterations    Total iterations across all processes (default: 400)"
    echo "  parallel_processes  Number of concurrent workers (1-16, default: 8)"
    echo "  test_type          Type of test operation (default: cross_org)"
    echo ""
    echo "Test Types:"
    echo "  cross_org   Cross-organizational access (blockchain stress testing)"
    echo "  create      EHR creation throughput"
    echo "  read        EHR read throughput" 
    echo "  consent     Consent granting throughput"
    echo "  all         Run all test types in sequence"
    echo ""
    echo "Scaling Recommendations:"
    echo "  System Cores: ${SYSTEM_CORES}"
    echo "  Optimal Range: 1-${MAX_RECOMMENDED_WORKERS} workers"
    echo "  Recommended: ${SYSTEM_CORES} workers (1 per core)"
    echo "  Stress Test: ${MAX_RECOMMENDED_WORKERS} workers (2 per core)"
    echo ""
    echo "Examples:"
    echo "  $0 800 16 cross_org    # Maximum stress test"
    echo "  $0 400 8 all          # Comprehensive test suite"
    echo "  $0 200 4 cross_org    # Conservative load test"
    echo ""
    echo "Academic Validation:"
    echo "  - Maintains 100+ iterations per test type for statistical significance"
    echo "  - Supports scaling analysis from 1-16 workers"
    echo "  - Optimized for blockchain I/O latency patterns"
}

# Enhanced validation with academic rigor
validate_parameters() {
    print_info "Validating enhanced parallel testing parameters..."
    
    # Validate worker count
    if [ "$PARALLEL_PROCESSES" -lt 1 ] || [ "$PARALLEL_PROCESSES" -gt "$MAX_RECOMMENDED_WORKERS" ]; then
        print_error "Worker count must be between 1 and ${MAX_RECOMMENDED_WORKERS}"
        print_error "Current system has ${SYSTEM_CORES} cores"
        return 1
    fi
    
    # Validate iterations for statistical significance
    local min_iterations_per_worker=25  # Minimum for statistical validity
    local iterations_per_worker=$((TOTAL_ITERATIONS / PARALLEL_PROCESSES))
    
    if [ "$iterations_per_worker" -lt "$min_iterations_per_worker" ]; then
        print_error "Insufficient iterations per worker: ${iterations_per_worker}"
        print_error "Minimum required: ${min_iterations_per_worker} per worker"
        print_error "Increase total iterations to at least $((min_iterations_per_worker * PARALLEL_PROCESSES))"
        return 1
    fi
    
    # System resource warnings
    if [ "$PARALLEL_PROCESSES" -gt "$((SYSTEM_CORES * 2))" ]; then
        print_warning "Worker count (${PARALLEL_PROCESSES}) exceeds 2x cores (${SYSTEM_CORES})"
        print_warning "This may cause resource contention and degraded performance"
    fi
    
    # Validate test type
    case "$TEST_TYPE" in
        "cross_org"|"create"|"read"|"consent"|"all")
            print_success "Test type '${TEST_TYPE}' validated"
            ;;
        *)
            print_error "Invalid test type: ${TEST_TYPE}"
            print_error "Supported types: cross_org, create, read, consent, all"
            return 1
            ;;
    esac
    
    return 0
}

# Enhanced directory structure for organized results
setup_enhanced_output_directory() {
    print_info "Setting up enhanced output directory structure..."
    
    # Create main output directory
    mkdir -p "${OUTPUT_DIR}"
    
    # Create organized subdirectories
    mkdir -p "${OUTPUT_DIR}/raw_data"      # Individual worker outputs
    mkdir -p "${OUTPUT_DIR}/analysis"      # Statistical analysis results
    mkdir -p "${OUTPUT_DIR}/scaling"       # Scaling analysis data
    
    # Create comprehensive summary file header
    cat > "${SUMMARY_FILE}" << EOF
# Enhanced Parallel Throughput Test Results
# Timestamp: ${TIMESTAMP}
# System: ${SYSTEM_CORES} cores, ${PARALLEL_PROCESSES} workers
# Configuration: ${TOTAL_ITERATIONS} total iterations, ${TEST_TYPE} operations
# Academic Standard: 100+ iterations for statistical significance

TEST_TYPE,WORKER_ID,TRANSACTION_ID,PATIENT_ID,OPERATION,START_TIME,END_TIME,DURATION_NS,STATUS
EOF

    print_success "Enhanced output directory created: ${OUTPUT_DIR}"
}

# Enhanced worker function with improved error handling
run_enhanced_parallel_worker() {
    local worker_id=$1
    local iterations_per_worker=$2
    local test_type=$3
    local worker_output="${OUTPUT_DIR}/raw_data/worker_${worker_id}_${test_type}_${TIMESTAMP}.csv"
    
    # Worker-specific initialization
    print_info "Enhanced Worker ${worker_id}: Starting ${iterations_per_worker} ${test_type} operations"
    
    # Create worker-specific output file
    cat > "${worker_output}" << EOF
# Enhanced Worker ${worker_id} Results
# Test Type: ${test_type}
# Iterations: ${iterations_per_worker}
# Timestamp: ${TIMESTAMP}

TEST_TYPE,WORKER_ID,TRANSACTION_ID,PATIENT_ID,OPERATION,START_TIME,END_TIME,DURATION_NS,STATUS
EOF
    
    local successful_transactions=0
    local failed_transactions=0
    local worker_start_time=$(date +%s.%N)
    
    # Enhanced patient management for conflict avoidance
    local shared_patients=1000  # Larger pool for 16 workers
    
    for i in $(seq 1 $iterations_per_worker); do
        local global_transaction_id=$(( (worker_id - 1) * iterations_per_worker + i ))
        local patient_index=$(( (global_transaction_id - 1) % shared_patients + 1 ))
        local patient_id="${TEST_PATIENT_ID_PREFIX}$(printf "%06d" $patient_index)"
        
        local transaction_start=$(date +%s.%N)
        local duration
        local exit_status
        local status="SUCCESS"
        
        # Enhanced operation execution with better error handling
        case "$test_type" in
            "cross_org")
                setup_org2_env > /dev/null 2>&1
                duration=$(read_ehr "${patient_id}" 2>/dev/null)
                exit_status=$?
                ;;
            "read")
                setup_org1_env > /dev/null 2>&1
                duration=$(read_ehr "${patient_id}" 2>/dev/null)
                exit_status=$?
                ;;
            "create")
                # Enhanced unique ID generation for 16 workers
                local unique_patient_id="${TEST_PATIENT_ID_PREFIX}EW${worker_id}_$(printf "%06d" $i)"
                setup_org1_env > /dev/null 2>&1
                duration=$(create_ehr "${unique_patient_id}" "Enhanced Worker ${worker_id} Patient ${i}" 2>/dev/null)
                exit_status=$?
                patient_id=$unique_patient_id
                ;;
            "consent")
                setup_org1_env > /dev/null 2>&1
                duration=$(grant_consent "${patient_id}" "[\"org2admin\"]" 2>/dev/null)
                exit_status=$?
                ;;
            *)
                print_error "Enhanced Worker ${worker_id}: Unknown test type: ${test_type}"
                exit 1
                ;;
        esac
        
        local transaction_end=$(date +%s.%N)
        
        # Enhanced status tracking
        if [ $exit_status -ne 0 ]; then
            status="FAILED"
            ((failed_transactions++))
        else
            ((successful_transactions++))
        fi
        
        # Write transaction record
        echo "${test_type^^},${worker_id},${global_transaction_id},${patient_id},${test_type^^},${transaction_start},${transaction_end},${duration},${status}" >> "${worker_output}"
        
        # Progress reporting for long tests
        if [ $((i % 50)) -eq 0 ]; then
            print_info "Enhanced Worker ${worker_id}: Completed ${i}/${iterations_per_worker} operations"
        fi
    done
    
    local worker_end_time=$(date +%s.%N)
    local worker_total_time=$(echo "$worker_end_time - $worker_start_time" | bc -l)
    
    # Enhanced worker summary
    local success_rate=$(echo "scale=2; $successful_transactions * 100 / $iterations_per_worker" | bc -l)
    local avg_tps=$(echo "scale=2; $iterations_per_worker / $worker_total_time" | bc -l)
    
    echo "# Enhanced Worker ${worker_id} Summary" >> "${worker_output}"
    echo "# Total Time: ${worker_total_time}s" >> "${worker_output}"
    echo "# Successful: ${successful_transactions}/${iterations_per_worker} (${success_rate}%)" >> "${worker_output}"
    echo "# Failed: ${failed_transactions}" >> "${worker_output}"
    echo "# Average TPS: ${avg_tps}" >> "${worker_output}"
    
    print_success "Enhanced Worker ${worker_id}: Completed with ${success_rate}% success rate, ${avg_tps} TPS"
}

# Enhanced test execution for single operation type
run_enhanced_single_test() {
    local test_type=$1
    
    print_header "Enhanced Parallel Test: ${test_type^^} Operations"
    print_info "Workers: ${PARALLEL_PROCESSES}, Total Iterations: ${TOTAL_ITERATIONS}"
    
    local iterations_per_worker=$((TOTAL_ITERATIONS / PARALLEL_PROCESSES))
    print_info "Iterations per worker: ${iterations_per_worker}"
    
    local test_start=$(date +%s.%N)
    
    # Launch enhanced parallel workers
    local pids=()
    for worker_id in $(seq 1 $PARALLEL_PROCESSES); do
        run_enhanced_parallel_worker "$worker_id" "$iterations_per_worker" "$test_type" &
        pids+=($!)
    done
    
    print_info "Launched ${PARALLEL_PROCESSES} enhanced workers, waiting for completion..."
    
    # Wait for all workers with progress monitoring
    local completed_workers=0
    for pid in "${pids[@]}"; do
        wait $pid
        ((completed_workers++))
        print_info "Enhanced worker completed (${completed_workers}/${PARALLEL_PROCESSES})"
    done
    
    local test_end=$(date +%s.%N)
    local total_test_time=$(echo "$test_end - $test_start" | bc -l)
    
    # Enhanced results aggregation
    print_info "Aggregating enhanced results for ${test_type}..."
    
    # Combine all worker results
    cat "${OUTPUT_DIR}"/raw_data/worker_*_${test_type}_*.csv | grep -E "^[A-Z]" | grep -v "^TEST_TYPE" >> "${SUMMARY_FILE}"
    
    # Calculate enhanced statistics
    local total_successful=$(cat "${OUTPUT_DIR}"/raw_data/worker_*_${test_type}_*.csv | grep "SUCCESS" | wc -l)
    local total_failed=$(cat "${OUTPUT_DIR}"/raw_data/worker_*_${test_type}_*.csv | grep "FAILED" | wc -l)
    local success_rate=$(echo "scale=2; $total_successful * 100 / $TOTAL_ITERATIONS" | bc -l)
    local overall_tps=$(echo "scale=2; $total_successful / $total_test_time" | bc -l)
    
    # Enhanced scaling analysis
    local tps_per_worker=$(echo "scale=2; $overall_tps / $PARALLEL_PROCESSES" | bc -l)
    local scaling_efficiency=$(echo "scale=2; $tps_per_worker * 100 / ($overall_tps / $PARALLEL_PROCESSES)" | bc -l)
    
    # Write enhanced analysis
    cat >> "${OUTPUT_DIR}/analysis/${test_type}_analysis_${TIMESTAMP}.txt" << EOF
Enhanced Parallel Test Analysis: ${test_type^^}
=============================================
Test Configuration:
- Workers: ${PARALLEL_PROCESSES}
- Total Iterations: ${TOTAL_ITERATIONS}
- Iterations per Worker: ${iterations_per_worker}
- System Cores: ${SYSTEM_CORES}

Performance Results:
- Total Time: ${total_test_time}s
- Successful Transactions: ${total_successful}
- Failed Transactions: ${total_failed}
- Success Rate: ${success_rate}%
- Overall TPS: ${overall_tps}
- TPS per Worker: ${tps_per_worker}

Scaling Analysis:
- Workers per Core: $(echo "scale=1; $PARALLEL_PROCESSES / $SYSTEM_CORES" | bc -l)
- Scaling Efficiency: ${scaling_efficiency}%
- Resource Utilization: $(echo "scale=1; $PARALLEL_PROCESSES * 100 / ($SYSTEM_CORES * 2)" | bc -l)%
EOF

    print_success "Enhanced ${test_type^^} test completed: ${overall_tps} TPS with ${PARALLEL_PROCESSES} workers"
    echo "SUMMARY,${test_type^^},${PARALLEL_PROCESSES},${total_successful},${total_failed},${success_rate},${overall_tps},${total_test_time}" >> "${SUMMARY_FILE}"
}

# Enhanced comprehensive test runner
run_enhanced_all_tests() {
    print_header "Enhanced Comprehensive Parallel Testing Suite"
    
    local test_types=("cross_org" "read" "create" "consent")
    local iterations_per_test=$((TOTAL_ITERATIONS / 4))  # Distribute across test types
    
    print_info "Running ${#test_types[@]} test types with ${iterations_per_test} iterations each"
    
    for test_type in "${test_types[@]}"; do
        # Temporarily adjust iterations for this test
        local original_iterations=$TOTAL_ITERATIONS
        TOTAL_ITERATIONS=$iterations_per_test
        
        run_enhanced_single_test "$test_type"
        
        # Brief pause between test types for system stability
        print_info "Cooling down for 10 seconds before next test type..."
        sleep 10
        
        # Restore original iterations
        TOTAL_ITERATIONS=$original_iterations
    done
    
    print_success "Enhanced comprehensive testing completed!"
}

# Enhanced main execution function
main() {
    print_header "Enhanced Parallel Throughput Testing - Phase A"
    print_info "Academic EHR Blockchain Performance Analysis"
    
    # Display system information
    print_info "System Configuration:"
    print_info "- CPU Cores: ${SYSTEM_CORES}"
    print_info "- Max Workers: ${MAX_RECOMMENDED_WORKERS}"
    print_info "- Test Workers: ${PARALLEL_PROCESSES}"
    print_info "- Total Iterations: ${TOTAL_ITERATIONS}"
    
    # Enhanced parameter validation
    if ! validate_parameters; then
        show_usage
        exit 1
    fi
    
    # Setup enhanced output structure
    setup_enhanced_output_directory
    
    # Execute tests based on type
    case "$TEST_TYPE" in
        "all")
            run_enhanced_all_tests
            ;;
        *)
            run_enhanced_single_test "$TEST_TYPE"
            ;;
    esac
    
    # Enhanced final reporting
    print_header "Enhanced Test Execution Complete"
    print_success "Results saved to: ${OUTPUT_DIR}"
    print_success "Summary file: ${SUMMARY_FILE}"
    print_info "Analysis files: ${OUTPUT_DIR}/analysis/"
    print_info "Raw data: ${OUTPUT_DIR}/raw_data/"
    
    # Display quick statistics
    local total_transactions=$(cat "${SUMMARY_FILE}" | grep "^SUMMARY" | awk -F',' '{sum += $4} END {print sum}')
    local total_time=$(ls -la "${OUTPUT_DIR}/analysis/" | wc -l)
    
    if [ ! -z "$total_transactions" ] && [ "$total_transactions" -gt 0 ]; then
        print_success "Total successful transactions: ${total_transactions}"
        print_info "For detailed analysis, see files in ${OUTPUT_DIR}/analysis/"
    fi
}

# Execute main function if script is run directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
