#!/bin/bash
# EHR Blockchain Infrastructure Setup Script
# Security: Uses service principal with least privilege

set -euo pipefail

echo "🔒 EHR Blockchain Infrastructure Setup"
echo "==============================================="

# Service Principal Credentials (from previous creation)
# NEVER commit these values to Git!
# In production, these would come from Azure Key Vault or GitHub Secrets

echo "⚠️  SECURITY REMINDER:"
echo "   - Service Principal has Contributor access ONLY to rg-ehr-blockchain-dev"
echo "   - These credentials are for DEVELOPMENT environment only"
echo "   - Never commit credentials to Git repository"
echo ""

# Check if Azure CLI is authenticated
if ! az account show >/dev/null 2>&1; then
    echo "❌ Azure CLI not authenticated. Please run 'az login' first."
    exit 1
fi

# Verify we're in correct subscription
CURRENT_SUB=$(az account show --query id -o tsv)
EXPECTED_SUB="99b14724-ce6f-408f-a38f-39cca9f2cb56"

if [ "$CURRENT_SUB" != "$EXPECTED_SUB" ]; then
    echo "❌ Wrong subscription. Expected: $EXPECTED_SUB, Current: $CURRENT_SUB"
    exit 1
fi

echo "✅ Azure authentication verified"
echo "✅ Using Azure for Students subscription"
echo "✅ Target region: East US (cost-optimized)"
echo ""

# Set up environment variables for Terraform
# In production, these would be GitHub Secrets
export ARM_SUBSCRIPTION_ID="99b14724-ce6f-408f-a38f-39cca9f2cb56"
export ARM_TENANT_ID="6aaaed4c-b261-440b-854a-cae28c166c7e"

# These would typically be set from secure storage
# For now, we'll use Azure CLI authentication
echo "Using Azure CLI authentication for Terraform..."

# Initialize Terraform
echo "📦 Initializing Terraform..."
cd "$(dirname "$0")"
terraform init

echo ""
echo "🎯 Next Steps:"
echo "   1. Review terraform plan: terraform plan"
echo "   2. Apply infrastructure: terraform apply"
echo "   3. Access via service principal for automation"
echo ""
echo "💰 Cost Monitoring:"
echo "   - Budget alert set for $80 (80% of $100 credit)"
echo "   - Estimated monthly cost: ~$170 (17 days with $100 credit)"
echo "   - Remember to destroy resources when not in use!"
echo ""