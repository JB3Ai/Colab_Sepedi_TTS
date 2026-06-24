#!/usr/bin/env bash
set -euo pipefail

# Install NVIDIA GPU drivers on Ubuntu 22.04/24.04 Google Cloud GPU VMs.
# Uses signed Ubuntu GCP kernel module packages where available.

log() {
  echo ""
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

log "System info"
lsb_release -a || true
uname -a

log "Update apt"
sudo apt-get update -y

log "Find latest Ubuntu/GCP NVIDIA driver package"
NVIDIA_DRIVER_VERSION=$(sudo apt-cache search 'linux-modules-nvidia-[0-9]+-gcp$' \
  | awk '{print $1}' \
  | sort -V \
  | tail -n 1 \
  | awk -F"-" '{print $4}')

if [[ -z "${NVIDIA_DRIVER_VERSION}" ]]; then
  echo "Could not find linux-modules-nvidia-*-gcp package."
  echo "Falling back to ubuntu-drivers autoinstall."
  sudo apt-get install -y ubuntu-drivers-common
  sudo ubuntu-drivers autoinstall
else
  echo "Selected NVIDIA driver version: ${NVIDIA_DRIVER_VERSION}"
  sudo apt-get install -y \
    "linux-modules-nvidia-${NVIDIA_DRIVER_VERSION}-gcp" \
    "nvidia-driver-${NVIDIA_DRIVER_VERSION}"
fi

log "Driver packages installed"
echo "A reboot is required before nvidia-smi will work."
echo "Run: sudo reboot"
