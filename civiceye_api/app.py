from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from jsonschema import validate

from routers import blockchain,chatbot,validate



app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],            
    allow_credentials=True,
    allow_methods=["*"],              
    allow_headers=["*"],              
)



@app.get('/')
def greet():
  return {"message":"working"}

app.include_router(validate.router)
app.include_router(chatbot.router, prefix="/chatbot")
app.include_router(blockchain.router, prefix="/blockchain")
