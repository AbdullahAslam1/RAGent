import logging
from pathlib import Path
from typing import List , Union

from langchain_community.document_loaders import PyMuPDFLoader , TextLoader
from langchain_core.documents import Document
from langchain_text_splitters import RecursiveCharacterTextSplitter

logger = logging.getLogger(__name__)

class DocumentIngestion:
    """Production-grade LangChain document ingestion pipeline for PDFs and TXT files."""

    def __init__(
            self,
            pdf_directory : Union[str , Path] = "../data.pdf_files", 
            chunk_size: int = 1000, 
            chunk_overlap : int = 200, 
        ):
            self.pdf_directory = Path(pdf_directory)
            self.chunk_size = chunk_size 
            self.chunk_overlap = chunk_overlap

            self.text_splitter = RecursiveCharacterTextSplitter(
                chunk_size = self.chunk_size,
                chunk_overlap = self.chunk_overlap,
                separators= ["\n\n", "\n", " ", ""], 
                length_function = len ,
                is_separator_regex= False
            )

    def load_single_file(self, file_path : Union[str, Path] , original_filename: Union[str, None] = None) -> List[Document]:
        """Loads a single PDF or TXT file into standard LangChain Document objects.
        This is what the Streamlit app actually calls (via run_single_file, below)
        every time someone uploads a file on the Documents screen.
        """
        path = Path(file_path)
        if not path.exists():
             raise FileNotFoundError(f"File not found: {path}")
        file_name = original_filename or path.name
        ext  = path.suffix.lower()

        if ext == ".pdf":
            loader = PyMuPDFLoader(str(path))
        elif ext == ".txt":
            loader = TextLoader(str(path), encoding= "utf-8")
        else:
            raise ValueError(f"Unsupported file type '{ext}'. Only .pdf and .txt are supported ")

        documents = loader.load()

        for doc in documents:
            doc.metadata["file_type"] = ext.lstrip(".")
            doc.metadata["source_file"] = file_name

            doc.metadata["page"] = doc.metadata.get("page" , 0) + 1

            logger.info(f"Successfully laoded '{file_name}'")

        return documents 

    def split_documents(self, documents: List[Document]) -> List[Document]:
        if not documents:
            logger.warning("No documents provided to split")
            return []

        chunked_docs = self.text_splitter.split_documents(documents)

        for idx , doc in enumerate(chunked_docs):
            doc.metadata["chunk_id"] = idx

        logger.info(
            f"Transformed {len(documents)} pages into {len(chunked_docs)} chunked Document objects."
        )

        return chunked_docs

    def run_single_file(self , file_path : Union[str, Path], orginal_filename: Union[str , None]) -> List[Document]:
        """Executes full pipeline for a single file: Load -> Split. This is the
        one the Streamlit app calls on every upload."""

        docs = self.load_single_file(file_path , orginal_filename)
        return self.split_documents(docs)