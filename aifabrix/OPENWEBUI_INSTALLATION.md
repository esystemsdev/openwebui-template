# OpenWebUI Installation Guide

This guide provides step-by-step instructions for installing OpenWebUI on both Azure VM and Local PC with PostgreSQL database integration.

## 🚀 Overview

OpenWebUI is an extensible, feature-rich, and user-friendly self-hosted WebUI designed to operate entirely offline. This guide covers installation on Azure VM and Local PC with connection to PostgreSQL databases.

## 📋 Prerequisites

### Local PC Installation
- Docker Desktop installed and running
- PostgreSQL client tools installed
- Existing PostgreSQL server running (from Flowise development setup)

### Developer Server (Azure VM) Installation
- Azure VM (`dev-flowise-vm`) with Docker installed
- PostgreSQL server access (`dev-flowise-pg.postgres.database.azure.com`)
- SSH access to the VM
- PostgreSQL client tools
- Azure CLI installed locally
- SSH key configured for VM access

## 🔧 Installation Options

### Option 1: Local PC Installation

#### Step 1: Prerequisites Check

Make sure you have:
- ✅ **Docker Desktop** installed and running
- ✅ **PostgreSQL client tools** installed
- ✅ **Flowise PostgreSQL** running (from your development setup)

#### Step 2: Create Database Manually

Before running the installation script, you need to manually create the `openwebui` database:

```powershell
# Connect to your local PostgreSQL server
PGPASSWORD=flowise123 psql -h localhost -p 5432 -U flowise -d postgres

# Create the openwebui database
CREATE DATABASE openwebui;

# Exit psql
\q
```

**Alternative method using command line:**
```powershell
# Create database directly from command line
PGPASSWORD=flowise123 psql -h localhost -p 5432 -U flowise -d postgres -c "CREATE DATABASE openwebui;"
```

#### Step 3: Run Installation Script

**PowerShell (Recommended for Windows):**
```powershell
# Navigate to your project directory
cd C:\git\esystemsdev\openwebui-template\aifabrix

# Run the PowerShell setup script
.\deploy-openwebui-local.ps1
```

#### Step 4: Access OpenWebUI

- **URL**: `http://localhost:3001`
- **Login**: Create your account through the signup form

#### Step 5: Management Commands

```powershell
# Stop OpenWebUI
docker-compose -f docker-compose-openwebui.yml down

# Restart OpenWebUI
docker-compose -f docker-compose-openwebui.yml restart

# View logs
docker logs openwebui-local
```

### Option 2: Developer Server (Azure VM) Installation

#### Step 1: Build and Push Docker Image

First, build and push the OpenWebUI image to Azure Container Registry:

```powershell
# Navigate to your project directory
cd C:\git\esystemsdev\openwebui-template\aifabrix

# Build and push the Docker image
.\deploy-openwebui-image.ps1
```

This script will:
- Build the Docker image with version tag
- Push it to Azure Container Registry (`devflowiseacr`)

#### Step 2: Deploy to Azure VM

Deploy OpenWebUI to the Azure VM using the deployment script:

```powershell
# Deploy OpenWebUI to Azure VM
.\deploy-openwebui-vm.ps1
```

This script will:
- Connect to Azure VM via SSH
- Pull the latest image from ACR
- Configure environment variables
- Start OpenWebUI container
- Set up proper networking and volumes

#### Step 3: Access OpenWebUI

- **URL**: `http://10.3.0.4:3000`
- **Login**: Use the configured admin credentials

## 🌐 Access OpenWebUI

### Local PC Access
- **URL**: `http://localhost:3001`
- **Login**: Create your account through the signup form

### Developer Server (Azure VM) Access
- **URL**: `http://10.3.0.4:3000`
- **Login**: Use the configured admin credentials from deployment script

## 📁 Configuration Details

### Local PC Configuration

The `docker-compose-openwebui.yml` file includes:

- **Port**: 3001 (mapped from container port 8080)
- **Database**: PostgreSQL connection to local Flowise database
- **Authentication**: Signup enabled for initial setup
- **Security**: Uses local PostgreSQL server
- **Persistence**: Docker volumes for data storage
- **Flowise Integration**: Connected to local Flowise instance

### Developer Server (Azure VM) Configuration

The deployment script (`deploy-openwebui-vm.ps1`) configures:

- **Port**: 3000 (mapped from container port 8080)
- **Database**: PostgreSQL connection using Azure PostgreSQL server
- **Authentication**: Admin user with configured credentials
- **Security**: Uses Azure Key Vault for secrets
- **Persistence**: Volume mounted to `/mnt/openwebui`
- **Flowise Integration**: Connected to production Flowise instance
- **Image**: Custom built image from Azure Container Registry

### Database Configuration

#### Local PC Database
- **Host**: `host.docker.internal` (connects to local PostgreSQL)
- **Port**: 5432
- **User**: `flowise`
- **Password**: `flowise123`
- **Database**: `openwebui` (created manually)

