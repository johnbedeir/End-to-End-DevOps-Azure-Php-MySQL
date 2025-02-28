#!/bin/bash

# Variables
subscription_id=$(cat subscription.txt)
service_perincipal_name="tmsapp"
federated_credential_name="GitHubActions"
repo_name="johnbedeir/End-to-End-DevOps-Azure-Php-MySQL"
branch_name="main"
issuer="https://token.actions.githubusercontent.com"
audience="api://AzureADTokenExchange"
description="GitHub Actions OIDC Federated Credential"
# End of Variables

# Check if the service principal already exists
sp_exists=$(az ad sp list --display-name $service_perincipal_name --query "[?appDisplayName=='$service_perincipal_name'].appId" -o tsv)

if [ -z "$sp_exists" ]; then
    echo "Service principal does not exist. Creating a new one..."
    service_perincipal=$(az ad sp create-for-rbac --name "$service_perincipal_name" --role Contributor --scopes /subscriptions/$subscription_id)

    # Extract details
    CLIENT_ID=$(echo $service_perincipal | jq -r .appId)
    CLIENT_SECRET=$(echo $service_perincipal | jq -r .password)
    TENANT_ID=$(echo $service_perincipal | jq -r .tenant)

    echo "Client ID: $CLIENT_ID"
    echo "Client Secret: $CLIENT_SECRET"
    echo "Tenant ID: $TENANT_ID"
else
    echo "Service principal already exists with App ID: $sp_exists"
    CLIENT_ID=$sp_exists
fi

# Add Federated Credential
echo "Adding federated credentials to the service principal..."
az ad app federated-credential create --id $CLIENT_ID \
    --parameters "{
        \"name\": \"$federated_credential_name\",
        \"issuer\": \"$issuer\",
        \"subject\": \"repo:$repo_name:ref:refs/heads/$branch_name\",
        \"audiences\": [\"$audience\"],
        \"description\": \"$description\"
    }"

echo "Federated credentials added successfully."
