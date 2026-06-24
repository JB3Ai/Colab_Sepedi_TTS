# Inspect Google Cloud GPU quota for Sepedi Piper TTS
# Project: sepedilearn / seped-500410

$ErrorActionPreference = "Continue"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

if (-not $env:PROJECT_ID) { $env:PROJECT_ID = "seped-500410" }

Write-Host "Project: $env:PROJECT_ID"
Write-Host ""

gcloud config set project $env:PROJECT_ID

Write-Host "Global GPU quota indicators:"
Write-Host "------------------------------------------------------------"
gcloud compute project-info describe --project $env:PROJECT_ID --format="flattened(quotas[])" | Select-String "GPUS|GPU|NVIDIA|PREEMPTIBLE"

Write-Host ""
Write-Host "Regional quota snapshots for common GPU regions:"
Write-Host "------------------------------------------------------------"
$regions = @(
    "europe-west4",
    "europe-west1",
    "europe-west2",
    "us-central1",
    "us-west1",
    "us-east1"
)

foreach ($region in $regions) {
    Write-Host ""
    Write-Host "### $region" -ForegroundColor Cyan
    gcloud compute regions describe $region --project $env:PROJECT_ID --format="flattened(quotas[])" | Select-String "GPUS|GPU|NVIDIA|T4|L4|PREEMPTIBLE"
}

Write-Host ""
Write-Host "If GPUS_ALL_REGIONS is 0.0, request a quota increase before creating GPU VMs."
Write-Host "Recommended minimum request:"
Write-Host "  GPUS_ALL_REGIONS: 1"
Write-Host "  NVIDIA_T4_GPUS or NVIDIA_L4_GPUS in one target region: 1"
