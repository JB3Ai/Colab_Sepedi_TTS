# Create Google Cloud Storage bucket for Sepedi Piper TTS
# Project: sepedilearn / seped-500410

$ErrorActionPreference = "Stop"

# Keep gcloud warnings/errors from becoming PowerShell-native exceptions.
# We inspect $LASTEXITCODE manually.
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

if (-not $env:PROJECT_ID) { $env:PROJECT_ID = "seped-500410" }
if (-not $env:BUCKET_NAME) { $env:BUCKET_NAME = "seped-500410-sepedi-tts" }
if (-not $env:BUCKET_LOCATION) { $env:BUCKET_LOCATION = "europe-west4" }

Write-Host "Using project: $env:PROJECT_ID"
Write-Host "Bucket: gs://$env:BUCKET_NAME"
Write-Host "Location: $env:BUCKET_LOCATION"

& gcloud config set project $env:PROJECT_ID
if ($LASTEXITCODE -ne 0) { throw "Failed to set gcloud project." }

Write-Host ""
Write-Host "Creating bucket..."
Write-Host "If it already exists, the script will continue."

& gcloud storage buckets create "gs://$env:BUCKET_NAME" `
    --project $env:PROJECT_ID `
    --location $env:BUCKET_LOCATION `
    --uniform-bucket-level-access

$createExit = $LASTEXITCODE

if ($createExit -ne 0) {
    Write-Host ""
    Write-Host "Bucket create returned exit code $createExit. Checking whether bucket exists..." -ForegroundColor Yellow

    & gcloud storage ls "gs://$env:BUCKET_NAME" --project $env:PROJECT_ID 1>$null 2>$null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Bucket already exists and is accessible: gs://$env:BUCKET_NAME"
    } else {
        Write-Host ""
        Write-Host "Bucket was not created and is not accessible." -ForegroundColor Red
        Write-Host "Possible causes: globally unique bucket name already taken, permission issue, or invalid location."
        Write-Host "Try a unique name, for example:"
        Write-Host '$env:BUCKET_NAME="seped-500410-sepedi-tts-jono"'
        Write-Host ".\scripts\gcp_create_bucket.ps1"
        exit 1
    }
}

Write-Host ""
Write-Host "Bucket ready: gs://$env:BUCKET_NAME"
Write-Host ""
Write-Host "Upload command example:"
Write-Host "gcloud storage cp `"C:\Users\jono\sepedi_tts_dataset\sepedi_tts_dataset.zip`" gs://$env:BUCKET_NAME/datasets/sepedi_tts_dataset.zip --project $env:PROJECT_ID"
