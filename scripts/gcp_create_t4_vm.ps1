# Create a Google Cloud Compute Engine T4 GPU VM for Sepedi Piper TTS
# Project: sepedilearn / seped-500410

$ErrorActionPreference = "Stop"

# Keep gcloud warnings/errors from becoming PowerShell-native exceptions.
# We inspect $LASTEXITCODE manually.
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
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

& gcloud config set project $env:PROJECT_ID
if ($LASTEXITCODE -ne 0) { throw "Failed to set gcloud project." }

Write-Host ""
Write-Host "Creating GPU VM..."
Write-Host "If it already exists, the script will continue after checking it."

& gcloud compute instances create $env:VM_NAME `
    --project $env:PROJECT_ID `
    --zone $env:ZONE `
    --machine-type $env:MACHINE_TYPE `
    --accelerator "type=$env:GPU_TYPE,count=$env:GPU_COUNT" `
    --maintenance-policy TERMINATE `
    --boot-disk-size $env:BOOT_DISK_SIZE `
    --boot-disk-type pd-balanced `
    --image-family ubuntu-2204-lts `
    --image-project ubuntu-os-cloud `
    --scopes https://www.googleapis.com/auth/cloud-platform

$createExit = $LASTEXITCODE

if ($createExit -ne 0) {
    Write-Host ""
    Write-Host "VM create returned exit code $createExit. Checking whether VM already exists..." -ForegroundColor Yellow

    & gcloud compute instances describe $env:VM_NAME --zone $env:ZONE --project $env:PROJECT_ID 1>$null 2>$null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "VM already exists and is accessible: $env:VM_NAME"
    } else {
        Write-Host ""
        Write-Host "VM was not created." -ForegroundColor Red
        Write-Host "Most likely causes:"
        Write-Host "  1. NVIDIA T4 GPU quota is 0 in this region."
        Write-Host "  2. T4 capacity is unavailable in this zone."
        Write-Host "  3. The selected machine/GPU combination is not available."
        Write-Host ""
        Write-Host "Try another zone:"
        Write-Host '$env:ZONE="europe-west4-b"'
        Write-Host ".\scripts\gcp_create_t4_vm.ps1"
        Write-Host ""
        Write-Host "or:"
        Write-Host '$env:ZONE="europe-west4-c"'
        Write-Host ".\scripts\gcp_create_t4_vm.ps1"
        Write-Host ""
        Write-Host "If all zones fail, request NVIDIA T4 GPU quota for europe-west4."
        exit 1
    }
}

Write-Host ""
Write-Host "VM ready command:"
Write-Host "gcloud compute ssh $env:VM_NAME --zone $env:ZONE --project $env:PROJECT_ID"
Write-Host ""
Write-Host "Cost safety commands:"
Write-Host "gcloud compute instances stop $env:VM_NAME --zone $env:ZONE --project $env:PROJECT_ID"
Write-Host "gcloud compute instances delete $env:VM_NAME --zone $env:ZONE --project $env:PROJECT_ID"
Write-Host ""
Write-Host "Next after SSH: install NVIDIA drivers, clone repo, copy dataset from Cloud Storage, run training pipeline."
