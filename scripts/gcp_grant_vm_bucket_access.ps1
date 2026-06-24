# Grant the Compute Engine VM service account access to the Sepedi TTS Cloud Storage bucket
# Run this from Windows PowerShell where you are authenticated as the project owner/admin.

$ErrorActionPreference = "Stop"

if (-not $env:PROJECT_ID) { $env:PROJECT_ID = "seped-500410" }
if (-not $env:PROJECT_NUMBER) { $env:PROJECT_NUMBER = "1041951369397" }
if (-not $env:BUCKET_NAME) { $env:BUCKET_NAME = "seped-500410-sepedi-tts" }

$serviceAccount = "$env:PROJECT_NUMBER-compute@developer.gserviceaccount.com"
$member = "serviceAccount:$serviceAccount"
$bucket = "gs://$env:BUCKET_NAME"

Write-Host "Project: $env:PROJECT_ID"
Write-Host "Bucket: $bucket"
Write-Host "VM service account: $serviceAccount"
Write-Host ""

Write-Host "Setting active project..."
gcloud config set project $env:PROJECT_ID

Write-Host ""
Write-Host "Granting Storage Object Admin on bucket so the VM can read dataset and upload outputs..."
gcloud storage buckets add-iam-policy-binding $bucket `
  --member=$member `
  --role=roles/storage.objectAdmin `
  --project=$env:PROJECT_ID

Write-Host ""
Write-Host "Done. The VM service account can now read/write objects in $bucket."
Write-Host "Return to the VM and rerun:"
Write-Host "cd ~/Colab_Sepedi_TTS"
Write-Host "./scripts/vm_bootstrap_train.sh"
