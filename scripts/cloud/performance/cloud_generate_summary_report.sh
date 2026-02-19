#!/bin/bash

# =============================================================================
# Performance Summary Report Generator — CLOUD VERSION
# Academic Project - Master's Dissertation
#
# Adapted from scripts/performance/generate_summary_report.sh for distributed
# cloud deployment across 3 Azure VMs with Docker Swarm overlay network.
#
# Reads cloud-collected CSVs from scripts/cloud/results/ and generates
# reports in the SAME format as local reports for direct comparison.
#
# Run this script FROM the Org1 VM or locally after downloading results.
# =============================================================================

# Source cloud configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Report parameters — cloud results directory
RESULTS_DIR="${SCRIPT_DIR}/../results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SUMMARY_DIR="${RESULTS_DIR}/performance_reports"
SUMMARY_REPORT="${SUMMARY_DIR}/cloud_performance_summary_${TIMESTAMP}.md"
CSV_REPORT="${SUMMARY_DIR}/cloud_performance_summary_${TIMESTAMP}.csv"
LATENCY_DIR="${RESULTS_DIR}/latency_analysis"
THROUGHPUT_DIR="${RESULTS_DIR}/throughput_analysis"
PARALLEL_DIR="${RESULTS_DIR}/parallel_analysis"

mkdir -p "$SUMMARY_DIR"

# Function to display usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Cloud Performance Summary Report Generator — Academic Research"
    echo ""
    echo "Options:"
    echo "  -l, --latency-only    Generate only latency summary"
    echo "  -t, --throughput-only Generate only throughput summary"
    echo "  -p, --parallel-only   Generate only parallel summary"
    echo "  -f, --format FORMAT   Output format: md, csv, both (default: both)"
    echo "  -o, --output DIR      Output directory (default: ../results/performance_reports)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Cloud Environment:"
    echo "  Orderer:  ${ORDERER_VM_IP}:7050  (VM1)"
    echo "  Org1:     ${ORG1_VM_IP}:7051     (VM2)"
    echo "  Org2:     ${ORG2_VM_IP}:9051     (VM3)"
    echo ""
    echo "Output Files:"
    echo "  Markdown: ${SUMMARY_REPORT}"
    echo "  CSV:      ${CSV_REPORT}"
}

# =============================================================================
# Data Extraction Functions (same logic as local, points to cloud results)
# =============================================================================

extract_latency_stats() {
    local operation="$1"
    local stats_file="$2"

    if [ ! -f "$stats_file" ]; then
        echo "N/A,N/A,N/A,N/A,N/A,N/A,N/A"
        return
    fi

    local count=$(grep "^Count," "$stats_file" | cut -d',' -f2)
    local mean_ms=$(grep "^Mean," "$stats_file" | cut -d',' -f3)
    local std_ms=$(grep "^Standard_Deviation," "$stats_file" | cut -d',' -f3)
    local p50_ms=$(grep "^P50_Median," "$stats_file" | cut -d',' -f3)
    local p95_ms=$(grep "^P95," "$stats_file" | cut -d',' -f3)
    local p99_ms=$(grep "^P99," "$stats_file" | cut -d',' -f3)
    local min_ms=$(grep "^Minimum," "$stats_file" | cut -d',' -f3)
    local max_ms=$(grep "^Maximum," "$stats_file" | cut -d',' -f3)

    local range="${min_ms}-${max_ms}"

    echo "${count:-N/A},${mean_ms:-N/A},${std_ms:-N/A},${p50_ms:-N/A},${p95_ms:-N/A},${p99_ms:-N/A},${range:-N/A}"
}

find_latest_latency_stats() {
    local operation="$1"
    find "$LATENCY_DIR" -name "latency_stats_${operation}_[0-9]*.csv" -type f 2>/dev/null | sort | tail -1
}

