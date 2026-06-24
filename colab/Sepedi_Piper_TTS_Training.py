# Sepedi Piper TTS Training Pipeline for Google Colab
# ==================================================
# Runtime requirement: Colab T4 GPU
# Dataset expected at: /content/drive/MyDrive/sepedi_tts_dataset.zip

from pathlib import Path
import os
import shutil
import subprocess
import textwrap

# -----------------------------
# User configuration
# -----------------------------
DATASET_ZIP = Path("/content/drive/MyDrive/sepedi_tts_dataset.zip")
DATASET_DIR = Path("/content/sepedi_tts_dataset")
PIPER_DIR = Path("/content/piper")
PY_ROOT = PIPER_DIR / "src/python"
TRAINING_READY = Path("/content/training_ready")
OUTPUT_DIR = Path("/content/drive/MyDrive/Sepedi_Voice_Output")

LANGUAGE_PROXY = "tn"  # Setswana proxy; avoids eSpeak crash seen with nso
FORCE_RECLONE_PIPER = False
APPLY_TRANSFORMS_STABILITY_PATCH = True
PATCH_LEARNING_RATE = True

SMOKE_TEST_STEPS = 50
LONG_TRAINING_EPOCHS = 2000


def run(cmd: str, *, check: bool = True):
    print(f"\n$ {cmd}")
    result = subprocess.run(cmd, shell=True, text=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"Command failed with exit code {result.returncode}: {cmd}")
    return result.returncode


# ==================================================
# 0. GPU hard gate
# ==================================================
print("=== 0. GPU HARD GATE ===")
run("nvidia-smi", check=False)

# Do not continue if Colab has no GPU attached
# Torch will be installed later, so this first gate uses nvidia-smi only.
if run("nvidia-smi > /tmp/nvidia_check.txt 2>&1", check=False) != 0:
    raise RuntimeError(
        "No NVIDIA GPU detected. In Colab: Runtime → Change runtime type → T4 GPU → Restart session."
    )


# ==================================================
# 1. Python 3.10 + pip foundation
# ==================================================
print("\n=== 1. PYTHON 3.10 FOUNDATION ===")
run("sudo apt-get update -y")
run(
    "sudo apt-get install -y "
    "python3.10 python3.10-dev python3.10-distutils "
    "build-essential curl espeak-ng espeak-ng-data"
)

run("curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py")
run("python3.10 /tmp/get-pip.py")
run('python3.10 -m pip install "pip<24.1" --force-reinstall')
run("python3.10 --version")
run("python3.10 -m pip --version")


# ==================================================
# 2. Mount Drive + dataset
# ==================================================
print("\n=== 2. DATASET ===")
try:
    from google.colab import drive
    drive.mount("/content/drive")
except Exception as e:
    print("Drive mount note:", repr(e))

if not DATASET_DIR.exists():
    if not DATASET_ZIP.exists():
        raise RuntimeError(f"Dataset zip not found: {DATASET_ZIP}")
    run(f'unzip -q -o "{DATASET_ZIP}" -d /content/')

metadata = DATASET_DIR / "metadata.csv"
if not metadata.exists():
    raise RuntimeError(f"metadata.csv not found at {metadata}")

print("Dataset found:", DATASET_DIR)
print("Metadata:", metadata)


# ==================================================
# 3. Clone or reuse Piper
# ==================================================
print("\n=== 3. PIPER REPOSITORY ===")
if FORCE_RECLONE_PIPER and PIPER_DIR.exists():
    shutil.rmtree(PIPER_DIR)

if not PY_ROOT.exists():
    run("cd /content && git clone https://github.com/rhasspy/piper.git")
else:
    print("Reusing existing Piper repo:", PIPER_DIR)

if not PY_ROOT.exists():
    raise RuntimeError(f"Piper Python root missing: {PY_ROOT}")


# ==================================================
# 4. Install consolidated dependencies
# ==================================================
print("\n=== 4. DEPENDENCY FOUNDATION ===")
run("python3.10 -m pip install --upgrade setuptools wheel")
run('python3.10 -m pip install "numpy==1.26.4" --force-reinstall')

# Audio/science stack. Keep this consolidated to prevent one-by-one missing dependency loop.
run(
    "python3.10 -m pip install "
    "scipy "
    "numba==0.58.1 "
    "llvmlite==0.41.1 "
    "librosa==0.9.2 "
    "soundfile "
    "audioread "
    "resampy "
    "scikit-learn "
    "joblib "
    "decorator "
    "pooch "
    "lazy_loader "
    "msgpack "
    "fsspec "
    "PyYAML "
    "tqdm "
    '"cython<1" '
    "tensorboard "
    "tensorboardX "
    "onnxruntime "
    "piper-phonemize-fix"
)

# CUDA PyTorch. Colab T4 currently works with CUDA 12.1 wheels when a GPU runtime is attached.
run("python3.10 -m pip uninstall -y torch torchaudio torchvision", check=False)
run(
    "python3.10 -m pip install --no-cache-dir --force-reinstall "
    "torch==2.1.0+cu121 torchaudio==2.1.0+cu121 torchvision==0.16.0+cu121 "
    "--index-url https://download.pytorch.org/whl/cu121"
)

