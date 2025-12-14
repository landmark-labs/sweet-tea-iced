#!/usr/bin/env bash
set -e

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --index-url) INDEX_URL="$2"; shift ;;
        --comfyui-commit) COMFYUI_COMMIT="$2"; shift ;;
        --civitai-downloader-version) CIVITAI_DOWNLOADER_VERSION="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

echo "Installing ComfyUI to local disk..."
echo "Target Commit: ${COMFYUI_COMMIT:-Latest}"

# Clone to LOCAL disk
git clone https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI
cd /opt/ComfyUI

if [ -n "${COMFYUI_COMMIT}" ] && [ "${COMFYUI_COMMIT}" != "master" ]; then
  echo "Checking out commit: ${COMFYUI_COMMIT}"
  git checkout "${COMFYUI_COMMIT}"
else
  echo "Using latest default branch."
fi

# Create and activate venv
python3.12 -m venv venv
source venv/bin/activate

PYBIN="$(command -v python)"
echo "Using Python: ${PYBIN}"

"${PYBIN}" -m pip install --upgrade pip wheel setuptools

# Install PyTorch
echo "Installing PyTorch..."
pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128

# Install Triton build deps
echo "Installing Triton dependencies..."
pip3 install --no-cache-dir packaging ninja

# Install Triton
echo "Installing Triton..."
export TRITON_PTXAS_PATH=/usr/local/cuda/bin/ptxas
export CUDA_HOME=/usr/local/cuda
pip3 install --no-cache-dir "triton>=3.4,<3.5"

# Return to main dir
cd /opt/ComfyUI

# Verify installation
echo "Verifying PyTorch and Triton..."
python3 -c "
import torch
import triton
print('✅ PyTorch and Triton installed.')
print(f'   Triton Version: {triton.__version__}')
"

# Install requirements
pip3 install --upgrade pip wheel setuptools
pip3 install -r requirements.txt
pip3 install accelerate
pip3 install setuptools --upgrade
pip3 install matplotlib webcolors scikit-image opencv-contrib-python mediapipe imageio-ffmpeg

# Install custom node dependencies
pip3 install \
  deepdiff \
  gguf \
  torchdiffeq \
  PyWavelets \
  scikit-learn \
  blend-modes \
  litelama \
  google-genai \
  POT \
  rembg \
  ftfy \
  onnxruntime \
  pyyaml \
  diffusers \
  opencv-python \
  piexif \
  numba \
  watchdog \
  pillow-simd \
  pyOpenSSL \
  timm \
  open_clip_torch \
  opencv-python-headless \
  fvcore \
  iopath \
  portalocker \
  tabulate \
  termcolor \
  yacs \
  yapf \
  addict \
  lxml \
  embreex \
  manifold3d \
  mapbox-earcut \
  pycollada \
  rtree \
  shapely \
  svg-path \
  trimesh \
  vhacdx \
  xxhash \
  albucore \
  albumentations \
  simsimd \
  stringzilla

# Install monitoring tools
pip3 install nvidia-ml-py3 gpustat psutil

# Install ComfyUI Manager
git clone https://github.com/ltdrdata/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager
cd custom_nodes/ComfyUI-Manager
pip3 install -r requirements.txt

deactivate

echo "ComfyUI installed to /opt/ComfyUI"