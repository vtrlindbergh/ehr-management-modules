#!/bin/bash

# =============================================================================
# Parallel Results Organization Script
# Academic Project - Master's Dissertation
# Final Version: Organize parallel testing results for analysis
# =============================================================================

# Source required utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Configuration
RESULTS_BASE="${RESULTS_DIR}/parallel_analysis"
ORGANIZED_BASE="${RESULTS_BASE}/organized"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Function to show usage
show_usage() {
    echo "Parallel Results Organization - Final Version"
    echo "============================================"
    echo "Usage: $0 [action]"
    echo ""
    echo "Actions:"
    echo "  organize     Organize existing parallel_* directories"
    echo "  clean        Clean up old unorganized directories" 
    echo "  status       Show current organization status"
    echo "  help         Show this help message"
    echo ""
    echo "Organization Structure:"
    echo "  parallel_analysis/"
    echo "  ├── organized/"
    echo "  │   ├── by_date/"
    echo "  │   │   └── YYYY-MM-DD/"
    echo "  │   ├── by_workers/"
    echo "  │   │   ├── workers_01/"
    echo "  │   │   ├── workers_04/"
    echo "  │   │   ├── workers_08/"
    echo "  │   │   └── workers_16/"
    echo "  │   ├── latest/"
    echo "  │   └── index.csv"
    echo "  ├── parallel_YYYYMMDD_HHMMSS/"
    echo "  └── scaling_YYYYMMDD_HHMMSS/"
}

