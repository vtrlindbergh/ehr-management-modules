#!/bin/bash

# =============================================================================
# End-to-End Latency Distribution Analysis Script
# Phase 1 Enhancement - Academic Project - Master's Dissertation
# 
# This script extends performance testing with detailed latency analysis:
# - End-to-end transaction confirmation timing
# - Statistical distribution analysis (p50, p95, p99)
# - Individual transaction latency tracking
# - Academic-quality data collection for dissertation
# =============================================================================

# Source required utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/ehr_operations.sh"

# Enhanced latency analysis parameters
LATENCY_TEST_ITERATIONS=${1:-100}
TEST_TYPE=${2:-"create"}
LATENCY_OUTPUT_DIR="${SCRIPT_DIR}/../results/latency_analysis"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LATENCY_RAW_FILE="${LATENCY_OUTPUT_DIR}/latency_raw_${TEST_TYPE}_${TIMESTAMP}.csv"
LATENCY_STATS_FILE="${LATENCY_OUTPUT_DIR}/latency_stats_${TEST_TYPE}_${TIMESTAMP}.csv"

# Ensure output directory exists
mkdir -p "${LATENCY_OUTPUT_DIR}"

# Function to display usage
show_usage() {
    echo "Usage: $0 [iterations] [test_type]"
    echo ""
    echo "Enhanced Latency Analysis - Phase 1 Dissertation Research"
    echo ""
    echo "Parameters:"
    echo "  iterations  Number of test iterations (default: 50)"
    echo "  test_type   Type of test to run (default: create)"
    echo ""
    echo "Test Types:"
    echo "  create      End-to-end EHR creation latency"
    echo "  read        EHR read latency (same-org)"
    echo "  read_cross  EHR read latency (cross-org with consent)"
    echo "  update      EHR update transaction latency"
    echo "  consent     Grant/Revoke consent latency"
    echo "  unauthorized Read unauthorized access (expected failure latency)"
    echo "  all         Run all operation types"
    echo ""
    echo "Output Files:"
    echo "  Raw Data:    ${LATENCY_RAW_FILE}"
    echo "  Statistics:  ${LATENCY_STATS_FILE}"
    echo ""
    echo "Examples:"
    echo "  $0 100 create     # 100 creation transactions"
    echo "  $0 50 cross_org   # 50 cross-org transactions"
}

# Enhanced function for end-to-end transaction timing with confirmation
invoke_chaincode_with_confirmation() {
    local function_name="$1"
    local args="$2"
    local transaction_id="$3"
    
    # Start timing
    local start_time=$(date +%s.%N)
    
    # Submit transaction and capture output
    local invoke_result
    invoke_result=$(peer chaincode invoke \
        -o ${ORDERER_ENDPOINT} \
        --tls \
        --cafile "${ORDERER_CA}" \
        -C ${CHANNEL_NAME} \
        -n ${CHAINCODE_NAME} \
        --peerAddresses ${PEER0_ORG1_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG1_TLS_ROOTCERT} \
        --peerAddresses ${PEER0_ORG2_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG2_TLS_ROOTCERT} \
        -c "{\"function\":\"${function_name}\",\"Args\":[${args}]}" \
        2>&1)
    
    local invoke_status=$?
    
    # End timing 
    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc)
    
    # Extract transaction ID from output (if successful)
    local txid=""
    if [ $invoke_status -eq 0 ]; then
        # Look for transaction ID in the output
        txid=$(echo "$invoke_result" | grep -o 'txid \[[^]]*\]' | sed 's/txid \[\(.*\)\]/\1/' | head -1)
    fi
    
    # Return status and duration
    echo "${invoke_status}:${duration}:${txid}"
}

# Enhanced function for query timing
query_chaincode_with_timing() {
    local function_name="$1"
    local args="$2"
    
    local start_time=$(date +%s.%N)
    
    local query_result
    query_result=$(peer chaincode query \
        -C ${CHANNEL_NAME} \
        -n ${CHAINCODE_NAME} \
        -c "{\"function\":\"${function_name}\",\"Args\":[${args}]}" \
        2>/dev/null)
    
    local query_status=$?
    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc)
    
    echo "${query_status}:${duration}"
}

