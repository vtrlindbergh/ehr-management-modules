#!/bin/bash

# =============================================================================
# EHR Operations Utility Functions — CLOUD VERSION
# Academic Project - Master's Dissertation
#
# Adapted from scripts/performance/ehr_operations.sh for distributed
# cloud deployment across 3 Azure VMs with Docker Swarm overlay network.
#
# KEY DIFFERENCES FROM LOCAL VERSION:
# - Orderer addressed by IP with --ordererTLSHostnameOverride
# - Peer addresses use VM private IPs (10.0.2.4:7051, 10.0.3.4:9051)
# - TLS cert paths use /opt/hyperledger/organizations/
# - All invoke commands include hostname override for orderer TLS
# =============================================================================

# Source cloud configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# =============================================================================
# FHIR Data Generation (identical to local — same chaincode, same data format)
# =============================================================================

generate_fhir_ehr_data() {
    local patient_id="$1"
    local patient_name="${2:-Test Patient}"
    local timestamp="${3:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

    local systolic=$((110 + RANDOM % 40))
    local diastolic=$((70 + RANDOM % 30))

    echo "{\"patientID\":\"${patient_id}\",\"patientName\":\"${patient_name}\",\"createdBy\":\"TestProvider\",\"healthData\":{\"resourceType\":\"Observation\",\"id\":\"bp-reading-${patient_id}\",\"meta\":[{\"version\":\"1.0\",\"lastUpdated\":\"${timestamp}\"}],\"rawContent\":\"{\\\"resourceType\\\":\\\"Observation\\\",\\\"id\\\":\\\"bp-reading-${patient_id}\\\",\\\"status\\\":\\\"final\\\",\\\"category\\\":[{\\\"coding\\\":[{\\\"system\\\":\\\"http://terminology.hl7.org/CodeSystem/observation-category\\\",\\\"code\\\":\\\"vital-signs\\\",\\\"display\\\":\\\"Vital Signs\\\"}]}],\\\"code\\\":{\\\"coding\\\":[{\\\"system\\\":\\\"http://loinc.org\\\",\\\"code\\\":\\\"85354-9\\\",\\\"display\\\":\\\"Blood pressure panel\\\"}]},\\\"subject\\\":{\\\"reference\\\":\\\"Patient/${patient_id}\\\"},\\\"effectiveDateTime\\\":\\\"${timestamp}\\\",\\\"component\\\":[{\\\"code\\\":{\\\"coding\\\":[{\\\"system\\\":\\\"http://loinc.org\\\",\\\"code\\\":\\\"8480-6\\\",\\\"display\\\":\\\"Systolic blood pressure\\\"}]},\\\"valueQuantity\\\":{\\\"value\\\":${systolic},\\\"unit\\\":\\\"mmHg\\\"}},{\\\"code\\\":{\\\"coding\\\":[{\\\"system\\\":\\\"http://loinc.org\\\",\\\"code\\\":\\\"8462-4\\\",\\\"display\\\":\\\"Diastolic blood pressure\\\"}]},\\\"valueQuantity\\\":{\\\"value\\\":${diastolic},\\\"unit\\\":\\\"mmHg\\\"}}]}\",\"content\":[${systolic},${diastolic}]},\"lastUpdated\":\"${timestamp}\"}"
}

escape_json() {
    local input="$1"
    echo "$input" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g'
}

# =============================================================================
# CRUD Operations — Cloud-adapted (ordererTLSHostnameOverride added)
# =============================================================================

create_ehr() {
    local patient_id="$1"
    local patient_name="${2:-Test Patient}"
    local start_time=$(date +%s.%N)

    local ehr_data=$(generate_fhir_ehr_data "${patient_id}" "${patient_name}")
    local escaped_ehr_data=$(escape_json "$ehr_data")

    peer chaincode invoke \
        -o ${ORDERER_ENDPOINT} \
        --ordererTLSHostnameOverride ${ORDERER_TLS_HOSTNAME_OVERRIDE} \
        --tls \
        --cafile "${ORDERER_CA}" \
        -C ${CHANNEL_NAME} \
        -n ${CHAINCODE_NAME} \
        --peerAddresses ${PEER0_ORG1_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG1_TLS_ROOTCERT} \
        --peerAddresses ${PEER0_ORG2_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG2_TLS_ROOTCERT} \
        -c "{\"function\":\"CreateEHR\",\"Args\":[\"${escaped_ehr_data}\"]}"

    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc)
    echo "${duration}"
}

grant_consent() {
    local patient_id="$1"
    local authorized_users="${2:-[\"org2admin\"]}"
    local start_time=$(date +%s.%N)

    local escaped_authorized_users=$(escape_json "$authorized_users")

    peer chaincode invoke \
        -o ${ORDERER_ENDPOINT} \
        --ordererTLSHostnameOverride ${ORDERER_TLS_HOSTNAME_OVERRIDE} \
        --tls \
        --cafile "${ORDERER_CA}" \
        -C ${CHANNEL_NAME} \
        -n ${CHAINCODE_NAME} \
        --peerAddresses ${PEER0_ORG1_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG1_TLS_ROOTCERT} \
        --peerAddresses ${PEER0_ORG2_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG2_TLS_ROOTCERT} \
        -c "{\"function\":\"GrantConsent\",\"Args\":[\"${patient_id}\", \"${escaped_authorized_users}\"]}"

    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc)
    echo "${duration}"
}

