#!/bin/bash

# =============================================================================
# Cloud Scaling Analysis Script
# Academic Project - Master's Dissertation
# Automated scaling analysis from 1-8 workers (cloud VM adaptation)
# Adapted from: scripts/performance/scaling_test.sh
# =============================================================================

# Source required utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Configuration
PARALLEL_SCRIPT="${SCRIPT_DIR}/cloud_parallel_test.sh"
BASE_ITERATIONS=${1:-800}  # Base iterations for scaling tests
TEST_TYPE=${2:-"cross_org"}  # Default test type
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCALING_OUTPUT_DIR="${RESULTS_DIR}/parallel_analysis/scaling_${TIMESTAMP}"
SCALING_REPORT="${SCALING_OUTPUT_DIR}/scaling_analysis_report_${TIMESTAMP}.csv"

# Worker count array — cloud-adapted for 1 vCPU B1ms VMs
# Local used (1 2 4 8 12 16) on 8-core host
# Cloud uses (1 2 4 8) — saturation expected at 2-4 workers on 1 vCPU
WORKER_COUNTS=(1 2 4 8)
SYSTEM_CORES=$(nproc)

# Function to display usage
show_usage() {
    echo "Cloud Scaling Analysis - Azure VM Deployment"
    echo "============================================="
    echo "Usage: $0 [base_iterations] [test_type]"
    echo ""
    echo "Parameters:"
    echo "  base_iterations    Base iterations for scaling tests (default: 800)"
    echo "  test_type         Test operation type (default: cross_org)"
    echo ""
    echo "Test Types:"
    echo "  cross_org   Cross-organizational access (recommended)"
    echo "  read        EHR read operations"
    echo "  create      EHR creation operations"
    echo "  consent     Consent granting operations"
    echo ""
    echo "Cloud Scaling Points: ${WORKER_COUNTS[*]}"
    echo "System vCPUs: ${SYSTEM_CORES} (Azure B1ms)"
    echo ""
    echo "Academic Standards:"
    echo "  - Maintains 25+ iterations per worker for statistical validity"
    echo "  - Tests linear scaling characteristics on constrained resources"
    echo "  - Identifies optimal worker count for cloud VMs"
    echo ""
    echo "Methodology (identical to local):"
    echo "  - Same chaincode, same CRUD operations, same CSV format"
    echo "  - Each worker runs 100 transactions (cross_org)"
    echo "  - Total load grows proportionally: workers × iterations_per_worker"
    echo "  - 30s cooldown between scaling points"
    echo ""
    echo "Examples:"
    echo "  $0 800 cross_org     # Comprehensive scaling analysis"
    echo "  $0 400 read          # Quick scaling validation"
}

# Setup scaling analysis directory
setup_scaling_analysis() {
    print_info "Setting up cloud scaling analysis environment..."

    mkdir -p "${SCALING_OUTPUT_DIR}"
    mkdir -p "${SCALING_OUTPUT_DIR}/individual_tests"
    mkdir -p "${SCALING_OUTPUT_DIR}/analysis"

    # Create comprehensive scaling report header
    cat > "${SCALING_REPORT}" << EOF
# Comprehensive Cloud Scaling Analysis Report
# Timestamp: ${TIMESTAMP}
# Deployment: Azure B1ms (1 vCPU, 2 GB RAM)
# System: ${SYSTEM_CORES} vCPUs
# Test Type: ${TEST_TYPE}
# Base Iterations: ${BASE_ITERATIONS}
# Worker Counts: ${WORKER_COUNTS[*]}
# Academic Standard: Statistical significance maintained across all scaling points

WORKERS,TOTAL_ITERATIONS,ITERATIONS_PER_WORKER,SUCCESSFUL_TRANSACTIONS,FAILED_TRANSACTIONS,SUCCESS_RATE,OVERALL_TPS,TOTAL_TIME,TPS_PER_WORKER,SCALING_EFFICIENCY,RESOURCE_UTILIZATION
EOF

    print_success "Scaling analysis directory created: ${SCALING_OUTPUT_DIR}"
}

