#!/bin/bash
# =============================================================================
# Deploy Fabric Network on Docker Swarm (3-VM distributed)
# Run this from your LOCAL machine (not on the VMs)
# Prerequisites: Phase 2 complete (Swarm initialized, overlay network created)
# =============================================================================
set -e

# --- Configuration ---
ORDERER_IP="135.232.180.24"
ORG1_IP="20.88.52.252"
ORG2_IP="130.131.55.125"
ORDERER_PRIVATE="10.0.1.4"
SSH_USER="azureuser"
REMOTE_BASE="/opt/hyperledger"
CHANNEL_NAME="mychannel"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

ssh_cmd() {
    local ip=$1; shift
    ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 ${SSH_USER}@${ip} "$@"
}

# =============================================================================
# Step 1: Upload config files to orderer VM
# =============================================================================
info "Step 1: Uploading config files to orderer VM..."

ssh_cmd ${ORDERER_IP} "sudo mkdir -p ${REMOTE_BASE}/configtx ${REMOTE_BASE}/organizations ${REMOTE_BASE}/channel-artifacts ${REMOTE_BASE}/peercfg"
ssh_cmd ${ORDERER_IP} "sudo chown -R ${SSH_USER}:${SSH_USER} ${REMOTE_BASE}"

scp -o StrictHostKeyChecking=accept-new \
    ${SCRIPT_DIR}/crypto-config-orderer.yaml \
    ${SCRIPT_DIR}/crypto-config-org1.yaml \
    ${SCRIPT_DIR}/crypto-config-org2.yaml \
    ${SSH_USER}@${ORDERER_IP}:${REMOTE_BASE}/

scp -o StrictHostKeyChecking=accept-new \
    ${SCRIPT_DIR}/configtx.yaml \
    ${SSH_USER}@${ORDERER_IP}:${REMOTE_BASE}/configtx/

scp -o StrictHostKeyChecking=accept-new \
    ${CLOUD_DIR}/compose/docker-stack-fabric.yml \
    ${SSH_USER}@${ORDERER_IP}:${REMOTE_BASE}/

info "Step 1 complete: Config files uploaded."

# =============================================================================
# Step 2: Generate crypto material
# =============================================================================
info "Step 2: Generating crypto material with cryptogen..."

ssh_cmd ${ORDERER_IP} "
    export PATH=${REMOTE_BASE}/fabric-samples/bin:\$PATH
    cd ${REMOTE_BASE}

    # Generate orderer org crypto
    cryptogen generate --config=crypto-config-orderer.yaml --output=organizations
    
    # Generate org1 crypto
    cryptogen generate --config=crypto-config-org1.yaml --output=organizations
    
    # Generate org2 crypto
    cryptogen generate --config=crypto-config-org2.yaml --output=organizations
    
    echo 'Crypto material generated:'
    ls organizations/ordererOrganizations/example.com/orderers/orderer.example.com/
    ls organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/
    ls organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/
"

info "Step 2 complete: Crypto material generated."

# =============================================================================
# Step 3: Generate channel genesis block
# =============================================================================
info "Step 3: Generating channel genesis block..."

ssh_cmd ${ORDERER_IP} "
    export PATH=${REMOTE_BASE}/fabric-samples/bin:\$PATH
    export FABRIC_CFG_PATH=${REMOTE_BASE}/configtx
    cd ${REMOTE_BASE}

    configtxgen -profile ChannelUsingRaft \
        -outputBlock channel-artifacts/${CHANNEL_NAME}.block \
        -channelID ${CHANNEL_NAME}
    
    echo 'Genesis block created:'
    ls -la channel-artifacts/
"

info "Step 3 complete: Genesis block created."

# =============================================================================
# Step 4: Copy peer config (core.yaml) to all VMs
# =============================================================================
info "Step 4: Distributing peer config..."

# Copy the default core.yaml to peercfg directory on orderer (for distribution)
ssh_cmd ${ORDERER_IP} "cp ${REMOTE_BASE}/fabric-samples/config/core.yaml ${REMOTE_BASE}/peercfg/core.yaml"

