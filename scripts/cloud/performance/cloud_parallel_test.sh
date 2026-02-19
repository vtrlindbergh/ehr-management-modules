#!/bin/bash

# =============================================================================
# Parallel Throughput Testing Script — CLOUD VERSION
# Academic Project - Master's Dissertation
#
# Adapted from scripts/performance/parallel_test.sh for distributed
# cloud deployment across 3 Azure VMs with Docker Swarm overlay network.
#
# SAME methodology, SAME CSV format, SAME scaling analysis.
# NOTE: Cloud VMs have fewer cores (1 vCPU each on B1ms), so parallel
# scaling behavior will differ from local (multi-core laptop).
# This is expected and valuable for the dissertation comparison.
#
# Run this script FROM the Org1 VM (10.0.2.4 / 20.88.52.252)
# =============================================================================

# Source cloud utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/ehr_operations.sh"

# Check for help flag first (before environment setup)
if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "help" ]]; then
    SYSTEM_CORES=$(nproc)
    MAX_RECOMMENDED_WORKERS=8  # Lower than local due to VM resource constraints

    echo "Cloud Parallel Throughput Testing"
    echo "================================="
    echo "Usage: $0 [total_iterations] [parallel_processes] [test_type]"
    echo ""
    echo "Parameters:"
    echo "  total_iterations    Total iterations across all processes (default: 200)"
    echo "  parallel_processes  Number of concurrent workers (1-8, default: 4)"
    echo "  test_type          Type of test operation (default: cross_org)"
    echo ""
    echo "Test Types:"
    echo "  cross_org   Cross-organizational access (blockchain stress testing)"
    echo "  create      EHR creation throughput"
    echo "  read        EHR read throughput"
    echo "  consent     Consent granting throughput"
    echo "  all         Run all test types in sequence"
    echo ""
    echo "Cloud Environment:"
    echo "  VM Size: ${VM_SIZE} (${VM_VCPUS} vCPU, ${VM_RAM_GB} GB RAM)"
    echo "  System Cores: ${SYSTEM_CORES}"
    echo "  Max Workers: ${MAX_RECOMMENDED_WORKERS} (cloud-limited)"
    echo "  Orderer: ${ORDERER_VM_IP}:7050 | Org1: ${ORG1_VM_IP}:7051 | Org2: ${ORG2_VM_IP}:9051"
    echo ""
    echo "NOTE: Cloud VMs have fewer cores than local machines."
    echo "      Parallel scaling will show different characteristics — this is"
    echo "      expected and valuable for the local vs cloud comparison."
    echo ""
    echo "Examples:"
    echo "  $0 200 4 cross_org    # 4-worker test (recommended for B1ms)"
    echo "  $0 400 8 all          # Comprehensive test suite"
    echo "  $0 100 2 cross_org    # Conservative load test"
    exit 0
fi

# Initialize Fabric environment
print_info "Setting up Cloud Fabric environment for parallel testing..."
setup_fabric_environment || exit 1

# Test parameters — cloud-adapted defaults (smaller than local due to VM resources)
TOTAL_ITERATIONS=${1:-200}
PARALLEL_PROCESSES=${2:-4}
TEST_TYPE=${3:-"cross_org"}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="${RESULTS_DIR}/parallel_analysis/parallel_${TIMESTAMP}"
SUMMARY_FILE="${OUTPUT_DIR}/parallel_summary_${TIMESTAMP}.csv"

# Cloud-specific limits
MAX_RECOMMENDED_WORKERS=8
SYSTEM_CORES=$(nproc)