#### Developer Server Database
- **Host**: `dev-flowise-pg.postgres.database.azure.com`
- **Port**: 5432
- **User**: `pgadmin`
- **Password**: Retrieved from Azure Key Vault (`PostgresPassword`)
- **Database**: `openwebui` (created automatically)

## 🛠️ Management Commands

### Local PC Operations

```powershell
# Stop OpenWebUI
docker-compose -f docker-compose-openwebui.yml down

# Restart OpenWebUI
docker-compose -f docker-compose-openwebui.yml restart

# View logs
docker logs openwebui-local

# Follow logs in real-time
docker logs -f openwebui-local

# Update to latest version
docker-compose -f docker-compose-openwebui.yml pull
docker-compose -f docker-compose-openwebui.yml up -d
```

### Developer Server Operations

```powershell
# Redeploy with current image (no rebuild)
.\deploy-openwebui-vm.ps1 -ReDeploy

# Full deployment (rebuild and deploy)
.\deploy-openwebui-image.ps1
.\deploy-openwebui-vm.ps1
```

### SSH Access to VM

```bash
# Connect to Azure VM
ssh flowiseuser@10.3.0.4

# Check container status
docker ps

# View logs
docker logs openwebui

# Restart container
docker restart openwebui
```

## 🔒 Security Considerations

### Network Security

#### Local PC
- Uses Docker's internal networking
- No external ports exposed beyond localhost

#### Developer Server
Ensure your Azure VM's Network Security Group (NSG) allows inbound traffic on port 3000:

- **Port**: 3000
- **Protocol**: TCP
- **Source**: Any (or specific IP ranges)
- **Action**: Allow

### Database Security

#### Local PC
- Uses existing PostgreSQL credentials
- Creates separate `openwebui` database
- No additional database users created

#### Developer Server
- Uses Azure Key Vault for secure credential storage
- Creates separate `openwebui` database
- Managed Identity for Azure services access
- Secure secrets management

## 🚨 Troubleshooting

### Common Issues

#### Port Already in Use

**Local PC:**
If port 3001 is occupied, modify the Docker Compose file:

```yaml
ports:
  - "3002:8080"  # Use port 3002 instead
```

**Developer Server:**
If port 3000 is occupied, modify the deployment script parameter:

```powershell
.\deploy-openwebui-vm.ps1 -Port 3001
```

#### Database Connection Issues

**Local PC:**
```powershell
# Test database connectivity
pg_isready -h localhost -p 5432 -U flowise

# Check database exists
PGPASSWORD=flowise123 psql -h localhost -p 5432 -U flowise -d postgres -c "\l"
```

**Developer Server:**
```bash
# Test database connectivity
pg_isready -h dev-flowise-pg.postgres.database.azure.com -p 5432 -U pgadmin

# Check database exists (password from Key Vault)
PGPASSWORD=$(az keyvault secret show --vault-name dev-flowise-kv --name PostgresPassword --query value -o tsv) psql -h dev-flowise-pg.postgres.database.azure.com -p 5432 -U pgadmin -d postgres -c "\l"
```

#### Permission Error During Signup
If you get "You do not have permission to access this resource" error:

**Local PC Solution:**
1. Make sure `ENABLE_SIGNUP=true` in Docker Compose
2. Clear the database and restart:
```powershell
# Stop containers
docker-compose -f docker-compose-openwebui.yml down

# Remove volume data
docker volume rm aifabrix-core_openwebui

# Recreate database
PGPASSWORD=flowise123 psql -h localhost -p 5432 -U flowise -d postgres -c "DROP DATABASE IF EXISTS openwebui; CREATE DATABASE openwebui;"

# Start fresh
docker-compose -f docker-compose-openwebui.yml up -d
```

**Developer Server Solution:**
1. Check that `EnableSignup` parameter is set correctly in deployment script
2. Redeploy with signup enabled:
```powershell
.\deploy-openwebui-vm.ps1 -EnableSignup "true"
```

#### Container Won't Start

**Local PC:**
```powershell
# Check detailed logs
docker logs openwebui-local

# Check container status
docker ps -a

# Restart with rebuild
docker-compose -f docker-compose-openwebui.yml down
docker-compose -f docker-compose-openwebui.yml up -d --force-recreate
```

**Developer Server:**
```bash
# Check detailed logs
docker logs openwebui

# Check container status
docker ps -a

# Restart container
docker restart openwebui
```

## 📊 Monitoring

### Health Checks

**Local PC:**
```powershell
# Check if OpenWebUI is responding
curl http://localhost:3001/api/v1/ping

# Check container health
docker inspect openwebui-local --format='{{.State.Health.Status}}'
```

**Developer Server:**
```bash
# Check if OpenWebUI is responding
curl http://10.3.0.4:3000/api/v1/ping

# Check container health
docker inspect openwebui --format='{{.State.Health.Status}}'
```

### Resource Monitoring

**Local PC:**
```powershell
# Monitor resource usage
docker stats openwebui-local

# Check disk usage
docker system df
```

