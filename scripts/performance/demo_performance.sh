#!/bin/bash

# =============================================================================
# Demo Performance Testing Script
# Academic Project - Master's Dissertation
# Demonstrates various performance testing scenarios
# =============================================================================

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Initialize Fabric environment
print_info "Setting up Fabric environment for demo..."
setup_fabric_environment || exit 1

print_info "=== EHR Management Performance Testing Demo ==="
print_info "Academic Project - Master's Dissertation"
echo ""

# Demo 1: Small scale tests (good for development/testing)
print_info "Demo 1: Small Scale Testing (5 iterations each)"
echo "This demonstrates the basic functionality with small datasets."
echo ""

print_info "Running CREATE throughput test..."
./throughput_test.sh 5 create
echo ""

print_info "Running READ throughput test..."
./throughput_test.sh 5 read
echo ""

print_info "Running UPDATE throughput test..."
./throughput_test.sh 5 update
echo ""

# Demo 2: Medium scale test
print_info "Demo 2: Medium Scale Testing (25 operations)"
echo "This simulates a moderate load for system validation."
echo ""

print_info "Running FULL CYCLE test..."
./throughput_test.sh 25 full_cycle
echo ""

# Demo 3: Show consent throughput
print_info "Demo 3: Consent Management Testing (10 operations)"
echo "This tests the consent granting performance."
echo ""

print_info "Running CONSENT throughput test..."
./throughput_test.sh 10 consent
echo ""

print_success "=== Performance Testing Demo Complete! ==="
print_info "All results have been saved to the ../results/ directory"
print_info "Check the CSV files for detailed metrics and analysis"

# Show results summary
echo ""
print_info "Recent test results:"
ls -la ../results/throughput_test_*.csv | tail -5