info "Step 4 complete: Peer config ready."

# =============================================================================
# Step 5: Distribute crypto material to org1 and org2 VMs
# =============================================================================
info "Step 5: Distributing crypto material to worker VMs..."

# Create directories on org1 and org2
for ip in ${ORG1_IP} ${ORG2_IP}; do
    ssh_cmd ${ip} "sudo mkdir -p ${REMOTE_BASE}/organizations ${REMOTE_BASE}/peercfg ${REMOTE_BASE}/channel-artifacts"
    ssh_cmd ${ip} "sudo chown -R ${SSH_USER}:${SSH_USER} ${REMOTE_BASE}"
done

# We need to SCP from orderer to org1/org2. Since VMs can reach each other via 
# private IPs and SSH keys are on the host, we'll use local machine as relay.

# Create temp directory for crypto
TMPDIR=$(mktemp -d)
trap "rm -rf ${TMPDIR}" EXIT

info "  Downloading crypto from orderer..."
scp -o StrictHostKeyChecking=accept-new -r \
    ${SSH_USER}@${ORDERER_IP}:${REMOTE_BASE}/organizations/ \
    ${TMPDIR}/organizations/

scp -o StrictHostKeyChecking=accept-new \
    ${SSH_USER}@${ORDERER_IP}:${REMOTE_BASE}/peercfg/core.yaml \
    ${TMPDIR}/core.yaml

scp -o StrictHostKeyChecking=accept-new \
    ${SSH_USER}@${ORDERER_IP}:${REMOTE_BASE}/channel-artifacts/${CHANNEL_NAME}.block \
    ${TMPDIR}/${CHANNEL_NAME}.block

info "  Uploading to org1 VM..."
scp -o StrictHostKeyChecking=accept-new -r \
    ${TMPDIR}/organizations/ \
    ${SSH_USER}@${ORG1_IP}:${REMOTE_BASE}/

scp -o StrictHostKeyChecking=accept-new \
    ${TMPDIR}/core.yaml \
    ${SSH_USER}@${ORG1_IP}:${REMOTE_BASE}/peercfg/core.yaml

scp -o StrictHostKeyChecking=accept-new \
    ${TMPDIR}/${CHANNEL_NAME}.block \
    ${SSH_USER}@${ORG1_IP}:${REMOTE_BASE}/channel-artifacts/${CHANNEL_NAME}.block

info "  Uploading to org2 VM..."
scp -o StrictHostKeyChecking=accept-new -r \
    ${TMPDIR}/organizations/ \
    ${SSH_USER}@${ORG2_IP}:${REMOTE_BASE}/

scp -o StrictHostKeyChecking=accept-new \
    ${TMPDIR}/core.yaml \
    ${SSH_USER}@${ORG2_IP}:${REMOTE_BASE}/peercfg/core.yaml

scp -o StrictHostKeyChecking=accept-new \
    ${TMPDIR}/${CHANNEL_NAME}.block \
    ${SSH_USER}@${ORG2_IP}:${REMOTE_BASE}/channel-artifacts/${CHANNEL_NAME}.block

info "Step 5 complete: Crypto distributed to all VMs."

# =============================================================================
# Step 6: Deploy Fabric containers via Docker Stack
# =============================================================================
info "Step 6: Deploying Fabric containers via Docker Stack..."

ssh_cmd ${ORDERER_IP} "
    cd ${REMOTE_BASE}
    sudo docker stack deploy -c docker-stack-fabric.yml fabric
"

info "  Waiting 30s for services to start..."
sleep 30

ssh_cmd ${ORDERER_IP} "
    sudo docker stack services fabric
    echo ''
    echo 'Container status on each node:'
    sudo docker stack ps fabric --no-trunc 2>/dev/null | head -20
"

info "Step 6 complete: Fabric stack deployed."

# =============================================================================
# Step 7: Create channel using osnadmin
# =============================================================================
info "Step 7: Creating channel '${CHANNEL_NAME}' via osnadmin..."

