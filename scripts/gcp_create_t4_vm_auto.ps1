# Auto-create a Google Cloud T4 GPU VM by trying multiple zones
# Project: sepedilearn / seped-500410

$ErrorActionPreference = "Continue"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

if (-not $env:PROJECT_ID) { $env:PROJECT_ID = "seped-500410" }
if (-not $env:VM_NAME) { $env:VM_NAME = "sepedi-tts-t4" }
if (-not $env:MACHINE_TYPE) { $env:MACHINE_TYPE = "n1-standard-4" }
if (-not $env:GPU_TYPE) { $env:GPU_TYPE = "nvidia-tesla-t4" }
if (-not $env:GPU_COUNT) { $env:GPU_COUNT = "1" }
if (-not $env:BOOT_DISK_SIZE) { $env:BOOT_DISK_SIZE = "150GB" }

# Preferred low-latency / Europe zones first, then broader fallback.
# Override manually with:
# $env:ZONES="europe-west4-c,europe-west4-a,europe-west1-b"
if ($env:ZONES) {
    $zones = $env:ZONES.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
} else {
    $zones = @(
        "europe-west4-c",
        "europe-west4-a",
        "europe-west4-b",
        "europe-west1-b",
        "europe-west1-c",
        "europe-west1-d",
        "europe-west2-a",
        "europe-west2-b",
        "europe-west2-c",
        "us-central1-a",
        "us-central1-b",
        "us-central1-c",
        "us-central1-f",
        "us-west1-a",
        "us-west1-b"
    )
}

Write-Host "Project: $env:PROJECT_ID"
Write-Host "VM: $env:VM_NAME"
Write-Host "Machine: $env:MACHINE_TYPE"
Write-Host "GPU: $env:GPU_TYPE x $env:GPU_COUNT"
Write-Host "Disk: $env:BOOT_DISK_SIZE"
Write-Host ""

gcloud config set project $env:PROJECT_ID

Write-Host ""
Write-Host "Checking if VM already exists anywhere in candidate zones..."
foreach ($zone in $zones) {
    gcloud compute instances describe $env:VM_NAME --zone $zone --project $env:PROJECT_ID 1>$null 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "VM already exists in zone: $zone" -ForegroundColor Green
        Write-Host "SSH: gcloud compute ssh $env:VM_NAME --zone $zone --project $env:PROJECT_ID"
        exit 0
    }
}

Write-Host ""
Write-Host "Trying zones in order:"
$zones | ForEach-Object { Write-Host "  $_" }

foreach ($zone in $zones) {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Trying zone: $zone" -ForegroundColor Cyan
    Write-Host "============================================================"

    $logPath = Join-Path $PWD "gcp_vm_create_$zone.log"

    gcloud compute instances create $env:VM_NAME `
      --project $env:PROJECT_ID `
      --zone $zone `
      --machine-type $env:MACHINE_TYPE `
      --accelerator "type=$env:GPU_TYPE,count=$env:GPU_COUNT" `
      --maintenance-policy TERMINATE `
      --boot-disk-size $env:BOOT_DISK_SIZE `
      --boot-disk-type pd-balanced `
      --image-family ubuntu-2204-lts `
      --image-project ubuntu-os-cloud `
      --scopes https://www.googleapis.com/auth/cloud-platform *> $logPath

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "SUCCESS: VM created in zone $zone" -ForegroundColor Green
        Get-Content $logPath -Tail 40
        Write-Host ""
        Write-Host "SSH command:"
        Write-Host "gcloud compute ssh $env:VM_NAME --zone $zone --project $env:PROJECT_ID"
        Write-Host ""
        Write-Host "Cost safety:"
        Write-Host "gcloud compute instances stop $env:VM_NAME --zone $zone --project $env:PROJECT_ID"
        Write-Host "gcloud compute instances delete $env:VM_NAME --zone $zone --project $env:PROJECT_ID"
        exit 0
    }

    Write-Host "Failed in zone $zone. Last lines:"
    Get-Content $logPath -Tail 30
}

Write-Host ""
Write-Host "No candidate zone succeeded." -ForegroundColor Red
Write-Host "Most likely causes:"
Write-Host "1. T4 capacity is exhausted across attempted zones."
Write-Host "2. T4 quota is not available in the relevant region."
Write-Host "3. Your project needs a specific regional GPU quota increase."
Write-Host ""
Write-Host "Try setting your own zone list, for example:"
Write-Host '$env:ZONES="us-central1-a,us-central1-b,us-west1-a"'
Write-Host ".\scripts\gcp_create_t4_vm_auto.ps1"
Write-Host ""
Write-Host "Then inspect logs:"
Write-Host "Get-Content .\gcp_vm_create_*.log -Tail 40"
exit 1
