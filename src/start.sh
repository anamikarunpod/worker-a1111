#!/usr/bin/env bash

# Выводим содержимое корня!
echo "[LOG] Root directory listing:"
ls -lh /

# Проверка наличия файла модели и вывод содержимого /runpod-volume
for i in {1..10}; do
    if [ -d "/runpod-volume" ]; then
        echo "[LOG] /runpod-volume found!"
        break
    fi
    echo "[LOG] Not found, retrying in 2s... ($i/10)"
    sleep 2
done

if [ ! -d "/runpod-volume" ]; then
    echo "[ERROR] /runpod-volume not mounted after 10 attempts. Exiting."
    exit 1
fi

# Поиск файла ImageModel.safetensors по всей файловой системе
echo "[LOG] Searching for ImageModel.safetensors in filesystem:"
find / -name 'ImageModel.safetensors' 2>/dev/null || echo "[LOG] File not found anywhere in filesystem."

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