# Parameter validation
validate_parameters() {
    print_info "Validating cloud parallel testing parameters..."

    if [ "$PARALLEL_PROCESSES" -lt 1 ] || [ "$PARALLEL_PROCESSES" -gt "$MAX_RECOMMENDED_WORKERS" ]; then
        print_error "Worker count must be between 1 and ${MAX_RECOMMENDED_WORKERS} (cloud limit)"
        print_error "Current VM has ${SYSTEM_CORES} vCPUs (${VM_SIZE})"
        return 1
    fi

    local min_iterations_per_worker=25
    local iterations_per_worker=$((TOTAL_ITERATIONS / PARALLEL_PROCESSES))

    if [ "$iterations_per_worker" -lt "$min_iterations_per_worker" ]; then
        print_error "Insufficient iterations per worker: ${iterations_per_worker}"
        print_error "Minimum required: ${min_iterations_per_worker} per worker"
        print_error "Increase total iterations to at least $((min_iterations_per_worker * PARALLEL_PROCESSES))"
        return 1
    fi

    if [ "$PARALLEL_PROCESSES" -gt "$((SYSTEM_CORES * 2))" ]; then
        print_warning "Worker count (${PARALLEL_PROCESSES}) exceeds 2x vCPUs (${SYSTEM_CORES})"
        print_warning "On cloud VMs this may cause significant resource contention"
    fi

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

setup_output_directory() {
    print_info "Setting up cloud output directory structure..."

    mkdir -p "${OUTPUT_DIR}"
    mkdir -p "${OUTPUT_DIR}/raw_data"
    mkdir -p "${OUTPUT_DIR}/analysis"

    cat > "${SUMMARY_FILE}" << EOF
# Cloud Parallel Throughput Test Results
# Deployment: 3 Azure VMs (${VM_SIZE}), Docker Swarm overlay, ${AZURE_REGION}
# Timestamp: ${TIMESTAMP}
# System: ${SYSTEM_CORES} vCPUs, ${PARALLEL_PROCESSES} workers
# Configuration: ${TOTAL_ITERATIONS} total iterations, ${TEST_TYPE} operations
# Academic Standard: 25+ iterations per worker for statistical significance

TEST_TYPE,WORKER_ID,TRANSACTION_ID,PATIENT_ID,OPERATION,START_TIME,END_TIME,DURATION_NS,STATUS
EOF

    print_success "Cloud output directory created: ${OUTPUT_DIR}"
}

# Parallel worker function
run_parallel_worker() {
    local worker_id=$1
    local iterations_per_worker=$2
    local test_type=$3
    local worker_output="${OUTPUT_DIR}/raw_data/worker_${worker_id}_${test_type}_${TIMESTAMP}.csv"

    print_info "Worker ${worker_id}: Starting ${iterations_per_worker} ${test_type} operations (CLOUD)"

    cat > "${worker_output}" << EOF
# Cloud Worker ${worker_id} Results
# VM Size: ${VM_SIZE} | Test Type: ${test_type}
# Iterations: ${iterations_per_worker}
# Timestamp: ${TIMESTAMP}

TEST_TYPE,WORKER_ID,TRANSACTION_ID,PATIENT_ID,OPERATION,START_TIME,END_TIME,DURATION_NS,STATUS
EOF

    local successful_transactions=0
    local failed_transactions=0
    local worker_start_time=$(date +%s.%N)

    local worker_patients=10
    local worker_patient_ids=()

    if [[ "$test_type" == "cross_org" || "$test_type" == "read" ]]; then
        setup_org1_env > /dev/null 2>&1
        for j in $(seq 1 $worker_patients); do
            local patient_id="${TEST_PATIENT_ID_PREFIX}W${worker_id}_$(printf "%06d" $j)"
            create_ehr "${patient_id}" "Cloud Worker ${worker_id} Patient ${j}" > /dev/null 2>&1
            if [ "$test_type" == "cross_org" ]; then
                grant_consent "${patient_id}" "[\"org2admin\"]" > /dev/null 2>&1
            fi
            worker_patient_ids+=("$patient_id")
        done
    fi

    for i in $(seq 1 $iterations_per_worker); do
        local patient_id
        if [[ "$test_type" == "cross_org" || "$test_type" == "read" ]]; then
            local patient_index=$(( (i - 1) % worker_patients ))
            patient_id="${worker_patient_ids[$patient_index]}"
        else
            patient_id="${TEST_PATIENT_ID_PREFIX}W${worker_id}_$(printf "%06d" $i)"
        fi

        local transaction_start=$(date +%s.%N)
        local duration
        local exit_status
        local status="SUCCESS"

        case "$test_type" in
            "cross_org")
                setup_org2_env > /dev/null 2>&1
                if [ $i -le 2 ]; then
                    duration=$(read_ehr "${patient_id}" "true" 2>/dev/null)
                else
                    duration=$(read_ehr "${patient_id}" 2>/dev/null)
                fi
                exit_status=$?
                ;;
            "read")
                setup_org1_env > /dev/null 2>&1
                if [ $i -le 2 ]; then
                    duration=$(read_ehr "${patient_id}" "true" 2>/dev/null)
                else
                    duration=$(read_ehr "${patient_id}" 2>/dev/null)
                fi
                exit_status=$?
                ;;
            "create")
                local unique_patient_id="${TEST_PATIENT_ID_PREFIX}W${worker_id}_$(printf "%06d" $i)"
                setup_org1_env > /dev/null 2>&1
                duration=$(create_ehr "${unique_patient_id}" "Cloud Worker ${worker_id} Patient ${i}" 2>/dev/null)
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
            ((failed_transactions++))
        else
            ((successful_transactions++))
        fi

        echo "${test_type^^},${worker_id},${i},${patient_id},${test_type^^},${transaction_start},${transaction_end},${duration},${status}" >> "${worker_output}"

        if [ $((i % 50)) -eq 0 ]; then
            print_info "Worker ${worker_id}: Completed ${i}/${iterations_per_worker} operations"
        fi
    done

    local worker_end_time=$(date +%s.%N)
    local worker_total_time=$(echo "$worker_end_time - $worker_start_time" | bc -l)

    local success_rate=$(echo "scale=2; $successful_transactions * 100 / $iterations_per_worker" | bc -l)
    local avg_tps=$(echo "scale=2; $iterations_per_worker / $worker_total_time" | bc -l)

    echo "# Cloud Worker ${worker_id} Summary" >> "${worker_output}"
    echo "# VM: ${VM_SIZE} (${VM_VCPUS} vCPU, ${VM_RAM_GB} GB RAM)" >> "${worker_output}"
    echo "# Total Time: ${worker_total_time}s" >> "${worker_output}"
    echo "# Successful: ${successful_transactions}/${iterations_per_worker} (${success_rate}%)" >> "${worker_output}"
    echo "# Failed: ${failed_transactions}" >> "${worker_output}"
    echo "# Average TPS: ${avg_tps}" >> "${worker_output}"

    print_success "Worker ${worker_id}: Completed with ${success_rate}% success rate, ${avg_tps} TPS"
}

