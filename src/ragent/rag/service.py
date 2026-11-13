from functools import lru_cache
from pathlib import Path

from .ingestion import DocumentIngestion
from .embeddings import EmbeddingManager
from .vector_store import VectorStoreManager
from .retriever import RAGRetriever



SUPPORTED_EXTENSIONS = [".pdf", ".txt"]

@lru_cache(maxsize=1)
def _components():
    """Build everything once, on first use (the embedding model is heavy)."""
    ingestor = DocumentIngestion()
    embeddings = EmbeddingManager().get_embedding_model()
    vector_manager = VectorStoreManager(embeddings)
    retriever = RAGRetriever(vector_manager)
    return ingestor, vector_manager, retriever


def add_document_to_rag(file_path: str, thread_id: str, original_filename: str | None = None) -> dict:
    ingestor, vector_manager, _ = _components()

    chunks = ingestor.run_single_file(file_path, original_filename)

    if not chunks:
        raise ValueError("No text could be extracted from this file.")

    # This tag is what keeps each chat's documents separate
    for chunk in chunks:
        chunk.metadata["thread_id"] = thread_id

    vector_manager.load_documents(chunks)

    return {
        "filename": original_filename or Path(file_path).name,
        "chunks": len(chunks),
    }


def retrieve_from_rag(query: str, thread_id: str) -> str:
    _, _, retriever = _components()

    docs = retriever.retrieve(query, filter={"thread_id": thread_id})

    if not docs:
        return "No relevant uploaded document content found."

    parts = []
    for i, doc in enumerate(docs, start=1):
        source = doc.metadata.get("source_file", "Unknown")
        page = doc.metadata.get("page", "?")
        parts.append(f"[Source {i}: {source}, page {page}]\n{doc.page_content}")

    return "\n\n".join(parts)

def delete_thread_documents(thread_id: str) -> None:
    _, vector_manager, _ = _components()
    vector_manager.get_vector_store().delete(where={"thread_id": thread_id})