extract_throughput_stats() {
    local operation="$1"

    local operation_lowercase
    case "$operation" in
        "CREATE") operation_lowercase="create" ;;
        "READ") operation_lowercase="read" ;;
        "UPDATE") operation_lowercase="update" ;;
        "CONSENT") operation_lowercase="consent" ;;
        "CROSS_ORG") operation_lowercase="cross_org" ;;
        *) operation_lowercase=$(echo "$operation" | tr '[:upper:]' '[:lower:]') ;;
    esac

    local throughput_files=($(find "${THROUGHPUT_DIR}" -name "throughput_${operation_lowercase}_*.csv" -type f 2>/dev/null | sort | tail -1))

    if [ ${#throughput_files[@]} -eq 0 ]; then
        throughput_files=($(find "${THROUGHPUT_DIR}" -name "throughput_test_*.csv" -type f 2>/dev/null | sort | tail -1))
    fi

    if [ ${#throughput_files[@]} -eq 0 ]; then
        echo "N/A,N/A,N/A,N/A,N/A"
        return
    fi

    local total_tps=0
    local count=0
    local max_tps=0
    local min_tps=999999
    local tps_values=()

    for file in "${throughput_files[@]}"; do
        if [ -f "$file" ]; then
            local tps=$(grep "^SUMMARY,${operation}," "$file" | tail -1 | cut -d',' -f6 2>/dev/null)
            if [ -n "$tps" ] && [[ "$tps" =~ ^[0-9]*\.?[0-9]+$ ]]; then
                tps_values+=("$tps")
                total_tps=$(echo "$total_tps + $tps" | bc)
                count=$((count + 1))
                if (( $(echo "$tps > $max_tps" | bc -l) )); then
                    max_tps=$tps
                fi
                if (( $(echo "$tps < $min_tps" | bc -l) )); then
                    min_tps=$tps
                fi
            fi
        fi
    done

    if [ $count -eq 0 ]; then
        echo "N/A,N/A,N/A,N/A,N/A"
        return
    fi

    local avg_tps=$(echo "scale=2; $total_tps / $count" | bc)
    local range="${min_tps}-${max_tps}"

    echo "${count},${avg_tps},${min_tps},${max_tps},${range}"
}

extract_parallel_stats() {
    local worker_count="$1"

    local scaling_dirs=($(find "${PARALLEL_DIR}" -maxdepth 1 -name "scaling_*" -type d 2>/dev/null | sort -r))

    for scaling_dir in "${scaling_dirs[@]}"; do
        local worker_dir="$scaling_dir/individual_tests/workers_${worker_count}"
        if [ -d "$worker_dir" ]; then
            local summary_file=$(find "$worker_dir" -maxdepth 1 -name "*summary*.csv" 2>/dev/null | head -1)
            if [ -f "$summary_file" ]; then
                local summary_line=$(grep "^SUMMARY" "$summary_file" 2>/dev/null | head -1)
                if [ -n "$summary_line" ]; then
                    local test_type=$(echo "$summary_line" | cut -d',' -f2)
                    local workers_actual=$(echo "$summary_line" | cut -d',' -f3)
                    local successful=$(echo "$summary_line" | cut -d',' -f4)
                    local failed=$(echo "$summary_line" | cut -d',' -f5)
                    local success_rate=$(echo "$summary_line" | cut -d',' -f6)
                    local total_tps=$(echo "$summary_line" | cut -d',' -f7)
                    local total_time=$(echo "$summary_line" | cut -d',' -f8)

                    if [ "$workers_actual" = "$worker_count" ]; then
                        local total_transactions=$((successful + failed))
                        local tps_per_worker=$(echo "scale=2; $total_tps / $worker_count" | bc -l 2>/dev/null || echo "N/A")

                        echo "${test_type},${total_transactions},${success_rate},${total_tps},${tps_per_worker},N/A,${total_time}"
                        return
                    fi
                fi
            fi
        fi
    done

    # Fallback: search parallel test summary files
    local parallel_files=($(find "${PARALLEL_DIR}" -maxdepth 2 -name "*summary*.csv" -type f 2>/dev/null | sort -r | head -10))

    for file in "${parallel_files[@]}"; do
        if [ -f "$file" ]; then
            local summary_line=$(grep "^SUMMARY" "$file" 2>/dev/null | head -1)
            if [ -n "$summary_line" ]; then
                local workers_in_file=$(echo "$summary_line" | cut -d',' -f3)
                if [ "$workers_in_file" = "$worker_count" ]; then
                    local test_type=$(echo "$summary_line" | cut -d',' -f2)
                    local successful=$(echo "$summary_line" | cut -d',' -f4)
                    local failed=$(echo "$summary_line" | cut -d',' -f5)
                    local success_rate=$(echo "$summary_line" | cut -d',' -f6)
                    local total_tps=$(echo "$summary_line" | cut -d',' -f7)
                    local total_time=$(echo "$summary_line" | cut -d',' -f8)

                    local total_transactions=$((successful + failed))
                    local tps_per_worker=$(echo "scale=2; $total_tps / $worker_count" | bc -l 2>/dev/null || echo "N/A")

                    echo "${test_type},${total_transactions},${success_rate},${total_tps},${tps_per_worker},N/A,${total_time}"
                    return
                fi
            fi
        fi
    done

    echo "N/A,N/A,N/A,N/A,N/A,N/A,N/A"
}

# =============================================================================
# Report Generation Functions
# =============================================================================

generate_latency_summary() {
    local format="$1"

    print_info "Generating cloud latency summary..."

    local operations=("create" "read" "read_cross" "update" "consent" "unauthorized")
    local operation_names=("CreateEHR" "ReadEHR (same-org)" "ReadEHR (cross-org)" "UpdateEHR" "Consent (Grant/Revoke)" "Unauthorized Read")

    if [ "$format" = "md" ] || [ "$format" = "both" ]; then
        cat >> "$SUMMARY_REPORT" << 'EOF'
# Latency Analysis Summary (Cloud)

## End-to-End Latency Distribution Results — Distributed Deployment

| Operation Type | Sample Size | Mean (ms) | Std Dev (ms) | P50 (ms) | P95 (ms) | P99 (ms) | Range (ms) |
|---|---|---|---|---|---|---|---|
EOF

        for i in "${!operations[@]}"; do
            local op="${operations[$i]}"
            local op_name="${operation_names[$i]}"
            local stats_file=$(find_latest_latency_stats "$op")
            local stats=$(extract_latency_stats "$op" "$stats_file")

            IFS=',' read -r count mean std p50 p95 p99 range <<< "$stats"
            echo "| **${op_name}** | ${count} | ${mean} | ${std} | ${p50} | ${p95} | ${p99} | ${range} |" >> "$SUMMARY_REPORT"
        done

        cat >> "$SUMMARY_REPORT" << 'EOF'

### Key Insights (Cloud):
- Latency includes real network hops between Azure VMs across subnets
- Docker Swarm overlay (VXLAN) adds encapsulation overhead vs local Docker bridge
- Cross-org operations traverse VM boundaries (Org1 VM → Org2 VM)
- Orderer communication crosses subnet (10.0.2.x → 10.0.1.x)

EOF
    fi

    if [ "$format" = "csv" ] || [ "$format" = "both" ]; then
        cat > "$CSV_REPORT" << EOF
# Cloud Performance Summary Report - Academic Research
# Deployment: 3 Azure VMs (${VM_SIZE}), Docker Swarm overlay, ${AZURE_REGION}
# Generated: $(date)

Operation_Type,Sample_Size,Mean_ms,Std_Dev_ms,P50_ms,P95_ms,P99_ms,Range_ms
EOF

        for i in "${!operations[@]}"; do
            local op="${operations[$i]}"
            local op_name="${operation_names[$i]}"
            local stats_file=$(find_latest_latency_stats "$op")
            local stats=$(extract_latency_stats "$op" "$stats_file")

            echo "${op_name},${stats}" >> "$CSV_REPORT"
        done
    fi
}

generate_throughput_summary() {
    local format="$1"

    print_info "Generating cloud throughput summary..."

    local operations=("CREATE" "READ" "UPDATE" "CONSENT" "CROSS_ORG")
    local operation_names=("CreateEHR" "ReadEHR" "UpdateEHR" "Consent" "Cross-Org")

    if [ "$format" = "md" ] || [ "$format" = "both" ]; then
        cat >> "$SUMMARY_REPORT" << 'EOF'
# Throughput Analysis Summary (Cloud)

## Transaction Throughput Results — Distributed Deployment

| Operation Type | Sample Size | TPS | Duration (s) | Deployment |
|---|---|---|---|---|
EOF

        for i in "${!operations[@]}"; do
            local op="${operations[$i]}"
            local op_name="${operation_names[$i]}"
            local stats=$(extract_throughput_stats "$op")

            IFS=',' read -r count avg_tps min_tps max_tps range <<< "$stats"
            local duration=$(echo "scale=2; 500 / $avg_tps" | bc 2>/dev/null || echo "N/A")
            echo "| **${op_name}** | 500 | ${avg_tps} | ${duration} | Cloud (3 VMs) |" >> "$SUMMARY_REPORT"
        done

        cat >> "$SUMMARY_REPORT" << 'EOF'

### Key Insights (Cloud):
- TPS reflects real distributed network overhead (inter-VM communication)
- Endorsement requests cross Azure VNet subnets between VMs
- Block delivery from orderer traverses separate subnet
- Direct comparison with local results reveals distributed deployment cost

EOF
    fi

    if [ "$format" = "csv" ] || [ "$format" = "both" ]; then
        cat >> "$CSV_REPORT" << EOF

# Cloud Throughput Analysis
# Deployment: 3 Azure VMs (${VM_SIZE}), Docker Swarm overlay
Operation_Type,Sample_Size,TPS,Duration_Seconds,Deployment
EOF

        for i in "${!operations[@]}"; do
            local op="${operations[$i]}"
            local op_name="${operation_names[$i]}"
            local stats=$(extract_throughput_stats "$op")

            IFS=',' read -r count avg_tps min_tps max_tps range <<< "$stats"
            local duration=$(echo "scale=2; 500 / $avg_tps" | bc 2>/dev/null || echo "N/A")
            echo "${op_name},500,${avg_tps},${duration},Cloud (3 VMs)" >> "$CSV_REPORT"
        done
    fi
}

generate_parallel_summary() {
    local format="$1"

    print_info "Generating cloud parallel scaling analysis summary..."

    # Cloud-adapted worker counts (fewer than local due to VM resource constraints)
    local worker_counts=(1 2 4 8)
    local system_cores=$(nproc)

    if [ "$format" = "md" ] || [ "$format" = "both" ]; then
        cat >> "$SUMMARY_REPORT" << EOF

# Parallel Scaling Analysis (Cloud)

## Scaling Performance — Distributed Deployment (${VM_SIZE})

| Workers | Test Type | Total Transactions | Success Rate | Total TPS | TPS/Worker | Duration (s) |
|---------|-----------|-------------------|--------------|-----------|------------|-------------|
EOF

        for workers in "${worker_counts[@]}"; do
            local stats=$(extract_parallel_stats "$workers")
            IFS=',' read -r test_type transactions success_rate total_tps tps_per_worker scaling_efficiency total_time <<< "$stats"

            printf "| %-7s | %-9s | %-17s | %-12s | %-9s | %-10s | %-11s |\n" \
                "$workers" \
                "$test_type" \
                "$transactions" \
                "${success_rate}%" \
                "$total_tps" \
                "$tps_per_worker" \
                "$total_time" >> "$SUMMARY_REPORT"
        done

        cat >> "$SUMMARY_REPORT" << EOF

### Cloud Scaling Analysis Insights

#### Cloud-Specific Characteristics
- **VM Resources**: ${VM_SIZE} (${VM_VCPUS} vCPU, ${VM_RAM_GB} GB RAM per VM)
- **Network**: Docker Swarm overlay with VXLAN encapsulation across Azure VNet
- **Parallelism Limit**: Fewer vCPUs than local machine limits scaling ceiling
- **I/O Bound**: Blockchain consensus is network-bound, not CPU-bound

#### Comparison with Local Results
- Cloud parallel scaling is expected to plateau at fewer workers (VM resource limits)
- Network latency between VMs adds constant overhead to each transaction
- Swarm overlay adds ~1-2ms per packet compared to local Docker bridge
- Cross-org operations show more latency variance due to inter-VM hops

EOF
    fi

    if [ "$format" = "csv" ] || [ "$format" = "both" ]; then
        echo "" >> "$CSV_REPORT"
        echo "# Cloud Parallel Scaling Analysis Results" >> "$CSV_REPORT"
        echo "# VM Size: ${VM_SIZE} (${VM_VCPUS} vCPU, ${VM_RAM_GB} GB RAM)" >> "$CSV_REPORT"
        echo "Workers,Test_Type,Total_Transactions,Success_Rate,Total_TPS,TPS_Per_Worker,Scaling_Efficiency_Percent,Test_Duration_Seconds" >> "$CSV_REPORT"

        for workers in "${worker_counts[@]}"; do
            local stats=$(extract_parallel_stats "$workers")
            echo "${workers},${stats}" >> "$CSV_REPORT"
        done
    fi
}

# =============================================================================
# Complete Report Generation
# =============================================================================

generate_complete_report() {
    local format="$1"

    if [ "$format" = "md" ] || [ "$format" = "both" ]; then
        cat > "$SUMMARY_REPORT" << EOF
# EHR Blockchain Performance Analysis — Cloud Deployment
**Academic Research - Master's Dissertation**  
**Generated:** $(date)  
**System:** Hyperledger Fabric v${FABRIC_VERSION}  
**Deployment:** 3 Azure VMs (${VM_SIZE}), Docker Swarm overlay, ${AZURE_REGION}  
**Network:** Orderer (${ORDERER_VM_IP}) | Org1 (${ORG1_VM_IP}) | Org2 (${ORG2_VM_IP})

---

EOF
    fi

    generate_latency_summary "$format"
    generate_throughput_summary "$format"
    generate_parallel_summary "$format"

    if [ "$format" = "md" ] || [ "$format" = "both" ]; then
        cat >> "$SUMMARY_REPORT" << EOF
---

## Cloud System Configuration
- **Blockchain Platform:** Hyperledger Fabric v${FABRIC_VERSION}
- **Certificate Authority:** v${CA_VERSION}
- **Go Version:** ${GO_VERSION}
- **Network Setup:** 2 Organizations (Org1, Org2) across 3 Azure VMs
- **Consensus:** Raft Ordering Service
- **Security:** TLS Enabled, MSP Authentication
- **Chaincode:** ehrCC v2.0 (sequence 2), Go, FHIR-based EHR model
- **Channel:** ${CHANNEL_NAME}

## Azure Infrastructure
- **VM Size:** ${VM_SIZE} (${VM_VCPUS} vCPU, ${VM_RAM_GB} GB RAM)
- **Region:** ${AZURE_REGION}
- **Network:** Docker Swarm overlay (${SWARM_OVERLAY_NETWORK})
- **VNet:** 10.0.0.0/16 with 3 subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
- **Orderer VM:** ${ORDERER_VM_IP} (10.0.1.0/24)
- **Org1 VM:** ${ORG1_VM_IP} (10.0.2.0/24)
- **Org2 VM:** ${ORG2_VM_IP} (10.0.3.0/24)

## Methodology
- **Same chaincode, same operations, same measurement methodology as local**
- **Only infrastructure changed:** local Docker → 3-VM Docker Swarm
- **Latency Tests:** End-to-end transaction timing with nanosecond precision
- **Throughput Tests:** Concurrent transaction processing measurement
- **Metrics:** P50, P95, P99 percentiles, mean, standard deviation
- **Operations:** CREATE, READ (same/cross-org), UPDATE, CONSENT, UNAUTHORIZED

*Report generated for academic research — local vs cloud comparison.*
EOF
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    local latency_only=false
    local throughput_only=false
    local parallel_only=false
    local format="both"
    local output_dir="${SUMMARY_DIR}"

    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--latency-only)
                latency_only=true
                shift
                ;;
            -t|--throughput-only)
                throughput_only=true
                shift
                ;;
            -p|--parallel-only)
                parallel_only=true
                shift
                ;;
            -f|--format)
                format="$2"
                shift 2
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    if [[ ! "$format" =~ ^(md|csv|both)$ ]]; then
        print_error "Invalid format: $format. Use 'md', 'csv', or 'both'"
        exit 1
    fi

    mkdir -p "$output_dir"

    SUMMARY_REPORT="${output_dir}/cloud_performance_summary_${TIMESTAMP}.md"
    CSV_REPORT="${output_dir}/cloud_performance_summary_${TIMESTAMP}.csv"

    print_header "Cloud Performance Summary Report Generator"
    print_info "Deployment: 3 Azure VMs (${VM_SIZE}), Docker Swarm overlay"
    print_info "Output directory: $output_dir"
    print_info "Format: $format"

    if [ "$latency_only" = true ]; then
        generate_latency_summary "$format"
    elif [ "$throughput_only" = true ]; then
        generate_throughput_summary "$format"
    elif [ "$parallel_only" = true ]; then
        generate_parallel_summary "$format"
    else
        generate_complete_report "$format"
    fi

    print_success "Cloud performance summary report generated!"

    if [ "$format" = "md" ] || [ "$format" = "both" ]; then
        print_success "Markdown report: $SUMMARY_REPORT"
    fi
    if [ "$format" = "csv" ] || [ "$format" = "both" ]; then
        print_success "CSV report: $CSV_REPORT"
    fi

    echo ""
    print_info "Report preview:"
    echo "------------------------"
    if [ "$format" = "md" ] || [ "$format" = "both" ]; then
        head -20 "$SUMMARY_REPORT"
    else
        head -20 "$CSV_REPORT"
    fi
}

main "$@"
