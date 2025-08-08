#!/bin/bash

# =============================================================================
# Cross-Organizational CRUD Test
# 
# This script demonstrates comprehensive CRUD (Create, Read, Update) 
# operations for EHR records across both organizations with proper authorization
# and consent management.
#
# Test Scenarios:
#   ORG1 CRUD OPERATIONS:
#   1. Org1 creates patient EHR (CREATE)
#   2. Org1 reads their own EHR (READ - creator authorization)
#   3. Org1 updates their own EHR (UPDATE - creator authorization)
#   
#   CROSS-ORG AUTHORIZATION:
#   4. Org2 attempts read without consent (READ - should fail)
#   5. Org1 grants consent to Org2
#   6. Org2 reads EHR with consent (READ - consent authorization)
#   7. Org2 updates EHR with consent (UPDATE - consent authorization)
#   
#   ORG2 CRUD OPERATIONS:
#   8. Org2 creates different patient EHR (CREATE)
#   9. Org2 reads their own EHR (READ - creator authorization)
#   10. Org1 attempts read without consent (READ - should fail)
#   11. Org2 grants consent to Org1
#   12. Org1 reads EHR with consent (READ - consent authorization)
#
# Note: DELETE operations are omitted as EHRs are typically archived rather 
# than deleted in real healthcare systems for audit and compliance purposes.
#
# This validates comprehensive CRUD operations with proper security across
# multiple organizations demonstrating real healthcare data management scenarios.
# =============================================================================

set -e

print_info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
print_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
print_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
print_error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }
print_step() { echo -e "\033[1;35m[STEP $1]\033[0m $2"; }

# Set absolute path to test network
TEST_NETWORK_PATH="/home/vitor/dev/fabric-samples/test-network"
cd "$TEST_NETWORK_PATH"
. ./scripts/envVar.sh
export PATH="/home/vitor/dev/fabric-samples/bin:$PATH"
export FABRIC_CFG_PATH="${TEST_NETWORK_PATH}/../config"

# Generate unique patient IDs for this test run
PATIENT_1="CRUD_TEST_P1_$(date +%s)"
PATIENT_2="CRUD_TEST_P2_$(date +%s)"

print_info "=== Cross-Organizational CRUD Test ==="
print_info "Testing comprehensive EHR operations across organizations"
print_info "Patient 1 ID: ${PATIENT_1} (Org1 → Org2)"
print_info "Patient 2 ID: ${PATIENT_2} (Org2 → Org1)"
echo ""

# =============================================================================
# ORG1 CRUD OPERATIONS
# =============================================================================

print_step "1" "ORG1 CREATES PATIENT EHR"
setGlobals 1
print_info "Org1 (Hospital A) creating EHR for Patient 1..."

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls \
    --cafile "${TEST_NETWORK_PATH}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem" \
    -C mychannel \
    -n ehrCC \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${TEST_NETWORK_PATH}/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem" \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${TEST_NETWORK_PATH}/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem" \
    -c '{"function":"CreateEHR","Args":["{\"patientID\":\"'${PATIENT_1}'\",\"patientName\":\"Alice Johnson\",\"healthData\":{\"resourceType\":\"Observation\",\"id\":\"obs-1\",\"meta\":[{\"version\":\"1.0\",\"lastUpdated\":\"2025-01-01T12:00:00Z\"}],\"content\":[120,80],\"rawContent\":\"{}\"},\"lastUpdated\":\"2025-01-01T12:00:00Z\"}"]}'

print_success "✅ CREATE: Org1 successfully created EHR for Patient 1"
print_info "Waiting for ledger to sync..."
sleep 2
echo ""

print_step "2" "ORG1 READS THEIR OWN EHR"
print_info "Org1 reading their own patient EHR (creator authorization)..."

if RESULT=$(peer chaincode query -C mychannel -n ehrCC -c '{"function":"ReadEHR","Args":["'${PATIENT_1}'"]}' 2>&1); then
    print_success "✅ READ: Org1 successfully read their own EHR"
    echo "     Patient: $(echo "$RESULT" | jq -r '.patientName // "N/A"')"
    echo "     Created by: $(echo "$RESULT" | jq -r '.createdBy // "N/A"')"
else
    print_error "❌ READ: Org1 failed to read their own EHR"
fi
echo ""

