subscription_id=$(cat subscription.txt)
cluster_name="cluster-1-dev-aks" # Update this if the cluster name is changed in terraform
Location="East US 2"
resource_group="cluster-1-dev-rg"
sql_servername="cluster-1-dev-sql-server"
acr_name="cluster1devacr"
service_principal_name="tmsapp"
#Docker Images
frontend_img="$acr_name.azurecr.io/tms-frontend-img:latest"
logout_img="$acr_name.azurecr.io/tms-logout-img:latest"
users_img="$acr_name.azurecr.io/tms-users-img:latest"
#Namespaces
namespace="tms-app"
argo_namespace="argocd"
monitoring_namespace="monitoring"
#Services Names
ingress_service_name="ingress-nginx"
argo_service_name="argocd-server"
alertmanager_service_name="kube-prometheus-stack-alertmanager"
grafana_service_name="kube-prometheus-stack-grafana"
prometheus_service_name="kube-prometheus-stack-prometheus"
#PORTS
alertmanager_port="9093"
prometheus_port="9090"

# # Check if the service principal already exists
echo "------------Check if Service Principal Exists---------------"
service_principal_id=$(az ad sp list --display-name "$service_principal_name" --query "[?appDisplayName=='$service_principal_name'].appId" -o tsv)

if [ -z "$service_principal_id" ]; then
  echo "Service principal '$service_principal_name' does not exist, Run the script 'run_me_first.sh' to create one."
  exit 1
else
  echo "Service principal '$service_principal_name' exists with ID: $service_principal_id"
fi

# # update helm repos
helm repo update

# # Build the infrastructure
echo "---------------------Creating AKS & ACR---------------------"
cd terraform || { echo "Terraform directory not found"; exit 1; }
terraform init || { echo "Terraform init failed"; exit 1; }
terraform apply -auto-approve || { echo "Terraform apply failed"; exit 1; }
cd ..

# # Update kubeconfig
echo "--------------------Updating Kubeconfig---------------------"
az aks get-credentials --resource-group $resource_group --name $cluster_name || { echo "Failed to update kubeconfig"; exit 1; }

# # remove preious docker images
echo "--------------------Remove Previous build--------------------"
docker rmi -f $frontend_img || true
docker rmi -f $users_img || true
docker rmi -f $logout_img || true

# # build new docker image with new tag
echo "--------------------Build new Image--------------------"
docker buildx build  --no-cache --platform linux/amd64 -f task-management-system/frontend.Dockerfile -t $frontend_img task-management-system/
docker buildx build  --no-cache --platform linux/amd64 -f task-management-system/users.Dockerfile -t $users_img task-management-system/
docker buildx build  --no-cache --platform linux/amd64 -f task-management-system/logout.Dockerfile -t $logout_img task-management-system/

# # ACR Login
echo "----------------------Logging into ACR----------------------"
az acr login --name $acr_name || { echo "ACR login failed"; exit 1; }

# push the latest build to ACR
echo "--------------------Pushing Docker Image--------------------"
docker push $frontend_img || { echo "Failed to push frontend image"; exit 1; }
docker push $users_img || { echo "Failed to push users image"; exit 1; }
docker push $logout_img || { echo "Failed to push logout image"; exit 1; }

# Verify images were pushed
echo "--------------------Verifying Images in ACR--------------------"
az acr repository show-tags --name $acr_name --repository tms-frontend-img --orderby time_desc --top 1 || { echo "Failed to verify frontend image"; exit 1; }
az acr repository show-tags --name $acr_name --repository tms-users-img --orderby time_desc --top 1 || { echo "Failed to verify users image"; exit 1; }
az acr repository show-tags --name $acr_name --repository tms-logout-img --orderby time_desc --top 1 || { echo "Failed to verify logout image"; exit 1; }

# # create namespace
echo "--------------------creating Namespace--------------------"
kubectl create ns $namespace || true
kubectl create ns $argo_namespace || true

# # Create role assignment (if not already created by Terraform)
echo "--------------------Setting up ACR Access--------------------"
AKS_MANAGED_IDENTITY=$(az aks show --resource-group $resource_group --name $cluster_name --query "identityProfile.kubeletidentity.objectId" -o tsv)

