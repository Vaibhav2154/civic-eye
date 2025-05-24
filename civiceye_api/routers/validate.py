from fastapi import APIRouter, UploadFile, File
from services.audio_validation import validate_audio
from services.video_validation import validate_video
from services.image_validation import validate_uploaded_image
from services.llm_verifier import analyze_with_llm

router = APIRouter(prefix="/validate", tags=["Validation"])


@router.post("/audio")
async def validate_audio_endpoint(file: UploadFile = File(...)):
    signal_result = await validate_audio(file)
    llm_flag = await analyze_with_llm("audio", {"signal_passed": signal_result})
    return {"tampered": llm_flag}

@router.post("/image")
async def validate_image_endpoint(file: UploadFile = File(...)):
    signal_result = await validate_uploaded_image(file)
    llm_flag = await analyze_with_llm("image", {"signal_passed": signal_result})
    return {"tampered": llm_flag}

@router.post("/video")
async def validate_video_endpoint(file: UploadFile = File(...)):
    signal_result = await validate_video(file)
    llm_flag = await analyze_with_llm("video", {"signal_passed": signal_result})
    return {"tampered": llm_flag}