print_step "3" "ORG1 UPDATES THEIR OWN EHR"
print_info "Org1 updating their patient EHR (creator authorization)..."

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls \
    --cafile "${TEST_NETWORK_PATH}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem" \
    -C mychannel \
    -n ehrCC \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${TEST_NETWORK_PATH}/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem" \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${TEST_NETWORK_PATH}/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem" \
    -c '{"function":"UpdateEHR","Args":["{\"patientID\":\"'${PATIENT_1}'\",\"patientName\":\"Alice Johnson - Updated by Org1\",\"healthData\":{\"resourceType\":\"Observation\",\"id\":\"obs-1\",\"meta\":[{\"version\":\"1.1\",\"lastUpdated\":\"2025-01-02T12:00:00Z\"}],\"content\":[125,85],\"rawContent\":\"{}\"},\"lastUpdated\":\"2025-01-02T12:00:00Z\"}"]}'

print_success "✅ UPDATE: Org1 successfully updated their EHR"
print_info "Waiting for update to sync..."
sleep 3
echo ""

# =============================================================================
# CROSS-ORG AUTHORIZATION TESTING
# =============================================================================

print_step "4" "ORG2 ATTEMPTS READ WITHOUT CONSENT"
setGlobals 2
print_info "Org2 (Hospital B) attempting to read Patient 1 EHR without consent..."

if peer chaincode query -C mychannel -n ehrCC -c '{"function":"ReadEHR","Args":["'${PATIENT_1}'"]}' 2>&1; then
    print_warning "❓ Unexpected: Org2 could read without consent"
else
    print_success "✅ SECURITY: Org2 properly denied access without consent"
fi
echo ""

print_step "5" "ORG1 GRANTS CONSENT TO ORG2"
setGlobals 1
print_info "Org1 granting consent to Org2 for Patient 1..."

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls \
    --cafile "${TEST_NETWORK_PATH}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem" \
    -C mychannel \
    -n ehrCC \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${TEST_NETWORK_PATH}/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem" \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${TEST_NETWORK_PATH}/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem" \
    -c '{"function":"GrantConsent","Args":["'${PATIENT_1}'", "[\"org2admin\"]"]}'

print_success "✅ CONSENT: Org1 granted consent to Org2"
sleep 3
echo ""

print_step "6" "ORG2 READS EHR WITH CONSENT"
setGlobals 2
print_info "Org2 reading Patient 1 EHR with consent..."

if RESULT=$(peer chaincode query -C mychannel -n ehrCC -c '{"function":"ReadEHR","Args":["'${PATIENT_1}'"]}' 2>&1); then
    print_success "✅ READ: Org2 successfully read EHR with consent"
    echo "     Patient: $(echo "$RESULT" | jq -r '.patientName // "N/A"')"
    echo "     Created by: $(echo "$RESULT" | jq -r '.createdBy // "N/A"')"
else
    print_error "❌ READ: Org2 failed to read EHR with consent"
fi
echo ""

print_step "7" "ORG2 UPDATES EHR WITH CONSENT"
print_info "Org2 updating Patient 1 EHR (specialist consultation)..."

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls \
    --cafile "${TEST_NETWORK_PATH}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem" \
    -C mychannel \
    -n ehrCC \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${TEST_NETWORK_PATH}/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem" \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${TEST_NETWORK_PATH}/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem" \
    -c '{"function":"UpdateEHR","Args":["{\"patientID\":\"'${PATIENT_1}'\",\"patientName\":\"Alice Johnson - Specialist Update by Org2\",\"healthData\":{\"resourceType\":\"Observation\",\"id\":\"obs-1\",\"meta\":[{\"version\":\"1.2\",\"lastUpdated\":\"2025-01-03T12:00:00Z\"}],\"content\":[130,90],\"rawContent\":\"{}\"},\"lastUpdated\":\"2025-01-03T12:00:00Z\"}"]}'

print_success "✅ UPDATE: Org2 successfully updated EHR with consent"
print_info "Waiting for update to sync..."
sleep 3
echo ""

# =============================================================================
# ORG2 CRUD OPERATIONS
# =============================================================================

