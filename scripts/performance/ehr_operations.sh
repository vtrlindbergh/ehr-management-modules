#!/bin/bash

# =============================================================================
# EHR Operations Utility Functions
# Academic Project - Master's Dissertation
# =============================================================================

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Function to generate FHIR-compliant EHR data
generate_fhir_ehr_data() {
    local patient_id="$1"
    local patient_name="${2:-Test Patient}"
    local timestamp="${3:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
    
    # Generate random vital signs for testing
    local systolic=$((110 + RANDOM % 40))  # 110-150
    local diastolic=$((70 + RANDOM % 30))   # 70-100
    
    cat << EOF
{
  "patientID": "${patient_id}",
  "patientName": "${patient_name}",
  "healthData": {
    "resourceType": "Observation",
    "id": "bp-reading-${patient_id}",
    "meta": [{
      "version": "1.0",
      "lastUpdated": "${timestamp}"
    }],
    "rawContent": "{\\\"resourceType\\\":\\\"Observation\\\",\\\"id\\\":\\\"bp-reading-${patient_id}\\\",\\\"status\\\":\\\"final\\\",\\\"category\\\":[{\\\"coding\\\":[{\\\"system\\\":\\\"http://terminology.hl7.org/CodeSystem/observation-category\\\",\\\"code\\\":\\\"vital-signs\\\",\\\"display\\\":\\\"Vital Signs\\\"}]}],\\\"code\\\":{\\\"coding\\\":[{\\\"system\\\":\\\"http://loinc.org\\\",\\\"code\\\":\\\"85354-9\\\",\\\"display\\\":\\\"Blood pressure panel\\\"}]},\\\"subject\\\":{\\\"reference\\\":\\\"Patient/${patient_id}\\\"},\\\"effectiveDateTime\\\":\\\"${timestamp}\\\",\\\"component\\\":[{\\\"code\\\":{\\\"coding\\\":[{\\\"system\\\":\\\"http://loinc.org\\\",\\\"code\\\":\\\"8480-6\\\",\\\"display\\\":\\\"Systolic blood pressure\\\"}]},\\\"valueQuantity\\\":{\\\"value\\\":${systolic},\\\"unit\\\":\\\"mmHg\\\"}},{\\\"code\\\":{\\\"coding\\\":[{\\\"system\\\":\\\"http://loinc.org\\\",\\\"code\\\":\\\"8462-4\\\",\\\"display\\\":\\\"Diastolic blood pressure\\\"}]},\\\"valueQuantity\\\":{\\\"value\\\":${diastolic},\\\"unit\\\":\\\"mmHg\\\"}}]}",
    "content": [${systolic}, ${diastolic}]
  },
  "lastUpdated": "${timestamp}"
}
EOF
}

# Function to create an EHR record
create_ehr() {
    local patient_id="$1"
    local patient_name="${2:-Test Patient}"
    local start_time=$(date +%s.%N)
    
    local ehr_data=$(generate_fhir_ehr_data "${patient_id}" "${patient_name}")
    
    peer chaincode invoke \
        -o ${ORDERER_ENDPOINT} \
        --tls \
        --cafile "${ORDERER_CA}" \
        -C ${CHANNEL_NAME} \
        -n ${CHAINCODE_NAME} \
        --peerAddresses ${PEER0_ORG1_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG1_TLS_ROOTCERT} \
        --peerAddresses ${PEER0_ORG2_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG2_TLS_ROOTCERT} \
        -c "{\"function\":\"CreateEHR\",\"Args\":[\"${ehr_data}\"]}" \
        2>/dev/null
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc)
    echo "${duration}"
}

# Function to grant consent for a patient
grant_consent() {
    local patient_id="$1"
    local authorized_users="${2:-[\"Org2MSP\"]}"  # Default to cross-org access for performance testing
    local start_time=$(date +%s.%N)
    
    peer chaincode invoke \
        -o ${ORDERER_ENDPOINT} \
        --tls \
        --cafile "${ORDERER_CA}" \
        -C ${CHANNEL_NAME} \
        -n ${CHAINCODE_NAME} \
        --peerAddresses ${PEER0_ORG1_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG1_TLS_ROOTCERT} \
        --peerAddresses ${PEER0_ORG2_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG2_TLS_ROOTCERT} \
        -c "{\"function\":\"GrantConsent\",\"Args\":[\"${patient_id}\", \"${authorized_users}\"]}" \
        2>/dev/null
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc)
    echo "${duration}"
}

