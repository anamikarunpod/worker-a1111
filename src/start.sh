#!/usr/bin/env bash

# Выводим содержимое корня!
echo "[LOG] Root directory listing:"
ls -lh /

# Поиск файла ImageModel.safetensors по всей файловой системе
echo "[LOG] Searching for ImageModel.safetensors in filesystem:"
find / -name 'ImageModel.safetensors' 2>/dev/null || echo "[LOG] File not found anywhere in filesystem."

echo "Worker Initiated"

echo "Starting WebUI API"
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"
export PYTHONUNBUFFERED=true

echo "Starting RunPod Handler"
python -u /handler.py
