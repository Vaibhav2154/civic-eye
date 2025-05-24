import tempfile
from utils.file_utils import save_upload_file_tmp
import torch
import librosa
import numpy as np

def is_audio_tampered(file_path: str) -> bool:
    try:
        y, sr = librosa.load(file_path)
        # Basic audio signal features
        zero_crossings = np.mean(librosa.zero_crossings(y, pad=False))
        spectral_centroid = np.mean(librosa.feature.spectral_centroid(y=y, sr=sr))

        # Placeholder rule: abnormal values suggest tampering
        if zero_crossings > 0.1 or spectral_centroid < 1500:
            return True
        return False
    except Exception as e:
        print(f"[Audio Check Error] {e}")
        return True  # Conservative assumption: mark as tampered

def load_audio_model():
    # No longer using random model - we're using the tampering detection function
    return is_audio_tampered

audio_model = load_audio_model()

async def validate_audio(file):
    path = await save_upload_file_tmp(file)
    result = not audio_model(path)  # Return True if audio is valid (not tampered)
    return result