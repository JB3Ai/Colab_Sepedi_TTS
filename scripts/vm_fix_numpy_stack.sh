#!/usr/bin/env bash
set -euo pipefail

CONSTRAINTS="/tmp/sepedi_tts_pip_constraints.txt"

cat > "$CONSTRAINTS" <<'EOF'
numpy==1.26.4
scipy==1.11.4
numba==0.58.1
llvmlite==0.41.1
librosa==0.9.2
scikit-learn==1.3.2
EOF

export PIP_CONSTRAINT="$CONSTRAINTS"

echo "Using constraints:"
cat "$CONSTRAINTS"

python3.10 -m pip install --upgrade "pip<24.1" setuptools wheel
python3.10 -m pip uninstall -y numpy scipy numba llvmlite librosa scikit-learn || true
python3.10 -m pip install --no-cache-dir --force-reinstall \
  "numpy==1.26.4" \
  "scipy==1.11.4" \
  "numba==0.58.1" \
  "llvmlite==0.41.1" \
  "librosa==0.9.2" \
  "scikit-learn==1.3.2"

python3.10 - <<'PY'
import numpy, scipy, numba, librosa
print('NumPy:', numpy.__version__)
print('SciPy:', scipy.__version__)
print('Numba:', numba.__version__)
print('Librosa:', librosa.__version__)
PY

echo "NumPy stack repaired."
echo "Run the training script with:"
echo "PIP_CONSTRAINT=$CONSTRAINTS python3.10 colab/Sepedi_Piper_TTS_Training.py"
