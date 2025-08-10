#!/bin/bash

# =============================================================================
# Multi-Phase Parallel Testing Script
# Academic Project - Master's Dissertation
# FIXED VERSION: Proper data setup, consent, and cross-org reading
# =============================================================================

# Source required utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/ehr_operations.sh"
source "${SCRIPT_DIR}/ehr_operations.sh"

# Initialize Fabric environment
print_info "Setting up Fabric environment for multi-phase parallel testing..."
setup_fabric_environment || exit 1

# Test parameters
TOTAL_PATIENTS=${1:-400}    # Total patients to test
PARALLEL_WORKERS=${2:-8}   # Number of parallel workers
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="${RESULTS_DIR}/parallel_analysis/multiphase_${TIMESTAMP}"
SUMMARY_FILE="${OUTPUT_DIR}/multiphase_summary_${TIMESTAMP}.csv"

# System parameters
MAX_WORKERS=16
SYSTEM_CORES=$(nproc)

# Function to display usage
show_usage() {
    echo "Multi-Phase Parallel Testing - FIXED VERSION"
    echo "============================================"
    echo "Usage: $0 [total_patients] [parallel_workers]"
    echo ""
    echo "Parameters:"
    echo "  total_patients    Total number of patients to test (default: 400)"
    echo "  parallel_workers  Number of concurrent workers (1-16, default: 8)"
    echo ""
    echo "Test Phases:"
    echo "  Phase 1: Parallel EHR Creation (Org1) → CREATE TPS"
    echo "  Phase 2: Parallel Consent Granting (Org1) → CONSENT TPS"
    echo "  Phase 3: Parallel Cross-Org Reading (Org2) → CROSS_ORG TPS"
    echo ""
    echo "Academic Standards:"
    echo "  - Minimum 25 patients per worker"
    echo "  - Proper error handling (no silent failures)"
    echo "  - Valid blockchain workflow simulation"
    echo ""
    echo "Examples:"
    echo "  $0 800 16    # Stress test: 50 patients per worker"
    echo "  $0 400 8     # Standard test: 50 patients per worker"
    echo "  $0 200 4     # Quick test: 50 patients per worker"
}

# Validation function
validate_parameters() {
    print_info "Validating multi-phase testing parameters..."
    
    # Validate worker count
    if [ "$PARALLEL_WORKERS" -lt 1 ] || [ "$PARALLEL_WORKERS" -gt "$MAX_WORKERS" ]; then
        print_error "Worker count must be between 1 and ${MAX_WORKERS}"
        return 1
    fi
    
    # Validate patients per worker
    local patients_per_worker=$((TOTAL_PATIENTS / PARALLEL_WORKERS))
    if [ "$patients_per_worker" -lt 25 ]; then
        print_error "Insufficient patients per worker: ${patients_per_worker}"
        print_error "Minimum required: 25 per worker"
        print_error "Increase total patients to at least $((25 * PARALLEL_WORKERS))"
        return 1
    fi
    
    print_success "Parameters validated: ${patients_per_worker} patients per worker"
    return 0
}

# Setup output directory
setup_output_directory() {
    print_info "Setting up multi-phase output directory..."
    
    mkdir -p "${OUTPUT_DIR}"
    mkdir -p "${OUTPUT_DIR}/phase1_CREATE"
    mkdir -p "${OUTPUT_DIR}/phase2_CONSENT" 
    mkdir -p "${OUTPUT_DIR}/phase3_CROSS_ORG_READ"
    mkdir -p "${OUTPUT_DIR}/analysis"
    
    # Create summary file
    cat > "${SUMMARY_FILE}" << EOF
# Multi-Phase Parallel Test Results - FIXED VERSION
# Timestamp: ${TIMESTAMP}
# System: ${SYSTEM_CORES} cores, ${PARALLEL_WORKERS} workers
# Total Patients: ${TOTAL_PATIENTS}
# Academic Standard: Proper error handling, valid workflow

PHASE,WORKER_ID,PATIENT_ID,OPERATION,START_TIME,END_TIME,DURATION_NS,STATUS,ERROR_MESSAGE
EOF

    print_success "Output directory created: ${OUTPUT_DIR}"
}