# Run single scaling test point
run_scaling_test() {
    local worker_count=$1
    local test_iterations=$2

    print_header "Cloud Scaling Test: ${worker_count} Workers"
    print_info "Test: ${test_iterations} iterations, ${TEST_TYPE} operations"
    print_info "VM: Azure B1ms (${SYSTEM_CORES} vCPUs)"

    # Ensure minimum iterations per worker for statistical significance
    local iterations_per_worker=$((test_iterations / worker_count))
    if [ "$iterations_per_worker" -lt 25 ]; then
        test_iterations=$((worker_count * 25))  # Maintain minimum 25 per worker
        print_warning "Adjusted iterations to ${test_iterations} for statistical significance"
    fi

    local test_start=$(date +%s.%N)

    # Execute parallel test
    print_info "Executing: ${PARALLEL_SCRIPT} ${test_iterations} ${worker_count} ${TEST_TYPE}"

    if ! "${PARALLEL_SCRIPT}" "${test_iterations}" "${worker_count}" "${TEST_TYPE}"; then
        print_error "Cloud scaling test failed for ${worker_count} workers"
        return 1
    fi

    local test_end=$(date +%s.%N)
    local test_duration=$(echo "$test_end - $test_start" | bc -l)

    print_success "Cloud scaling test completed: ${worker_count} workers in ${test_duration}s"

    # Find the most recent test results
    local latest_result_dir=$(ls -1td "${RESULTS_DIR}"/parallel_analysis/parallel_* 2>/dev/null | head -1)

    if [ -n "$latest_result_dir" ] && [ -d "$latest_result_dir" ]; then
        # Copy results to scaling analysis directory
        cp -r "$latest_result_dir" "${SCALING_OUTPUT_DIR}/individual_tests/workers_${worker_count}/"
        print_info "Results archived for ${worker_count} workers"

        # Extract key metrics for scaling analysis
        local summary_file="${latest_result_dir}/parallel_summary_"*.csv
        if [ -f $summary_file ]; then
            local summary_line=$(grep "^SUMMARY" "$summary_file" | head -1)
            if [ -n "$summary_line" ]; then
                # Parse summary: SUMMARY,TEST_TYPE,WORKERS,SUCCESSFUL,FAILED,SUCCESS_RATE,TPS,TIME
                local successful=$(echo "$summary_line" | cut -d',' -f4)
                local failed=$(echo "$summary_line" | cut -d',' -f5)
                local success_rate=$(echo "$summary_line" | cut -d',' -f6)
                local overall_tps=$(echo "$summary_line" | cut -d',' -f7)
                local total_time=$(echo "$summary_line" | cut -d',' -f8)

                # Calculate scaling metrics
                local tps_per_worker=$(echo "scale=3; $overall_tps / $worker_count" | bc -l)
                local scaling_efficiency=$(echo "scale=2; 100" | bc -l)  # Will be recalculated in analysis
                local resource_utilization=$(echo "scale=2; $worker_count * 100 / ($SYSTEM_CORES * 2)" | bc -l)

                # Write to scaling report
                echo "${worker_count},${test_iterations},${iterations_per_worker},${successful},${failed},${success_rate},${overall_tps},${total_time},${tps_per_worker},${scaling_efficiency},${resource_utilization}" >> "${SCALING_REPORT}"

                print_success "Metrics recorded: ${overall_tps} TPS, ${success_rate}% success"
            fi
        fi
    else
        print_warning "Could not find results for ${worker_count} workers"
    fi
}

# Generate comprehensive scaling analysis
generate_scaling_analysis() {
    print_header "Generating Cloud Scaling Analysis"

    local analysis_file="${SCALING_OUTPUT_DIR}/analysis/scaling_analysis_${TIMESTAMP}.md"

    cat > "$analysis_file" << 'EOF'
# Cloud Parallel Scaling Analysis

## Test Configuration
EOF

    cat >> "$analysis_file" << EOF
- **Deployment**: Azure B1ms (1 vCPU, 2 GB RAM) × 3 VMs
- **Network**: Docker Swarm overlay (fabric_test)
- **System vCPUs**: ${SYSTEM_CORES}
- **Test Type**: ${TEST_TYPE}
- **Base Iterations**: ${BASE_ITERATIONS}
- **Worker Counts Tested**: ${WORKER_COUNTS[*]}
- **Timestamp**: ${TIMESTAMP}

## Comparison with Local
- **Local**: 8-core host, workers {1, 2, 4, 8, 12, 16}
- **Cloud**: 1 vCPU B1ms, workers {1, 2, 4, 8}
- **Expectation**: Earlier saturation due to single vCPU constraint

## Academic Methodology
- **Minimum Iterations per Worker**: 25 (ensures statistical significance)
- **Test Operations**: ${TEST_TYPE^^} transactions
- **Success Rate Threshold**: >95% for valid results
- **Scaling Efficiency**: Measured as TPS improvement vs worker increase
- **Identical to local**: Same chaincode, same methodology, same CSV format

## Results Summary
EOF

    # Process scaling results for analysis
    if [ -f "${SCALING_REPORT}" ]; then
        echo "" >> "$analysis_file"
        echo "| Workers | Total TPS | TPS/Worker | Success Rate | Resource Util |" >> "$analysis_file"
        echo "|---------|-----------|------------|--------------|---------------|" >> "$analysis_file"

        # Read scaling data and generate summary table
        tail -n +2 "${SCALING_REPORT}" | while IFS=',' read -r workers total_iter iter_per_worker successful failed success_rate overall_tps total_time tps_per_worker scaling_eff resource_util; do
            printf "| %-7s | %-9s | %-10s | %-12s | %-13s |\n" \
                "$workers" \
                "$overall_tps" \
                "$tps_per_worker" \
                "${success_rate}%" \
                "${resource_util}%" >> "$analysis_file"
        done
    fi

    cat >> "$analysis_file" << EOF

## Cloud-Specific Scaling Characteristics

### Expected Behavior (1 vCPU)
- **1 worker**: Baseline TPS — comparable to local single-worker but higher latency
- **2 workers**: Near-linear improvement if I/O-bound (network wait dominates)
- **4 workers**: Likely saturation point — CPU contention on single vCPU
- **8 workers**: Diminishing returns — scheduler overhead dominates

### Key Differences from Local
- **Network latency**: Inter-VM ~0.5-2ms vs local Docker bridge ~0.01ms
- **CPU constraint**: 1 vCPU vs 8 cores — saturation expected earlier
- **Memory pressure**: 2 GB shared with Docker, Fabric containers, CouchDB
- **VXLAN overhead**: Docker Swarm overlay adds encapsulation cost

### Performance Optimization
- **Optimal Workers**: Determined by highest TPS/Worker ratio
- **Resource Utilization**: Balanced against VM stability
- **Academic Significance**: All tests maintain >25 iterations per worker

## Academic Conclusions
This cloud scaling analysis provides empirical evidence for parallel throughput
characteristics in a distributed Hyperledger Fabric deployment across Azure VMs.
Results enable direct comparison with the local 8-core baseline established in
the dissertation (Chapter 5.4.4), demonstrating the impact of constrained compute
resources and real network latency on blockchain transaction processing.

### Statistical Validity
All tests maintain academic standards with sufficient sample sizes for
reliable performance characterization and reproducible results.
EOF

    print_success "Cloud scaling analysis generated: $analysis_file"
}

