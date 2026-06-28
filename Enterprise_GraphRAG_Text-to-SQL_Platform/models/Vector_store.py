#This script is used to store the schema_metedat in to the qdrantDB.
from langchain_core.documents import Document
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_qdrant import QdrantVectorStore
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams
import os
import torch
from sentence_transformers import SentenceTransformer
local_model_path = r"bge_embeddings"


#CREATE DOCUMENT CHUNKS
with open(r"schema_metadata_text.txt", encoding="utf-8") as f:
    text = f.read()
parts = text.split("DOCUMENT_TABLE")
documents = []
for idx, part in enumerate(parts):
    part = part.strip()
    if part:
        doc = Document(
            page_content=part,
            metadata={
                "document_name": "schema_metadata_text.txt",
                "document_type": "schema_metadata",
                "chunk_id": idx,
                "source": "telecom"
            }
        )
        documents.append(doc)

#LOAD EMBEDDING MODEL
embedding_model = HuggingFaceEmbeddings(
    model_name=local_model_path,
    model_kwargs={"device": "cpu"},          
    encode_kwargs={
        "normalize_embeddings": True    
    }
)

#CONNECT TO QDRANT
client = QdrantClient(
    path="./qdrant_db"
)

collection_name = "employee_rag"

#CREATE COLLECTION ONLY ONCE
sample_embedding = embedding_model.embed_query("dimension check")
vector_dimension = len(sample_embedding)
if not client.collection_exists(collection_name):
    client.create_collection(
        collection_name=collection_name,
        vectors_config=VectorParams(
            size=vector_dimension,
            distance=Distance.COSINE
        )
    )

#STORE DOCUMENTS
vector_store = QdrantVectorStore(
    client=client,
    collection_name=collection_name,
    embedding=embedding_model
)
vector_store.add_documents(documents)
print("\nDOCUMENT STORED SUCCESSFULLY") 