# Function to run latency analysis for CREATE operations
analyze_create_latency() {
    local iterations=$1
    
    print_info "Starting End-to-End CREATE Latency Analysis"
    print_info "Iterations: ${iterations}"
    print_info "Output: ${LATENCY_RAW_FILE}"
    
    # Generate unique patient ID prefix based on timestamp to avoid conflicts
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="LAT_CREATE_${timestamp}_P"
    
    # Initialize CSV header
    echo "Transaction_ID,Patient_ID,Start_Time,End_Time,Latency_Seconds,Status" > "${LATENCY_RAW_FILE}"
    
    local successful_count=0
    local failed_count=0
    
    # Array to store latencies for statistics calculation
    declare -a latencies=()
    
    for i in $(seq 1 $iterations); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        local patient_name="Latency Test Patient ${i}"
        
        print_info "Creating EHR ${i}/${iterations} for patient ${patient_id}"
        
        local start_timestamp=$(date +%s.%N)
        
        # Use the same create_ehr function that we know works
        local latency
        latency=$(create_ehr "${patient_id}" "${patient_name}")
        local exit_status=$?
        
        local end_timestamp
        
        # Record result
        if [ "$exit_status" -eq 0 ] && [ -n "$latency" ] && [[ "$latency" =~ ^[0-9]*\.?[0-9]+$ ]]; then
            end_timestamp=$(echo "${start_timestamp} + ${latency}" | bc)
            local result_status="SUCCESS"
            ((successful_count++))
            latencies+=("$latency")
        else
            local result_status="FAILED"
            ((failed_count++))
            latency="0.000000"  # Set to 0 for failed transactions
            end_timestamp=""
        fi
        
        echo "${i},${patient_id},${start_timestamp},${end_timestamp},${latency},${result_status}" >> "${LATENCY_RAW_FILE}"
        
        # Small delay to avoid overwhelming the network
        sleep 0.05
    done
    
    # Calculate and save statistics
    calculate_latency_statistics "${latencies[@]}"
    
    print_success "CREATE Latency Analysis completed!"
    print_info "Total transactions: ${iterations}"
    print_info "Successful: ${successful_count}"
    print_info "Failed: ${failed_count}"
    print_info "Raw data saved to: ${LATENCY_RAW_FILE}"
    print_info "Statistics saved to: ${LATENCY_STATS_FILE}"
}

# Function to run latency analysis for READ operations (same-org)
analyze_read_latency() {
    local iterations=$1
    
    print_info "Starting READ Latency Analysis (Same-Org)"
    print_info "Iterations: ${iterations}"
    
    # Generate unique patient ID prefix based on timestamp to avoid conflicts
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="LAT_READ_${timestamp}_P"
    
    # First, create test data with unique naming
    print_info "Setting up test data (10 patients)..."
    local test_patients=()
    for i in $(seq 1 10); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        print_info "Creating test patient: ${patient_id}"
        create_ehr "${patient_id}" "Read Test Patient ${i}" > /dev/null 2>&1
        test_patients+=("$patient_id")
    done
    
    # Initialize CSV header
    echo "Transaction_ID,Patient_ID,Start_Time,End_Time,Latency_Seconds,Status" > "${LATENCY_RAW_FILE}"
    
    local successful_count=0
    local failed_count=0
    declare -a latencies=()
    
    for i in $(seq 1 $iterations); do
        # Cycle through test patients
        local patient_index=$(( (i - 1) % 10 ))
        local patient_id="${test_patients[$patient_index]}"
        
        print_info "Reading EHR ${i}/${iterations} for patient ${patient_id}"
        
        local start_timestamp=$(date +%s.%N)
        
        # Use data verification for first 2 reads to prove actual data retrieval
        local latency
        if [ $i -le 2 ]; then
            latency=$(read_ehr "${patient_id}" "true")
        else
            latency=$(read_ehr "${patient_id}")
        fi
        local exit_status=$?
        
        # Record result
        if [ "$exit_status" -eq 0 ] && [ -n "$latency" ] && [[ "$latency" =~ ^[0-9]*\.?[0-9]+$ ]]; then
            local end_timestamp=$(echo "${start_timestamp} + ${latency}" | bc)
            local result_status="SUCCESS"
            ((successful_count++))
            latencies+=("$latency")
        else
            local result_status="FAILED"
            ((failed_count++))
            latency="0.000000"  # Set to 0 for failed transactions
            local end_timestamp=""
        fi
        
        echo "${i},${patient_id},${start_timestamp},${end_timestamp},${latency},${result_status}" >> "${LATENCY_RAW_FILE}"
    done
    
    # Calculate and save statistics
    calculate_latency_statistics "${latencies[@]}"
    
    print_success "READ Latency Analysis completed!"
    print_info "Total transactions: ${iterations}"
    print_info "Successful: ${successful_count}"
    print_info "Failed: ${failed_count}"
}

