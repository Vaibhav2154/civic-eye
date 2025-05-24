# services/chatbot_rag.py
import chromadb
from chromadb.api.types import Documents, EmbeddingFunction
import google.generativeai as genai
import os
from dotenv import load_dotenv


load_dotenv()

API_KEY = os.environ.get("GEMINI_API_KEY")
if not API_KEY:
  raise ValueError("GEMINI_API_KEY not found in environment variables")
API_KEY = ""
genai.configure(api_key=API_KEY)

class GeminiEmbeddingFunction(EmbeddingFunction):
    def __init__(self, api_key):
        genai.configure(api_key=api_key)
    
    def __call__(self, texts: Documents) -> list:
        embeddings = []
        for text in texts:
            result = genai.embed_content(
                model="embedding-001",
                content=text,
                task_type="retrieval_document",
            )
            embeddings.append(result["embedding"])
        return embeddings

embedding_fn = GeminiEmbeddingFunction(api_key=API_KEY)

client = chromadb.Client()
collection = client.get_or_create_collection(name="indian_constitution", embedding_function=embedding_fn)

def ingest_documents():
    with open("data/indian_constitution.txt", "r") as f:
        text = f.read()
    chunks = [text[i:i+500] for i in range(0, len(text), 500)]
    for i, chunk in enumerate(chunks):
        collection.add(documents=[chunk], ids=[f"doc_{i}"])

def query_constitution(user_query: str) -> str:
    long_response_keywords = ["explain", "describe", "elaborate", "detailed", "in detail", "clarify", "interpret"]

    normalized_query = user_query.lower()

    is_detailed = any(keyword in normalized_query for keyword in long_response_keywords)


    results = collection.query(query_texts=[user_query], n_results=5)
    retrieved_chunks = [doc for doc in results["documents"][0]]
    context = "\n".join(retrieved_chunks)

    prompt = f"""
You are a legal assistant AI, strictly limited to referencing and interpreting the Indian Constitution and criminal law.

Your task:
1. Use only the context provided below from the Constitution or respond with general legal reasoning if appropriate.
2. Provide a {'detailed, structured explanation' if is_detailed else 'brief, clear, and direct answer'} to the user's query.
3. If the query pertains to a violation or crime, suggest appropriate legal actions under Indian law.

Instructions:
- Use a formal, objective, and helpful tone.
- Use bullet points or numbered steps where applicable.
- Do not discuss topics outside the domain of Indian law or criminal law.
- If insufficient information is available, acknowledge it rather than guessing.

========================
Context (from the Constitution or Criminal Law):
{context}

User's Legal Query:
{user_query}

Your Answer:
"""

    model = genai.GenerativeModel('gemini-1.5-flash')
    response = model.generate_content(prompt)

    return response.text
