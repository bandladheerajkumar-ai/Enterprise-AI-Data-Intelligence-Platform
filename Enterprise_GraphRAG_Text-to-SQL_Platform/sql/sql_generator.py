#This is main script for generating the Answer.
#This script fetch the retrivel from the vectorDB and the Graphs use those retrivel to generate the answer.
#If it does not got any retrivel based on the user query then it will communicate normaly to the user.
import json
import re
import time
import requests
import sqlite3
from models.embeddings_model import EmbeddingModel
from retrieval.qdrant_retriever import QdrantManager
from qdrant_client import QdrantClient
from qdrant_client.models import (Distance, VectorParams, PointStruct)
import uuid
from Monitoring.telemetry_func import save_telemetry
import traceback


DB_PATH = "employee_management.db"

conn = sqlite3.connect(DB_PATH, check_same_thread=False)
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

OLLAMA_URL = "used local server H200 gpu serving via API."
MODEL_NAME = "Agentar-Scale-SQL-Generation-32B:latest"
FINAL_MODEL = "gpt-oss:20b"

max_retries = 5
attempt = 0

error_history = []
current_sql = None

# Helper Function
def extract_json(response_text):
    """
    Handles:
    - Pure JSON
    - ```json ... ```
    - Extra text around JSON
    """
    response_text = response_text.strip()
    # Remove markdown fences
    response_text = re.sub(r"^```json\s*", "", response_text)
    response_text = re.sub(r"^```\s*", "", response_text)
    response_text = re.sub(r"\s*```$", "", response_text)
    # Extract JSON object
    match = re.search(r"\{.*\}", response_text, re.DOTALL)
    if not match:
        raise ValueError("No JSON found in model response")
    return json.loads(match.group())

def get_schema_context(user_query, top_n_chunks=3):
    
    model = EmbeddingModel.get_model()

    #Generate Query Embedding
    query_embedding = model.encode(
        user_query,
        normalize_embeddings=True
    )
    client = QdrantManager.get_client()

    #Query Qdrant
    results = client.query_points(
        collection_name="employee_rag",
        query=query_embedding.tolist(),
        limit=10
    )

    if not results.points:
        print("No matching points found in Qdrant.")
        return [], []

    #Dynamic Thresholding (Keep matches within 96% of the top match)
    score_threshold = results.points[0].score * 0.96
    candidate_tables = []
    top_chunks_context = []

    #Process Chunks Safely
    for r in results.points:
        if r.score >= score_threshold:
            page_content = r.payload.get('page_content', '')
            
            #Keep track of the top chunk texts for the LLM prompt
            if page_content and len(top_chunks_context) < top_n_chunks:
                top_chunks_context.append(page_content)
            
            #Extract Table Name
            match = re.search(r"Table Name:\s*(\w+)", page_content)
            if match:
                table_name = match.group(1)
                candidate_tables.append(table_name)
            else:
                print("Table name pattern not found in chunk.")

    #Deduplicate table names while preserving vector score order
    candidate_tables = list(dict.fromkeys(candidate_tables))

    print(f"--- Schema Context Found ({len(top_chunks_context)} Chunks) ---")
    print("Identified Tables:", candidate_tables)

    #Returns actual text chunks for your LLM and the list of unique tables
    return top_chunks_context, candidate_tables