# Function to run latency analysis for UPDATE operations
analyze_update_latency() {
    local iterations=$1
    
    print_info "Starting UPDATE Latency Analysis"
    print_info "Iterations: ${iterations}"
    
    # Generate unique patient ID prefix based on timestamp to avoid conflicts
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="LAT_UPD_${timestamp}_P"
    
    # Create initial test data with unique naming
    print_info "Setting up test data for updates..."
    local test_patients=()
    for i in $(seq 1 10); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        create_ehr "${patient_id}" "Update Test Patient ${i}" > /dev/null 2>&1
        test_patients+=("$patient_id")
    done
    
    # Initialize CSV header
    echo "Transaction_ID,Patient_ID,Start_Time,End_Time,Latency_Seconds,Status" > "${LATENCY_RAW_FILE}"
    
    local successful_count=0
    local failed_count=0
    declare -a latencies=()
    
    for i in $(seq 1 $iterations); do
        # Cycle through test patients
        local patient_index=$(( (i - 1) % 10 ))
        local patient_id="${test_patients[$patient_index]}"
        local updated_name="Updated Patient ${i}"
        
        print_info "Updating EHR ${i}/${iterations} for patient ${patient_id}"
        
        local start_timestamp=$(date +%s.%N)
        
        # Use the update_ehr function
        local latency
        latency=$(update_ehr "${patient_id}" "${updated_name}")
        local exit_status=$?
        
        # Record result
        if [ "$exit_status" -eq 0 ] && [ -n "$latency" ] && [[ "$latency" =~ ^[0-9]*\.?[0-9]+$ ]]; then
            local end_timestamp=$(echo "${start_timestamp} + ${latency}" | bc)
            local result_status="SUCCESS"
            ((successful_count++))
            latencies+=("$latency")
        else
            local result_status="FAILED"
            ((failed_count++))
            latency="0.000000"
            local end_timestamp=""
        fi
        
        echo "${i},${patient_id},${start_timestamp},${end_timestamp},${latency},${result_status}" >> "${LATENCY_RAW_FILE}"
        
        sleep 0.05
    done
    
    # Calculate and save statistics
    calculate_latency_statistics "${latencies[@]}"
    
    print_success "UPDATE Latency Analysis completed!"
    print_info "Total transactions: ${iterations}"
    print_info "Successful: ${successful_count}"
    print_info "Failed: ${failed_count}"
}

