# Sepedi Piper TTS Colab Pipeline

Clean Colab training pipeline for a Sepedi/Northern Sotho Piper TTS voice model.

This repo exists to stop the repeated fragile setup loop and preserve a working path:

1. Prepare Python 3.10 and pip.
2. Install the full audio/ML dependency stack in one consolidated pass.
3. Verify CUDA/GPU before training.
4. Clone or reuse Piper without repeatedly deleting patches.
5. Create a top-level `monotonic_align` fallback package.
6. Preprocess the 663-utterance Sepedi dataset using the Setswana (`tn`) proxy.
7. Run a 50-step smoke test before launching long training.

## Current known blockers solved

- `ModuleNotFoundError: No module named 'monotonic_align'`
- Missing `config.json` after preprocessing
- Missing `msgpack`, `pooch`, `decorator`, `scipy`, `numba`, and related audio dependencies
- TensorBoard `add_audio` logger issue
- Fragile external install of `rhasspy/monotonic-align`

## Important operating rules

Do not use the old broken cycle:

```bash
rm -rf piper
rm -rf piper_train/vits/monotonic_align
python3.10 -m pip install git+https://github.com/rhasspy/monotonic-align.git@vits-lightning-2
```

That flow failed because the external GitHub install could not complete, leaving Piper without any usable `monotonic_align` module.

Use the fallback built into this repo instead.

## Colab file

Open:

```text
colab/Sepedi_Piper_TTS_Training.ipynb
```

or copy the script version:

```text
colab/Sepedi_Piper_TTS_Training.py
```

## Required Colab runtime

Before running the notebook:

```text
Runtime → Change runtime type → Hardware accelerator → T4 GPU
```

The pipeline intentionally stops if Python 3.10 cannot see CUDA. Do not continue training until this check passes:

```text
CUDA available: True
GPU: Tesla T4
```

## Dataset expectation

The notebook expects:

```text
/content/drive/MyDrive/sepedi_tts_dataset.zip
```

which should unzip to:

```text
/content/sepedi_tts_dataset/
```

Expected dataset format:

```text
metadata.csv
wavs/*.wav
```

## Training strategy

The first run is intentionally conservative:

```text
batch-size: 1
validation-split: 0.0
num-test-examples: 0
gradient-clip: 0.1
max-steps: 50
```

Only after the 50-step smoke test passes should the long training run be started.

## Strategic note

Training VITS from scratch on 663 utterances is fragile. The clean long-term path is to fine-tune from an existing Piper checkpoint, then export to ONNX.