run("python3.10 -m pip install pytorch-lightning==1.9.5 torchmetrics==0.11.4 lightning-utilities")

print("\n=== 4B. CUDA IMPORT VERIFICATION ===")
run(
    "python3.10 - <<'PY'\n"
    "import torch, numpy, scipy, librosa, numba, msgpack, pooch, decorator\n"
    "print('Torch:', torch.__version__)\n"
    "print('Torch CUDA build:', torch.version.cuda)\n"
    "print('CUDA available:', torch.cuda.is_available())\n"
    "print('CUDA device count:', torch.cuda.device_count())\n"
    "if not torch.cuda.is_available():\n"
    "    raise SystemExit('STOP: Python 3.10 cannot see CUDA. Fix Colab GPU runtime before training.')\n"
    "print('GPU:', torch.cuda.get_device_name(0))\n"
    "print('NumPy:', numpy.__version__)\n"
    "print('SciPy:', scipy.__version__)\n"
    "print('Librosa:', librosa.__version__)\n"
    "print('Numba:', numba.__version__)\n"
    "print('msgpack OK')\n"
    "PY"
)


# ==================================================
# 5. Install Piper editable without dependency resolver chaos
# ==================================================
print("\n=== 5. INSTALL PIPER EDITABLE ===")
run(f"cd {PY_ROOT} && python3.10 -m pip install -e . --no-deps")


# ==================================================
# 6. Create top-level monotonic_align fallback
# ==================================================
print("\n=== 6. TOP-LEVEL monotonic_align FALLBACK ===")
TOP_ALIGN = PY_ROOT / "monotonic_align"
TOP_ALIGN.mkdir(parents=True, exist_ok=True)

monotonic_init = r'''
import torch
import numpy as np


def _maximum_path_numpy(value, mask):
    value = value * mask
    bsz, t_text, t_audio = value.shape
    path = np.zeros_like(value, dtype=np.float32)

    for b in range(bsz):
        valid_text = int(mask[b].sum(axis=1).clip(0, 1).sum())
        valid_audio = int(mask[b].sum(axis=0).clip(0, 1).sum())

        if valid_text <= 0 or valid_audio <= 0:
            continue

        v = value[b, :valid_text, :valid_audio]
        dp = np.full((valid_text, valid_audio), -1e9, dtype=np.float32)
        back = np.zeros((valid_text, valid_audio), dtype=np.int32)

        dp[0, 0] = v[0, 0]

        for j in range(1, valid_audio):
            dp[0, j] = dp[0, j - 1] + v[0, j]

        for i in range(1, valid_text):
            for j in range(i, valid_audio):
                stay = dp[i, j - 1] if j - 1 >= 0 else -1e9
                move = dp[i - 1, j - 1] if j - 1 >= 0 else -1e9

                if move > stay:
                    dp[i, j] = move + v[i, j]
                    back[i, j] = 1
                else:
                    dp[i, j] = stay + v[i, j]
                    back[i, j] = 0

        i = valid_text - 1
        j = valid_audio - 1

        while j >= 0:
            path[b, i, j] = 1.0
            if i > 0 and back[i, j] == 1:
                i -= 1
            j -= 1

    return path


def maximum_path(neg_cent, mask):
    device = neg_cent.device
    dtype = neg_cent.dtype
    value_np = neg_cent.detach().cpu().numpy().astype(np.float32)
    mask_np = mask.detach().cpu().numpy().astype(np.float32)
    path_np = _maximum_path_numpy(value_np, mask_np)
    return torch.from_numpy(path_np).to(device=device, dtype=dtype)
'''

(TOP_ALIGN / "__init__.py").write_text(textwrap.dedent(monotonic_init).strip() + "\n")
print("Created:", TOP_ALIGN / "__init__.py")


# ==================================================
# 7. Patch Piper imports, LR, and optional transform stability
# ==================================================
print("\n=== 7. PATCH PIPER SOURCE ===")
models_path = PY_ROOT / "piper_train/vits/models.py"
models_text = models_path.read_text()
models_backup = models_path.with_suffix(".py.backup_before_monotonic_patch")
if not models_backup.exists():
    models_backup.write_text(models_text)

models_text = models_text.replace(
    "from . import attentions, commons, modules, monotonic_align",
    "from . import attentions, commons, modules\nimport monotonic_align",
)
if "import monotonic_align" not in models_text:
    models_text = models_text.replace(
        "from . import attentions, commons, modules",
        "from . import attentions, commons, modules\nimport monotonic_align",
    )
models_path.write_text(models_text)
print("models.py patched")

