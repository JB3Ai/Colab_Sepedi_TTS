# Google Cloud API enablement for Windows PowerShell
# Project: sepedilearn / seped-500410

$ErrorActionPreference = "Stop"

# Keep gcloud warnings from being treated as fatal PowerShell exceptions.
# We check $LASTEXITCODE manually after each gcloud command instead.
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
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
Write-Host "Refreshing Application Default Credentials quota project..."
Write-Host "If this asks for login, use the Google account that owns/bills the project."
Invoke-Gcloud @("auth", "application-default", "set-quota-project", $env:PROJECT_ID)

Write-Host ""
Write-Host "Enabling core services..."
Write-Host "If billing is not linked, compute.googleapis.com will fail here with a clear billing error."
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
    "logging.googleapis.com",
    "cloudbilling.googleapis.com"
)

Write-Host ""
Write-Host "Enabled services check:"
Invoke-Gcloud @(
    "services", "list",
    "--enabled",
    "--filter=compute.googleapis.com OR storage.googleapis.com OR cloudbilling.googleapis.com",
    "--format=table(config.name,state)"
)

Write-Host ""
Write-Host "Optional managed ML services, enable later if needed:"
Write-Host "gcloud services enable aiplatform.googleapis.com notebooks.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com --project $env:PROJECT_ID"

Write-Host ""
Write-Host "Done. Core Google Cloud APIs are enabled for $env:PROJECT_ID."
