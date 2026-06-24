# Google Cloud Setup for Sepedi Piper TTS

Project details:

```text
Project name: sepedilearn
Project ID: seped-500410
Project number: 1041951369397
```

This guide moves training away from Colab when Colab GPU availability or credits become a blocker.

## Recommended architecture

```text
GitHub repo
  ↓ clone
Compute Engine GPU VM
  ↓ reads/writes
Cloud Storage bucket
  ├── dataset zip
  ├── preprocessed training_ready output
  └── checkpoints / exported models
```

## APIs to enable

Minimum:

```bash
gcloud services enable \
  serviceusage.googleapis.com \
  compute.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com
```

Recommended cost controls:

```bash
gcloud services enable \
  billingbudgets.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com
```

Optional later, if moving to managed ML / Docker jobs:

```bash
gcloud services enable \
  aiplatform.googleapis.com \
  notebooks.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com
```

## One-time Cloud Shell setup

Open Google Cloud Shell and run:

```bash
gcloud config set project seped-500410

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
```

## Create a storage bucket

Bucket names are globally unique. If this name is taken, add a suffix.

```bash
export PROJECT_ID=seped-500410
export REGION=europe-west1
export BUCKET=gs://seped-500410-sepedi-tts

gcloud storage buckets create $BUCKET \
  --project=$PROJECT_ID \
  --location=$REGION \
  --uniform-bucket-level-access
```

Upload dataset:

```bash
gcloud storage cp /path/to/sepedi_tts_dataset.zip $BUCKET/datasets/sepedi_tts_dataset.zip
```

If using Cloud Shell upload UI, upload the zip to Cloud Shell first, then run the copy command.

## Create a GPU VM

Start with a low-risk T4 VM:

```bash
export PROJECT_ID=seped-500410
export ZONE=europe-west4-a
export VM_NAME=sepedi-tts-t4

gcloud compute instances create $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --machine-type=n1-standard-4 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --maintenance-policy=TERMINATE \
  --boot-disk-size=150GB \
  --boot-disk-type=pd-balanced \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --scopes=https://www.googleapis.com/auth/cloud-platform
```

If this fails with quota or zone errors:

- Try another zone.
- Request GPU quota for NVIDIA T4 in the selected region.
- Consider Vertex AI Workbench later if VM management becomes too manual.

## SSH into the VM

```bash
gcloud compute ssh sepedi-tts-t4 --zone=europe-west4-a
```

## VM setup commands

Inside the VM:

```bash
sudo apt-get update -y
sudo apt-get install -y git curl unzip python3.10 python3.10-dev python3.10-distutils build-essential espeak-ng espeak-ng-data

curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
python3.10 /tmp/get-pip.py
python3.10 -m pip install "pip<24.1" --force-reinstall
```

Install NVIDIA drivers. On many Google GPU VM images, the simplest route is:

```bash
sudo apt-get install -y ubuntu-drivers-common
sudo ubuntu-drivers autoinstall
sudo reboot
```

After reboot:

```bash
nvidia-smi
```

## Clone repo and run pipeline

```bash
cd ~
git clone https://github.com/JB3Ai/Colab_Sepedi_TTS.git
cd Colab_Sepedi_TTS
```

Copy the dataset from Cloud Storage:

```bash
mkdir -p /content/drive/MyDrive
mkdir -p /content

gcloud storage cp gs://seped-500410-sepedi-tts/datasets/sepedi_tts_dataset.zip /content/drive/MyDrive/sepedi_tts_dataset.zip
```

Then run:

```bash
python3.10 colab/Sepedi_Piper_TTS_Training.py
```

The script still uses `/content/...` paths to remain compatible with Colab. On the VM, those folders are created locally.

## Save outputs back to Cloud Storage

After training or smoke test:

```bash
gcloud storage cp --recursive /content/drive/MyDrive/Sepedi_Voice_Output gs://seped-500410-sepedi-tts/outputs/Sepedi_Voice_Output
```

## Cost safety

Always stop the GPU VM when not training:

```bash
gcloud compute instances stop sepedi-tts-t4 --zone=europe-west4-a
```

Delete the VM when finished:

```bash
gcloud compute instances delete sepedi-tts-t4 --zone=europe-west4-a
```

Keep the bucket and checkpoints if you still need the training artifacts.

## Next upgrade path

Once the manual GPU VM flow works, the next clean upgrade is:

1. Dockerize the training pipeline.
2. Push image to Artifact Registry.
3. Launch training using Vertex AI Custom Training.
4. Store checkpoints and ONNX export in Cloud Storage.

That is the more professional production version, but the Compute Engine GPU VM is the fastest bridge from Colab to Google Cloud billing.