# Enhanced worker function with proper error handling
run_phase_worker() {
    local phase="$1"
    local worker_id="$2"
    local start_patient="$3"
    local end_patient="$4"
    local worker_output="${OUTPUT_DIR}/phase${phase}_${phase_names[$phase]}/worker_${worker_id}.csv"
    
    print_info "Phase ${phase} Worker ${worker_id}: Processing patients ${start_patient}-${end_patient}"
    
    # Create worker output file
    cat > "${worker_output}" << EOF
# Phase ${phase} Worker ${worker_id} Results
# Range: ${start_patient}-${end_patient}
# Timestamp: ${TIMESTAMP}

PHASE,WORKER_ID,PATIENT_ID,OPERATION,START_TIME,END_TIME,DURATION_NS,STATUS,ERROR_MESSAGE
EOF
    
    local successful=0
    local failed=0
    local worker_start_time=$(date +%s.%N)
    
    for patient_num in $(seq $start_patient $end_patient); do
        local patient_id="${TEST_PATIENT_ID_PREFIX}$(printf "%06d" $patient_num)"
        local transaction_start=$(date +%s.%N)
        local duration=""
        local status="SUCCESS"
        local error_message=""
        local operation=""
        
        case "$phase" in
            "1")
                operation="CREATE"
                setup_org1_env > /dev/null 2>&1
                
                # Use enhanced function with proper error handling
                local result=$(create_ehr_enhanced "${patient_id}" "Multi-phase Patient ${patient_num}" 2>&1)
                local exit_code=$?
                
                if [ $exit_code -eq 0 ]; then
                    duration="$result"
                    ((successful++))
                else
                    duration="0"
                    status="FAILED"
                    error_message="$result"
                    ((failed++))
                fi
                ;;
                
            "2")
                operation="CONSENT"
                setup_org1_env > /dev/null 2>&1
                
                # Use enhanced function with proper error handling
                local result=$(grant_consent_enhanced "${patient_id}" "[\"org2admin\"]" 2>&1)
                local exit_code=$?
                
                if [ $exit_code -eq 0 ]; then
                    duration="$result"
                    ((successful++))
                else
                    duration="0"
                    status="FAILED"
                    error_message="$result"
                    ((failed++))
                fi
                ;;
                
            "3")
                operation="CROSS_ORG_READ"
                setup_org2_env > /dev/null 2>&1
                
                # Use enhanced function with proper error handling
                local result=$(read_ehr_enhanced "${patient_id}" 2>&1)
                local exit_code=$?
                
                if [ $exit_code -eq 0 ]; then
                    duration="$result"
                    ((successful++))
                else
                    duration="0"
                    status="FAILED"
                    error_message="$result"
                    ((failed++))
                fi
                ;;
        esac
        
        local transaction_end=$(date +%s.%N)
        
        # Write result (escape error message for CSV)
        local escaped_error=$(echo "$error_message" | tr '"' "'" | tr '\n' ' ' | cut -c1-100)
        echo "${phase},${worker_id},${patient_id},${operation},${transaction_start},${transaction_end},${duration},${status},\"${escaped_error}\"" >> "${worker_output}"
        
        # Progress reporting
        if [ $((patient_num % 25)) -eq 0 ]; then
            local current_count=$((patient_num - start_patient + 1))
            local total_count=$((end_patient - start_patient + 1))
            print_info "Phase ${phase} Worker ${worker_id}: ${current_count}/${total_count} completed"
        fi
    done
    
    local worker_end_time=$(date +%s.%N)
    local worker_total_time=$(echo "$worker_end_time - $worker_start_time" | bc -l)
    local success_rate=$(echo "scale=2; $successful * 100 / ($successful + $failed)" | bc -l)
    local avg_tps=$(echo "scale=2; $successful / $worker_total_time" | bc -l)
    
    # Worker summary
    echo "# Phase ${phase} Worker ${worker_id} Summary" >> "${worker_output}"
    echo "# Total Time: ${worker_total_time}s" >> "${worker_output}"
    echo "# Successful: ${successful}" >> "${worker_output}"
    echo "# Failed: ${failed}" >> "${worker_output}"
    echo "# Success Rate: ${success_rate}%" >> "${worker_output}"
    echo "# Average TPS: ${avg_tps}" >> "${worker_output}"
    
    print_success "Phase ${phase} Worker ${worker_id}: ${success_rate}% success, ${avg_tps} TPS"
}

