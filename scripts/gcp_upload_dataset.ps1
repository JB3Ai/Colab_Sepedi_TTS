# Upload Sepedi dataset zip to Google Cloud Storage
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

Write-Host "Using project: $env:PROJECT_ID"
Write-Host "Target bucket: gs://$env:BUCKET_NAME"

Invoke-Gcloud @("config", "set", "project", $env:PROJECT_ID)

$datasetPath = $null

if ($env:DATASET_ZIP -and (Test-Path $env:DATASET_ZIP)) {
    $datasetPath = (Resolve-Path $env:DATASET_ZIP).Path
}

if (-not $datasetPath) {
    $candidates = @(
        (Join-Path $PWD "sepedi_tts_dataset.zip"),
        (Join-Path $HOME "sepedi_tts_dataset.zip"),
        (Join-Path $HOME "Downloads\sepedi_tts_dataset.zip"),
        (Join-Path $HOME "Desktop\sepedi_tts_dataset.zip"),
        (Join-Path $HOME "Documents\sepedi_tts_dataset.zip"),
        (Join-Path $HOME "sepedi_tts_dataset\sepedi_tts_dataset.zip")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $datasetPath = (Resolve-Path $candidate).Path
            break
        }
    }
}

if (-not $datasetPath) {
    Write-Host ""
    Write-Host "Dataset zip not found in common locations." -ForegroundColor Yellow
    Write-Host "Searching your user folder for sepedi_tts_dataset.zip. This may take a moment..."

    $found = Get-ChildItem -Path $HOME -Filter "sepedi_tts_dataset.zip" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($found) {
        $datasetPath = $found.FullName
    }
}

if (-not $datasetPath) {
    Write-Host ""
    Write-Host "STOP: Could not find sepedi_tts_dataset.zip." -ForegroundColor Red
    Write-Host "Either move the file into one of these locations:"
    Write-Host "  $HOME\Downloads\sepedi_tts_dataset.zip"
    Write-Host "  $HOME\sepedi_tts_dataset.zip"
    Write-Host "or set the path manually:"
    Write-Host '$env:DATASET_ZIP="C:\full\path\to\sepedi_tts_dataset.zip"'
    Write-Host ".\scripts\gcp_upload_dataset.ps1"
    exit 1
}

Write-Host ""
Write-Host "Dataset zip found: $datasetPath"
Write-Host "Uploading to gs://$env:BUCKET_NAME/datasets/sepedi_tts_dataset.zip"

Invoke-Gcloud @(
    "storage", "cp",
    $datasetPath,
    "gs://$env:BUCKET_NAME/datasets/sepedi_tts_dataset.zip",
    "--project", $env:PROJECT_ID
)

Write-Host ""
Write-Host "Upload complete. Verifying object..."
Invoke-Gcloud @(
    "storage", "ls", "-l",
    "gs://$env:BUCKET_NAME/datasets/sepedi_tts_dataset.zip",
    "--project", $env:PROJECT_ID
)

Write-Host ""
Write-Host "Dataset ready in Cloud Storage."
