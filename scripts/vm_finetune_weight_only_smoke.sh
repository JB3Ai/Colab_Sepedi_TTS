#!/usr/bin/env bash
set -euo pipefail

PY_ROOT="/content/piper/src/python"
TRAINING_READY="/content/training_ready"
OUTPUT_DIR="/content/drive/MyDrive/Sepedi_Voice_Output_WEIGHT_ONLY"
CKPT_DIR="/content/pretrained_piper_checkpoints"
CKPT="$CKPT_DIR/lessac_medium.ckpt"
CKPT_URL="https://huggingface.co/datasets/rhasspy/piper-checkpoints/resolve/main/en/en_US/lessac/medium/epoch%3D2164-step%3D1355540.ckpt"
SAFE_PYTHONPATH="$PY_ROOT:${PYTHONPATH:-}"
SMOKE_LOG="/tmp/sepedi_weight_only_smoke.log"

log() {
  echo ""
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

log "GPU check"
nvidia-smi

log "Ensure checkpoint exists"
mkdir -p "$CKPT_DIR"
if [ ! -f "$CKPT" ]; then
  wget -O "$CKPT" "$CKPT_URL"
fi
ls -lh "$CKPT"

log "Verify training_ready exists"
test -f "$TRAINING_READY/config.json"
test -f "$TRAINING_READY/dataset.jsonl"

log "Patch Piper for single-speaker weight-only loading"
python3.10 - <<'PY'
from pathlib import Path
import re

main_path = Path('/content/piper/src/python/piper_train/__main__.py')
text = main_path.read_text()
backup = main_path.with_suffix('.py.backup_before_weight_only_patch')
if not backup.exists():
    backup.write_text(text)

text = re.sub(
    r'\n\s*assert \(\n\s*num_speakers > 1\n\s*\), "--resume_from_single_speaker_checkpoint is only for multi-speaker models\. Use --resume_from_checkpoint for single-speaker models\."\n',
    '\n        # JB3 patch: allow single-speaker target to load checkpoint weights only.\n',
    text,
)
main_path.write_text(text)
print('Patched:', main_path)

lightning_path = Path('/content/piper/src/python/piper_train/vits/lightning.py')
lt = lightning_path.read_text()
lt = re.sub(r'learning_rate:\s*float\s*=\s*[0-9.eE+-]+', 'learning_rate: float = 1e-6', lt)
lightning_path.write_text(lt)
for line in lt.splitlines():
    if 'learning_rate:' in line:
        print(line)
PY

log "Run 50-step weight-only fine-tune smoke test"
rm -rf "$OUTPUT_DIR/lightning_logs"
mkdir -p "$OUTPUT_DIR"
set +e
PYTHONPATH="$SAFE_PYTHONPATH" python3.10 -m piper_train \
  --dataset-dir "$TRAINING_READY" \
  --accelerator gpu \
  --devices 1 \
  --batch-size 1 \
  --validation-split 0.0 \
  --num-test-examples 0 \
  --num_sanity_val_steps 0 \
  --gradient_clip_val 0.005 \
  --gradient_clip_algorithm norm \
  --max-phoneme-ids 160 \
  --max_steps 50 \
  --resume_from_single_speaker_checkpoint "$CKPT" \
  --default_root_dir "$OUTPUT_DIR" 2>&1 | tee "$SMOKE_LOG"
train_exit=${PIPESTATUS[0]}
set -e

if [ "$train_exit" -ne 0 ]; then
  echo "Weight-only smoke command failed with exit code $train_exit"
  echo "Log: $SMOKE_LOG"
  exit "$train_exit"
fi

if grep -qiE 'loss=nan|loss=[^ ,]*nan|loss=[^ ,]*inf|\bnan\b.*loss|\binf\b.*loss' "$SMOKE_LOG"; then
  echo "Weight-only smoke still shows NaN/Inf loss. Do not run long fine-tuning yet."
  echo "Log: $SMOKE_LOG"
  exit 2
fi

log "Weight-only smoke test passed without detected NaN/Inf loss"
echo "Long weight-only fine-tune command:"
echo "PYTHONPATH=$SAFE_PYTHONPATH python3.10 -m piper_train --dataset-dir $TRAINING_READY --accelerator gpu --devices 1 --batch-size 1 --validation-split 0.0 --num-test-examples 0 --num_sanity_val_steps 0 --gradient_clip_val 0.005 --gradient_clip_algorithm norm --max-phoneme-ids 160 --max_epochs 1000 --resume_from_single_speaker_checkpoint $CKPT --checkpoint-epochs 1 --default_root_dir $OUTPUT_DIR"
