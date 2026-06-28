#This script help us to connect ot the sql DB and insert the records for every answer Generation
#for monitoring the time.
import sqlite3

def save_telemetry(request_id,question,schema_retrieval_total_time_ms, sql_generation_total_time_ms, performaing_sql_query_total_time_ms,
                   repair_attempts, total_latency_in_sec, success):

        conn = sqlite3.connect(r"C:\Users\a1gp3d1m\Desktop\airtel_chatbot\app\vector_store\Employee_graph_rag\Main_employee_rag_system\Monitoring\telemetry.db")
        cursor = conn.cursor()

        cursor.execute("""
            INSERT INTO telemetry (
                request_id,
                question,
                schema_retrieval_total_time_ms,
                sql_generation_total_time_ms,
                performaing_sql_query_total_time_ms,
                repair_attempts,
                total_latency_in_sec,
                success
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
                request_id,
                question,
                schema_retrieval_total_time_ms,
                sql_generation_total_time_ms,
                performaing_sql_query_total_time_ms,
                repair_attempts,
                total_latency_in_sec,
                success
        ))

        conn.commit()
        #conn.close()