**Developer Server:**
```bash
# Monitor resource usage
docker stats openwebui

# Check disk usage
docker system df
```

## 🔄 Backup and Recovery

### Data Backup

**Local PC:**
```powershell
# Backup OpenWebUI data volume
docker run --rm -v aifabrix-core_openwebui:/data -v ${PWD}:/backup alpine tar czf /backup/openwebui-backup.tar.gz -C /data .
```

**Developer Server:**
```bash
# Backup OpenWebUI data volume
docker run --rm -v /mnt/openwebui:/data -v $(pwd):/backup alpine tar czf /backup/openwebui-backup.tar.gz -C /data .
```

### Data Restore

**Local PC:**
```powershell
# Restore OpenWebUI data volume
docker run --rm -v aifabrix-core_openwebui:/data -v ${PWD}:/backup alpine tar xzf /backup/openwebui-backup.tar.gz -C /data
```

**Developer Server:**
```bash
# Restore OpenWebUI data volume
docker run --rm -v /mnt/openwebui:/data -v $(pwd):/backup alpine tar xzf /backup/openwebui-backup.tar.gz -C /data
```

## 📋 Deployment Scripts Reference

### deploy-openwebui-image.ps1

Builds and pushes the OpenWebUI Docker image to Azure Container Registry.

**Parameters:**
- `DockerImageName`: Image name with version tag (default: `openwebui/esystems:3.1.1`)
- `arcName`: Azure Container Registry name (default: `devflowiseacr`)

**Usage:**
```powershell
# Use defaults
.\deploy-openwebui-image.ps1

# Custom image name and version
.\deploy-openwebui-image.ps1 -DockerImageName "openwebui/esystems:latest" -arcName "myacr"
```

### deploy-openwebui-vm.ps1

Deploys OpenWebUI to Azure VM with full configuration management.

**Key Parameters:**
- `ResourceGroupName`: Azure resource group (default: `rg-esys-flowise`)
- `VirtualMachineName`: VM name (default: `dev-flowise-vm`)
- `AcrName`: Azure Container Registry name (default: `devflowiseacr`)
- `VaultName`: Azure Key Vault name (default: `dev-flowise-kv`)
- `DockerImageName`: Image repository path (default: `openwebui/esystems`)
- `DockerName`: Container name (default: `openwebui`)
- `DatabaseHost`: PostgreSQL host (default: `dev-flowise-pg.postgres.database.azure.com`)
- `DatabaseName`: Database name (default: `openwebui`)
- `DatabaseUser`: Database user (default: `pgadmin`)
- `VmUser`: VM SSH user (default: `flowiseuser`)
- `VmIp`: VM IP address (default: `10.3.0.4`)
- `Port`: External port (default: `3000`)
- `DefaultUser`: Admin user email (default: `admin@esystems.fi`)
- `WebuiName`: Web UI display name (default: `AIFabrix OpenWebUI`)
- `OllamaBaseUrl`: Ollama service URL (default: `http://ollama:11434`)
- `FlowiseApiUrl`: Flowise integration URL (default: `https://chat.esystems.fi/api/v1/`)
- `EnableSignup`: Enable user signup (default: `false`)
- `ReDeploy`: Redeploy with current image (switch)

**Usage:**
```powershell
# Full deployment
.\deploy-openwebui-vm.ps1

# Redeploy with current image
.\deploy-openwebui-vm.ps1 -ReDeploy

# Custom configuration
.\deploy-openwebui-vm.ps1 -Port 3001 -EnableSignup "true" -WebuiName "My OpenWebUI"
```

**Required Azure Key Vault Secrets:**
- `PostgresPassword`: PostgreSQL database password
- `OpenWebUIPassword`: OpenWebUI admin password
- `OpenWebUISecretKey`: Web UI secret key
- `SMTPPassword`: SMTP password (optional)

## 📚 Additional Resources

- [OpenWebUI GitHub Repository](https://github.com/open-webui/open-webui)
- [OpenWebUI Documentation](https://docs.openwebui.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Azure Container Registry Documentation](https://docs.microsoft.com/en-us/azure/container-registry/)
- [Azure Key Vault Documentation](https://docs.microsoft.com/en-us/azure/key-vault/)

## 🎯 Success Indicators

You'll know OpenWebUI is working correctly when:

### Local PC
- ✅ Container shows "Up" status in `docker ps`
- ✅ OpenWebUI loads at `http://localhost:3001`
- ✅ Signup form works without permission errors
- ✅ Database connection is established
- ✅ No errors in container logs
- ✅ Flowise integration works (if configured)

### Developer Server (Azure VM)
- ✅ Container shows "Up" status in `docker ps`
- ✅ OpenWebUI loads at `http://10.3.0.4:3000`
- ✅ Admin login works with configured credentials
- ✅ Database connection is established
- ✅ No errors in container logs
- ✅ Flowise integration works (if configured)
- ✅ Azure Key Vault secrets are properly retrieved

---

**Happy Chatting! 🤖**

*This documentation is maintained by the development team. Keep it updated as you learn new things!*

