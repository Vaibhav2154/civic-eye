from fastapi import APIRouter, UploadFile, File, Form
from services.blockchain_core import Blockchain
import hashlib

router = APIRouter()
blockchain = Blockchain()


def hash_report_data(text: str, media_links: list) -> str:
    combined = text + "".join(media_links)
    return hashlib.sha256(combined.encode()).hexdigest()


@router.post("/report")
async def submit_crime_report(
    text: str = Form(...),
    media_links: list[str] = Form(...),
    user_id: str = Form("anonymous")  # optional
):
    report_hash = hash_report_data(text, media_links)

    data = {
        "user_id": user_id,
        "report_hash": report_hash,
        "media": media_links,
        "text": text
    }

    block = blockchain.add_block(data)
    return {
        "message": "Report logged on local blockchain",
        "block": block.__dict__
    }


@router.get("/chain")
def get_blockchain():
    return blockchain.to_dict()
