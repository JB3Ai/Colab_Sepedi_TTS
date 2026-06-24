# Create Google Cloud Storage bucket for Sepedi Piper TTS
# Project: sepedilearn / seped-500410

$ErrorActionPreference = "Stop"

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

if (-not $env:PROJECT_ID) { $env:PROJECT_ID = "seped-500410" }
if (-not $env:BUCKET_NAME) { $env:BUCKET_NAME = "seped-500410-sepedi-tts" }
if (-not $env:BUCKET_LOCATION) { $env:BUCKET_LOCATION = "EUROPE-WEST4" }

Write-Host "Using project: $env:PROJECT_ID"
Write-Host "Bucket: gs://$env:BUCKET_NAME"
Write-Host "Location: $env:BUCKET_LOCATION"

Invoke-Gcloud @("config", "set", "project", $env:PROJECT_ID)

Write-Host ""
Write-Host "Creating bucket if it does not exist..."
$bucketExists = (& gcloud storage buckets describe "gs://$env:BUCKET_NAME" --project $env:PROJECT_ID 2>$null)

if ($LASTEXITCODE -eq 0) {
    Write-Host "Bucket already exists: gs://$env:BUCKET_NAME"
} else {
    Invoke-Gcloud @(
        "storage", "buckets", "create", "gs://$env:BUCKET_NAME",
        "--project", $env:PROJECT_ID,
        "--location", $env:BUCKET_LOCATION,
        "--uniform-bucket-level-access"
    )
}

Write-Host ""
Write-Host "Bucket ready: gs://$env:BUCKET_NAME"
Write-Host ""
Write-Host "To upload the dataset later, run:"
Write-Host "gcloud storage cp C:\path\to\sepedi_tts_dataset.zip gs://$env:BUCKET_NAME/datasets/sepedi_tts_dataset.zip --project $env:PROJECT_ID"
