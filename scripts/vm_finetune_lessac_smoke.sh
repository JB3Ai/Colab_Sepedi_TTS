#!/usr/bin/env bash
set -euo pipefail

PY_ROOT="/content/piper/src/python"
TRAINING_READY="/content/training_ready"
OUTPUT_DIR="/content/drive/MyDrive/Sepedi_Voice_Output_FINETUNE"
CKPT_DIR="/content/pretrained_piper_checkpoints"
CKPT="$CKPT_DIR/lessac_medium.ckpt"
CKPT_URL="https://huggingface.co/datasets/rhasspy/piper-checkpoints/resolve/main/en/en_US/lessac/medium/epoch%3D2164-step%3D1355540.ckpt"
CKPT_BASE_STEP=1355540
SMOKE_STEPS=50
SMOKE_MAX_STEPS=$((CKPT_BASE_STEP + SMOKE_STEPS))
SAFE_PYTHONPATH="$PY_ROOT:${PYTHONPATH:-}"
SMOKE_LOG="/tmp/sepedi_finetune_lessac_smoke.log"

log() {
  echo ""
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

log "GPU check"
nvidia-smi

log "Download Piper Lessac medium checkpoint if missing"
mkdir -p "$CKPT_DIR"
if [ ! -f "$CKPT" ]; then
  wget -O "$CKPT" "$CKPT_URL"
else
  echo "Checkpoint already exists: $CKPT"
fi
ls -lh "$CKPT"

log "Verify training_ready exists"
test -f "$TRAINING_READY/config.json"
test -f "$TRAINING_READY/dataset.jsonl"

log "Patch true Piper learning rate to 1e-6"
python3.10 - <<'PY'
from pathlib import Path
import re
p = Path('/content/piper/src/python/piper_train/vits/lightning.py')
text = p.read_text()
text = re.sub(r'learning_rate:\s*float\s*=\s*[0-9.eE+-]+', 'learning_rate: float = 1e-6', text)
p.write_text(text)
for line in text.splitlines():
    if 'learning_rate:' in line:
        print(line)
PY

log "Run 50-step fine-tune smoke test from checkpoint step $CKPT_BASE_STEP to $SMOKE_MAX_STEPS"
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
  --max_steps "$SMOKE_MAX_STEPS" \
  --resume_from_checkpoint "$CKPT" \
  --default_root_dir "$OUTPUT_DIR" 2>&1 | tee "$SMOKE_LOG"
train_exit=${PIPESTATUS[0]}
set -e

if [ "$train_exit" -ne 0 ]; then
  echo "Fine-tune smoke command failed with exit code $train_exit"
  echo "Log: $SMOKE_LOG"
  exit "$train_exit"
fi

if grep -qiE 'loss=nan|loss=[^ ,]*nan|loss=[^ ,]*inf|\bnan\b.*loss|\binf\b.*loss' "$SMOKE_LOG"; then
  echo "Fine-tune smoke still shows NaN/Inf loss. Do not run long fine-tuning yet."
  echo "Log: $SMOKE_LOG"
  exit 2
fi

log "Fine-tune smoke test passed without detected NaN/Inf loss"
echo "Long fine-tune command:"
echo "PYTHONPATH=$SAFE_PYTHONPATH python3.10 -m piper_train --dataset-dir $TRAINING_READY --accelerator gpu --devices 1 --batch-size 1 --validation-split 0.0 --num-test-examples 0 --num_sanity_val_steps 0 --gradient_clip_val 0.005 --gradient_clip_algorithm norm --max-phoneme-ids 160 --max_steps 1356540 --resume_from_checkpoint $CKPT --checkpoint-epochs 1 --default_root_dir $OUTPUT_DIR"
