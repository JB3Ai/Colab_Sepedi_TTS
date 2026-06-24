# GPU Quota Request Guide

The project is ready for GPU training, but GPU VM creation is blocked by quota.

Observed error:

```text
Quota 'GPUS_ALL_REGIONS' exceeded. Limit: 0.0 globally.
metric name = compute.googleapis.com/gpus_all_regions
limit name = GPUS-ALL-REGIONS-per-project
limit = 0.0
dimensions = global: global
```

This means the Google Cloud project currently has zero GPU quota. No GPU VM can be created until quota is approved.

## Project

```text
Project name: sepedilearn
Project ID: seped-500410
Project number: 1041951369397
```

## Recommended quota request

Minimum request:

```text
GPUS_ALL_REGIONS: 1
NVIDIA_T4_GPUS in one region: 1
```

Recommended target region:

```text
europe-west4
```

Backup regions:

```text
europe-west1
us-central1
us-west1
```

Alternative modern GPU request:

```text
GPUS_ALL_REGIONS: 1
NVIDIA_L4_GPUS in one region: 1
```

## Suggested business justification

```text
We are training a small single-speaker Sepedi/Northern Sotho text-to-speech model for educational language technology research and development. The training dataset is approximately 663 utterances and requires one GPU for short-duration model training and testing. We are requesting quota for one GPU only, with pay-as-you-go billing enabled, and will stop or delete the VM when training is complete.
```

## Before requesting quota

Run:

```powershell
.\scripts\gcp_check_gpu_quota.ps1
```

This will print current global and regional GPU quota indicators.

## After quota is approved

Run:

```powershell
.\scripts\gcp_create_gpu_vm_fallback.ps1
```

or the direct T4 script:

```powershell
.\scripts\gcp_create_t4_vm_auto.ps1
```

## Cost safety

Stop the VM when not training:

```powershell
gcloud compute instances stop sepedi-tts-gpu --zone <ZONE> --project seped-500410
```

Delete it when finished:

```powershell
gcloud compute instances delete sepedi-tts-gpu --zone <ZONE> --project seped-500410
```