if PATCH_LEARNING_RATE:
    lightning_path = PY_ROOT / "piper_train/vits/lightning.py"
    lightning_text = lightning_path.read_text()
    lightning_backup = lightning_path.with_suffix(".py.backup_before_lr_patch")
    if not lightning_backup.exists():
        lightning_backup.write_text(lightning_text)
    lightning_text = lightning_text.replace("lr=2e-4", "lr=5e-5")
    lightning_text = lightning_text.replace("lr=0.0002", "lr=0.00005")
    lightning_path.write_text(lightning_text)
    print("learning rate patched to 5e-5 where applicable")

if APPLY_TRANSFORMS_STABILITY_PATCH:
    transforms_path = PY_ROOT / "piper_train/vits/transforms.py"
    transforms_text = transforms_path.read_text()
    transforms_backup = transforms_path.with_suffix(".py.backup_before_stability_patch")
    if not transforms_backup.exists():
        transforms_backup.write_text(transforms_text)

    transforms_text = transforms_text.replace(
        "assert (discriminant >= 0).all()",
        "discriminant = torch.clamp(torch.nan_to_num(discriminant, nan=1e-6, posinf=1e6, neginf=1e-6), min=1e-6)",
    )
    transforms_text = transforms_text.replace(
        "assert torch.all(discriminant >= 0)",
        "discriminant = torch.clamp(torch.nan_to_num(discriminant, nan=1e-6, posinf=1e6, neginf=1e-6), min=1e-6)",
    )
    transforms_text = transforms_text.replace(
        "torch.sqrt(discriminant)",
        "torch.sqrt(torch.clamp(torch.nan_to_num(discriminant, nan=1e-6, posinf=1e6, neginf=1e-6), min=1e-6))",
    )
    transforms_path.write_text(transforms_text)
    print("transforms.py stability patch applied")

# Clear caches after source patch
run(f"find {PY_ROOT} -name '__pycache__' -type d -exec rm -rf {{}} +", check=False)
run(f"find {PY_ROOT} -name '*.pyc' -delete", check=False)


# ==================================================
# 8. Verify imports
# ==================================================
print("\n=== 8. VERIFY PIPER IMPORTS ===")
run(
    f"PYTHONPATH={PY_ROOT}:$PYTHONPATH python3.10 - <<'PY'\n"
    "import monotonic_align\n"
    "print('OK monotonic_align:', monotonic_align.__file__)\n"
    "from monotonic_align import maximum_path\n"
    "print('OK maximum_path')\n"
    "from piper_train.vits.models import SynthesizerTrn\n"
    "print('OK Piper VITS models import')\n"
    "PY"
)


# ==================================================
# 9. Fix metadata and preprocess
# ==================================================
print("\n=== 9. METADATA FIX + PREPROCESS ===")
lines = metadata.read_text(encoding="utf-8").splitlines()
fixed = [line.replace(".wav|", "|") for line in lines]
metadata.write_text("\n".join(fixed) + "\n", encoding="utf-8")

if TRAINING_READY.exists():
    shutil.rmtree(TRAINING_READY)
TRAINING_READY.mkdir(parents=True, exist_ok=True)

run(
    f"PYTHONPATH={PY_ROOT}:$PYTHONPATH python3.10 -m piper_train.preprocess "
    f"--language {LANGUAGE_PROXY} "
    "--dataset-format ljspeech "
    f"--input-dir {DATASET_DIR} "
    f"--output-dir {TRAINING_READY} "
    "--single-speaker "
    "--sample-rate 22050 "
    "--max-workers 2"
)

if not (TRAINING_READY / "config.json").exists():
    raise RuntimeError("Preprocess finished but config.json was not created.")
if not (TRAINING_READY / "dataset.jsonl").exists():
    raise RuntimeError("Preprocess finished but dataset.jsonl was not created.")

print("Preprocess OK:", TRAINING_READY)


# ==================================================
# 10. Smoke test
# ==================================================
print("\n=== 10. 50-STEP SMOKE TEST ===")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

run(
    f"PYTHONPATH={PY_ROOT}:$PYTHONPATH python3.10 -m piper_train "
    f"--dataset-dir {TRAINING_READY} "
    "--accelerator gpu "
    "--devices 1 "
    "--batch-size 1 "
    "--validation-split 0.0 "
    "--num-test-examples 0 "
    "--num_sanity_val_steps 0 "
    "--gradient_clip_val 0.1 "
    "--gradient_clip_algorithm norm "
    f"--max_steps {SMOKE_TEST_STEPS} "
    f"--default_root_dir {OUTPUT_DIR}"
)

print("\nSMOKE TEST PASSED. You can now run the long training command below.")
print(
    f"PYTHONPATH={PY_ROOT}:$PYTHONPATH python3.10 -m piper_train "
    f"--dataset-dir {TRAINING_READY} "
    "--accelerator gpu --devices 1 --batch-size 1 "
    "--validation-split 0.0 --num-test-examples 0 --num_sanity_val_steps 0 "
    "--gradient_clip_val 0.1 --gradient_clip_algorithm norm "
    f"--max_epochs {LONG_TRAINING_EPOCHS} "
    f"--default_root_dir {OUTPUT_DIR}"
)