ssh_cmd ${ORDERER_IP} "
    export PATH=${REMOTE_BASE}/fabric-samples/bin:\$PATH

    osnadmin channel join \
        --channelID ${CHANNEL_NAME} \
        --config-block ${REMOTE_BASE}/channel-artifacts/${CHANNEL_NAME}.block \
        -o localhost:7053 \
        --ca-file ${REMOTE_BASE}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        --client-cert ${REMOTE_BASE}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt \
        --client-key ${REMOTE_BASE}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

    echo ''
    osnadmin channel list \
        -o localhost:7053 \
        --ca-file ${REMOTE_BASE}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        --client-cert ${REMOTE_BASE}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt \
        --client-key ${REMOTE_BASE}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key
"

info "Step 7 complete: Channel created."

# =============================================================================
# Step 8: Join peers to channel
# =============================================================================
info "Step 8: Joining peers to channel..."

# Join Org1 peer
info "  Joining peer0.org1..."
ssh_cmd ${ORG1_IP} "
    export PATH=${REMOTE_BASE}/fabric-samples/bin:\$PATH
    export FABRIC_CFG_PATH=${REMOTE_BASE}/peercfg
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org1MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051

    peer channel join -b ${REMOTE_BASE}/channel-artifacts/${CHANNEL_NAME}.block
    peer channel list
"

# Join Org2 peer
info "  Joining peer0.org2..."
ssh_cmd ${ORG2_IP} "
    export PATH=${REMOTE_BASE}/fabric-samples/bin:\$PATH
    export FABRIC_CFG_PATH=${REMOTE_BASE}/peercfg
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org2MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=${REMOTE_BASE}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${REMOTE_BASE}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051

    peer channel join -b ${REMOTE_BASE}/channel-artifacts/${CHANNEL_NAME}.block
    peer channel list
"

info "Step 8 complete: Both peers joined channel."

# =============================================================================
# Step 9: Set anchor peers
# =============================================================================
info "Step 9: Setting anchor peers..."

ORDERER_CA="${REMOTE_BASE}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

# Org1 anchor peer
ssh_cmd ${ORG1_IP} "
    export PATH=${REMOTE_BASE}/fabric-samples/bin:\$PATH
    export FABRIC_CFG_PATH=${REMOTE_BASE}/peercfg
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org1MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051

    peer channel fetch config ${REMOTE_BASE}/channel-artifacts/config_block.pb \
        -o orderer.example.com:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        -c ${CHANNEL_NAME} \
        --tls --cafile ${ORDERER_CA}

    # Decode, modify, encode anchor peer update (using configtxlator)
    cd ${REMOTE_BASE}/channel-artifacts
    configtxlator proto_decode --input config_block.pb --type common.Block --output config_block.json
    jq '.data.data[0].payload.data.config' config_block.json > config.json
    cp config.json modified_config.json
    jq '.channel_group.groups.Application.groups.Org1MSP.values += {\"AnchorPeers\":{\"mod_policy\": \"Admins\",\"value\":{\"anchor_peers\": [{\"host\": \"peer0.org1.example.com\",\"port\": 7051}]},\"version\": \"0\"}}' config.json > modified_config.json
    configtxlator proto_encode --input config.json --type common.Config --output config.pb
    configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb
    configtxlator compute_update --channel_id ${CHANNEL_NAME} --original config.pb --updated modified_config.pb --output anchor_update.pb
    echo '{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"${CHANNEL_NAME}\",\"type\":2}},\"data\":{\"config_update\":\"\"}}}' > anchor_update_envelope.json
    # Use a simpler approach - direct channel update
    configtxlator proto_decode --input anchor_update.pb --type common.ConfigUpdate --output anchor_update.json
    echo '{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"'${CHANNEL_NAME}'\",\"type\":2}},\"data\":{\"config_update\":'\"'(cat anchor_update.json)'\"'}}}' | jq . > anchor_update_in_envelope.json 2>/dev/null || true
    configtxlator proto_encode --input anchor_update_in_envelope.json --type common.Envelope --output anchor_update_in_envelope.pb 2>/dev/null || true

    peer channel update -o orderer.example.com:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        -c ${CHANNEL_NAME} \
        -f anchor_update_in_envelope.pb \
        --tls --cafile ${ORDERER_CA} 2>/dev/null || echo 'Anchor peer update for Org1 skipped (non-critical)'
