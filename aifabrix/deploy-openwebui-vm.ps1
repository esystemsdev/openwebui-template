param(
  # Azure / infra
  [string]$ResourceGroupName = "rg-esys-flowise",
  [string]$VirtualMachineName = "dev-flowise-vm",
  [string]$AcrName = "devflowiseacr",
  [string]$VaultName = "dev-flowise-kv",
  [string]$SubscriptionId = "67576622-504a-4532-9903-dbae7df491f5",
  [string]$ApplicationUrl = "https://chat.esystems.fi",

  # Docker/ACR
  [string]$DockerImageName = "openwebui/esystems",   # repo path in ACR (no registry)
  [string]$DockerName = "openwebui",

  # DB
  [string]$DatabaseHost = "dev-flowise-pg.postgres.database.azure.com",
  [string]$DatabaseName = "openwebui",
  [string]$DatabaseUser = "pgadmin",

  # VM SSH
  [string]$VmUser = "flowiseuser",
  [string]$VmIp = "10.3.0.4",
  [string]$SshKey = "$env:USERPROFILE\.ssh\id_rsa",

  # App / logging
  [ValidateSet('error','warn','info','verbose','debug')]
  [string]$LOG_LEVEL = "info",
  [int]$Port = 8080,

  # OpenWebUI specific settings
  [string]$DefaultUser = "admin@esystems.fi",
  [string]$WebuiName = "AIFabrix OpenWebUI",
  [string]$OllamaBaseUrl = "http://ollama:11434",
  [string]$FlowiseApiUrl = "https://chat.esystems.fi/api/v1/",
  [string]$FlowiseApiKey = "",
  [string]$EnableSignup = "true",
  [string]$EnableCommunitySharing = "false",
  [string]$EnableOauthSocialLogin = "false",
  [string]$MaxFileSize = "15728640",
  [string]$MaxRequestSize = "15728640",

  # SMTP (optional; add secure password only if host provided)
  [string]$SMTP_HOST = "email-smtp.eu-central-1.amazonaws.com",
  [int]$SMTP_PORT = 465,
  [string]$SMTP_USER = "AKIAXB7YA7RQHMVYC36D",
  [string]$SENDER_EMAIL = "noreply@esystems.fi",
  [string]$SMTP_SecretName = "SMTPPassword",

  # Behavior
  [switch]$ReDeploy, # if set, reuse current image and just recreate container
  [string]$AzureCliPath = "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin" # Azure CLI installation path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path "$PSScriptRoot\..")

# Add Azure CLI to PATH if not already present
if (Test-Path $AzureCliPath) {
    if ($env:PATH -notlike "*$AzureCliPath*") {
        $env:PATH += ";$AzureCliPath"
        Write-Host "Added Azure CLI to PATH: $AzureCliPath" -ForegroundColor Yellow
    }
} else {
    Write-Warning "Azure CLI path not found: $AzureCliPath"
}

# Basic validation
foreach ($p in @(
  'ResourceGroupName','VirtualMachineName','VaultName','DockerImageName',
  'AcrName','VmUser','VmIp','SshKey','DatabaseHost','DatabaseName','DatabaseUser',
  'DefaultUser','WebuiName','OllamaBaseUrl'
)) { if (-not (Get-Variable -Name $p -ErrorAction SilentlyContinue).Value) { throw "Missing required parameter: $p" } }

# Azure login once locally (only to set subscription — VM uses MI)
Write-Host "[1/5] Azure login (local)..." -ForegroundColor Green
if (-not (az account show --query id -o tsv)) { az login | Out-Null }
az account set --subscription $SubscriptionId

# --- Compose the DOCKER_BLOCK (two modes) ---
$dockerBlock = if ($ReDeploy) {
@'
echo "[VM] Force pulling $REMOTE_REF..."
docker pull "$REMOTE_REF" >/dev/null
'@
} else {
@'
# Determine what is currently running (image ID)
CURRENT_ID=$(docker inspect --format '{{.Image}}' "$DOCKER" 2>/dev/null || true)
echo "[VM] Current container image ID: ${CURRENT_ID:-<none>}"

# Ensure we can inspect the remote ref to get its image ID (pull only if needed)
REMOTE_ID=$(docker image inspect --format '{{.Id}}' "$REMOTE_REF" 2>/dev/null || true)
if [ -z "${REMOTE_ID:-}" ]; then
  echo "[VM] Local cache missing for $REMOTE_REF; pulling metadata..."
  docker pull "$REMOTE_REF" >/dev/null
  REMOTE_ID=$(docker image inspect --format '{{.Id}}' "$REMOTE_REF" 2>/dev/null || true)
fi
echo "[VM] Remote image ID for $REMOTE_REF: ${REMOTE_ID:-<none>}"

# If same image ID, nothing to do
if [ -n "${CURRENT_ID:-}" ] && [ -n "${REMOTE_ID:-}" ] && [ "$CURRENT_ID" = "$REMOTE_ID" ]; then
  echo "[VM] Container already at latest image ($REMOTE_ID). Nothing to do."
  exit 0
fi

echo "[VM] Updating to new image..."
docker pull "$REMOTE_REF" >/dev/null
'@
}


# --- Helper: build SECURE_ENV lines for the bash script (resolved on VM) ---
function Add-SecureEnvLine {
  param([string]$VarName, [string]$SecretName)
  'SECURE_ENV+=("-e" "' + $VarName + '=$(az keyvault secret show --vault-name $VAULT --name ' + $SecretName + ' --query value -o tsv)")'
}

# Mandatory secure envs
$secureEnv = New-Object System.Collections.Generic.List[string]
$secureEnv.Add( (Add-SecureEnvLine -VarName 'DATABASE_PASSWORD' -SecretName 'PostgresPassword') )
$secureEnv.Add( (Add-SecureEnvLine -VarName 'DEFAULT_PASSWORD' -SecretName 'OpenWebUIPassword') )
$secureEnv.Add( (Add-SecureEnvLine -VarName 'WEBUI_SECRET_KEY' -SecretName 'OpenWebUISecretKey') )

# Optional SMTP
$includeSmtp = ($SMTP_HOST -ne '' -and $SMTP_USER -ne '' -and $SENDER_EMAIL -ne '')
if ($includeSmtp) {
  $secureEnv.Add( (Add-SecureEnvLine -VarName 'SMTP_PASSWORD' -SecretName $SMTP_SecretName) )
}

# EXTRA_ENV (only add what's needed)
$extraEnv = New-Object System.Collections.Generic.List[string]
$extraEnv.Add('EXTRA_ENV+=("-e" "LOG_LEVEL=' + $LOG_LEVEL + '")')
if ($LOG_LEVEL -eq 'debug') { $extraEnv.Add('EXTRA_ENV+=("-e" "DEBUG=true")') }

# OpenWebUI specific environment variables
$extraEnv.Add('EXTRA_ENV+=("-e" "DEFAULT_USER=' + $DefaultUser + '")')
$extraEnv.Add('EXTRA_ENV+=("-e" "WEBUI_NAME=' + $WebuiName + '")')
$extraEnv.Add('EXTRA_ENV+=("-e" "OLLAMA_BASE_URL=' + $OllamaBaseUrl + '")')
$extraEnv.Add('EXTRA_ENV+=("-e" "ENABLE_SIGNUP=' + $EnableSignup + '")')
$extraEnv.Add('EXTRA_ENV+=("-e" "ENABLE_COMMUNITY_SHARING=' + $EnableCommunitySharing + '")')
$extraEnv.Add('EXTRA_ENV+=("-e" "ENABLE_OAUTH_SOCIAL_LOGIN=' + $EnableOauthSocialLogin + '")')
$extraEnv.Add('EXTRA_ENV+=("-e" "MAX_FILE_SIZE=' + $MaxFileSize + '")')
$extraEnv.Add('EXTRA_ENV+=("-e" "MAX_REQUEST_SIZE=' + $MaxRequestSize + '")')

# Flowise integration (if configured)
if ($FlowiseApiUrl -ne '' -and $FlowiseApiKey -ne '') {
  $extraEnv.Add('EXTRA_ENV+=("-e" "FLOWISE_API_URL=' + $FlowiseApiUrl + '")')
  $extraEnv.Add('EXTRA_ENV+=("-e" "FLOWISE_API_KEY=' + $FlowiseApiKey + '")')
}

if ($includeSmtp) {
  $extraEnv.Add('EXTRA_ENV+=("-e" "SMTP_HOST=' + $SMTP_HOST + '")')
  $extraEnv.Add('EXTRA_ENV+=("-e" "SMTP_PORT=' + $SMTP_PORT + '")')
  $extraEnv.Add('EXTRA_ENV+=("-e" "SMTP_USER=' + $SMTP_USER + '")')
  $extraEnv.Add('EXTRA_ENV+=("-e" "SENDER_EMAIL=' + $SENDER_EMAIL + '")')
}

# Turn lists into script text
$secureEnvText = ($secureEnv -join "`n")
$extraEnvText  = ($extraEnv  -join "`n")

# ---- Static vars assigned IN BASH (used multiple times) ----
$staticVars = @"
set -euo pipefail

DOCKER="$DockerName"
VAULT="$VaultName"
ACR_NAME="$AcrName"
REPO="$DockerImageName"

DB_HOST="$DatabaseHost"
DB_NAME="$DatabaseName"
DB_USER="$DatabaseUser"
PORT="$Port"
APP_URL="$ApplicationUrl"
"@

# Remote script template — minimal, only what’s needed
$remoteScriptTemplate = @'
#!/usr/bin/env bash
{{STATIC_VARS}}

echo "[VM] az login with Managed Identity (quiet)..."
az login --identity >/dev/null 2>&1 || true

echo "[VM] Logging in Docker to ACR..."
az acr login --name "$ACR_NAME" >/dev/null

echo "[VM] Getting newest manifest (by push time) from ACR..."
DIGEST=$(az acr manifest list-metadata \
  --registry "$ACR_NAME" \
  --name "$REPO" \
  --orderby time_desc \
  --top 1 --query "[0].digest" -o tsv 2>/dev/null)

if [ -z "${DIGEST:-}" ]; then
  echo "[VM] No manifests found for $ACR_NAME.azurecr.io/$REPO"; exit 0
fi
REMOTE_REF="$ACR_NAME.azurecr.io/$REPO@$DIGEST"

{{DOCKER_BLOCK}}

SECURE_ENV=()
{{SECURE_ENV}}

EXTRA_ENV=()
{{EXTRA_ENV}}

echo "[VM] Restarting $DOCKER..."
docker rm -f "$DOCKER" >/dev/null 2>&1 || true

# If REMOTE_REF not set (Redeploy mode uses current), default to current image ref
if [ -z "${REMOTE_REF:-}" ]; then
  REMOTE_REF=$(docker inspect --format '{{.Config.Image}}' "$DOCKER" 2>/dev/null || true)
  if [ -z "$REMOTE_REF" ]; then
    echo "[VM] No image reference available."; exit 1
  fi
fi

docker run -d -p "$PORT:8080" \
  --name "$DOCKER" \
  --restart unless-stopped \
  -v /mnt/openwebui:/app/backend/data \
  -e DATABASE_URL="postgresql://$DB_USER:$(az keyvault secret show --vault-name $VAULT --name PostgresPassword --query value -o tsv)@$DB_HOST:5432/$DB_NAME" \
  "${SECURE_ENV[@]}" \
  "${EXTRA_ENV[@]}" \
  "$REMOTE_REF"

echo "[VM] Done. $DOCKER is running on port $PORT."
'@

# Fill placeholders
$remoteScript = $remoteScriptTemplate.
  Replace("{{STATIC_VARS}}", $staticVars).
  Replace("{{DOCKER_BLOCK}}", $dockerBlock).
  Replace("{{SECURE_ENV}}", $secureEnvText).
  Replace("{{EXTRA_ENV}}", $extraEnvText)

# Normalize line endings & ship it
$remoteScriptPath = "/home/$VmUser/deploy-$DockerName.sh"
$tempFile = [System.IO.Path]::GetTempFileName()
$remoteScript = $remoteScript.Replace("`r`n", "`n")
[System.IO.File]::WriteAllText($tempFile, $remoteScript, [System.Text.UTF8Encoding]::new($false))

Write-Host "[3/5] Upload script..." -ForegroundColor Green
scp -o StrictHostKeyChecking=no -i $SshKey $tempFile "${VmUser}@${VmIp}:${remoteScriptPath}"

Write-Host "[4/5] Make executable..." -ForegroundColor Green
ssh -o StrictHostKeyChecking=no -i $SshKey "${VmUser}@${VmIp}" "chmod +x $remoteScriptPath"

Write-Host "[5/5] Execute..." -ForegroundColor Green
ssh -o StrictHostKeyChecking=no -i $SshKey "${VmUser}@${VmIp}" "bash $remoteScriptPath"

#Remove-Item $tempFile -Force
Write-Host "Daily update check completed." -ForegroundColor Green
Write-Host "OpenWebUI running on http://${VmIp}:${Port}"
Write-Host "To access OpenWebUI, open http://${VmIp}:${Port} in your browser." -ForegroundColor Yellow
Write-Host "Deployment script completed successfully." -ForegroundColor Green