# Run a complete phase
run_phase() {
    local phase="$1"
    local phase_name="$2"
    
    print_header "Phase ${phase}: ${phase_name}"
    
    local patients_per_worker=$((TOTAL_PATIENTS / PARALLEL_WORKERS))
    local phase_start_time=$(date +%s.%N)
    
    # Launch workers
    local pids=()
    for worker_id in $(seq 1 $PARALLEL_WORKERS); do
        local start_patient=$(( (worker_id - 1) * patients_per_worker + 1 ))
        local end_patient=$(( worker_id * patients_per_worker ))
        
        # Adjust last worker to handle remainder
        if [ "$worker_id" -eq "$PARALLEL_WORKERS" ]; then
            end_patient=$TOTAL_PATIENTS
        fi
        
        run_phase_worker "$phase" "$worker_id" "$start_patient" "$end_patient" &
        pids+=($!)
    done
    
    print_info "Phase ${phase}: Launched ${PARALLEL_WORKERS} workers, waiting for completion..."
    
    # Wait for all workers
    local completed=0
    for pid in "${pids[@]}"; do
        wait $pid
        ((completed++))
        print_info "Phase ${phase}: Worker completed (${completed}/${PARALLEL_WORKERS})"
    done
    
    local phase_end_time=$(date +%s.%N)
    local phase_duration=$(echo "$phase_end_time - $phase_start_time" | bc -l)
    
    # Aggregate results
    print_info "Phase ${phase}: Aggregating results..."
    
    # Combine worker results
    cat "${OUTPUT_DIR}/phase${phase}_"*"/worker_"*.csv | grep -E "^[0-9]" >> "${SUMMARY_FILE}"
    
    # Calculate phase statistics
    local total_successful=$(cat "${OUTPUT_DIR}/phase${phase}_"*"/worker_"*.csv | grep ",SUCCESS," | wc -l)
    local total_failed=$(cat "${OUTPUT_DIR}/phase${phase}_"*"/worker_"*.csv | grep ",FAILED," | wc -l)
    local success_rate=$(echo "scale=2; $total_successful * 100 / ($total_successful + $total_failed)" | bc -l)
    local phase_tps=$(echo "scale=2; $total_successful / $phase_duration" | bc -l)
    
    # Write phase analysis
    cat >> "${OUTPUT_DIR}/analysis/phase${phase}_analysis.txt" << EOF
Phase ${phase}: ${phase_name} Analysis
=====================================
Configuration:
- Workers: ${PARALLEL_WORKERS}
- Total Patients: ${TOTAL_PATIENTS}
- Patients per Worker: ${patients_per_worker}

Results:
- Phase Duration: ${phase_duration}s
- Successful Operations: ${total_successful}
- Failed Operations: ${total_failed}
- Success Rate: ${success_rate}%
- Phase TPS: ${phase_tps}

Error Analysis:
EOF

    # Add error summary
    if [ "$total_failed" -gt 0 ]; then
        echo "Failed operations detected:" >> "${OUTPUT_DIR}/analysis/phase${phase}_analysis.txt"
        cat "${OUTPUT_DIR}/phase${phase}_"*"/worker_"*.csv | grep ",FAILED," | cut -d',' -f9 | sort | uniq -c >> "${OUTPUT_DIR}/analysis/phase${phase}_analysis.txt"
    else
        echo "No failures detected - all operations successful" >> "${OUTPUT_DIR}/analysis/phase${phase}_analysis.txt"
    fi
    
    print_success "Phase ${phase} (${phase_name}): ${phase_tps} TPS, ${success_rate}% success"
    echo "PHASE_SUMMARY,${phase},${phase_name},${PARALLEL_WORKERS},${total_successful},${total_failed},${success_rate},${phase_tps},${phase_duration}" >> "${SUMMARY_FILE}"
}

# Main execution
main() {
    print_header "Multi-Phase Parallel Testing - FIXED VERSION"
    print_info "Academic EHR Blockchain Performance Analysis"
    
    # Show help if requested
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_usage
        exit 0
    fi
    
    # Display configuration
    print_info "Configuration:"
    print_info "- System Cores: ${SYSTEM_CORES}"
    print_info "- Workers: ${PARALLEL_WORKERS}"
    print_info "- Total Patients: ${TOTAL_PATIENTS}"
    print_info "- Patients per Worker: $((TOTAL_PATIENTS / PARALLEL_WORKERS))"
    
    # Validate parameters
    if ! validate_parameters; then
        show_usage
        exit 1
    fi
    
    # Setup output
    setup_output_directory
    
    # Define phase names
    declare -A phase_names
    phase_names[1]="CREATE"
    phase_names[2]="CONSENT" 
    phase_names[3]="CROSS_ORG_READ"
    
    # Execute all phases
    run_phase "1" "Parallel EHR Creation (Org1)"
    sleep 10  # Brief cooldown
    
    run_phase "2" "Parallel Consent Granting (Org1)"
    sleep 10  # Brief cooldown
    
    run_phase "3" "Parallel Cross-Org Reading (Org2)"
    
    # Final analysis
    print_header "Multi-Phase Testing Complete"
    print_success "Results saved to: ${OUTPUT_DIR}"
    print_success "Summary file: ${SUMMARY_FILE}"
    print_info "Phase analyses: ${OUTPUT_DIR}/analysis/"
    
    # Display summary
    echo ""
    print_info "PERFORMANCE SUMMARY:"
    grep "^PHASE_SUMMARY" "${SUMMARY_FILE}" | while IFS=',' read -r prefix phase_num phase_name workers successful failed success_rate tps duration; do
        printf "  Phase %s (%s): %.2f TPS, %.1f%% success\n" "$phase_num" "$phase_name" "$tps" "$success_rate"
    done
    
    print_success "Multi-phase parallel testing completed successfully!"
}

# Execute if run directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