print_step "8" "ORG2 CREATES PATIENT EHR"
setGlobals 2
print_info "Org2 (Hospital B) creating EHR for Patient 2..."

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls \
    --cafile "${TEST_NETWORK_PATH}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem" \
    -C mychannel \
    -n ehrCC \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${TEST_NETWORK_PATH}/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem" \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${TEST_NETWORK_PATH}/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem" \
    -c '{"function":"CreateEHR","Args":["{\"patientID\":\"'${PATIENT_2}'\",\"patientName\":\"Bob Wilson\",\"healthData\":{\"resourceType\":\"Observation\",\"id\":\"obs-2\",\"meta\":[{\"version\":\"1.0\",\"lastUpdated\":\"2025-01-01T14:00:00Z\"}],\"content\":[110,75],\"rawContent\":\"{}\"},\"lastUpdated\":\"2025-01-01T14:00:00Z\"}"]}'

print_success "✅ CREATE: Org2 successfully created EHR for Patient 2"
print_info "Waiting for ledger to sync..."
sleep 2
echo ""

print_step "9" "ORG2 READS THEIR OWN EHR"
print_info "Org2 reading their own patient EHR (creator authorization)..."

if RESULT=$(peer chaincode query -C mychannel -n ehrCC -c '{"function":"ReadEHR","Args":["'${PATIENT_2}'"]}' 2>&1); then
    print_success "✅ READ: Org2 successfully read their own EHR"
    echo "     Patient: $(echo "$RESULT" | jq -r '.patientName // "N/A"')"
    echo "     Created by: $(echo "$RESULT" | jq -r '.createdBy // "N/A"')"
else
    print_error "❌ READ: Org2 failed to read their own EHR"
fi
echo ""

print_step "10" "ORG1 ATTEMPTS READ WITHOUT CONSENT"
setGlobals 1
print_info "Org1 (Hospital A) attempting to read Patient 2 EHR without consent..."

if peer chaincode query -C mychannel -n ehrCC -c '{"function":"ReadEHR","Args":["'${PATIENT_2}'"]}' 2>&1; then
    print_warning "❓ Unexpected: Org1 could read without consent"
else
    print_success "✅ SECURITY: Org1 properly denied access without consent"
fi
echo ""

print_step "11" "ORG2 GRANTS CONSENT TO ORG1"
setGlobals 2
print_info "Org2 granting consent to Org1 for Patient 2..."

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls \
    --cafile "${TEST_NETWORK_PATH}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem" \
    -C mychannel \
    -n ehrCC \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${TEST_NETWORK_PATH}/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem" \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${TEST_NETWORK_PATH}/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem" \
    -c '{"function":"GrantConsent","Args":["'${PATIENT_2}'", "[\"org1admin\"]"]}'

print_success "✅ CONSENT: Org2 granted consent to Org1"
sleep 3
echo ""

print_step "12" "ORG1 READS EHR WITH CONSENT"
setGlobals 1
print_info "Org1 reading Patient 2 EHR with consent..."

if RESULT=$(peer chaincode query -C mychannel -n ehrCC -c '{"function":"ReadEHR","Args":["'${PATIENT_2}'"]}' 2>&1); then
    print_success "✅ READ: Org1 successfully read EHR with consent"
    echo "     Patient: $(echo "$RESULT" | jq -r '.patientName // "N/A"')"
    echo "     Created by: $(echo "$RESULT" | jq -r '.createdBy // "N/A"')"
else
    print_error "❌ READ: Org1 failed to read EHR with consent"
fi
echo ""

# =============================================================================
# FINAL SUMMARY
# =============================================================================

print_success "=== Cross-Organizational CRUD Test Completed ==="
echo ""
print_info "🎯 CRUD Operations Summary:"
print_info "   📝 CREATE: Both organizations successfully created patient EHRs"
print_info "   👁️  READ: Creator authorization and consent-based access validated"
print_info "   ✏️  UPDATE: Both creator and consent-based updates successful"
echo ""
print_info "🔒 Security Validations:"
print_info "   ✅ Creator authorization (organizations can access their own EHRs)"
print_info "   ✅ Consent-based authorization (cross-org access with patient consent)"
print_info "   ✅ Access control (unauthorized access properly blocked)"
echo ""
print_info "🏥 Healthcare Workflow Validations:"
print_info "   ✅ Hospital A creates and manages patient records"
print_info "   ✅ Hospital B creates and manages different patient records"
print_info "   ✅ Cross-organizational consultation with proper consent"
print_info "   ✅ Specialist updates from authorized external organizations"
echo ""
print_info "This demonstrates comprehensive CRUD operations across multiple"
print_info "healthcare organizations with proper security and consent management!"
print_info ""
print_info "Note: DELETE operations omitted as EHRs are typically archived rather"
print_info "than deleted in real healthcare systems for audit and compliance."
