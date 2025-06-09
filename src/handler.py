import time
import runpod
import requests
import subprocess
import os
import logging
import sys
from requests.adapters import HTTPAdapter, Retry

LOCAL_URL = "http://127.0.0.1:3000/sdapi/v1"

automatic_session = requests.Session()
retries = Retry(total=10, backoff_factor=0.1, status_forcelist=[502, 503, 504])
automatic_session.mount('http://', HTTPAdapter(max_retries=retries))


# ---------------------------------------------------------------------------- #
#                              Automatic Functions                             #
# ---------------------------------------------------------------------------- #
def wait_for_service(url):
    """
    Check if the service is ready to receive requests.
    """
    retries = 0

    while True:
        try:
            requests.get(url, timeout=120)
            return
        except requests.exceptions.RequestException:
            retries += 1

            # Only log every 15 retries so the logs don't get spammed
            if retries % 15 == 0:
                print("Service not ready yet. Retrying...")
        except Exception as err:
            print("Error: ", err)

        time.sleep(0.2)


def run_inference(inference_request):
    """
    Run inference on a request.
    """
    response = automatic_session.post(url=f'{LOCAL_URL}/txt2img',
                                      json=inference_request, timeout=600)
    return response.json()


# ---------------------------------------------------------------------------- #
#                                RunPod Handler                                #
# ---------------------------------------------------------------------------- #
def handler(event):
    """
    This is the handler function that will be called by the serverless.
    """

    json = run_inference(event["input"])

    # return the output that you want to be returned like pre-signed URLs to output artifacts
    return json

def launch_webui():
    command = [
        "python", "/stable-diffusion-webui/webui.py",
        "--xformers",
        "--no-half-vae",
        "--skip-python-version-check",
        "--skip-torch-cuda-test",
        "--skip-install",
        "--ckpt", "/runpod-volume/ImageModel.safetensors",
        "--opt-sdp-attention",
        "--disable-safe-unpickle",
        "--port", "3000",
        "--api",
        "--nowebui",
        "--skip-version-check",
        "--no-hashing",
        "--no-download-sd-model"
    ]
    logging.info("Launching webui.py...")
    try:
        subprocess.Popen(command)
        logging.info("webui.py launched successfully.")
    except Exception as e:
        logging.error(f"Failed to launch webui.py: {e}")


def wait_for_volume(mount_path="/runpod-volume", max_attempts=20, sleep_secs=2):
    logging.info(f"Waiting for {mount_path} to mount...")

    for i in range(1, max_attempts + 1):
        if os.path.isdir(mount_path) and os.listdir(mount_path):
            logging.info(f"{mount_path} mounted and contains files.")
            break
        logging.info(f"Attempt {i}: {mount_path} not ready. Retrying in {sleep_secs}s...")
        time.sleep(sleep_secs)
    else:
        logging.error(f"{mount_path} not mounted or empty after {max_attempts} attempts. Exiting.")
        sys.exit(1)

    # List contents of the mounted directory
    logging.info(f"Listing contents of {mount_path}:")
    for item in os.listdir(mount_path):
        item_path = os.path.join(mount_path, item)
        try:
            size = os.path.getsize(item_path)
            logging.info(f"- {item} ({size} bytes)")
        except Exception as e:
            logging.warning(f"- {item} (error getting size: {e})")


if __name__ == "__main__":
    wait_for_volume()
    launch_webui()
    wait_for_service(url=f'{LOCAL_URL}/sd-models')
    print("WebUI API Service is ready. Starting RunPod Serverless...")
    runpod.serverless.start({"handler": handler})