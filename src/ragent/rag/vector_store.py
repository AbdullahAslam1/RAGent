from typing import List, Optional
from langchain_chroma import Chroma
from langchain_core.documents import Document
from langchain_core.embeddings import Embeddings
from pathlib import Path

DEFAULT_COLLECTION_NAME = "pdf_documents"
DEFAULT_PERSIST_DIRECTORY = str(Path(__file__).resolve().parent.parent / "chroma_db")


class VectorStoreManager:
    """Manages low-level database connection and chunk persistence in ChromaDB."""

    def __init__(
        self,
        embedding_model: Embeddings,
        collection_name: str = DEFAULT_COLLECTION_NAME,
        persist_directory: str = DEFAULT_PERSIST_DIRECTORY,
    ):
        """Dependency Injection: Pass the embedding model during initialization."""
        self.embedding_model = embedding_model
        self.collection_name = collection_name
        self.persist_directory = persist_directory
        self._vector_store: Optional[Chroma] = None

    def get_vector_store(self) -> Chroma:
        """Connects to or instantiates the local Chroma vector store instance."""
        if self._vector_store is None:
            self._vector_store = Chroma(
                collection_name=self.collection_name,
                embedding_function=self.embedding_model,
                persist_directory=self.persist_directory,
                collection_metadata={"hnsw:space": "cosine"},
            )
        return self._vector_store

    def load_documents(self, documents: List[Document]) -> List[str]:
        """Saves document chunks into ChromaDB with deterministic tracking IDs."""
        if not documents:
            print("⚠️ No documents provided to index.")
            return []

        store = self.get_vector_store()

        ids = [
            f"{doc.metadata.get('thread_id', 'global')}_"
            f"{doc.metadata.get('source_file', 'doc')}_"
            f"p{doc.metadata.get('page', 0)}_c{idx}"
            for idx, doc in enumerate(documents)
        ]

        return store.add_documents(documents, ids=ids)