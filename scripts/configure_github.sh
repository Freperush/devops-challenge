#!/usr/bin/env bash
# Copy Terraform outputs and the current Azure/GitHub identity into GitHub Actions.
# Run this from a clean checkout after terraform apply, while az and gh are logged in.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/infra"

: "${JWT_SECRET:?Set JWT_SECRET to the same value used in terraform.tfvars}"
: "${API_KEY:?Set API_KEY to the evaluation key}"

subscription_id="$(az account show --query id -o tsv)"
tenant_id="$(az account show --query tenantId -o tsv)"
owner="$(gh api user --jq .login)"
owner_id="$(gh api user --jq .id)"
repository="$(gh repo view --json name --jq .name)"
repository_id="$(gh repo view --json databaseId --jq .databaseId)"

gh secret set AZURE_CLIENT_ID --body "$(terraform output -raw github_client_id)"
gh secret set AZURE_TENANT_ID --body "$tenant_id"
gh secret set AZURE_SUBSCRIPTION_ID --body "$subscription_id"
gh secret set ACR_NAME --body "$(terraform output -raw acr_name)"
gh secret set AKS_RESOURCE_GROUP --body "$(terraform output -raw resource_group)"
gh secret set AKS_CLUSTER_NAME --body "$(terraform output -raw aks_name)"
gh secret set APIM_NAME --body "$(terraform output -raw apim_name)"
gh secret set API_KEY --body "$API_KEY"
gh secret set JWT_SECRET --body "$JWT_SECRET"

gh variable set REPO_OWNER --body "$owner"
gh variable set REPO_OWNER_ID --body "$owner_id"
gh variable set REPO_NAME --body "$repository"
gh variable set REPO_ID --body "$repository_id"

echo "GitHub is configured for ${owner}/${repository}."
echo "Public URL: $(terraform output -raw gateway_url)/DevOps"
