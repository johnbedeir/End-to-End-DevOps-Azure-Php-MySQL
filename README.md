# End-to-End DevOps Azure PHP MySQL Project

<img src=cover.png>

This project deploys a PHP-based Task Management System on Azure using AKS (Azure Kubernetes Service), ACR (Azure Container Registry), and Azure SQL Database.

## Architecture

- **Frontend**: PHP application served via Apache
- **Backend Services**: PHP microservices (users-service, logout-service)
- **Database**: Azure SQL Server (SQL Server, not MySQL despite the name)
- **Container Registry**: Azure Container Registry (ACR)
- **Orchestration**: Azure Kubernetes Service (AKS)
- **Ingress**: NGINX Ingress Controller
- **Monitoring**: Prometheus, Grafana, Alertmanager
- **CI/CD**: ArgoCD

## Prerequisites

- Azure CLI installed and configured
- Docker installed
- kubectl installed
- Helm installed
- Terraform installed
- Azure subscription with appropriate permissions
- `subscription.txt` file containing your Azure subscription ID

## Quick Start

### Step 1: Create Service Principal

**IMPORTANT**: You must run this script first before building the infrastructure.

```bash
./run_me_first.sh
```

This script creates an Azure service principal with Contributor role and sets up federated credentials for GitHub Actions.

### Step 2: Build and Deploy

After the service principal is created, run the build script:

```bash
./build.sh
```

This script will:

1. Create Azure infrastructure (AKS, ACR, SQL Database, VNet, etc.)
2. Build Docker images for the application
3. Push images to Azure Container Registry
4. Deploy the application to AKS
5. Initialize the database
6. Display access URLs and credentials

### Step 3: Access the Application

After the build completes, you'll see output with:

- Application URL (LoadBalancer IP)
- ArgoCD URL and credentials
- Prometheus, Grafana, and Alertmanager URLs and credentials

## Project Structure

```
.
├── build.sh              # Main build and deployment script
├── destroy.sh             # Cleanup script to remove all resources
├── run_me_first.sh        # Service principal creation script
├── subscription.txt       # Azure subscription ID
├── terraform/             # Infrastructure as Code
│   ├── aks.tf            # AKS cluster configuration
│   ├── acr.tf            # Container registry configuration
│   ├── sql-db.tf         # SQL database configuration
│   └── ...
├── task-management-system/  # PHP application source code
│   ├── pages/            # PHP pages (login, register, dashboard)
│   ├── includes/         # Database and function files
│   ├── *.Dockerfile      # Docker build files
│   └── ...
└── k8s/                   # Kubernetes manifests
    ├── frontend-service/
    ├── users-service/
    ├── logout-service/
    ├── ingress/
    └── db-init/
```

## Cleanup

To destroy all resources:

```bash
./destroy.sh
```

This will:

1. Delete all Kubernetes resources
2. Remove Docker images from ACR
3. Destroy Terraform infrastructure
4. Clean up the resource group
5. Remove the service principal

## Notes

- The application uses Azure SQL Server (not MySQL) despite the project name
- Database tables are automatically created via a Kubernetes Job
- All secrets are stored in Kubernetes secrets
- The infrastructure uses private endpoints for secure database access
