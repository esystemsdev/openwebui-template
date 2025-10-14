param (
    [string]$DockerImageName = "openwebui/esystems:3.1.1",  # version tag
    [string]$arcName = "devflowiseacr"
)

# Move up one folder from scripts to project root
Set-Location (Resolve-Path "$PSScriptRoot\..")

# --- Derived paths for pushing ---
$arcUrlVersioned = "$arcName.azurecr.io/$DockerImageName"

# --- Step 1: Build Docker image ---
Write-Host "[1/2] Building Docker image '$DockerImageName'..." -ForegroundColor Green
docker build --no-cache -t $DockerImageName .

# --- Step 2: Push versioned tag ---
Write-Host "[2/2] Pushing versioned image to $arcUrlVersioned..." -ForegroundColor Green
az acr login -n $arcName
docker tag  $DockerImageName $arcUrlVersioned
docker push $arcUrlVersioned