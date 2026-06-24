# Inspect Google Cloud GPU quota for Sepedi Piper TTS
# Project: sepedilearn / seped-500410

$ErrorActionPreference = "Continue"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

if (-not $env:PROJECT_ID) { $env:PROJECT_ID = "seped-500410" }

function Show-QuotaRows {
    param(
        [Parameter(Mandatory = $true)]
        $QuotaJson,
        [Parameter(Mandatory = $true)]
        [string[]]$MetricNames
    )

    $rows = @()
    foreach ($quota in $QuotaJson.quotas) {
        if ($MetricNames -contains $quota.metric) {
            $rows += [PSCustomObject]@{
                Metric = $quota.metric
                Usage  = $quota.usage
                Limit  = $quota.limit
            }
        }
    }

    if ($rows.Count -eq 0) {
        Write-Host "No matching quota rows found."
    } else {
        $rows | Format-Table -AutoSize
    }
}

$targetMetrics = @(
    "GPUS_ALL_REGIONS",
    "NVIDIA_T4_GPUS",
    "PREEMPTIBLE_NVIDIA_T4_GPUS",
    "NVIDIA_L4_GPUS",
    "PREEMPTIBLE_NVIDIA_L4_GPUS",
    "NVIDIA_A100_GPUS",
    "NVIDIA_A100_80GB_GPUS"
)

Write-Host "Project: $env:PROJECT_ID"
Write-Host ""

gcloud config set project $env:PROJECT_ID

Write-Host ""
Write-Host "Global GPU quota summary:"
Write-Host "------------------------------------------------------------"
$projectJsonRaw = gcloud compute project-info describe --project $env:PROJECT_ID --format=json
$projectJson = $projectJsonRaw | ConvertFrom-Json
Show-QuotaRows -QuotaJson $projectJson -MetricNames $targetMetrics

Write-Host ""
Write-Host "Regional GPU quota summary:"
Write-Host "------------------------------------------------------------"
$regions = @(
    "europe-west4",
    "europe-west1",
    "europe-west2",
    "us-central1",
    "us-west1",
    "us-east1",
    "us-east4",
    "asia-southeast1"
)

foreach ($region in $regions) {
    Write-Host ""
    Write-Host "### $region" -ForegroundColor Cyan
    $regionJsonRaw = gcloud compute regions describe $region --project $env:PROJECT_ID --format=json
    if ($LASTEXITCODE -eq 0) {
        $regionJson = $regionJsonRaw | ConvertFrom-Json
        Show-QuotaRows -QuotaJson $regionJson -MetricNames $targetMetrics
    } else {
        Write-Host "Could not read region quota for $region"
    }
}

Write-Host ""
Write-Host "Interpretation:"
Write-Host "  If GPUS_ALL_REGIONS limit is 0, no GPU VM can be created in any region."
Write-Host "  Request at least: GPUS_ALL_REGIONS = 1"
Write-Host "  Then request one regional GPU quota: NVIDIA_T4_GPUS = 1 or NVIDIA_L4_GPUS = 1"