revoke_consent() {
    local patient_id="$1"
    local start_time=$(date +%s.%N)

    peer chaincode invoke \
        -o ${ORDERER_ENDPOINT} \
        --ordererTLSHostnameOverride ${ORDERER_TLS_HOSTNAME_OVERRIDE} \
        --tls \
        --cafile "${ORDERER_CA}" \
        -C ${CHANNEL_NAME} \
        -n ${CHAINCODE_NAME} \
        --peerAddresses ${PEER0_ORG1_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG1_TLS_ROOTCERT} \
        --peerAddresses ${PEER0_ORG2_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG2_TLS_ROOTCERT} \
        -c "{\"function\":\"RevokeConsent\",\"Args\":[\"${patient_id}\"]}"

    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc)
    echo "${duration}"
}

read_ehr() {
    local patient_id="$1"
    local show_data="${2:-false}"
    local start_time=$(date +%s.%N)

    local result=$(peer chaincode query \
        -C ${CHANNEL_NAME} \
        -n ${CHAINCODE_NAME} \
        -c "{\"function\":\"ReadEHR\",\"Args\":[\"${patient_id}\"]}" 2>/dev/null)

    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc)

    if [ "$show_data" = "true" ] && [ -n "$result" ]; then
        local patient_name=$(echo "$result" | jq -r '.patientName // "N/A"' 2>/dev/null || echo "N/A")
        local creator=$(echo "$result" | jq -r '.createdBy // "N/A"' 2>/dev/null || echo "N/A")
        local bp_values=$(echo "$result" | jq -r '.healthData.content // [] | join("/")' 2>/dev/null || echo "N/A")
        echo "[DATA_VERIFIED] Patient: $patient_name, Creator: $creator, BP: ${bp_values}mmHg" >&2
    fi

    echo "${duration}"
}

read_ehr_with_data() {
    local patient_id="$1"

    peer chaincode query \
        -C ${CHANNEL_NAME} \
        -n ${CHAINCODE_NAME} \
        -c "{\"function\":\"ReadEHR\",\"Args\":[\"${patient_id}\"]}"
}

update_ehr() {
    local patient_id="$1"
    local patient_name="${2:-Test Patient Updated}"
    local start_time=$(date +%s.%N)

    local ehr_data=$(generate_fhir_ehr_data "${patient_id}" "${patient_name}")
    local escaped_ehr_data=$(escape_json "$ehr_data")

    peer chaincode invoke \
        -o ${ORDERER_ENDPOINT} \
        --ordererTLSHostnameOverride ${ORDERER_TLS_HOSTNAME_OVERRIDE} \
        --tls \
        --cafile "${ORDERER_CA}" \
        -C ${CHANNEL_NAME} \
        -n ${CHAINCODE_NAME} \
        --peerAddresses ${PEER0_ORG1_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG1_TLS_ROOTCERT} \
        --peerAddresses ${PEER0_ORG2_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG2_TLS_ROOTCERT} \
        -c "{\"function\":\"UpdateEHR\",\"Args\":[\"${escaped_ehr_data}\"]}"

    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc)
    echo "${duration}"
}

delete_ehr() {
    local patient_id="$1"
    local start_time=$(date +%s.%N)

    peer chaincode invoke \
        -o ${ORDERER_ENDPOINT} \
        --ordererTLSHostnameOverride ${ORDERER_TLS_HOSTNAME_OVERRIDE} \
        --tls \
        --cafile "${ORDERER_CA}" \
        -C ${CHANNEL_NAME} \
        -n ${CHAINCODE_NAME} \
        --peerAddresses ${PEER0_ORG1_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG1_TLS_ROOTCERT} \
        --peerAddresses ${PEER0_ORG2_ENDPOINT} \
        --tlsRootCertFiles ${PEER0_ORG2_TLS_ROOTCERT} \
        -c "{\"function\":\"DeleteEHR\",\"Args\":[\"${patient_id}\"]}"

    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc)
    echo "${duration}"
}

# =============================================================================
# Organization Environment Switching — Cloud Paths
# =============================================================================

setup_org1_env() {
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE="${ORGANIZATIONS_PATH}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"
    export CORE_PEER_MSPCONFIGPATH="${ORGANIZATIONS_PATH}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp"
    export CORE_PEER_ADDRESS="localhost:7051"
}

setup_org2_env() {
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE="${ORGANIZATIONS_PATH}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"
    export CORE_PEER_MSPCONFIGPATH="${ORGANIZATIONS_PATH}/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp"
    export CORE_PEER_ADDRESS="localhost:9051"
}

# =============================================================================
# Cross-Org Helpers (same logic as local)
# =============================================================================

create_ehr_as_org() {
    local org="$1"
    local patient_id="$2"
    local patient_name="${3:-Test Patient}"

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

read_ehr_as_org() {
    local org="$1"
    local patient_id="$2"

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

grant_cross_org_consent() {
    local patient_id="$1"
    local from_org="$2"
    local to_org="$3"

    local to_client_id
    if [ "$to_org" = "Org1" ]; then
        to_client_id="org1admin"
    elif [ "$to_org" = "Org2" ]; then
        to_client_id="org2admin"
    else
        echo "Error: Unknown target organization $to_org"
        return 1
    fi

    if [ "$from_org" = "Org1" ]; then
        setup_org1_env
        grant_consent "$patient_id" "[\"${to_client_id}\"]"
    elif [ "$from_org" = "Org2" ]; then
        setup_org2_env
        grant_consent "$patient_id" "[\"${to_client_id}\"]"
    else
        echo "Error: Unknown organization $from_org"
        return 1
    fi
}
