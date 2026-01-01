#!/bin/bash

set -e  # Exit on error (but we use || true for non-critical operations)

# Variables
subscription_id=$(cat subscription.txt)
cluster_name="cluster-1-dev-aks"
Location="East US 2"
resource_group="cluster-1-dev-rg"
acr_name="cluster1devacr"
service_principal_name="tmsapp"

# Namespaces
namespace="tms-app"
argo_namespace="argocd"
monitoring_namespace="monitoring"
ingress_namespace="ingress-nginx"

# Docker images name
frontend_img="$acr_name.azurecr.io/tms-frontend-img:latest"
logout_img="$acr_name.azurecr.io/tms-logout-img:latest"
users_img="$acr_name.azurecr.io/tms-users-img:latest"

echo "========================================="
echo "Starting Infrastructure Destruction"
echo "========================================="
echo ""

# Step 1: Clean up Kubernetes resources (if cluster still exists)
echo "--------------------Step 1: Clean up Kubernetes Resources--------------------"
if az aks show --resource-group $resource_group --name $cluster_name &>/dev/null; then
    echo "AKS cluster exists, cleaning up Kubernetes resources..."
    
    # Update kubeconfig
    echo "Updating kubeconfig..."
    az aks get-credentials --resource-group $resource_group --name $cluster_name --overwrite-existing || echo "Failed to get credentials, continuing..."
    
    # Delete Kubernetes application resources
    if kubectl cluster-info &>/dev/null; then
        echo "Deleting application deployments and services..."
        kubectl delete -n $namespace -f k8s/frontend-service 2>/dev/null || true
        kubectl delete -n $namespace -f k8s/users-service 2>/dev/null || true
        kubectl delete -n $namespace -f k8s/logout-service 2>/dev/null || true
        kubectl delete -n $namespace -f k8s/ingress 2>/dev/null || true
        kubectl delete -n $namespace -f k8s/db-init/db-init-job.yml 2>/dev/null || true
        
        # Delete jobs
        echo "Deleting jobs..."
        kubectl delete jobs -n $namespace --all 2>/dev/null || true
        
        # Delete secrets
        echo "Deleting secrets..."
        kubectl delete secrets -n $namespace --all 2>/dev/null || true
        
        # Delete configmaps
        echo "Deleting configmaps..."
        kubectl delete configmaps -n $namespace --all 2>/dev/null || true
        
        # Uninstall Helm releases
        echo "Uninstalling Helm releases..."
        helm uninstall nginx-ingress -n $ingress_namespace 2>/dev/null || true
        helm uninstall argocd -n $argo_namespace 2>/dev/null || true
        helm uninstall kube-prometheus-stack -n $monitoring_namespace 2>/dev/null || true
        helm uninstall cluster-autoscaler -n kube-system 2>/dev/null || true
        
        # Delete namespaces (this will delete all resources in them)
        echo "Deleting namespaces..."
        kubectl delete namespace $namespace 2>/dev/null || true
        kubectl delete namespace $argo_namespace 2>/dev/null || true
        kubectl delete namespace $monitoring_namespace 2>/dev/null || true
        kubectl delete namespace $ingress_namespace 2>/dev/null || true
        
        echo "Kubernetes resources cleaned up."
    else
        echo "Cannot connect to cluster, skipping Kubernetes cleanup..."
    fi
else
    echo "AKS cluster does not exist, skipping Kubernetes cleanup..."
fi

echo ""

# Step 2: Remove local Docker images
echo "--------------------Step 2: Remove Local Docker Images--------------------"
docker rmi -f $frontend_img 2>/dev/null || true
docker rmi -f $users_img 2>/dev/null || true
docker rmi -f $logout_img 2>/dev/null || true
echo "Local Docker images removed."

echo ""

# Step 3: Delete Docker images from ACR (if ACR exists)
echo "--------------------Step 3: Delete ACR Images--------------------"
if az acr show --name $acr_name --resource-group $resource_group &>/dev/null; then
    echo "Deleting images from ACR..."
    # Fix: Use correct ACR command syntax
    az acr repository delete --name $acr_name --repository tms-frontend-img --yes 2>/dev/null || true
    az acr repository delete --name $acr_name --repository tms-users-img --yes 2>/dev/null || true
    az acr repository delete --name $acr_name --repository tms-logout-img --yes 2>/dev/null || true
    echo "ACR images deleted."
else
    echo "ACR does not exist, skipping image deletion..."
fi

echo ""

# Step 4: Destroy Terraform infrastructure
echo "--------------------Step 4: Destroy Terraform Infrastructure--------------------"
if [ -d "terraform" ]; then
    cd terraform
    if [ -f "terraform.tfstate" ] || [ -f "terraform.tfstate.backup" ]; then
        echo "Running terraform destroy..."
        terraform init -upgrade 2>/dev/null || true
        terraform destroy -auto-approve || echo "Terraform destroy completed with warnings/errors"
    else
        echo "No Terraform state found, skipping destroy..."
    fi
    cd ..
else
    echo "Terraform directory not found, skipping..."
fi

echo ""

# Step 5: Clean up any remaining resources
echo "--------------------Step 5: Clean up Remaining Resources--------------------"
# Wait a bit for resources to be deleted
echo "Waiting 30 seconds for resources to be deleted..."
sleep 30

# Delete the resource group if it still exists
if az group show --name $resource_group &>/dev/null; then
    echo "Deleting resource group: $resource_group"
    az group delete --name $resource_group --yes --no-wait || true
    echo "Resource group deletion initiated (this may take several minutes)."
else
    echo "Resource group does not exist."
fi

echo ""

# Step 6: Clean up Service Principal
echo "--------------------Step 6: Clean up Service Principal--------------------"
service_principal_id=$(az ad sp list --display-name "$service_principal_name" --query "[?appDisplayName=='$service_principal_name'].appId" -o tsv 2>/dev/null || echo "")
if [ ! -z "$service_principal_id" ]; then
    echo "Deleting service principal: $service_principal_name (ID: $service_principal_id)"
    az ad sp delete --id $service_principal_id 2>/dev/null || true
    echo "Service principal deleted."
else
    echo "Service principal '$service_principal_name' does not exist."
fi

echo ""
echo "========================================="
echo "Destroy Complete"
echo "========================================="
echo ""
echo "All Azure resources have been destroyed or marked for deletion."
echo ""
echo "Note:"
echo "  - Some resources may take a few minutes to be completely removed from Azure"
echo "  - Resource group deletion is asynchronous and may take 10-15 minutes"
echo "  - You can check resource group status with:"
echo "    az group show --name $resource_group"
echo ""
echo "To verify all resources are deleted, run:"
echo "  az group list --query \"[?name=='$resource_group']\"" 