# Function to analyze directory and extract metadata
analyze_parallel_directory() {
    local dir_path="$1"
    local dir_name=$(basename "$dir_path")
    
    # Extract timestamp from directory name
    local timestamp=$(echo "$dir_name" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
    
    # Extract worker count from summary file
    local worker_count=""
    local summary_file=""
    
    # Try both naming patterns
    summary_file=$(find "$dir_path" -name "parallel_summary_*.csv" -o -name "parallel_enhanced_summary_*.csv" | head -1)
    
    if [ -f "$summary_file" ]; then
        # Extract worker count from summary file header
        worker_count=$(grep "# System:" "$summary_file" | grep -o '[0-9]\+ workers' | grep -o '[0-9]\+')
    fi
    
    # Extract test type from summary
    local test_type=""
    if [ -f "$summary_file" ]; then
        test_type=$(grep "# Configuration:" "$summary_file" | grep -o '[a-z_]\+ operations' | cut -d' ' -f1)
    fi
    
    # Extract transaction count
    local transaction_count=""
    if [ -f "$summary_file" ]; then
        transaction_count=$(grep "^SUMMARY" "$summary_file" | head -1 | cut -d',' -f4)
    fi
    
    # Return metadata
    echo "${timestamp}|${worker_count}|${test_type}|${transaction_count}|${dir_path}"
}

# Function to organize parallel results by date
organize_by_date() {
    print_info "Organizing parallel results by date..."
    
    local date_base="${ORGANIZED_BASE}/by_date"
    mkdir -p "$date_base"
    
    # Find all parallel directories
    find "$RESULTS_BASE" -maxdepth 1 -type d -name "parallel_*" | while read -r dir; do
        local metadata=$(analyze_parallel_directory "$dir")
        local timestamp=$(echo "$metadata" | cut -d'|' -f1)
        local worker_count=$(echo "$metadata" | cut -d'|' -f2)
        local test_type=$(echo "$metadata" | cut -d'|' -f3)
        
        if [ -n "$timestamp" ]; then
            local date_part=$(echo "$timestamp" | cut -d'_' -f1)
            local formatted_date="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}"
            local date_dir="${date_base}/${formatted_date}"
            
            mkdir -p "$date_dir"
            
            # Create symbolic link with descriptive name
            local link_name="${timestamp}_w${worker_count}_${test_type}"
            if [ ! -e "${date_dir}/${link_name}" ]; then
                ln -sf "$dir" "${date_dir}/${link_name}"
                print_success "Linked: ${formatted_date}/${link_name}"
            fi
        fi
    done
}

# Function to organize parallel results by worker count
organize_by_workers() {
    print_info "Organizing parallel results by worker count..."
    
    local workers_base="${ORGANIZED_BASE}/by_workers"
    mkdir -p "$workers_base"
    
    # Find all parallel directories
    find "$RESULTS_BASE" -maxdepth 1 -type d -name "parallel_*" | while read -r dir; do
        local metadata=$(analyze_parallel_directory "$dir")
        local timestamp=$(echo "$metadata" | cut -d'|' -f1)
        local worker_count=$(echo "$metadata" | cut -d'|' -f2)
        local test_type=$(echo "$metadata" | cut -d'|' -f3)
        
        if [ -n "$worker_count" ]; then
            local workers_dir="${workers_base}/workers_$(printf "%02d" "$worker_count")"
            mkdir -p "$workers_dir"
            
            # Create symbolic link with descriptive name
            local link_name="${timestamp}_${test_type}"
            if [ ! -e "${workers_dir}/${link_name}" ]; then
                ln -sf "$dir" "${workers_dir}/${link_name}"
                print_success "Linked: workers_$(printf "%02d" "$worker_count")/${link_name}"
            fi
        fi
    done
}

# Function to create latest links
create_latest_links() {
    print_info "Creating latest result links..."
    
    local latest_base="${ORGANIZED_BASE}/latest"
    mkdir -p "$latest_base"
    
    # Find latest results for each worker count
    for workers in 1 2 4 8 12 16; do
        local latest_dir=$(find "$RESULTS_BASE" -maxdepth 1 -type d -name "parallel_*" | while read -r dir; do
            local metadata=$(analyze_parallel_directory "$dir")
            local worker_count=$(echo "$metadata" | cut -d'|' -f2)
            local timestamp=$(echo "$metadata" | cut -d'|' -f1)
            
            if [ "$worker_count" = "$workers" ]; then
                echo "${timestamp}|${dir}"
            fi
        done | sort -r | head -1 | cut -d'|' -f2)
        
        if [ -n "$latest_dir" ]; then
            local link_name="latest_workers_$(printf "%02d" "$workers")"
            rm -f "${latest_base}/${link_name}"
            ln -sf "$latest_dir" "${latest_base}/${link_name}"
            print_success "Latest link: ${link_name}"
        fi
    done
    
    # Create overall latest link
    local overall_latest=$(find "$RESULTS_BASE" -maxdepth 1 -type d -name "parallel_*" | while read -r dir; do
        local metadata=$(analyze_parallel_directory "$dir")
        local timestamp=$(echo "$metadata" | cut -d'|' -f1)
        echo "${timestamp}|${dir}"
    done | sort -r | head -1 | cut -d'|' -f2)
    
    if [ -n "$overall_latest" ]; then
        rm -f "${latest_base}/latest_overall"
        ln -sf "$overall_latest" "${latest_base}/latest_overall"
        print_success "Overall latest link created"
    fi
}

# Function to create summary index
create_summary_index() {
    print_info "Creating summary index..."
    
    local index_file="${ORGANIZED_BASE}/parallel_results_index.csv"
    
    cat > "$index_file" << EOF
# Parallel Results Index - Final Version
# Generated: $(date)
# Academic Project - Comprehensive Organization

TIMESTAMP,WORKER_COUNT,TEST_TYPE,SUCCESSFUL_TRANSACTIONS,TOTAL_TPS,SUCCESS_RATE,DIRECTORY_PATH
EOF

    # Analyze all directories and create index
    find "$RESULTS_BASE" -maxdepth 1 -type d -name "parallel_*" | while read -r dir; do
        local metadata=$(analyze_parallel_directory "$dir")
        local timestamp=$(echo "$metadata" | cut -d'|' -f1)
        local worker_count=$(echo "$metadata" | cut -d'|' -f2)
        local test_type=$(echo "$metadata" | cut -d'|' -f3)
        local transaction_count=$(echo "$metadata" | cut -d'|' -f4)
        
        # Extract additional metrics from summary file
        local summary_file=$(find "$dir" -name "*summary_*.csv" | head -1)
        if [ -f "$summary_file" ]; then
            local summary_line=$(grep "^SUMMARY" "$summary_file" | head -1)
            if [ -n "$summary_line" ]; then
                local total_tps=$(echo "$summary_line" | cut -d',' -f7)
                local success_rate=$(echo "$summary_line" | cut -d',' -f6)
                
                echo "${timestamp},${worker_count},${test_type},${transaction_count},${total_tps},${success_rate},${dir}" >> "$index_file"
            fi
        fi
    done
    
    print_success "Summary index created: $index_file"
}

# Function to show organization status
show_status() {
    print_header "Parallel Results Organization Status"
    
    # Count total directories
    local total_dirs=$(find "$RESULTS_BASE" -maxdepth 1 -type d -name "parallel_*" | wc -l)
    print_info "Total parallel directories: $total_dirs"
    
    # Show organization structure
    if [ -d "$ORGANIZED_BASE" ]; then
        print_info "Organization structure:"
        tree "$ORGANIZED_BASE" 2>/dev/null || ls -la "$ORGANIZED_BASE"
    else
        print_warning "No organization structure found. Run 'organize' action first."
    fi
    
    # Show worker count distribution
    print_info "Distribution by worker count:"
    find "$RESULTS_BASE" -maxdepth 1 -type d -name "parallel_*" | while read -r dir; do
        local metadata=$(analyze_parallel_directory "$dir")
        local worker_count=$(echo "$metadata" | cut -d'|' -f2)
        echo "$worker_count"
    done | sort -n | uniq -c | while read -r count workers; do
        print_info "  ${workers} workers: ${count} tests"
    done
}

# Function to clean up old directories
clean_old_directories() {
    print_header "Cleaning Up Old Directories"
    
    print_warning "This will move old parallel_* directories to archive/"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local archive_dir="${ORGANIZED_BASE}/archive"
        mkdir -p "$archive_dir"
        
        local cutoff_date=$(date -d "7 days ago" +%Y%m%d)
        
        find "$RESULTS_BASE" -maxdepth 1 -type d -name "parallel_*" | while read -r dir; do
            local metadata=$(analyze_parallel_directory "$dir")
            local timestamp=$(echo "$metadata" | cut -d'|' -f1)
            local date_part=$(echo "$timestamp" | cut -d'_' -f1)
            
            if [ "$date_part" -lt "$cutoff_date" ]; then
                local archive_name="$(basename "$dir")_archived_${TIMESTAMP}"
                mv "$dir" "${archive_dir}/${archive_name}"
                print_success "Archived: $(basename "$dir")"
            fi
        done
    else
        print_info "Cleanup cancelled"
    fi
}

# Main execution function
main() {
    local action=${1:-"status"}
    
    case "$action" in
        "organize")
            print_header "Organizing Parallel Results - Final Version"
            organize_by_date
            organize_by_workers
            create_latest_links
            create_summary_index
            print_success "Organization complete!"
            ;;
        "clean")
            clean_old_directories
            ;;
        "status")
            show_status
            ;;
        "help"|"--help")
            show_usage
            ;;
        *)
            print_error "Unknown action: $action"
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
