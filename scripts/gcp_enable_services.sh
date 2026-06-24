#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-seped-500410}"

echo "Using project: ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}"

echo "Enabling core services..."
gcloud services enable \
  serviceusage.googleapis.com \
  compute.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  billingbudgets.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com

echo "Optional managed ML services. Uncomment if needed:"
echo "gcloud services enable aiplatform.googleapis.com notebooks.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com"

echo "Done."