# Function to read an EHR record
read_ehr() {
    local patient_id="$1"
    local start_time=$(date +%s.%N)
    
    peer chaincode query \
        -C ${CHANNEL_NAME} \
        -n ${CHAINCODE_NAME} \
        -c "{\"function\":\"ReadEHR\",\"Args\":[\"${patient_id}\"]}" \
        2>/dev/null
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc)
    echo "${duration}"
}

# Function to update an EHR record
update_ehr() {
    local patient_id="$1"
    local patient_name="${2:-Test Patient Updated}"
    local start_time=$(date +%s.%N)
    
    local ehr_data=$(generate_fhir_ehr_data "${patient_id}" "${patient_name}")
    
    peer chaincode invoke \
        -o ${ORDERER_ENDPOINT} \
        --tls \
        --cafile "${ORDERER_CA}" \
        -C ${CHANNEL_NAME} \
        -n ${CHAINCODE_NAME} \
        --peerAddresses ${PEER0_ORG1_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG1_TLS_ROOTCERT} \
        --peerAddresses ${PEER0_ORG2_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG2_TLS_ROOTCERT} \
        -c "{\"function\":\"UpdateEHR\",\"Args\":[\"${ehr_data}\"]}" \
        2>/dev/null
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc)
    echo "${duration}"
}

# Function to delete an EHR record
delete_ehr() {
    local patient_id="$1"
    local start_time=$(date +%s.%N)
    
    peer chaincode invoke \
        -o ${ORDERER_ENDPOINT} \
        --tls \
        --cafile "${ORDERER_CA}" \
        -C ${CHANNEL_NAME} \
        -n ${CHAINCODE_NAME} \
        --peerAddresses ${PEER0_ORG1_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG1_TLS_ROOTCERT} \
        --peerAddresses ${PEER0_ORG2_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG2_TLS_ROOTCERT} \
        -c "{\"function\":\"DeleteEHR\",\"Args\":[\"${patient_id}\"]}" \
        2>/dev/null
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc)
    echo "${duration}"
}

# Function to setup Org1 environment
setup_org1_env() {
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE="${TEST_NETWORK_PATH}/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem"
    export CORE_PEER_MSPCONFIGPATH="${TEST_NETWORK_PATH}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp"
    export CORE_PEER_ADDRESS="${PEER0_ORG1_ENDPOINT}"
}

# Function to setup Org2 environment
setup_org2_env() {
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE="${TEST_NETWORK_PATH}/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem"
    export CORE_PEER_MSPCONFIGPATH="${TEST_NETWORK_PATH}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp"
    export CORE_PEER_ADDRESS="${PEER0_ORG2_ENDPOINT}"
}

# Function to create EHR with specific organization
create_ehr_as_org() {
    local org="$1"
    local patient_id="$2"
    local patient_name="${3:-Test Patient}"
    
    # Switch to appropriate org
    if [ "$org" = "Org1" ]; then
        setup_org1_env
    elif [ "$org" = "Org2" ]; then
        setup_org2_env
    else
        echo "Error: Unknown organization $org"
        return 1
    fi
    
    create_ehr "$patient_id" "$patient_name"
}

# Function to read EHR with specific organization
read_ehr_as_org() {
    local org="$1"
    local patient_id="$2"
    
    # Switch to appropriate org
    if [ "$org" = "Org1" ]; then
        setup_org1_env
    elif [ "$org" = "Org2" ]; then
        setup_org2_env
    else
        echo "Error: Unknown organization $org"
        return 1
    fi
    
    read_ehr "$patient_id"
}

# Function to grant consent for cross-org access
grant_cross_org_consent() {
    local patient_id="$1"
    local from_org="$2"
    local to_org="$3"
    
    # Switch to the organization that owns the EHR (to grant consent)
    if [ "$from_org" = "Org1" ]; then
        setup_org1_env
        grant_consent "$patient_id" "[\"${to_org}MSP\"]"
    elif [ "$from_org" = "Org2" ]; then
        setup_org2_env
        grant_consent "$patient_id" "[\"${to_org}MSP\"]"
    else
        echo "Error: Unknown organization $from_org"
        return 1
    fi
}
