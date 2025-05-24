import os
from dotenv import load_dotenv
# from fastapi.logger import logger  # Changed import
import google.generativeai as genai

load_dotenv()
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

model = genai.GenerativeModel("gemini-1.5-flash")

async def analyze_with_llm(media_type: str, signal_result: dict) -> bool:
    """
    media_type: "audio", "video", or "image"
    signal_result: a dictionary with metrics or flags
    """

    prompt = f"""
You are a media forensic AI assistant.
Your job is to reason over signal-based analysis of media files and detect potential manipulation.

Type: {media_type}
Analysis Results:
{signal_result}

Rules:
- If statistical patterns are inconsistent or abnormal, raise a tampering flag.
- If JPEG or DCT anomalies, consider it suspicious.
- If frame differences are erratic (video) or noise variance is high (image), it could be fake.
- Your answer must be either "Tampered" or "Authentic".

Verdict:
"""

    try:
        response = model.generate_content(prompt)
        decision = response.text.strip().lower()
        print(response.text)
        return "tampered" in decision
    except Exception as e:
        print(f"[LLM ERROR] {e}")
        return True  # conservative fallback
