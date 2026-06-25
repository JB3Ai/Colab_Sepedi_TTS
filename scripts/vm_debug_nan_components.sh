#!/usr/bin/env bash
set -euo pipefail

PY_ROOT="/content/piper/src/python"
TRAINING_READY="/content/training_ready"
OUTPUT_DIR="/content/drive/MyDrive/Sepedi_Voice_Output_NAN_DEBUG"
CKPT="/content/pretrained_piper_checkpoints/lessac_medium.ckpt"
SAFE_PYTHONPATH="$PY_ROOT:${PYTHONPATH:-}"
DEBUG_LOG="/tmp/sepedi_nan_component_debug.log"

log() {
  echo ""
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

log "Patch Piper for weight-only checkpoint loading and NaN component debug"
python3.10 - <<'PY'
from pathlib import Path
import re

main_path = Path('/content/piper/src/python/piper_train/__main__.py')
main_text = main_path.read_text()
main_backup = main_path.with_suffix('.py.backup_before_jb3_debug_patch')
if not main_backup.exists():
    main_backup.write_text(main_text)

main_text = re.sub(
    r'\n\s*assert \(\n\s*num_speakers > 1\n\s*\), "--resume_from_single_speaker_checkpoint is only for multi-speaker models\. Use --resume_from_checkpoint for single-speaker models\."\n',
    '\n        # JB3 patch: allow single-speaker target to load checkpoint weights only.\n',
    main_text,
)
main_path.write_text(main_text)

lightning_path = Path('/content/piper/src/python/piper_train/vits/lightning.py')
text = lightning_path.read_text()
lightning_backup = lightning_path.with_suffix('.py.backup_before_jb3_debug_patch')
if not lightning_backup.exists():
    lightning_backup.write_text(text)

# Force ultra-low LR.
text = re.sub(r'learning_rate:\s*float\s*=\s*[0-9.eE+-]+', 'learning_rate: float = 1e-6', text)

# Inject tensor debug after generator forward.
needle_forward = '        self._y_hat = y_hat\n\n        mel = spec_to_mel_torch('
insert_forward = '''        self._y_hat = y_hat

        # JB3_NAN_DEBUG: inspect tensors immediately after generator forward.
        def _jb3_tensor(name, value):
            try:
                finite = bool(torch.isfinite(value).all().detach().cpu())
                v = value.detach().float()
                print(
                    f"JB3_NAN_DEBUG {name}: finite={finite} "
                    f"shape={tuple(value.shape)} "
                    f"min={float(torch.nan_to_num(v).min().cpu()):.6f} "
                    f"max={float(torch.nan_to_num(v).max().cpu()):.6f} "
                    f"mean={float(torch.nan_to_num(v).mean().cpu()):.6f}",
                    flush=True,
                )
            except Exception as exc:
                print(f"JB3_NAN_DEBUG {name}: debug_error={type(exc).__name__}:{exc}", flush=True)

        _jb3_tensor("y_hat", y_hat)
        _jb3_tensor("l_length", l_length)
        _jb3_tensor("z_p", z_p)
        _jb3_tensor("m_p", m_p)
        _jb3_tensor("logs_p", logs_p)
        _jb3_tensor("logs_q", logs_q)

        mel = spec_to_mel_torch('''
if 'JB3_NAN_DEBUG: inspect tensors immediately after generator forward' not in text:
    text = text.replace(needle_forward, insert_forward)

# Inject component loss debug before generator return.
needle_loss = '''            loss_gen_all = loss_gen + loss_fm + loss_mel + loss_dur + loss_kl

            self.log("loss_gen_all", loss_gen_all)

            return loss_gen_all
'''
insert_loss = '''            loss_gen_all = loss_gen + loss_fm + loss_mel + loss_dur + loss_kl

            # JB3_NAN_DEBUG: print loss components before Lightning progress bar.
            def _jb3_loss(name, value):
                try:
                    finite = bool(torch.isfinite(value).all().detach().cpu())
                    scalar = float(value.detach().float().mean().cpu())
                    print(f"JB3_NAN_DEBUG {name}: finite={finite} value={scalar:.6f}", flush=True)
                except Exception as exc:
                    print(f"JB3_NAN_DEBUG {name}: debug_error={type(exc).__name__}:{exc}", flush=True)

            _jb3_loss("loss_dur", loss_dur)
            _jb3_loss("loss_mel", loss_mel)
            _jb3_loss("loss_kl", loss_kl)
            _jb3_loss("loss_fm", loss_fm)
            _jb3_loss("loss_gen", loss_gen)
            _jb3_loss("loss_gen_all", loss_gen_all)

            if not torch.isfinite(loss_gen_all).all():
                raise RuntimeError("JB3_NAN_DEBUG generator loss is not finite")

            self.log("loss_gen_all", loss_gen_all)

            return loss_gen_all
'''
if 'JB3_NAN_DEBUG: print loss components before Lightning progress bar' not in text:
    text = text.replace(needle_loss, insert_loss)

# Inject discriminator debug.
needle_disc = '''            loss_disc_all = loss_disc

            self.log("loss_disc_all", loss_disc_all)

            return loss_disc_all
'''
insert_disc = '''            loss_disc_all = loss_disc

            # JB3_NAN_DEBUG: print discriminator loss.
            try:
                finite = bool(torch.isfinite(loss_disc_all).all().detach().cpu())
                scalar = float(loss_disc_all.detach().float().mean().cpu())
                print(f"JB3_NAN_DEBUG loss_disc_all: finite={finite} value={scalar:.6f}", flush=True)
            except Exception as exc:
                print(f"JB3_NAN_DEBUG loss_disc_all: debug_error={type(exc).__name__}:{exc}", flush=True)

            if not torch.isfinite(loss_disc_all).all():
                raise RuntimeError("JB3_NAN_DEBUG discriminator loss is not finite")

            self.log("loss_disc_all", loss_disc_all)

            return loss_disc_all
'''
if 'JB3_NAN_DEBUG: print discriminator loss' not in text:
    text = text.replace(needle_disc, insert_disc)

lightning_path.write_text(text)
print('Patched:', main_path)
print('Patched:', lightning_path)
for line in text.splitlines():
    if 'learning_rate:' in line:
        print(line)
PY

log "Run NaN component diagnostic"
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
  --max_steps 2 \
  --resume_from_single_speaker_checkpoint "$CKPT" \
  --default_root_dir "$OUTPUT_DIR" 2>&1 | tee "$DEBUG_LOG"
train_exit=${PIPESTATUS[0]}
set -e

echo ""
echo "Diagnostic exit code: $train_exit"
echo "Debug log: $DEBUG_LOG"
echo ""
echo "Important JB3_NAN_DEBUG lines:"
grep 'JB3_NAN_DEBUG' "$DEBUG_LOG" || true

exit "$train_exit"