run_single_test() {
    local test_type=$1

    print_header "Cloud Parallel Test: ${test_type^^} Operations"
    print_info "Workers: ${PARALLEL_PROCESSES}, Total Iterations: ${TOTAL_ITERATIONS}"
    print_info "VM: ${VM_SIZE} (${VM_VCPUS} vCPU, ${VM_RAM_GB} GB RAM)"

    local iterations_per_worker=$((TOTAL_ITERATIONS / PARALLEL_PROCESSES))
    print_info "Iterations per worker: ${iterations_per_worker}"

    local test_start=$(date +%s.%N)

    local pids=()
    for worker_id in $(seq 1 $PARALLEL_PROCESSES); do
        run_parallel_worker "$worker_id" "$iterations_per_worker" "$test_type" &
        pids+=($!)
    done

    print_info "Launched ${PARALLEL_PROCESSES} workers, waiting for completion..."

    local completed_workers=0
    for pid in "${pids[@]}"; do
        wait $pid
        ((completed_workers++))
        print_info "Worker completed (${completed_workers}/${PARALLEL_PROCESSES})"
    done

    local test_end=$(date +%s.%N)
    local total_test_time=$(echo "$test_end - $test_start" | bc -l)

    print_info "Aggregating results for ${test_type}..."

    cat "${OUTPUT_DIR}"/raw_data/worker_*_${test_type}_*.csv | grep -E "^[A-Z]" | grep -v "^TEST_TYPE" >> "${SUMMARY_FILE}"

    local total_successful=$(cat "${OUTPUT_DIR}"/raw_data/worker_*_${test_type}_*.csv | grep "SUCCESS" | wc -l)
    local total_failed=$(cat "${OUTPUT_DIR}"/raw_data/worker_*_${test_type}_*.csv | grep "FAILED" | wc -l)
    local success_rate=$(echo "scale=2; $total_successful * 100 / $TOTAL_ITERATIONS" | bc -l)
    local overall_tps=$(echo "scale=2; $total_successful / $total_test_time" | bc -l)

    local tps_per_worker=$(echo "scale=2; $overall_tps / $PARALLEL_PROCESSES" | bc -l)

    cat >> "${OUTPUT_DIR}/analysis/${test_type}_analysis_${TIMESTAMP}.txt" << EOF
Cloud Parallel Test Analysis: ${test_type^^}
=============================================
Deployment:
- Cloud Provider: Azure (${AZURE_REGION})
- VM Size: ${VM_SIZE} (${VM_VCPUS} vCPU, ${VM_RAM_GB} GB RAM)
- Network: Docker Swarm overlay (${SWARM_OVERLAY_NETWORK})
- Orderer: ${ORDERER_VM_IP}:7050 | Org1: ${ORG1_VM_IP}:7051 | Org2: ${ORG2_VM_IP}:9051

Test Configuration:
- Workers: ${PARALLEL_PROCESSES}
- Total Iterations: ${TOTAL_ITERATIONS}
- Iterations per Worker: ${iterations_per_worker}
- System vCPUs: ${SYSTEM_CORES}

Performance Results:
- Total Time: ${total_test_time}s
- Successful Transactions: ${total_successful}
- Failed Transactions: ${total_failed}
- Success Rate: ${success_rate}%
- Overall TPS: ${overall_tps}
- TPS per Worker: ${tps_per_worker}

Scaling Metrics:
- Workers per vCPU: $(echo "scale=1; $PARALLEL_PROCESSES / $SYSTEM_CORES" | bc -l)
- Resource Utilization: $(echo "scale=1; $PARALLEL_PROCESSES * 100 / ($SYSTEM_CORES * 2)" | bc -l)%
EOF

    print_success "${test_type^^} test completed: ${overall_tps} TPS with ${PARALLEL_PROCESSES} workers (CLOUD)"
    echo "SUMMARY,${test_type^^},${PARALLEL_PROCESSES},${total_successful},${total_failed},${success_rate},${overall_tps},${total_test_time}" >> "${SUMMARY_FILE}"
}

