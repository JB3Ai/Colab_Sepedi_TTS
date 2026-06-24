# Google Cloud API enablement for Windows PowerShell
# Project: sepedilearn / seped-500410

$ErrorActionPreference = "Stop"

if (-not $env:PROJECT_ID) {
    $env:PROJECT_ID = "seped-500410"
}

Write-Host "Using project: $env:PROJECT_ID"
gcloud config set project $env:PROJECT_ID

Write-Host "Updating Application Default Credentials quota project..."
gcloud auth application-default set-quota-project $env:PROJECT_ID

Write-Host "Enabling core services..."
gcloud services enable `
  serviceusage.googleapis.com `
  compute.googleapis.com `
  storage.googleapis.com `
  iam.googleapis.com `
  iamcredentials.googleapis.com `
  cloudresourcemanager.googleapis.com `
  billingbudgets.googleapis.com `
  monitoring.googleapis.com `
  logging.googleapis.com

Write-Host ""
Write-Host "Optional managed ML services, enable later if needed:"
Write-Host "gcloud services enable aiplatform.googleapis.com notebooks.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com"

Write-Host ""
Write-Host "Done. Core Google Cloud APIs are enabled for $env:PROJECT_ID."
