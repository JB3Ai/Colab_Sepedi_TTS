# Debug T4 VM creation for Sepedi Piper TTS
# Prints the raw Google Cloud error so quota/zone issues are visible.

$ErrorActionPreference = "Continue"
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

Write-Host "Project: $env:PROJECT_ID"
Write-Host "VM: $env:VM_NAME"
Write-Host "Zone: $env:ZONE"
Write-Host "GPU: $env:GPU_TYPE x $env:GPU_COUNT"
Write-Host ""

gcloud config set project $env:PROJECT_ID

Write-Host ""
Write-Host "Checking available accelerator types. Your gcloud SDK does not support --zones on this command, so filtering locally:"
$accelerators = gcloud compute accelerator-types list --project $env:PROJECT_ID --format="table(name,zone)"
$accelerators | Select-String $env:ZONE

Write-Host ""
Write-Host "Creating VM and showing raw error if it fails..."
gcloud compute instances create $env:VM_NAME `
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

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Creation failed. Common fixes:" -ForegroundColor Yellow
    Write-Host "1. Try another zone:"
    Write-Host '   $env:ZONE="europe-west4-b"'
    Write-Host '   .\scripts\gcp_create_t4_vm_debug.ps1'
    Write-Host "2. Then try:"
    Write-Host '   $env:ZONE="europe-west4-c"'
    Write-Host '   .\scripts\gcp_create_t4_vm_debug.ps1'
    Write-Host "3. If the error mentions quota, request NVIDIA T4 GPU quota for europe-west4."
    exit 1
}

Write-Host ""
Write-Host "VM created. SSH command:"
Write-Host "gcloud compute ssh $env:VM_NAME --zone $env:ZONE --project $env:PROJECT_ID"
