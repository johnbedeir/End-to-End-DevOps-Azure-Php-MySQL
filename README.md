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

**After running this script, you'll see output with:**

- Client ID
- Client Secret
- Tenant ID

### Step 1.5: Configure Terraform Variables

Copy the example Terraform variables file and fill in the values from `run_me_first.sh`:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Then edit `terraform/terraform.tfvars` and replace the placeholder values:

- `subscription_id`: Your Azure subscription ID (from `subscription.txt`)
- `client_id`: The Client ID shown when you ran `run_me_first.sh`
- `client_secret`: The Client Secret shown when you ran `run_me_first.sh`
- `tenant_id`: The Tenant ID shown when you ran `run_me_first.sh`
- `location`: Your preferred Azure region (e.g., "East US 2")
- `db_username`: Your desired SQL database admin username (e.g., "sqladmin")

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
│   ├── terraform.tfvars.example  # Example Terraform variables (copy to terraform.tfvars)
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

## GitHub Actions CI/CD

The project includes a GitHub Actions workflow (`.github/workflows/build-and-push.yml`) that automatically builds and pushes Docker images to ACR when code is pushed to the `main` branch.

### Setting up GitHub Secrets

Before the workflow can run, you need to add these secrets to your GitHub repository:

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add:

   - **Name:** `AZURE_CLIENT_ID`

     - **Value:** The Client ID from your service principal (shown when you run `run_me_first.sh`)

   - **Name:** `AZURE_TENANT_ID`

     - **Value:** Your Azure Tenant ID (shown when you run `run_me_first.sh`)

   - **Name:** `AZURE_SUBSCRIPTION_ID`
     - **Value:** Your Azure Subscription ID (from `subscription.txt`)

**Important:** These must be added as **Secrets**, not Environment Variables.

## Notes

- The application uses Azure SQL Server (not MySQL) despite the project name
- Database tables are automatically created via a Kubernetes Job
- All secrets are stored in Kubernetes secrets
- The infrastructure uses private endpoints for secure database access