# Function to run latency analysis for CONSENT operations (Grant/Revoke)
analyze_consent_latency() {
    local iterations=$1
    
    print_info "Starting CONSENT Latency Analysis (Grant/Revoke)"
    print_info "Iterations: ${iterations}"
    
    # Generate unique patient ID prefix based on timestamp to avoid conflicts
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="LAT_CNS_${timestamp}_P"
    
    # Create test data with unique naming
    print_info "Setting up test data for consent operations..."
    local test_patients=()
    for i in $(seq 1 5); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        create_ehr "${patient_id}" "Consent Test Patient ${i}" > /dev/null 2>&1
        test_patients+=("$patient_id")
    done
    
    # Initialize CSV header
    echo "Transaction_ID,Patient_ID,Operation,Start_Time,End_Time,Latency_Seconds,Status" > "${LATENCY_RAW_FILE}"
    
    local successful_count=0
    local failed_count=0
    declare -a latencies=()
    
    for i in $(seq 1 $iterations); do
        # Cycle through test patients
        local patient_index=$(( (i - 1) % 5 ))
        local patient_id="${test_patients[$patient_index]}"
        
        # Alternate between Grant and Revoke
        if [ $((i % 2)) -eq 1 ]; then
            local operation="GRANT"
            print_info "Granting consent ${i}/${iterations} for patient ${patient_id}"
            
            local start_timestamp=$(date +%s.%N)
            local latency
            latency=$(grant_consent "${patient_id}" "[\"org2admin\"]")
            local exit_status=$?
        else
            local operation="REVOKE"
            print_info "Revoking consent ${i}/${iterations} for patient ${patient_id}"
            
            local start_timestamp=$(date +%s.%N)
            local latency
            latency=$(revoke_consent "${patient_id}")
            local exit_status=$?
        fi
        
        local end_timestamp
        
        # Record result
        if [ "$exit_status" -eq 0 ] && [ -n "$latency" ] && [[ "$latency" =~ ^[0-9]*\.?[0-9]+$ ]]; then
            end_timestamp=$(echo "${start_timestamp} + ${latency}" | bc)
            local result_status="SUCCESS"
            ((successful_count++))
            latencies+=("$latency")
        else
            local result_status="FAILED"
            ((failed_count++))
            latency="0.000000"
            end_timestamp=""
        fi
        
        echo "${i},${patient_id},${operation},${start_timestamp},${end_timestamp},${latency},${result_status}" >> "${LATENCY_RAW_FILE}"
        
        sleep 0.1
    done
    
    # Calculate and save statistics
    calculate_latency_statistics "${latencies[@]}"
    
    print_success "CONSENT Latency Analysis completed!"
    print_info "Total transactions: ${iterations}"
    print_info "Successful: ${successful_count}"
    print_info "Failed: ${failed_count}"
}

# Function to run latency analysis for Cross-Org READ operations
analyze_read_cross_latency() {
    local iterations=$1
    
    print_info "Starting READ Latency Analysis (Cross-Org with Consent)"
    print_info "Iterations: ${iterations}"
    
    # Generate unique patient ID prefix based on timestamp to avoid conflicts
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="LAT_XRD_${timestamp}_P"
    
    # Create test data and grant consent (as Org1) with unique naming
    print_info "Setting up test data with cross-org consent..."
    local test_patients=()
    for i in $(seq 1 5); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        create_ehr "${patient_id}" "Cross-Org Read Test Patient ${i}" > /dev/null 2>&1
        grant_consent "${patient_id}" "[\"org2admin\"]" > /dev/null 2>&1
        test_patients+=("$patient_id")
    done
    
    # Switch to Org2 for cross-org reads
    setup_org2_env
    
    # Initialize CSV header
    echo "Transaction_ID,Patient_ID,Start_Time,End_Time,Latency_Seconds,Status" > "${LATENCY_RAW_FILE}"
    
    local successful_count=0
    local failed_count=0
    declare -a latencies=()
    
    for i in $(seq 1 $iterations); do
        # Cycle through test patients
        local patient_index=$(( (i - 1) % 5 ))
        local patient_id="${test_patients[$patient_index]}"
        
        print_info "Cross-org reading EHR ${i}/${iterations} for patient ${patient_id}"
        
        local start_timestamp=$(date +%s.%N)
        
        # Use data verification for first 2 cross-org reads to prove actual data retrieval
        local latency
        if [ $i -le 2 ]; then
            latency=$(read_ehr "${patient_id}" "true")  # Enable data verification
        else
            latency=$(read_ehr "${patient_id}")
        fi
        local exit_status=$?
        
        local end_timestamp
        
        # Record result
        if [ "$exit_status" -eq 0 ] && [ -n "$latency" ] && [[ "$latency" =~ ^[0-9]*\.?[0-9]+$ ]]; then
            end_timestamp=$(echo "${start_timestamp} + ${latency}" | bc)
            local result_status="SUCCESS"
            ((successful_count++))
            latencies+=("$latency")
        else
            local result_status="FAILED"
            ((failed_count++))
            latency="0.000000"
            end_timestamp=""
        fi
        
        echo "${i},${patient_id},${start_timestamp},${end_timestamp},${latency},${result_status}" >> "${LATENCY_RAW_FILE}"
    done
    
    # Reset to Org1
    setup_org1_env
    
    # Calculate and save statistics
    calculate_latency_statistics "${latencies[@]}"
    
    print_success "Cross-Org READ Latency Analysis completed!"
    print_info "Total transactions: ${iterations}"
    print_info "Successful: ${successful_count}"
    print_info "Failed: ${failed_count}"
}

