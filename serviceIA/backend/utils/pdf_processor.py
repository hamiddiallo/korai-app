from pathlib import Path
from dotenv import load_dotenv
from langchain_community.document_loaders import PyPDFLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_community.vectorstores import Chroma
import chromadb
from tqdm import tqdm


load_dotenv()

_EMBEDDING_MODEL = "intfloat/multilingual-e5-base"

# Separators ordered from coarsest to finest for medical French text
_MEDICAL_SEPARATORS = ["\n\n", "\n", ". ", ".\n", "! ", "? ", "; ", " ", ""]


class _E5Embeddings(HuggingFaceEmbeddings):
    """Adds 'passage: ' prefix at indexing time for intfloat/multilingual-e5-* models."""
    def embed_documents(self, texts: list) -> list:
        return super().embed_documents([f"passage: {t}" for t in texts])


def process_pdfs(
    pdf_folder: str,
    chroma_dir: str = None,
    collection_name: str = "orl_knowledge_base",
    chunk_size: int = 500,
    chunk_overlap: int = 150,
    reset: bool = False,
):
    """
    Index PDF documents into ChromaDB.

    Args:
        pdf_folder:      Directory containing the PDF files to index.
        chroma_dir:      Destination ChromaDB directory. Defaults to
                         ../KORAI-APP/chroma_db relative to this file.
        collection_name: ChromaDB collection name.
        chunk_size:      Target character count per chunk (500 works well for
                         clinical paragraphs — tight enough for precise retrieval).
        chunk_overlap:   Overlap between consecutive chunks (150 ≈ 30 % of
                         chunk_size, prevents losing context at boundaries).
        reset:           If True, drop the existing collection before indexing.
    """
    if chroma_dir is None:
        chroma_dir = str(
            Path(__file__).parent.parent / "KORAI-APP" / "chroma_db"
        )

    # ── 1. Load PDFs ────────────────────────────────────────────────────
    pdf_folder = Path(pdf_folder)
    pdf_files = sorted(pdf_folder.glob("*.pdf"))
    if not pdf_files:
        raise FileNotFoundError(f"No PDF found in: {pdf_folder}")

    docs = []
    for pdf_path in pdf_files:
        print(f"  Loading: {pdf_path.name}")
        loader = PyPDFLoader(str(pdf_path))
        pages = loader.load()
        # Attach a clean filename so metadata is readable in retrieval logs.
        # PyPDFLoader met le chemin complet dans `source` (C:\Users\<auteur>\…) : seul le nom du
        # fichier est gardé, pour que la base ne révèle pas le poste qui l'a construite.
        for page in pages:
            page.metadata["filename"] = pdf_path.name
            page.metadata["source"] = pdf_path.name
        docs.extend(pages)

    print(f"  {len(docs)} pages loaded from {len(pdf_files)} PDF(s)")

    # ── 2. Split into chunks ─────────────────────────────────────────────
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=chunk_size,
        chunk_overlap=chunk_overlap,
        length_function=len,
        separators=_MEDICAL_SEPARATORS,
    )
    splits = splitter.split_documents(docs)
    print(f"  {len(splits)} chunks created (size={chunk_size}, overlap={chunk_overlap})")

    # ── 3. Embeddings ────────────────────────────────────────────────────
    print(f"  Loading embeddings model ({_EMBEDDING_MODEL})…")
    embeddings = _E5Embeddings(
        model_name=_EMBEDDING_MODEL,
        model_kwargs={"device": "cpu"},
        encode_kwargs={"normalize_embeddings": True},
    )

    # ── 4. Store in ChromaDB ─────────────────────────────────────────────
    if reset:
        client = chromadb.PersistentClient(path=chroma_dir)
        try:
            client.delete_collection(collection_name)
            print(f"  Existing collection '{collection_name}' dropped.")
        except Exception:
            pass

    # Initialiser la collection vide
    vectorstore = Chroma(
        persist_directory=chroma_dir,
        embedding_function=embeddings,
        collection_name=collection_name,
    )

    # Ajouter les chunks par lots avec barre de progression
    batch_size = 100
    batches = [splits[i:i + batch_size] for i in range(0, len(splits), batch_size)]
    for batch in tqdm(batches, desc="Indexation ChromaDB", unit="lot"):
        vectorstore.add_documents(batch)

    print(f"✅ Indexed {len(splits)} chunks → {chroma_dir} (collection: {collection_name})")
    return vectorstore


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Index ORL PDFs into ChromaDB")
    parser.add_argument("--pdf-folder", required=True, help="Dossier des PDF du corpus ORL")
    parser.add_argument("--chroma-dir", default=None)
    parser.add_argument("--collection", default="orl_knowledge_base")
    parser.add_argument("--chunk-size", type=int, default=500)
    parser.add_argument("--chunk-overlap", type=int, default=150)
    parser.add_argument("--reset", action="store_true", help="Drop existing collection before indexing")
    args = parser.parse_args()

    process_pdfs(
        pdf_folder=args.pdf_folder,
        chroma_dir=args.chroma_dir,
        collection_name=args.collection,
        chunk_size=args.chunk_size,
        chunk_overlap=args.chunk_overlap,
        reset=args.reset,
    )
