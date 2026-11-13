import logging
from typing import Dict , Any , Optional
from langchain_core.embeddings import Embeddings
from langchain_huggingface import HuggingFaceEmbeddings

logger = logging.getLogger(__name__)

DEFAULT_MODEL_NAME =  "sentence-transformers/all-MiniLM-L6-v2"

class EmbeddingManager:
    """Manages LangChain-compatible embedding model initialization."""

    def __init__(
            self, 
            model_name : str = DEFAULT_MODEL_NAME, 
            device : str = "cpu", 
            normalize_embeddings : bool = True
        ):
            self.model_name = model_name
            self.device = device
            self.normalize_embeddings = normalize_embeddings
            self.embedding_instance : Optional[Embeddings] = None

    def get_embedding_model(self) -> Embeddings:
        """Instantiates and returns a standard LangChain Embeddings object.
        
        Uses lazy initialization so the model is only loaded into memory when requested.
        """

        if self.embedding_instance is None:
            logging.info(f"loading langchain huggingface embedding model '{self.model_name}'")

            model_kwargs : Dict[str , Any] ={"device": self.device}
            encode_kwargs : Dict[str , Any] = {"normalize_embeddings": self.normalize_embeddings}

            try:
                self.embedding_instance = HuggingFaceEmbeddings(
                    model_name = self.model_name,
                    model_kwargs = model_kwargs,
                    encode_kwargs = encode_kwargs
                )
                logger.info("Embedding model successfully loaded.")
            except Exception as e:
                logger.error(f"Failed to load embedding model {self.model_name}: {e}")
                raise
        
        return self.embedding_instance

        