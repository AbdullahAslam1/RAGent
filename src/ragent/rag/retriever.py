from enum import Enum
from typing import Any, List, Optional , Dict

from langchain_core.documents import Document
from langchain_core.vectorstores import VectorStoreRetriever

from .vector_store import VectorStoreManager

DEFAULT_TOP_K = 6
DEFAULT_FETCH_K = 25
DEFAULT_SCORE_THRESHOLD = 0.5


class SearchType(str, Enum):
    SIMILARITY = "similarity"
    MMR = "mmr"
    SCORE_THRESHOLD = "similarity_score_threshold"


class RAGRetriever:
    """High-level retrieval manager."""

    def __init__(
        self,
        vector_store_manager: VectorStoreManager,
        top_k: int = DEFAULT_TOP_K,
        fetch_k: int = DEFAULT_FETCH_K,
        score_threshold: float = DEFAULT_SCORE_THRESHOLD,
        default_search_type: SearchType = SearchType.MMR,
    ):
        self.vector_store_manager = vector_store_manager
        self.top_k = top_k
        self.fetch_k = fetch_k
        self.score_threshold = score_threshold
        self.default_search_type = default_search_type

    def get_retriever(
        self,
        search_type: Optional[SearchType] = None,
        **extra_kwargs: Any,
    ) -> VectorStoreRetriever:

        strategy = search_type or self.default_search_type

        search_kwargs: Dict[str , Any] = {
            "k": self.top_k,
        }

        if strategy == SearchType.MMR:
            search_kwargs["fetch_k"] = self.fetch_k

        elif strategy == SearchType.SCORE_THRESHOLD:
            search_kwargs["score_threshold"] = self.score_threshold

        search_kwargs.update(extra_kwargs)

        return (
            self.vector_store_manager
            .get_vector_store()
            .as_retriever(
                search_type=strategy.value,
                search_kwargs=search_kwargs,
            )
        )

    def retrieve(
        self,
        query: str,
        search_type: Optional[SearchType] = None,
        **kwargs: Any,
    ) -> List[Document]:

        retriever = self.get_retriever(search_type=search_type, **kwargs)
        return retriever.invoke(query)