if [ -z "$AKS_MANAGED_IDENTITY" ]; then
  echo "ERROR: Failed to get AKS managed identity. Trying alternative method..."
  AKS_MANAGED_IDENTITY=$(az aks show --resource-group $resource_group --name $cluster_name --query "identityProfile.kubeletidentity.clientId" -o tsv)
  if [ -z "$AKS_MANAGED_IDENTITY" ]; then
    echo "ERROR: Could not retrieve AKS managed identity"
    exit 1
  fi
fi

ACR_ID=$(az acr show --name $acr_name --resource-group $resource_group --query id -o tsv)

if [ -z "$ACR_ID" ]; then
  echo "ERROR: Failed to get ACR resource ID"
  exit 1
fi

# Check if role assignment already exists
ROLE_ASSIGNMENT_EXISTS=$(az role assignment list --assignee $AKS_MANAGED_IDENTITY --scope $ACR_ID --role AcrPull --query "[].id" -o tsv 2>/dev/null)

if [ -z "$ROLE_ASSIGNMENT_EXISTS" ]; then
  echo "Creating ACR Pull role assignment..."
  az role assignment create \
    --assignee $AKS_MANAGED_IDENTITY \
    --scope $ACR_ID \
    --role AcrPull \
    --output none || { echo "Failed to create role assignment"; exit 1; }
  echo "Role assignment created successfully"
  echo "Waiting 15 seconds for role assignment to propagate..."
  sleep 15
else
  echo "Role assignment already exists: $ROLE_ASSIGNMENT_EXISTS"
fi

# # Secret for the SQL Server endpoint (DB_HOST)
# Use FQDN for Azure SQL connection (works with private endpoint)
DB_HOST=$(az sql server show --name $sql_servername --resource-group $resource_group --query fullyQualifiedDomainName --output tsv)
kubectl create secret -n $namespace generic sql-endpoint --from-literal=endpoint=$DB_HOST --dry-run=client -o yaml | kubectl apply -f -

# # Secret for the SQL Server username (DB_USER)
DB_USER=$(cd terraform && terraform output -raw db_username)
kubectl create secret -n $namespace generic db-username --from-literal=username=$DB_USER --dry-run=client -o yaml | kubectl apply -f -

# # Secret for the SQL Server password (DB_PASSWORD)
DB_PASSWORD=$(cd terraform && terraform output -raw db_password)
kubectl create secret -n $namespace generic db-password --from-literal=password=$DB_PASSWORD --dry-run=client -o yaml | kubectl apply -f -

# # Secret for the SQL Server database name (DB_NAME)
DB_NAME="task_manager"
kubectl create secret -n $namespace generic db-name --from-literal=name=$DB_NAME --dry-run=client -o yaml | kubectl apply -f -

# # Secret for the SQL Server port (DB_PORT)
DB_PORT="1433"
kubectl create secret -n $namespace generic db-port --from-literal=port=$DB_PORT --dry-run=client -o yaml | kubectl apply -f -

# # Deploy the application
# echo "-----------------------Deploying App------------------------"
kubectl apply -n $namespace -f k8s/frontend-service || { echo "App deployment failed"; exit 1; }
kubectl apply -n $namespace -f k8s/ingress || { echo "App deployment failed"; exit 1; }
kubectl apply -n $namespace -f k8s/logout-service || { echo "App deployment failed"; exit 1; }
kubectl apply -n $namespace -f k8s/users-service || { echo "App deployment failed"; exit 1; }

# # Initialize database (optional - run once)
echo "--------------------Initializing Database--------------------"
kubectl apply -n $namespace -f k8s/db-init/db-init-job.yml || echo "Database init job already exists or failed"

# # Wait for application to be deployed
echo "--------------------Wait for all pods to be running--------------------"
echo "Checking pod status..."
kubectl get pods -n $namespace

