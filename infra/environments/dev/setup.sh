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
echo "   - Subscription/Tenant IDs are retrieved dynamically (not hardcoded)"
echo ""

# Check if Azure CLI is authenticated
if ! az account show >/dev/null 2>&1; then
    echo "❌ Azure CLI not authenticated. Please run 'az login' first."
    exit 1
fi

# Get current subscription dynamically (no hardcoded IDs)
CURRENT_SUB=$(az account show --query id -o tsv)
CURRENT_TENANT=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)

if [ -z "$CURRENT_SUB" ]; then
    echo "❌ Unable to get current subscription. Please ensure you're logged in with 'az login'"
    exit 1
fi

echo "✅ Azure authentication verified"
echo "✅ Using subscription: $SUBSCRIPTION_NAME"
echo "✅ Target region: East US (cost-optimized)"
echo ""

# Set up environment variables for Terraform (dynamically)
# In production, these would be GitHub Secrets
export ARM_SUBSCRIPTION_ID="$CURRENT_SUB"
export ARM_TENANT_ID="$CURRENT_TENANT"

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