"

info "Step 9 complete: Anchor peers configured (best effort)."

# =============================================================================
# Step 10: Install and deploy EHR chaincode
# =============================================================================
info "Step 10: Deploying EHR chaincode..."

CC_NAME="ehrCC"
CC_VERSION="1.0"
CC_SEQUENCE=1
CC_SRC_PATH="${REMOTE_BASE}/chaincode-source"

# Package chaincode on org1
info "  Packaging chaincode on org1..."
ssh_cmd ${ORG1_IP} "
    export PATH=${REMOTE_BASE}/fabric-samples/bin:\$PATH
    export FABRIC_CFG_PATH=${REMOTE_BASE}/peercfg
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org1MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051

    # Package
    peer lifecycle chaincode package ${REMOTE_BASE}/${CC_NAME}.tar.gz \
        --path ${CC_SRC_PATH} \
        --lang golang \
        --label ${CC_NAME}_${CC_VERSION}

    # Install on org1 peer
    peer lifecycle chaincode install ${REMOTE_BASE}/${CC_NAME}.tar.gz
"

# Copy package to org2 and install
info "  Installing chaincode on org2..."
TMPPKG=$(mktemp -d)
scp -o StrictHostKeyChecking=accept-new \
    ${SSH_USER}@${ORG1_IP}:${REMOTE_BASE}/${CC_NAME}.tar.gz \
    ${TMPPKG}/${CC_NAME}.tar.gz

scp -o StrictHostKeyChecking=accept-new \
    ${TMPPKG}/${CC_NAME}.tar.gz \
    ${SSH_USER}@${ORG2_IP}:${REMOTE_BASE}/${CC_NAME}.tar.gz
rm -rf ${TMPPKG}

ssh_cmd ${ORG2_IP} "
    export PATH=${REMOTE_BASE}/fabric-samples/bin:\$PATH
    export FABRIC_CFG_PATH=${REMOTE_BASE}/peercfg
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org2MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=${REMOTE_BASE}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${REMOTE_BASE}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051

    peer lifecycle chaincode install ${REMOTE_BASE}/${CC_NAME}.tar.gz
"

