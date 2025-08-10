#!/bin/bash

# =============================================================================
# Parallel Performance Demo Script
# Academic Project - Master's Dissertation
# Demonstrates parallel cross-organizational throughput testing
# Optimized for multi-core systems (8-core recommended)
# =============================================================================

# Source required utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

print_info "Setting up Fabric environment for parallel demo..."
setup_fabric_environment || exit 1

print_info "=== EHR Management Parallel Performance Testing Demo ==="
print_info "Academic Project - Master's Dissertation"
print_info "Optimized for Multi-Core Systems (8-core recommended)"
echo ""

# Demo 1: Baseline parallel test
print_info "Demo 1: Baseline Parallel Test (100 total iterations, 4 workers)"
echo "This establishes baseline parallel performance."
echo ""

print_info "Running PARALLEL CROSS-ORG test (4 workers)..."
./parallel_test.sh 100 4 cross_org
echo ""

# Demo 2: Full 8-core test  
print_info "Demo 2: Full 8-Core Test (200 total iterations, 8 workers)"
echo "This demonstrates maximum parallel throughput on 8-core systems."
echo ""

print_info "Running PARALLEL CROSS-ORG test (8 workers)..."
./parallel_test.sh 200 8 cross_org
echo ""

print_success "=== Parallel Performance Demo Complete! ==="
print_info "Results demonstrate scaling from 4 to 8 workers"
print_info "Check ../results/parallel_analysis/ directories for detailed metrics"

# Show recent results comparison
echo ""
print_info "Performance Summary:"
echo "- 4 workers: 25 iterations each (academic standard)"  
echo "- 8 workers: 25 iterations each (academic standard)"
echo "- Validates cross-org authorization under parallel load"
echo "- Simulates multiple hospitals accessing data simultaneously"
echo "- Results saved in organized parallel_analysis structure"
