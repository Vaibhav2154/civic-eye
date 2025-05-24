from fastapi import APIRouter
from pydantic import BaseModel
from services.chatbot_rag import query_constitution

router = APIRouter()

class ChatRequest(BaseModel):
    question: str

@router.post("/chat", tags=["Legal Chatbot"])
async def legal_chat(req: ChatRequest):
    answer = query_constitution(req.question)
    return {"answer": answer}
