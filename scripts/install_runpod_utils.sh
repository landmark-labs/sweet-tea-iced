#!/bin/bash

# Configuration
TUSD_BIN_PATH="/usr/local/bin/tusd"
RUNPOD_UPLOADER_BIN_PATH="/usr/local/bin/runpod-uploader"
RUNPOD_UPLOADER_SCRIPT_PATH="/etc/runpod-uploader/scripts"
HOOKS_DIR="/etc/tusd/hooks"

# Create directories
mkdir -p "${HOOKS_DIR}"
mkdir -p "${RUNPOD_UPLOADER_SCRIPT_PATH}"

# Install tusd
echo "Installing tusd..."
curl -L https://github.com/tus/tusd/releases/download/v2.2.2/tusd_linux_amd64.tar.gz -o tusd.tar.gz
tar -xzf tusd.tar.gz tusd_linux_amd64/tusd
mv tusd_linux_amd64/tusd "${TUSD_BIN_PATH}"
chmod +x "${TUSD_BIN_PATH}"

# Install runpod-uploader
echo "Installing runpod-uploader..."
curl -L https://github.com/kodxana/RunPod-FilleUploader/releases/download/v1.2/runpod-uploader -o "${RUNPOD_UPLOADER_BIN_PATH}"
chmod +x "${RUNPOD_UPLOADER_BIN_PATH}"

# Install hooks and scripts
echo "Installing hooks and scripts..."
curl -L https://github.com/kodxana/RunPod-FilleUploader/raw/main/hook/post-finish -o "${HOOKS_DIR}/post-finish"
curl -L https://github.com/kodxana/RunPod-FilleUploader/raw/main/hook/rename_uploaded_file.py -o "${HOOKS_DIR}/rename_uploaded_file.py"
chmod +x "${HOOKS_DIR}/post-finish"
chmod +x "${HOOKS_DIR}/rename_uploaded_file.py"

curl -L https://github.com/kodxana/RunPod-FilleUploader/raw/main/scripts/ssh-setup.sh -o "${RUNPOD_UPLOADER_SCRIPT_PATH}/ssh-setup.sh"
curl -L https://github.com/kodxana/RunPod-FilleUploader/raw/main/scripts/run-speedtest.sh -o "${RUNPOD_UPLOADER_SCRIPT_PATH}/run-speedtest.sh"
chmod +x "${RUNPOD_UPLOADER_SCRIPT_PATH}/ssh-setup.sh"
chmod +x "${RUNPOD_UPLOADER_SCRIPT_PATH}/run-speedtest.sh"

# Cleanup
rm -rf tusd.tar.gz tusd_linux_amd64 /root/.cache/*

echo "RunPod utils setup complete."
