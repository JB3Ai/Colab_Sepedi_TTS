# Create a Google Cloud Compute Engine T4 GPU VM for Sepedi Piper TTS
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
if (-not $env:VM_NAME) { $env:VM_NAME = "sepedi-tts-t4" }
if (-not $env:ZONE) { $env:ZONE = "europe-west4-a" }
if (-not $env:MACHINE_TYPE) { $env:MACHINE_TYPE = "n1-standard-4" }
if (-not $env:GPU_TYPE) { $env:GPU_TYPE = "nvidia-tesla-t4" }
if (-not $env:GPU_COUNT) { $env:GPU_COUNT = "1" }
if (-not $env:BOOT_DISK_SIZE) { $env:BOOT_DISK_SIZE = "150GB" }

Write-Host "Using project: $env:PROJECT_ID"
Write-Host "VM: $env:VM_NAME"
Write-Host "Zone: $env:ZONE"
Write-Host "Machine: $env:MACHINE_TYPE"
Write-Host "GPU: $env:GPU_TYPE x $env:GPU_COUNT"

Invoke-Gcloud @("config", "set", "project", $env:PROJECT_ID)

Write-Host ""
Write-Host "Checking whether VM already exists..."
$vmExists = (& gcloud compute instances describe $env:VM_NAME --zone $env:ZONE --project $env:PROJECT_ID 2>$null)

if ($LASTEXITCODE -eq 0) {
    Write-Host "VM already exists: $env:VM_NAME"
} else {
    Write-Host "Creating GPU VM..."
    Invoke-Gcloud @(
        "compute", "instances", "create", $env:VM_NAME,
        "--project", $env:PROJECT_ID,
        "--zone", $env:ZONE,
        "--machine-type", $env:MACHINE_TYPE,
        "--accelerator", "type=$env:GPU_TYPE,count=$env:GPU_COUNT",
        "--maintenance-policy", "TERMINATE",
        "--boot-disk-size", $env:BOOT_DISK_SIZE,
        "--boot-disk-type", "pd-balanced",
        "--image-family", "ubuntu-2204-lts",
        "--image-project", "ubuntu-os-cloud",
        "--scopes", "https://www.googleapis.com/auth/cloud-platform"
    )
}

Write-Host ""
Write-Host "VM ready command:"
Write-Host "gcloud compute ssh $env:VM_NAME --zone $env:ZONE --project $env:PROJECT_ID"
Write-Host ""
Write-Host "Cost safety commands:"
Write-Host "gcloud compute instances stop $env:VM_NAME --zone $env:ZONE --project $env:PROJECT_ID"
Write-Host "gcloud compute instances delete $env:VM_NAME --zone $env:ZONE --project $env:PROJECT_ID"
Write-Host ""
Write-Host "If VM creation fails with quota or resource availability, try changing `$env:ZONE to europe-west4-b, europe-west4-c, or request NVIDIA T4 GPU quota."
