from fastapi import FastAPI, Request, Depends
from pydantic import BaseModel
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import os
from models.embeddings_model import EmbeddingModel
from sql.sql_generator import get_query_results
import sqlite3
from fastapi.responses import FileResponse

class QueryRequest(BaseModel):
    question: str
    
# Initialize the FastAPI application with metadata
app = FastAPI(
    title="Employee Database RAG",
    version="1.0"
)

# Ensure the 'static' directory exists to prevent app crash on mounting
if not os.path.exists("static"):
    os.makedirs("static")

# Mount static files (CSS, JS, Images) under the '/static' URL path
# Initialize Jinja2 template engine for rendering HTML files
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

#Pre loading the Embedding model.
@app.on_event("startup")
async def startup():
    print("Loading services...")
    EmbeddingModel.get_model()

#Route: GET /
#Purpose: Renders and serves the main web chat interface using Jinja2 templates.
@app.get("/", response_class=HTMLResponse)
async def get_chat_ui(request: Request):
    return templates.TemplateResponse(
        request=request, 
        name="index.html", 
        context={"request": request}
    )

#Storing the LLM interaction history
chat_history = []

#Route: POST /query
#Purpose: Accepts a user question, processes it via the RAG pipeline using the chat history context, updates the history log, and returns the result.
@app.post("/query")
def query_database(request: QueryRequest):
    question = request.question
    current_history_list = list(chat_history)
    results = get_query_results(question, current_history_list)
    chat_history.append({
        "user": question,
        "llm": results
    })

    return {"answer": results}

#Route: GET /telemetry
#Purpose: Connects to the local SQLite monitoring database and fetches the latest 100 logged application telemetry records in a readable JSON format.
#Testing
@app.get("/telemetry")
def get_telemetry():
    conn = sqlite3.connect("Monitoring\telemetry.db")
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("""
        SELECT *
        FROM telemetry
        ORDER BY id DESC
        LIMIT 100
    """)

    rows = [dict(row) for row in cursor.fetchall()]
    conn.close()

    return rows

#Route: GET /dashboard
#Purpose: Telementory data showing in the dashboard UI.
@app.get("/dashboard")
async def dashboard():
    return FileResponse("static_monitor/dashboard.html")


