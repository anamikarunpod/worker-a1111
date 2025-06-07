#!/usr/bin/env bash

# Проверка наличия файла модели
if [ -f /runpod-volume/ImageModel.safetensors ]; then
  echo "[LOG] Model file found: /runpod-volume/ImageModel.safetensors"
  ls -lh /runpod-volume/ImageModel.safetensors
else
  echo "[ERROR] Model file NOT found: /runpod-volume/ImageModel.safetensors"
  ls -lh /runpod-volume || true
fi

echo "Worker Initiated"

echo "Starting WebUI API"
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"
export PYTHONUNBUFFERED=true
python /stable-diffusion-webui/webui.py \
  --xformers \
  --no-half-vae \
  --skip-python-version-check \
  --skip-torch-cuda-test \
  --skip-install \
  --ckpt /runpod-volume/ImageModel.safetensors \
  --opt-sdp-attention \
  --disable-safe-unpickle \
  --port 3000 \
  --api \
  --nowebui \
  --skip-version-check \
  --no-hashing \
  --no-download-sd-model &

echo "Starting RunPod Handler"
python -u /handler.py
