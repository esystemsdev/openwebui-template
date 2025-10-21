#!/usr/bin/env pwsh

Write-Host "Setting up OpenWebUI for Local PC..." -ForegroundColor Green

# Check if Docker is running
try {
    docker info | Out-Null
    Write-Host "Docker is running ✓" -ForegroundColor Green
} catch {
    Write-Host "Error: Docker is not running. Please start Docker Desktop and try again." -ForegroundColor Red
    exit 1
}

# Check if PostgreSQL client is available
Write-Host "Starting OpenWebUI with local PostgreSQL..." -ForegroundColor Yellow
Write-Host "This will start OpenWebUI containers." -ForegroundColor Yellow

# Start the containers
docker-compose -f docker-compose-openwebui.yml up -d

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "Access OpenWebUI at: http://localhost:3003" -ForegroundColor Cyan
Write-Host "Login: admin@esystems.fi / Flowise,1234" -ForegroundColor Cyan
Write-Host ""
Write-Host "To stop: docker-compose -f docker-compose-openwebui.yml down" -ForegroundColor White