# Wait for pods with retry logic
MAX_RETRIES=12
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  FAILED_PODS=$(kubectl get pods -n $namespace -o json | jq -r '.items[] | select(.status.phase=="Failed" or (.status.containerStatuses[]? | select(.state.waiting.reason=="ImagePullBackOff" or .state.waiting.reason=="ErrImagePull"))) | .metadata.name' 2>/dev/null || echo "")
  
  if [ -z "$FAILED_PODS" ]; then
    RUNNING_PODS=$(kubectl get pods -n $namespace -o json | jq -r '.items[] | select(.status.phase=="Running") | .metadata.name' 2>/dev/null | wc -l | tr -d ' ')
    TOTAL_PODS=$(kubectl get pods -n $namespace --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
      echo "All pods are running!"
      break
    fi
  else
    echo "Found pods with image pull issues: $FAILED_PODS"
    echo "Troubleshooting ACR access..."
    
    # Check ACR role assignment
    AKS_MANAGED_IDENTITY=$(az aks show --resource-group $resource_group --name $cluster_name --query "identityProfile.kubeletidentity.objectId" -o tsv)
    ACR_ID=$(az acr show --name $acr_name --resource-group $resource_group --query id -o tsv)
    ROLE_CHECK=$(az role assignment list --assignee $AKS_MANAGED_IDENTITY --scope $ACR_ID --role AcrPull --query "[].id" -o tsv 2>/dev/null)
    
    if [ -z "$ROLE_CHECK" ]; then
      echo "ERROR: ACR Pull role assignment is missing!"
      echo "Attempting to create role assignment..."
      az role assignment create --assignee $AKS_MANAGED_IDENTITY --scope $ACR_ID --role AcrPull --output none
      echo "Waiting 30 seconds for role assignment to propagate..."
      sleep 30
    fi
    
    # Verify images exist in ACR
    echo "Verifying images exist in ACR..."
    az acr repository show --name $acr_name --repository tms-users-img >/dev/null 2>&1 || echo "WARNING: tms-users-img repository not found in ACR"
    az acr repository show-tags --name $acr_name --repository tms-users-img --orderby time_desc --top 1 || echo "WARNING: No tags found for tms-users-img"
  fi
  
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "Waiting for pods... (attempt $RETRY_COUNT/$MAX_RETRIES)"
  sleep 10
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "WARNING: Not all pods are running after waiting. Check pod status:"
  kubectl get pods -n $namespace
  echo ""
  echo "To troubleshoot image pull issues, run:"
  echo "  kubectl describe pod <pod-name> -n $namespace"
  echo "  kubectl logs <pod-name> -n $namespace"
fi

# # Get LoadBalancer
echo "----------------------Application URL-----------------------"
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || \
             kubectl get svc $ingress_service_name -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || \
             echo "Failed to retrieve service IP")
echo "$INGRESS_IP"

echo ""

echo "------------------------ArgoCD URL--------------------------"
kubectl get svc $argo_service_name -n $argo_namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || { echo "Failed to retrieve service IP"; exit 1; }

echo ""

echo "-------------------- ArgoCD Credentials---------------------"
argo_pass=$(kubectl -n $argo_namespace get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)
echo "┌─────────┬───────────────────────────┐"
echo "│  USER   │  PASSWORD                 │"
echo "├─────────┼───────────────────────────┤"
echo "│  admin  │ $argo_pass          │"
echo "└─────────┴───────────────────────────┘"

echo ""

echo "----------------------Alertmanager URL----------------------"
echo "$(kubectl get svc $alertmanager_service_name -n $monitoring_namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || { echo "Failed to retrieve service IP"; exit 1; }):$alertmanager_port"

echo ""

echo "-----------------------Prometheus URL-----------------------"
echo "$(kubectl get svc $prometheus_service_name -n $monitoring_namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || { echo "Failed to retrieve service IP"; exit 1; }):$prometheus_port"

echo ""

echo "------------------------ Grafana URL------------------------"
kubectl get svc $grafana_service_name -n $monitoring_namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || { echo "Failed to retrieve service IP"; exit 1; }

echo ""

echo "-------------------- Grafana Credentials--------------------"
grafana_user=$(kubectl -n $monitoring_namespace get secret $grafana_service_name -o jsonpath="{.data.admin-user}" | base64 --decode)
grafana_pass=$(kubectl -n $monitoring_namespace get secret $grafana_service_name -o jsonpath="{.data.admin-password}" | base64 --decode)
echo "┌───────────────┬─────────────────────────┐"
echo "│  USER         │  PASSWORD               │"
echo "├───────────────┼─────────────────────────┤"
echo "│ $grafana_user         │ $grafana_pass                   │"
echo "└───────────────┴─────────────────────────┘"