# ReAct Loop
def get_query_results(user_query, chat_history):
    
        start_time = time.perf_counter()
        schema_retrieval_start_time = time.perf_counter()
        schema_context, candidate_tables = get_schema_context(user_query)
        schema_retrieval_end_time = time.perf_counter()
        schema_retrieval_total_time_ms = (schema_retrieval_end_time - schema_retrieval_start_time) * 1000
        
        if len(candidate_tables) == 0:
            not_found_table_prompt = """Think you are Company HR.

                                        User Question:
                                        {user_question}

                                        1)Handel the question if user question is other that the employee data.
                                        2)Replay in polite manner.
                                        3)Ask more information for retriving the correct table based on the database.
                                        """
            payload = {
                    "model": FINAL_MODEL,
                    "prompt": not_found_table_prompt,
                    "stream": False
                }

            response = requests.post(
                OLLAMA_URL,
                json=payload,
                timeout=300
            )
            return response.json()["response"]
            
        user_question = user_query
        max_retries = 5
        attempt = 0
        error_history = []
        current_sql = None
    
        while attempt < max_retries:

            attempt += 1

            print("\n" + "=" * 80)
            print(f"ATTEMPT #{attempt}")
            print("=" * 80)

            try:
                # First attempt -> generate SQL from user question
                # Later attempts -> repair previous SQL
                
                sql_generation_start_time = time.perf_counter()

                if current_sql is None:
                    prompt = f"""
                                You are an expert ClickHouse SQL generator.

                                constraint:
                                    1)Please verify the columns are correct or not.
                                    2)If getting error change the column names.
                                    3)If one column choosen, It should not repeat again.
                                
                                Return ONLY valid JSON.
                                
                                Format:
                                
                                {{
                                    "sql": "",
                                    "tables_used": [],
                                    "columns_used": []
                                }}
                                
                                Schema Context:
                                {schema_context}
                                
                                Question:
                                {user_question}
                                
                                Chat History:
                                (chat_history)
                                """

                else:
                    prompt = f"""
                                You are an expert ClickHouse SQL repair agent.

                                constraint:
                                    1)Please verify the columns are correct or not.
                                    2)If getting error change the column names 
                                    3)If one column choosen, It should not repeat again.
                                The previous SQL failed.
                                
                                Question:
                                {user_question}
                                
                                Previous SQL:
                                {current_sql}
                                
                                Error History:
                                {chr(10).join(error_history)}
                                
                                Schema Context:
                                {schema_context}

                                Chat History:
                                (chat_history)
                                
                                
                                Generate a corrected SQL query.
                                
                                Return ONLY valid JSON.
                                
                                Format:
                                
                                {{
                                    "sql": "",
                                    "tables_used": [],
                                    "columns_used": []
                                }}
                                """

                # Call LLM
                payload = {
                    "model": MODEL_NAME,
                    "prompt": prompt,
                    "stream": False
                }

                response = requests.post(
                    OLLAMA_URL,
                    json=payload,
                    timeout=300
                )
                
                sql_generation_end_time = time.perf_counter()
                sql_generation_total_time_ms = (sql_generation_end_time - sql_generation_start_time) * 1000
                raw_response = response.json()["response"]

                # Parse JSON
                sql_dict = extract_json(raw_response)
                current_sql = sql_dict["sql"]
                performaing_sql_query_start_time = time.perf_counter()
                cursor.execute(current_sql)
                rows = cursor.fetchall()
                performaing_sql_query_end_time = time.perf_counter()
                performaing_sql_query_total_time_ms = (performaing_sql_query_end_time - performaing_sql_query_start_time) * 1000
                result = [dict(row) for row in rows]
                end_time = time.perf_counter()
                elapsed_ms = (end_time - start_time) * 1000

                answer_prompt = f"""
                    You are a business assistant.

                    User Question:
                    {user_question}

                    SQL Results:
                    {result}
                    
                    RAW response:
                    (raw_response)

                    Time:
                    {elapsed_ms}

                    Rules:
                    1. Answer naturally.
                    2. Summarize key findings.
                    3. If no rows found, say so.
                    4. Do not mention SQL.
                    5. Use bullet points when useful.
                    6. In saparate line use RAW response and give explanation to the user about table used, sql Generated Execution Time in milliseconds use elapsed_ms (Note: Final Answer and RAW Response should be saparate) 
                    """
                
                payload = {
                    "model": FINAL_MODEL,
                    "prompt": answer_prompt,
                    "stream": False
                }

                response = requests.post(
                    OLLAMA_URL,
                    json=payload,
                    timeout=300
                )

                print("---------------------------------------------")
                print("Status Code:", response.status_code)
                print("Answer : ", response.json()["response"])
                print("----------------------------------------------")
                
                request_id = str(uuid.uuid4())
                total_latency_in_sec = (schema_retrieval_total_time_ms + sql_generation_total_time_ms + performaing_sql_query_total_time_ms)/1000
                
                save_telemetry(request_id = request_id, question = user_question, schema_retrieval_total_time_ms = schema_retrieval_total_time_ms, sql_generation_total_time_ms = sql_generation_total_time_ms,
                                performaing_sql_query_total_time_ms = performaing_sql_query_total_time_ms, repair_attempts = attempt, total_latency_in_sec = total_latency_in_sec, success = 1)
                
                return response.json()["response"]

            except Exception as e: 
                error_message = traceback.format_exc()
                print("\nFAILED")
                print(error_message)
                error_history.append(error_message)

            