# Function to run latency analysis for UNAUTHORIZED read operations
analyze_unauthorized_latency() {
    local iterations=$1
    
    print_info "Starting UNAUTHORIZED READ Latency Analysis (Expected Failures)"
    print_info "Iterations: ${iterations}"
    
    # Generate unique patient ID prefix based on timestamp to avoid conflicts
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local unique_prefix="LAT_UNA_${timestamp}_P"
    
    # Create test data WITHOUT granting cross-org consent (as Org1) with unique naming
    print_info "Setting up test data without cross-org consent..."
    local test_patients=()
    for i in $(seq 1 5); do
        local patient_id="${unique_prefix}$(printf "%06d" $i)"
        create_ehr "${patient_id}" "Unauthorized Test Patient ${i}" > /dev/null 2>&1
        # Deliberately NOT granting consent for cross-org access
        test_patients+=("$patient_id")
    done
    
    # Switch to Org2 to attempt unauthorized reads
    setup_org2_env
    
    # Initialize CSV header
    echo "Transaction_ID,Patient_ID,Start_Time,End_Time,Latency_Seconds,Status,Expected" > "${LATENCY_RAW_FILE}"
    
    local successful_count=0
    local failed_count=0
    declare -a latencies=()
    
    for i in $(seq 1 $iterations); do
        # Cycle through test patients
        local patient_index=$(( (i - 1) % 5 ))
        local patient_id="${test_patients[$patient_index]}"
        
        print_info "Attempting unauthorized read ${i}/${iterations} for patient ${patient_id}"
        
        local start_timestamp=$(date +%s.%N)
        
        # Attempt unauthorized read (should fail)
        local latency
        latency=$(read_ehr "${patient_id}")
        local exit_status=$?
        
        # For unauthorized access, we expect failures but still measure latency
        if [ -n "$latency" ] && [[ "$latency" =~ ^[0-9]*\.?[0-9]+$ ]]; then
            local end_timestamp=$(echo "${start_timestamp} + ${latency}" | bc)
            latencies+=("$latency")
            if [ "$exit_status" -ne 0 ]; then
                local result_status="FAILED"
                ((failed_count++))
            else
                local result_status="UNEXPECTED_SUCCESS"
                ((successful_count++))
            fi
        else
            local result_status="NO_RESPONSE"
            latency="0.000000"
            local end_timestamp=""
            ((failed_count++))
        fi
        
        echo "${i},${patient_id},${start_timestamp},${end_timestamp},${latency},${result_status},EXPECTED_FAILURE" >> "${LATENCY_RAW_FILE}"
    done
    
    # Reset to Org1
    setup_org1_env
    
    # Calculate and save statistics (even for failed operations)
    calculate_latency_statistics "${latencies[@]}"
    
    print_success "UNAUTHORIZED READ Latency Analysis completed!"
    print_info "Total transactions: ${iterations}"
    print_info "Expected failures: ${failed_count}"
    print_info "Unexpected successes: ${successful_count}"
}

