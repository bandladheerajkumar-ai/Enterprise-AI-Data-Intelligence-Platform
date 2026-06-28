#This script help us to load the embeddings.
from sentence_transformers import SentenceTransformer

class EmbeddingModel:
    _model = None

    @classmethod
    def get_model(cls):
        if cls._model is None:          
            EMBEDDING_MODEL = r"bge_embeddings"
            print("Loading embedding model...")           
            cls._model = SentenceTransformer(EMBEDDING_MODEL)
        return cls._model
