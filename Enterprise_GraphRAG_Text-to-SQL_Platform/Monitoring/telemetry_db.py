#This script help us to connect to the sqliteDB and create a table.
import sqlite3

conn = sqlite3.connect("telemetry.db")
cursor = conn.cursor()

cursor.execute("""
    CREATE TABLE IF NOT EXISTS telemetry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        request_id TEXT,

        question TEXT,

        schema_retrieval_total_time_ms REAL,
        sql_generation_total_time_ms REAL,
        performaing_sql_query_total_time_ms REAL,

        repair_attempts REAL,
        total_latency_in_sec REAL,

        success INTEGER,

        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

conn.commit()
print("Telemetry table created successfully")