# Function to run all operation types
analyze_all_operations() {
    local iterations=$1
    
    # Use the full iteration count for each operation type (not divided)
    local base_iterations=$iterations
    
    print_info "Starting COMPREHENSIVE Latency Analysis - All Operation Types"
    print_info "Total iterations requested: ${iterations}"
    print_info "Base iterations per operation: ${base_iterations}"
    
    # Run all operation types
    local operations=("create" "read" "read_cross" "update" "consent" "unauthorized")
    
    for operation in "${operations[@]}"; do
        print_info "Running ${operation} latency analysis..."
        
        # Update file names for each operation
        LATENCY_RAW_FILE="${LATENCY_OUTPUT_DIR}/latency_raw_${operation}_${TIMESTAMP}.csv"
        LATENCY_STATS_FILE="${LATENCY_OUTPUT_DIR}/latency_stats_${operation}_${TIMESTAMP}.csv"
        
        case $operation in
            "create")
                analyze_create_latency $base_iterations
                ;;
            "read")
                analyze_read_latency $base_iterations
                ;;
            "read_cross")
                analyze_read_cross_latency $base_iterations
                ;;
            "update")
                analyze_update_latency $base_iterations
                ;;
            "consent")
                analyze_consent_latency $base_iterations
                ;;
            "unauthorized")
                analyze_unauthorized_latency $base_iterations
                ;;
        esac
        
        print_info "Completed ${operation} analysis"
        echo "---"
    done
    
    print_success "COMPREHENSIVE Analysis completed for all operation types!"
}

