#!/usr/bin/env bash
set -euo pipefail

PY_ROOT="/content/piper/src/python"
DATASET_DIR="/content/sepedi_tts_dataset"
TRAINING_READY="/content/training_ready"
OUTPUT_DIR="/content/drive/MyDrive/Sepedi_Voice_Output"
SMOKE_LOG="/tmp/sepedi_nan_repair_smoke.log"
SAFE_PYTHONPATH="$PY_ROOT:${PYTHONPATH:-}"

log() {
  echo ""
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

log "GPU and Python stack check"
nvidia-smi
python3.10 - <<'PY'
import torch, numpy, scipy, librosa, numba
print('Torch:', torch.__version__)
print('CUDA available:', torch.cuda.is_available())
print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'NONE')
print('NumPy:', numpy.__version__)
print('SciPy:', scipy.__version__)
print('Librosa:', librosa.__version__)
print('Numba:', numba.__version__)
PY

log "Back up raw dataset once"
if [ ! -d /content/sepedi_tts_dataset_raw_backup ]; then
  cp -a "$DATASET_DIR" /content/sepedi_tts_dataset_raw_backup
  echo "Backup created: /content/sepedi_tts_dataset_raw_backup"
else
  echo "Backup already exists: /content/sepedi_tts_dataset_raw_backup"
fi

log "Normalize WAV files to safe peak level"
python3.10 - <<'PY'
from pathlib import Path
import numpy as np
import soundfile as sf

root = Path('/content/sepedi_tts_dataset')
wavs = sorted(root.rglob('*.wav'))
if not wavs:
    raise SystemExit('No WAV files found under /content/sepedi_tts_dataset')

count = 0
max_before = 0.0
for wav in wavs:
    audio, sr = sf.read(wav, always_2d=True, dtype='float32')
    audio = np.nan_to_num(audio, nan=0.0, posinf=0.0, neginf=0.0)
    if audio.shape[1] > 1:
        audio = audio.mean(axis=1, keepdims=True)
    peak = float(np.max(np.abs(audio))) if audio.size else 0.0
    max_before = max(max_before, peak)
    if peak > 0:
        audio = audio / peak * 0.95
    sf.write(wav, audio.squeeze(axis=1), sr, subtype='PCM_16')
    count += 1

print(f'Normalized WAV files: {count}')
print(f'Max peak before normalization: {max_before:.6f}')
PY

log "Patch Piper learning rate lower for NaN recovery"
python3.10 - <<'PY'
from pathlib import Path
p = Path('/content/piper/src/python/piper_train/vits/lightning.py')
text = p.read_text()
for old in ['lr=2e-4', 'lr=0.0002', 'lr=5e-5', 'lr=0.00005', 'lr=1e-5']:
    text = text.replace(old, 'lr=1e-5')
p.write_text(text)
print('Patched learning rate to 1e-5 where matched')
PY

log "Clear previous training_ready and smoke output"
rm -rf "$TRAINING_READY"
mkdir -p "$TRAINING_READY"
mkdir -p "$OUTPUT_DIR"

log "Re-run preprocess"
PYTHONPATH="$SAFE_PYTHONPATH" python3.10 -m piper_train.preprocess \
  --language tn \
  --dataset-format ljspeech \
  --input-dir "$DATASET_DIR" \
  --output-dir "$TRAINING_READY" \
  --single-speaker \
  --sample-rate 22050 \
  --max-workers 2

log "Run NaN-aware 50-step smoke test"
set +e
PYTHONPATH="$SAFE_PYTHONPATH" python3.10 -m piper_train \
  --dataset-dir "$TRAINING_READY" \
  --accelerator gpu \
  --devices 1 \
  --batch-size 1 \
  --validation-split 0.0 \
  --num-test-examples 0 \
  --num_sanity_val_steps 0 \
  --gradient_clip_val 0.05 \
  --gradient_clip_algorithm norm \
  --max_steps 50 \
  --default_root_dir "$OUTPUT_DIR" 2>&1 | tee "$SMOKE_LOG"
train_exit=${PIPESTATUS[0]}
set -e

if [ "$train_exit" -ne 0 ]; then
  echo "Training command failed with exit code $train_exit"
  exit "$train_exit"
fi

if grep -qiE 'loss=nan|\bnan\b|inf' "$SMOKE_LOG"; then
  echo "Smoke test still shows NaN/Inf. Do NOT start long training yet."
  echo "Log: $SMOKE_LOG"
  exit 2
fi

log "Smoke test passed without detected NaN/Inf"
echo "Long training command:"
echo "PYTHONPATH=$SAFE_PYTHONPATH python3.10 -m piper_train --dataset-dir $TRAINING_READY --accelerator gpu --devices 1 --batch-size 1 --validation-split 0.0 --num-test-examples 0 --num_sanity_val_steps 0 --gradient_clip_val 0.05 --gradient_clip_algorithm norm --max_epochs 2000 --default_root_dir $OUTPUT_DIR"
