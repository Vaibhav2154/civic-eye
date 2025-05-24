import tempfile
from utils.file_utils import save_upload_file_tmp
import cv2
import numpy as np

def is_video_tampered(file_path: str) -> bool:
    try:
        cap = cv2.VideoCapture(file_path)
        ret, prev_frame = cap.read()
        
        if not ret:  # Can't read the video file
            print("Cannot read")
            return True
            
        frame_diffs = []
        while True:
            ret, curr_frame = cap.read()
            if not ret:
                break

            diff = cv2.absdiff(cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY),
                               cv2.cvtColor(curr_frame, cv2.COLOR_BGR2GRAY))
            diff_score = np.mean(diff)
            frame_diffs.append(diff_score)
            prev_frame = curr_frame

        cap.release()
        
        if not frame_diffs:
            print("No frames were processed")# No frames were processed
            return True
            
        std_dev = np.std(frame_diffs)
        return std_dev > 10.0  # High fluctuation = tampering
    except Exception as e:
        print(f"[Video Check Error] {e}")
        return True  # Conservative assumption: mark as tampered

def load_video_model():
    # Using frame-level analysis for tampering detection
    return is_video_tampered

video_model = load_video_model()

async def validate_video(file):
    path = await save_upload_file_tmp(file)
    result = not video_model(path)  # Return True if video is valid (not tampered)
    return result