# Function to calculate latency distribution statistics
calculate_latency_statistics() {
    local latencies=("$@")
    local count=${#latencies[@]}
    
    if [ $count -eq 0 ]; then
        print_warning "No successful transactions to analyze"
        return 1
    fi
    
    print_info "Calculating latency distribution statistics for ${count} successful transactions..."
    
    # Sort latencies
    IFS=$'\n' sorted=($(sort -n <<<"${latencies[*]}"))
    unset IFS
    
    # Calculate percentiles with proper handling for small samples
    local p50_index p95_index p99_index
    
    # For P50 (median)
    if [ $count -eq 1 ]; then
        p50_index=0
    elif [ $count -eq 2 ]; then
        # For 2 elements, median is the average (we'll handle this specially)
        p50_index=0  # Will be calculated as average below
    else
        p50_index=$(echo "scale=0; ($count * 50) / 100" | bc)
        p50_index=$((p50_index > 0 ? p50_index - 1 : 0))
    fi
    
    # For P95
    if [ $count -le 2 ]; then
        p95_index=$((count - 1))  # Use the maximum value
    else
        p95_index=$(echo "scale=0; ($count * 95) / 100" | bc)
        p95_index=$((p95_index > 0 ? p95_index - 1 : 0))
    fi
    
    # For P99
    if [ $count -le 2 ]; then
        p99_index=$((count - 1))  # Use the maximum value
    else
        p99_index=$(echo "scale=0; ($count * 99) / 100" | bc)
        p99_index=$((p99_index > 0 ? p99_index - 1 : 0))
    fi
    
    # Calculate percentile values
    local p95=${sorted[$p95_index]}
    local p99=${sorted[$p99_index]}
    
    # Special handling for P50 when count=2 (median is average of two values)
    local p50
    if [ $count -eq 2 ]; then
        p50=$(echo "scale=9; (${sorted[0]} + ${sorted[1]}) / 2" | bc)
    else
        p50=${sorted[$p50_index]}
    fi
    local min=${sorted[0]}
    local max=${sorted[$((count-1))]}
    
    # Calculate mean
    local sum=0
    for latency in "${latencies[@]}"; do
        sum=$(echo "$sum + $latency" | bc)
    done
    local mean=$(echo "scale=6; $sum / $count" | bc)
    
    # Calculate standard deviation
    local variance_sum=0
    for latency in "${latencies[@]}"; do
        local diff=$(echo "$latency - $mean" | bc)
        local squared=$(echo "$diff * $diff" | bc)
        variance_sum=$(echo "$variance_sum + $squared" | bc)
    done
    local variance=$(echo "scale=6; $variance_sum / $count" | bc)
    local std_dev=$(echo "scale=6; sqrt($variance)" | bc -l)
    
    # Save statistics to file
    cat > "${LATENCY_STATS_FILE}" << EOF
# End-to-End Latency Distribution Analysis
# Test Type: ${TEST_TYPE}
# Timestamp: ${TIMESTAMP}
# Sample Size: ${count}

Metric,Value_Seconds,Value_Milliseconds
Count,${count},${count}
Minimum,${min},$(echo "scale=3; ${min} * 1000" | bc)
Maximum,${max},$(echo "scale=3; ${max} * 1000" | bc)
Mean,${mean},$(echo "scale=3; ${mean} * 1000" | bc)
Standard_Deviation,${std_dev},$(echo "scale=3; ${std_dev} * 1000" | bc)
P50_Median,${p50},$(echo "scale=3; ${p50} * 1000" | bc)
P95,${p95},$(echo "scale=3; ${p95} * 1000" | bc)
P99,${p99},$(echo "scale=3; ${p99} * 1000" | bc)
EOF
    
    # Display results
    print_success "Latency Distribution Statistics:"
    printf "  Sample Size:     %d transactions\n" $count
    local min_ms=$(echo "scale=3; $min * 1000" | bc)
    local max_ms=$(echo "scale=3; $max * 1000" | bc)  
    local mean_ms=$(echo "scale=3; $mean * 1000" | bc)
    local std_ms=$(echo "scale=3; $std_dev * 1000" | bc)
    local p50_ms=$(echo "scale=3; $p50 * 1000" | bc)
    local p95_ms=$(echo "scale=3; $p95 * 1000" | bc)
    local p99_ms=$(echo "scale=3; $p99 * 1000" | bc)
    printf "  Minimum:         %s ms\n" "$min_ms"
    printf "  Maximum:         %s ms\n" "$max_ms"
    printf "  Mean:            %s ms\n" "$mean_ms"
    printf "  Std Deviation:   %s ms\n" "$std_ms"
    printf "  P50 (Median):    %s ms\n" "$p50_ms"
    printf "  P95:             %s ms\n" "$p95_ms"
    printf "  P99:             %s ms\n" "$p99_ms"
}

# Main execution logic
main() {
    # Check if help is requested
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # Initialize Fabric environment
    print_info "Setting up Fabric environment for latency analysis..."
    setup_fabric_environment || exit 1
    
    print_info "Starting Phase 1 - End-to-End Latency Distribution Analysis"
    print_info "Test Type: ${TEST_TYPE}"
    print_info "Iterations: ${LATENCY_TEST_ITERATIONS}"
    print_info "Output Directory: ${LATENCY_OUTPUT_DIR}"
    
    case $TEST_TYPE in
        "create")
            analyze_create_latency $LATENCY_TEST_ITERATIONS
            ;;
        "read")
            analyze_read_latency $LATENCY_TEST_ITERATIONS
            ;;
        "read_cross")
            analyze_read_cross_latency $LATENCY_TEST_ITERATIONS
            ;;
        "update")
            analyze_update_latency $LATENCY_TEST_ITERATIONS
            ;;
        "consent")
            analyze_consent_latency $LATENCY_TEST_ITERATIONS
            ;;
        "unauthorized")
            analyze_unauthorized_latency $LATENCY_TEST_ITERATIONS
            ;;
        "all")
            analyze_all_operations $LATENCY_TEST_ITERATIONS
            ;;
        *)
            print_error "Unsupported test type: $TEST_TYPE"
            print_info "Supported types: create, read, read_cross, update, consent, unauthorized, all"
            exit 1
            ;;
    esac
    
    print_success "Phase 1 Latency Analysis completed successfully!"
    print_info "Raw data: ${LATENCY_RAW_FILE}"
    print_info "Statistics: ${LATENCY_STATS_FILE}"
}

# Run main function
main "$@"
