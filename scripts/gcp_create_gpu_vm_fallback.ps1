# Auto-create a Google Cloud GPU VM using fallback GPU/machine configs
# Project: sepedilearn / seped-500410
# Strategy:
# 1. Try T4 with smaller n1 CPU shapes.
# 2. Try L4 G2 machine shapes as a modern fallback.

$ErrorActionPreference = "Continue"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

if (-not $env:PROJECT_ID) { $env:PROJECT_ID = "seped-500410" }
if (-not $env:VM_NAME) { $env:VM_NAME = "sepedi-tts-gpu" }
if (-not $env:BOOT_DISK_SIZE) { $env:BOOT_DISK_SIZE = "150GB" }

# Override manually if needed:
# $env:ZONES="europe-west4-c,europe-west1-b,us-central1-a"
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
        "us-central1-a",
        "us-central1-b",
        "us-central1-c",
        "us-central1-f",
        "us-west1-a",
        "us-west1-b",
        "us-east1-b",
        "us-east1-c",
        "us-east1-d"
    )
}

# Configs are tried in order.
# T4 configs use an explicit accelerator flag.
# G2 configs have attached L4 GPUs via the machine type, so no accelerator flag is used.
$configs = @(
    @{ Name = "T4-n1-standard-2"; Machine = "n1-standard-2"; Accelerator = "type=nvidia-tesla-t4,count=1"; Type = "explicit" },
    @{ Name = "T4-n1-standard-1"; Machine = "n1-standard-1"; Accelerator = "type=nvidia-tesla-t4,count=1"; Type = "explicit" },
    @{ Name = "T4-n1-standard-4"; Machine = "n1-standard-4"; Accelerator = "type=nvidia-tesla-t4,count=1"; Type = "explicit" },
    @{ Name = "L4-g2-standard-4"; Machine = "g2-standard-4"; Accelerator = ""; Type = "g2" },
    @{ Name = "L4-g2-standard-8"; Machine = "g2-standard-8"; Accelerator = ""; Type = "g2" }
)

Write-Host "Project: $env:PROJECT_ID"
Write-Host "VM: $env:VM_NAME"
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

foreach ($config in $configs) {
    Write-Host ""
    Write-Host "############################################################"
    Write-Host "Trying config: $($config.Name)" -ForegroundColor Magenta
    Write-Host "############################################################"

    foreach ($zone in $zones) {
        Write-Host ""
        Write-Host "============================================================"
        Write-Host "Trying zone: $zone" -ForegroundColor Cyan
        Write-Host "============================================================"

        $logPath = Join-Path $PWD "gcp_vm_create_$($config.Name)_$zone.log"

        if ($config.Type -eq "explicit") {
            gcloud compute instances create $env:VM_NAME `
              --project $env:PROJECT_ID `
              --zone $zone `
              --machine-type $config.Machine `
              --accelerator $config.Accelerator `
              --maintenance-policy TERMINATE `
              --boot-disk-size $env:BOOT_DISK_SIZE `
              --boot-disk-type pd-balanced `
              --image-family ubuntu-2204-lts `
              --image-project ubuntu-os-cloud `
              --scopes https://www.googleapis.com/auth/cloud-platform *> $logPath
        } else {
            gcloud compute instances create $env:VM_NAME `
              --project $env:PROJECT_ID `
              --zone $zone `
              --machine-type $config.Machine `
              --maintenance-policy TERMINATE `
              --boot-disk-size $env:BOOT_DISK_SIZE `
              --boot-disk-type pd-balanced `
              --image-family ubuntu-2204-lts `
              --image-project ubuntu-os-cloud `
              --scopes https://www.googleapis.com/auth/cloud-platform *> $logPath
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "SUCCESS: VM created" -ForegroundColor Green
            Write-Host "Config: $($config.Name)"
            Write-Host "Zone: $zone"
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

        Write-Host "Failed. Last lines:"
        Get-Content $logPath -Tail 20
    }
}

Write-Host ""
Write-Host "No GPU VM config succeeded." -ForegroundColor Red
Write-Host "Next options:"
Write-Host "1. Request GPU quota for T4 and/or L4."
Write-Host "2. Try more zones/regions manually with `$env:ZONES."
Write-Host "3. Use Vertex AI Workbench/Custom Training after quota is approved."
Write-Host ""
Write-Host "Example custom zones:"
Write-Host '$env:ZONES="asia-southeast1-a,asia-southeast1-b,us-east4-a,us-east4-b"'
Write-Host ".\scripts\gcp_create_gpu_vm_fallback.ps1"
exit 1