run_all_tests() {
    print_header "Comprehensive Cloud Parallel Testing Suite"

    local test_types=("cross_org" "read" "create" "consent")
    local iterations_per_test=$((TOTAL_ITERATIONS / 4))

    print_info "Running ${#test_types[@]} test types with ${iterations_per_test} iterations each"

    for test_type in "${test_types[@]}"; do
        local original_iterations=$TOTAL_ITERATIONS
        TOTAL_ITERATIONS=$iterations_per_test

        run_single_test "$test_type"

        print_info "Cooling down for 10 seconds before next test type..."
        sleep 10

        TOTAL_ITERATIONS=$original_iterations
    done

    print_success "Comprehensive cloud testing completed!"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    print_header "Cloud Parallel Throughput Testing"
    print_info "Deployment: 3 Azure VMs (${VM_SIZE}), Docker Swarm overlay"
    print_info "Academic EHR Blockchain Performance Analysis"

    print_info "Cloud Configuration:"
    print_info "- VM Size: ${VM_SIZE} (${VM_VCPUS} vCPU, ${VM_RAM_GB} GB RAM)"
    print_info "- vCPUs: ${SYSTEM_CORES}"
    print_info "- Max Workers: ${MAX_RECOMMENDED_WORKERS}"
    print_info "- Test Workers: ${PARALLEL_PROCESSES}"
    print_info "- Total Iterations: ${TOTAL_ITERATIONS}"
    print_info "- Orderer: ${ORDERER_ENDPOINT} | Org1: ${PEER0_ORG1_ENDPOINT} | Org2: ${PEER0_ORG2_ENDPOINT}"

    if ! validate_parameters; then
        exit 1
    fi

    setup_output_directory

    case "$TEST_TYPE" in
        "all")
            run_all_tests
            ;;
        *)
            run_single_test "$TEST_TYPE"
            ;;
    esac

    print_header "Cloud Test Execution Complete"
    print_success "Results saved to: ${OUTPUT_DIR}"
    print_success "Summary file: ${SUMMARY_FILE}"
    print_info "Analysis files: ${OUTPUT_DIR}/analysis/"
    print_info "Raw data: ${OUTPUT_DIR}/raw_data/"

    local total_transactions=$(cat "${SUMMARY_FILE}" | grep "^SUMMARY" | awk -F',' '{sum += $4} END {print sum}')

    if [ ! -z "$total_transactions" ] && [ "$total_transactions" -gt 0 ]; then
        print_success "Total successful transactions: ${total_transactions}"
        print_info "For detailed analysis, see files in ${OUTPUT_DIR}/analysis/"
    fi
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
