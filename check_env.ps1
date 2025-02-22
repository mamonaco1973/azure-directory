Write-Host "NOTE: Validating that required commands are found in your PATH."  -ForegroundColor Green

# List of required commands
$commands = @("az", "packer", "terraform")
$all_found = $true

foreach ($cmd in $commands) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: $cmd is not found in the current PATH."  -ForegroundColor Red
        $all_found = $false
    } else {
        Write-Host "NOTE: $cmd is found in the current PATH." -ForegroundColor Green
    }
}

if (-not $all_found) {
    Write-Host "ERROR: One or more commands are missing." -ForegroundColor Red
    exit 1
}

# Explicit checks for required environment variables
if (-not $Env:ARM_CLIENT_ID) {
    Write-Host "ERROR: ARM_CLIENT_ID is not set or is empty." -ForegroundColor Red
    exit 1
} else {
    Write-Host "NOTE: ARM_CLIENT_ID is set."  -ForegroundColor Green
}

if (-not $Env:ARM_CLIENT_SECRET) {
    Write-Host "ERROR: ARM_CLIENT_SECRET is not set or is empty." -ForegroundColor Red
    exit 1
} else {
    Write-Host "NOTE: ARM_CLIENT_SECRET is set."  -ForegroundColor Green
}

if (-not $Env:ARM_SUBSCRIPTION_ID) {
    Write-Host "ERROR: ARM_SUBSCRIPTION_ID is not set or is empty." -ForegroundColor Red
    exit 1
} else {
    Write-Host "NOTE: ARM_SUBSCRIPTION_ID is set."  -ForegroundColor Green
}

if (-not $Env:ARM_TENANT_ID) {
    Write-Host "ERROR: ARM_TENANT_ID is not set or is empty." -ForegroundColor Red
    exit 1
} else {
    Write-Host "NOTE: ARM_TENANT_ID is set."  -ForegroundColor Green
}

Write-Host "NOTE: Logging in to Azure using Service Principal..."  -ForegroundColor Green
az login --service-principal --username $Env:ARM_CLIENT_ID --password $Env:ARM_CLIENT_SECRET --tenant $Env:ARM_TENANT_ID | Out-Null

if (-not $?) {
    Write-Host "ERROR: Failed to log into Azure. Please check your credentials and environment variables." -ForegroundColor Red
    exit 1
} else {
    Write-Host "NOTE: Successfully logged into Azure."  -ForegroundColor Green
}