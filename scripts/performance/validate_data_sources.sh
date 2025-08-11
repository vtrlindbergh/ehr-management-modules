#!/bin/bash

# =============================================================================
# Data Source Validation Script
# Validates that all three test types extract the most recent data
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Override directories with absolute paths for validation
LATENCY_DIR="${SCRIPT_DIR}/../results/latency_analysis"
THROUGHPUT_DIR="${SCRIPT_DIR}/../results/throughput_analysis"
PARALLEL_DIR="${SCRIPT_DIR}/../results/parallel_analysis"

echo "==================================================="
echo "DATA SOURCE VALIDATION REPORT"
echo "==================================================="
echo "Timestamp: $(date)"
echo ""

# 1. LATENCY ANALYSIS DATA SOURCES
echo "1. LATENCY ANALYSIS DATA SOURCES"
echo "--------------------------------"
echo "Directory: $LATENCY_DIR"
echo ""

for operation in "create" "read" "read_cross" "update" "consent" "unauthorized"; do
    latest_file=$(find "$LATENCY_DIR" -name "latency_stats_${operation}_*.csv" -type f | sort | tail -1)
    if [ -f "$latest_file" ]; then
        timestamp=$(basename "$latest_file" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
        sample_size=$(grep "Count," "$latest_file" | cut -d',' -f2)
        echo "  $operation: $timestamp (Sample: $sample_size)"
    else
        echo "  $operation: NO DATA FOUND"
    fi
done

echo ""

# 2. THROUGHPUT ANALYSIS DATA SOURCES
echo "2. THROUGHPUT ANALYSIS DATA SOURCES"
echo "-----------------------------------"
echo "Directory: $THROUGHPUT_DIR"
echo ""

# Latest throughput test files
throughput_files=($(find "${THROUGHPUT_DIR}" -name "throughput_test_*.csv" -type f | sort | tail -5))
echo "Recent throughput test files:"
for file in "${throughput_files[@]}"; do
    if [ -f "$file" ]; then
        timestamp=$(basename "$file" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
        operation=$(grep "^SUMMARY" "$file" | cut -d',' -f2)
        tps=$(grep "^SUMMARY" "$file" | cut -d',' -f6)
        echo "  $timestamp: $operation ($tps TPS)"
    fi
done

echo ""

# Individual operation throughput files
for operation in "create" "read" "update" "consent" "cross_org"; do
    op_files=($(find "$THROUGHPUT_DIR" -name "throughput_${operation}_*.csv" -type f | sort | tail -1))
    if [ ${#op_files[@]} -gt 0 ] && [ -f "${op_files[0]}" ]; then
        timestamp=$(basename "${op_files[0]}" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
        echo "  $operation: $timestamp"
    else
        echo "  $operation: NO SPECIFIC FILE FOUND"
    fi
done

echo ""

# 3. PARALLEL/SCALING ANALYSIS DATA SOURCES
echo "3. PARALLEL/SCALING ANALYSIS DATA SOURCES"
echo "-----------------------------------------"
echo "Directory: $PARALLEL_DIR"
echo ""

# Scaling test directories
scaling_dirs=($(find "${PARALLEL_DIR}" -maxdepth 1 -name "scaling_*" -type d | sort))
echo "Scaling test directories:"
for dir in "${scaling_dirs[@]}"; do
    timestamp=$(basename "$dir" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
    worker_counts=($(ls "$dir/individual_tests/" 2>/dev/null | grep "workers_" | sed 's/workers_//' | sort -n))
    echo "  $timestamp: Workers [${worker_counts[*]}]"
done

echo ""

# Most recent scaling test data validation
latest_scaling=$(find "${PARALLEL_DIR}" -maxdepth 1 -name "scaling_*" -type d | sort | tail -1)
if [ -d "$latest_scaling" ]; then
    echo "Most recent scaling test: $(basename $latest_scaling)"
    echo "Worker data availability:"
    for workers in 1 2 4 8 12 16; do
        worker_dir="$latest_scaling/individual_tests/workers_$workers"
        if [ -d "$worker_dir" ]; then
            summary_file=$(find "$worker_dir" -name "*summary*.csv" | head -1)
            if [ -f "$summary_file" ]; then
                summary_line=$(grep "^SUMMARY" "$summary_file" | head -1)
                if [ -n "$summary_line" ]; then
                    tps=$(echo "$summary_line" | cut -d',' -f7)
                    echo "  Workers $workers: ✅ $tps TPS"
                else
                    echo "  Workers $workers: ❌ No summary line"
                fi
            else
                echo "  Workers $workers: ❌ No summary file"
            fi
        else
            echo "  Workers $workers: ❌ No directory"
        fi
    done
fi

echo ""

# 4. VALIDATION SUMMARY
echo "4. VALIDATION SUMMARY"
echo "--------------------"

# Check if we have recent data for all three test types
latency_recent=$(find "$LATENCY_DIR" -name "latency_stats_*_20250810_*.csv" | wc -l)
throughput_recent=$(find "$THROUGHPUT_DIR" -name "throughput_*_20250810_*.csv" | wc -l)
scaling_recent=$(find "$PARALLEL_DIR" -name "scaling_20250810_*" -type d | wc -l)

echo "Recent data availability (today: 20250810):"
echo "  Latency tests: $latency_recent files"
echo "  Throughput tests: $throughput_recent files"
echo "  Scaling tests: $scaling_recent directories"

if [ "$latency_recent" -gt 0 ] && [ "$throughput_recent" -gt 0 ] && [ "$scaling_recent" -gt 0 ]; then
    echo ""
    echo "✅ ALL THREE TEST TYPES have recent data available"
    echo "✅ Ready for Phase C implementation"
else
    echo ""
    echo "⚠️  Some test types may be missing recent data"
    echo "   Consider running additional tests if needed"
fi

echo ""
echo "==================================================="
