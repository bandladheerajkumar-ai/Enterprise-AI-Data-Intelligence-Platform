#This script help us to connect to the QdrantDB. 
from qdrant_client import QdrantClient

class QdrantManager:
    _client = None

    @classmethod
    def get_client(cls):
        if cls._client is None:
            cls._client = QdrantClient(
                path="qdrant_db"
            )
        return cls._client