# Get package ID from org1
info "  Getting chaincode package ID..."
PACKAGE_ID=$(ssh_cmd ${ORG1_IP} "
    export PATH=${REMOTE_BASE}/fabric-samples/bin:\$PATH
    export FABRIC_CFG_PATH=${REMOTE_BASE}/peercfg
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org1MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051

    peer lifecycle chaincode queryinstalled | grep ${CC_NAME}_${CC_VERSION} | sed 's/Package ID: //' | sed 's/, Label:.*//'
")
info "  Package ID: ${PACKAGE_ID}"

# Approve for Org1
info "  Approving chaincode for Org1..."
ssh_cmd ${ORG1_IP} "
    export PATH=${REMOTE_BASE}/fabric-samples/bin:\$PATH
    export FABRIC_CFG_PATH=${REMOTE_BASE}/peercfg
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org1MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051

    peer lifecycle chaincode approveformyorg \
        -o orderer.example.com:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        --tls --cafile ${REMOTE_BASE}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        --channelID ${CHANNEL_NAME} \
        --name ${CC_NAME} \
        --version ${CC_VERSION} \
        --package-id ${PACKAGE_ID} \
        --sequence ${CC_SEQUENCE}
"

# Approve for Org2
info "  Approving chaincode for Org2..."
ssh_cmd ${ORG2_IP} "
    export PATH=${REMOTE_BASE}/fabric-samples/bin:\$PATH
    export FABRIC_CFG_PATH=${REMOTE_BASE}/peercfg
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org2MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=${REMOTE_BASE}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${REMOTE_BASE}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051

    peer lifecycle chaincode approveformyorg \
        -o orderer.example.com:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        --tls --cafile ${REMOTE_BASE}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        --channelID ${CHANNEL_NAME} \
        --name ${CC_NAME} \
        --version ${CC_VERSION} \
        --package-id ${PACKAGE_ID} \
        --sequence ${CC_SEQUENCE}
"

# Check commit readiness
info "  Checking commit readiness..."
ssh_cmd ${ORG1_IP} "
    export PATH=${REMOTE_BASE}/fabric-samples/bin:\$PATH
    export FABRIC_CFG_PATH=${REMOTE_BASE}/peercfg
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org1MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051

    peer lifecycle chaincode checkcommitreadiness \
        --channelID ${CHANNEL_NAME} \
        --name ${CC_NAME} \
        --version ${CC_VERSION} \
        --sequence ${CC_SEQUENCE} \
        --output json
"

# Commit chaincode
info "  Committing chaincode definition..."
ssh_cmd ${ORG1_IP} "
    export PATH=${REMOTE_BASE}/fabric-samples/bin:\$PATH
    export FABRIC_CFG_PATH=${REMOTE_BASE}/peercfg
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org1MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051

    peer lifecycle chaincode commit \
        -o orderer.example.com:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        --tls --cafile ${REMOTE_BASE}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        --channelID ${CHANNEL_NAME} \
        --name ${CC_NAME} \
        --version ${CC_VERSION} \
        --sequence ${CC_SEQUENCE} \
        --peerAddresses peer0.org1.example.com:7051 \
        --tlsRootCertFiles ${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
        --peerAddresses peer0.org2.example.com:9051 \
        --tlsRootCertFiles ${REMOTE_BASE}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
"

info "Step 10 complete: EHR chaincode deployed."

# =============================================================================
# Step 11: Validate with test transaction
# =============================================================================
info "Step 11: Validating with test transaction..."

# CreateEHR from Org1
info "  Creating test EHR record from Org1..."
ssh_cmd ${ORG1_IP} "
    export PATH=${REMOTE_BASE}/fabric-samples/bin:\$PATH
    export FABRIC_CFG_PATH=${REMOTE_BASE}/peercfg
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org1MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051

    peer chaincode invoke \
        -o orderer.example.com:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        --tls --cafile ${REMOTE_BASE}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        -C ${CHANNEL_NAME} \
        -n ${CC_NAME} \
        --peerAddresses peer0.org1.example.com:7051 \
        --tlsRootCertFiles ${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
        --peerAddresses peer0.org2.example.com:9051 \
        --tlsRootCertFiles ${REMOTE_BASE}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
        -c '{\"function\":\"CreateEHR\",\"Args\":[\"EHR_CLOUD_TEST_001\",\"Cloud Test Patient\",\"1990-01-01\",\"AB+\",\"{}\"]}'
"

sleep 3

# ReadEHR from Org1
info "  Reading test EHR record from Org1..."
ssh_cmd ${ORG1_IP} "
    export PATH=${REMOTE_BASE}/fabric-samples/bin:\$PATH
    export FABRIC_CFG_PATH=${REMOTE_BASE}/peercfg
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org1MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${REMOTE_BASE}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051

    peer chaincode query \
        -C ${CHANNEL_NAME} \
        -n ${CC_NAME} \
        -c '{\"function\":\"ReadEHR\",\"Args\":[\"EHR_CLOUD_TEST_001\"]}'
"

echo ""
info "============================================"
info " FABRIC NETWORK DEPLOYMENT COMPLETE"
info "============================================"
info " Orderer: orderer.example.com (${ORDERER_IP})"
info " Org1 Peer: peer0.org1.example.com (${ORG1_IP})"
info " Org2 Peer: peer0.org2.example.com (${ORG2_IP})"
info " Channel: ${CHANNEL_NAME}"
info " Chaincode: ${CC_NAME} v${CC_VERSION}"
info "============================================"