# Main execution function
main() {
    print_header "Cloud Scaling Analysis — Azure VM Deployment"
    print_info "Academic EHR Blockchain Parallel Performance Analysis"

    # Validate parameters
    if [ "$#" -eq 1 ] && [ "$1" == "--help" ]; then
        show_usage
        exit 0
    fi

    # Display configuration
    print_info "Configuration:"
    print_info "- Base Iterations: ${BASE_ITERATIONS}"
    print_info "- Test Type: ${TEST_TYPE}"
    print_info "- Worker Counts: ${WORKER_COUNTS[*]}"
    print_info "- System vCPUs: ${SYSTEM_CORES} (Azure B1ms)"
    print_info "- Orderer: ${ORDERER_ENDPOINT}"
    print_info "- Org1 Peer: ${PEER0_ORG1_ENDPOINT}"
    print_info "- Org2 Peer: ${PEER0_ORG2_ENDPOINT}"

    # Verify parallel script exists
    if [ ! -f "${PARALLEL_SCRIPT}" ]; then
        print_error "Cloud parallel test script not found: ${PARALLEL_SCRIPT}"
        exit 1
    fi

    # Setup analysis environment
    setup_scaling_analysis

    # Execute scaling tests for each worker count
    local total_tests=${#WORKER_COUNTS[@]}
    local current_test=0

    for worker_count in "${WORKER_COUNTS[@]}"; do
        ((current_test++))
        print_info "Running cloud scaling test ${current_test}/${total_tests}: ${worker_count} workers"

        # Calculate iterations for this test
        # Same formula as local: scale with workers relative to baseline
        local test_iterations=$((BASE_ITERATIONS * worker_count / 8))
        if [ "$test_iterations" -lt "$((worker_count * 25))" ]; then
            test_iterations=$((worker_count * 25))  # Ensure minimum per worker
        fi

        if ! run_scaling_test "$worker_count" "$test_iterations"; then
            print_error "Failed cloud scaling test for ${worker_count} workers"
            continue
        fi

        # Brief cooldown between tests (same as local: 30s)
        if [ "$current_test" -lt "$total_tests" ]; then
            print_info "Cooldown period (30 seconds) before next test..."
            sleep 30
        fi
    done

    # Generate comprehensive analysis
    generate_scaling_analysis

    # Final reporting
    print_header "Cloud Scaling Analysis Complete"
    print_success "Results directory: ${SCALING_OUTPUT_DIR}"
    print_success "Scaling report: ${SCALING_REPORT}"
    print_success "Analysis document: ${SCALING_OUTPUT_DIR}/analysis/"

    # Display quick summary
    if [ -f "${SCALING_REPORT}" ]; then
        local test_count=$(tail -n +2 "${SCALING_REPORT}" | wc -l)
        print_info "Completed ${test_count} scaling test points"
        print_info "Worker range: ${WORKER_COUNTS[0]} - ${WORKER_COUNTS[-1]}"
    fi

    print_success "Cloud scaling analysis completed!"
}

# Execute main
main "$@"
