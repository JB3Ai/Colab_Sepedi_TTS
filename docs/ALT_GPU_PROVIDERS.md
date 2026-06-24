# Alternate GPU Providers for Sepedi Piper TTS

Google Cloud project setup is complete, but GPU training is blocked by quota:

```text
GPUS_ALL_REGIONS limit = 0.0
```

Until Google approves GPU quota, use an external GPU provider.

## Recommended order

### 1. RunPod — fastest practical route

Use this first if the goal is to get training running quickly.

Recommended GPU choices:

```text
RTX A5000 24GB
RTX 3090 24GB
RTX 4090 24GB
L4 24GB
A40 48GB
A6000 48GB
```

Minimum practical VRAM:

```text
16GB+
```

Safer target:

```text
24GB+
```

Suggested RunPod template:

```text
PyTorch 2.x / CUDA / Ubuntu
```

Workflow:

```bash
git clone https://github.com/JB3Ai/Colab_Sepedi_TTS.git
cd Colab_Sepedi_TTS
```

Upload or download the dataset zip, then run/adapt:

```bash
python3.10 colab/Sepedi_Piper_TTS_Training.py
```

The script currently expects Colab-style paths:

```text
/content/drive/MyDrive/sepedi_tts_dataset.zip
/content/drive/MyDrive/Sepedi_Voice_Output
```

On RunPod, either create those paths manually or adapt the script to use local paths.

## 2. Lambda Cloud — cleaner ML VM experience

Lambda is good if you want a more traditional ML VM with PyTorch/CUDA already installed.

Recommended GPU:

```text
1x A10 24GB
1x RTX 6000 24GB
1x A6000 48GB
```

This may cost more than RunPod but is usually less fiddly than marketplace GPUs.

## 3. Vast.ai — cheapest but more variable

Good when budget matters. Pick verified/data-center hosts where possible.

Recommended filters:

```text
GPU: RTX 3090 / RTX 4090 / A5000 / A6000 / A40 / L4
VRAM: 24GB+
Disk: 80GB+
CUDA image: PyTorch / Ubuntu
Reliability: high
```

Use checkpoints frequently because interruptible/marketplace machines can disappear.

## 4. Modal — later automation/serverless route

Modal is powerful for packaging the training as a reproducible job, but it requires adapting the repo into a Modal app.

Best later after the training command is stable.

## Current best call

Use RunPod first.

Target:

```text
RTX A5000 24GB or RTX 3090/4090 24GB
```

Run the 50-step smoke test first. If it passes, launch long training.

## Keep GCP alive

Still request GCP quota:

```text
GPUS_ALL_REGIONS = 1
NVIDIA_T4_GPUS = 1 or NVIDIA_L4_GPUS = 1
```

Once quota is approved, the existing GCP scripts can be reused.
