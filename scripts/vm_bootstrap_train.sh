#!/usr/bin/env bash
set -euo pipefail

# Bootstrap and run Sepedi Piper TTS training on a Google Cloud GPU VM.
# Designed for the GCP VM created by scripts/gcp_create_gpu_vm_fallback.ps1.

PROJECT_ID="${PROJECT_ID:-seped-500410}"
BUCKET_NAME="${BUCKET_NAME:-seped-500410-sepedi-tts}"
REPO_URL="${REPO_URL:-https://github.com/JB3Ai/Colab_Sepedi_TTS.git}"
REPO_DIR="${REPO_DIR:-$HOME/Colab_Sepedi_TTS}"
DATASET_GCS="gs://${BUCKET_NAME}/datasets/sepedi_tts_dataset.zip"
DATASET_LOCAL="/content/drive/MyDrive/sepedi_tts_dataset.zip"
OUTPUT_LOCAL="/content/drive/MyDrive/Sepedi_Voice_Output"
OUTPUT_GCS="gs://${BUCKET_NAME}/outputs/Sepedi_Voice_Output"

log() {
  echo ""
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

log "System info"
whoami
pwd
uname -a

log "GPU check"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi || true
else
  echo "nvidia-smi not found yet. Install NVIDIA drivers first if GPU is not visible."
fi

log "Install base packages"
sudo apt-get update -y
sudo apt-get install -y \
  git \
  curl \
  unzip \
  build-essential \
  espeak-ng \
  espeak-ng-data \
  python3.10 \
  python3.10-dev \
  python3.10-distutils \
  python3-pip

log "Prepare Colab-compatible paths"
sudo mkdir -p /content/drive/MyDrive
sudo chown -R "$USER:$USER" /content

log "Clone or update repo"
if [ -d "$REPO_DIR/.git" ]; then
  cd "$REPO_DIR"
  git pull
else
  git clone "$REPO_URL" "$REPO_DIR"
  cd "$REPO_DIR"
fi

log "Copy dataset from Cloud Storage"
gcloud storage cp "$DATASET_GCS" "$DATASET_LOCAL" --project "$PROJECT_ID"
ls -lh "$DATASET_LOCAL"

log "Run training pipeline"
python3.10 colab/Sepedi_Piper_TTS_Training.py

log "Upload outputs back to Cloud Storage"
if [ -d "$OUTPUT_LOCAL" ]; then
  gcloud storage cp --recursive "$OUTPUT_LOCAL" "$OUTPUT_GCS" --project "$PROJECT_ID"
  echo "Outputs uploaded to: $OUTPUT_GCS"
else
  echo "Output directory not found yet: $OUTPUT_LOCAL"
fi
