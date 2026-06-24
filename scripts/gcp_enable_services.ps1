# Google Cloud API enablement for Windows PowerShell
# Project: sepedilearn / seped-500410

$ErrorActionPreference = "Stop"

# Make native command failures stop the script in PowerShell 7+
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $true
}

function Invoke-Gcloud {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args
    )

    & gcloud @Args

    if ($LASTEXITCODE -ne 0) {
        throw "gcloud command failed: gcloud $($Args -join ' ')"
    }
}

if (-not $env:PROJECT_ID) {
    $env:PROJECT_ID = "seped-500410"
}

Write-Host "Using project: $env:PROJECT_ID"
Invoke-Gcloud @("config", "set", "project", $env:PROJECT_ID)

Write-Host ""
Write-Host "Checking billing status..."
$billingStatus = (& gcloud beta billing projects describe $env:PROJECT_ID --format="value(billingEnabled)" 2>$null)

if ($LASTEXITCODE -ne 0 -or $billingStatus -ne "True") {
    Write-Host ""
    Write-Host "STOP: Billing is not enabled for project $env:PROJECT_ID." -ForegroundColor Red
    Write-Host "Open Google Cloud Console → Billing → My Projects → find sepedilearn / $env:PROJECT_ID → Link billing account."
    Write-Host "Then rerun this script."
    exit 1
}

Write-Host "Billing enabled: $billingStatus"

Write-Host ""
Write-Host "Refreshing Application Default Credentials..."
Write-Host "A browser login may open. Use the same Google account that owns/bills the project."
Invoke-Gcloud @("auth", "application-default", "login")
Invoke-Gcloud @("auth", "application-default", "set-quota-project", $env:PROJECT_ID)

Write-Host ""
Write-Host "Enabling core services..."
Invoke-Gcloud @(
    "services", "enable",
    "serviceusage.googleapis.com",
    "compute.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "billingbudgets.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com"
)

Write-Host ""
Write-Host "Optional managed ML services, enable later if needed:"
Write-Host "gcloud services enable aiplatform.googleapis.com notebooks.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com"

Write-Host ""
Write-Host "Done. Core Google Cloud APIs are enabled for $env:PROJECT_ID."
