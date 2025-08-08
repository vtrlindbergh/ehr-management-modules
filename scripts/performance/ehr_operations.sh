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
    local authorized_users="${2:-[\"org1admin\"]}"
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
