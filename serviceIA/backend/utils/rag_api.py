"""
KORAI ORL - Backend API v3
Séparation RAG (symptômes) + Vision (image) avec validation experte
Stockage sur Google Drive
"""
import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"
# Pas de télémétrie ChromaDB : ce service traite des données de santé.
os.environ.setdefault("ANONYMIZED_TELEMETRY", "False")

# Doit être importé avant onnxruntime/torch pour éviter un conflit pydantic.v1
from langchain_classic.chains import RetrievalQA

from dotenv import load_dotenv
load_dotenv()
import asyncio
import threading
import io
import json
import csv
import uuid
import sys
import logging
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict, Tuple, AsyncGenerator
import base64
import hmac
import re
from contextlib import asynccontextmanager

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

from PIL import Image
from fastapi import FastAPI, HTTPException, UploadFile, File, Form, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

# Google Drive imports
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseUpload
from google.auth.transport.requests import Request

def get_resource_path(relative_path):
    """ Récupère le chemin absolu des ressources (modèles, db) pour PyInstaller """
    try:
        # PyInstaller crée un dossier temporaire et stocke le chemin dans _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

# ================= PIPELINE IMAGE =================
from utils.orl_Inference_pipeline import load_model, predict_top3

# ================= LANGCHAIN / RAG (Version 1.2.10) =================
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_community.vectorstores import Chroma


# Le tokenizer Hugging Face refuse deux encodages simultanés (« Already borrowed ») : les analyses
# tournent dans des threads, les encodages passent donc un par un (quelques millisecondes chacun).
_EMBEDDING_LOCK = threading.Lock()


class _E5Embeddings(HuggingFaceEmbeddings):
    """
    Wraps intfloat/multilingual-e5-* to inject the mandatory
    'query: ' / 'passage: ' prefixes that the model was trained with.
    """
    def embed_query(self, text: str) -> list:
        # Appel direct de la classe parente : son embed_query passe par self.embed_documents, qui
        # ajoutait « passage: » devant « query: » (la question était encodée comme un passage).
        with _EMBEDDING_LOCK:
            return HuggingFaceEmbeddings.embed_documents(self, [f"query: {text}"])[0]

    def embed_documents(self, texts: list) -> list:
        with _EMBEDDING_LOCK:
            return HuggingFaceEmbeddings.embed_documents(self, [f"passage: {t}" for t in texts])
from langchain_mistralai import ChatMistralAI
from langchain_core.prompts import PromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough, RunnableParallel
from langchain_core.documents import Document
from langchain_classic.chains import RetrievalQA


# =====================================================================
# CONFIG
# =====================================================================
class Config:
    # Chemins des ressources - compatible PyInstaller avec --add-data
    PROJECT_DIR    = "KORAI-APP"
    CHROMA_DIR     = get_resource_path(f"{PROJECT_DIR}/chroma_db")
    COLLECTION     = "orl_knowledge_base"
    EMBEDDING_MODEL= "intfloat/multilingual-e5-base"
    # Modèle selon l'abonnement Mistral (mistral-large-latest n'est pas inclus dans tous les abonnements).
    LLM_MODEL      = os.getenv("MISTRAL_MODEL", "mistral-large-latest")
    # Délai d'une réponse et nouvelles tentatives : le backend Korai abandonne après
    # AI_SERVICE_TIMEOUT_MS, inutile de continuer au-delà.
    LLM_TIMEOUT_S  = int(os.getenv("MISTRAL_TIMEOUT_S", "40"))
    LLM_MAX_RETRIES= int(os.getenv("MISTRAL_MAX_RETRIES", "1"))
    MISTRAL_API_KEY= os.getenv("MISTRAL_API_KEY", "")
    MODEL_PATH     = get_resource_path("efficientnet.onnx")
    API_HOST       = os.getenv("API_HOST", "127.0.0.1")
    API_PORT       = int(os.getenv("API_PORT", "8000"))
    
    # Google Drive Configuration
    GOOGLE_DRIVE_ENABLED = os.getenv("GOOGLE_DRIVE_ENABLED", "false").lower() == "true"
    GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
    GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET", "")
    GOOGLE_REFRESH_TOKEN = os.getenv("GOOGLE_REFRESH_TOKEN", "")
    # Partage public des images Drive : désactivé par défaut (données de santé)
    GOOGLE_DRIVE_PUBLIC_LINKS = os.getenv("GOOGLE_DRIVE_PUBLIC_LINKS", "false").lower() == "true"
    # Origines autorisées (CORS), séparées par des virgules. "*" à éviter en production.
    ALLOWED_ORIGINS = [o.strip() for o in os.getenv("ALLOWED_ORIGINS", "http://localhost:5173").split(",") if o.strip()]
    # Jeton partagé avec le backend Korai. Défini : exigé sur toutes les routes sauf « / », « /health »
    # et la documentation. Vide : service ouvert, à réserver au développement sur 127.0.0.1.
    SERVICE_API_TOKEN = os.getenv("SERVICE_API_TOKEN", "").strip()
    # Cas gardés en mémoire pour la validation et l'export (0 = aucun : Korai conserve ses dossiers).
    CASE_HISTORY_SIZE = int(os.getenv("CASE_HISTORY_SIZE", "500"))
    MAX_CONVERSATIONS = 200
    MAX_UPLOAD_BYTES  = int(os.getenv("MAX_UPLOAD_MB", "10")) * 1024 * 1024
    # Texte de symptômes transmis à Mistral (au-delà : tronqué).
    MAX_SYMPTOMS_CHARS = 4000

CLASS_KEYWORDS: Dict[str, List[str]] = {
    "aspect post tympanoplastie": ["tympanoplastie", "greffe tympanique", "cicatrice"],
    "bouchon de cerumen":         ["cérumen", "bouchon", "obstruction"],
    "cholestéatome":              ["cholestéatome", "épiderme", "os pétreux"],
    "corps étranger oreille":    ["corps étranger", "objet", "oreille"],
    "myringosclerose":            ["myringosclérose", "tympanosclérose", "calcification"],
    "otomycose":                  ["otomycose", "candida", "aspergillus", "champignon"],
    "otite moyenne aigue":        ["otite", "otalgie", "fièvre", "otorrhée"],
    "otite séromuqueuse":         ["otite séromuqueuse", "épanchement", "colle"],
    "perforation tympanique":     ["perforation", "rupture tympan", "traumatisme"],
    "tympan normal":              ["tympan normal", "examen normal", "pas de pathologie"],
}

# Liste ordonnée des 10 pathologies valides (utilisée pour la collecte de dataset)
VALID_PATHOLOGIES = list(CLASS_KEYWORDS.keys())


# =====================================================================
# PYDANTIC MODELS
# =====================================================================
class ChatRequest(BaseModel):
    message: str
    show_sources: bool = False
    conversation_id: Optional[str] = None

class ChatResponse(BaseModel):
    response: str
    sources: Optional[List[Dict]] = None
    conversation_id: str
    timestamp: str

class VisionDiagnosticResponse(BaseModel):
    prediction: str
    confidence: float
    top3: List[Dict]
    timestamp: str

class RAGDiagnosticResponse(BaseModel):
    summary: str
    sources: Optional[List[Dict]]
    timestamp: str

class SeparateDiagnosticResponse(BaseModel):
    case_id: str
    timestamp: str
    vision: VisionDiagnosticResponse
    # Analyse des symptômes impossible (Mistral indisponible) : `rag` vide, `rag_error` renseigné,
    # la prédiction de l'image reste fournie.
    rag: Optional[RAGDiagnosticResponse] = None
    rag_error: Optional[str] = None
    requires_expert_validation: bool
    drive_image_url: Optional[str] = None
    drive_file_id: Optional[str] = None

class ExpertValidation(BaseModel):
    case_id: str
    expert_diagnosis: str
    expert_comment: Optional[str] = ""
    expert_id: Optional[str] = "anonymous"
    # L'expert peut choisir entre :
    # - valider le diagnostic vision
    # - valider le diagnostic RAG
    # - donner un tout nouveau diagnostic
    validated_prediction: Optional[str] = None  # La prédiction validée
    validation_source: str = "expert"  # "vision", "rag", or "expert"
    # Jugements séparés de l'expert (envoyés par le frontend VersionFinale)
    vision_validated: Optional[bool] = None
    rag_validated: Optional[bool] = None
    vision_comment: Optional[str] = None
    rag_comment: Optional[str] = None

class ExpertValidationResponse(BaseModel):
    case_id: str
    saved: bool
    message: str
    drive_export_url: Optional[str] = None

# ─────────────────────────────────────────────────────────────────────
# SIMPLE CHATBOT - Q&A conversationnel
# ─────────────────────────────────────────────────────────────────────
class SimpleChatRequest(BaseModel):
    question: str
    conversation_id: Optional[str] = None
    show_sources: bool = False

class SimpleChatResponse(BaseModel):
    answer: str
    conversation_id: str
    sources: Optional[List[Dict]] = None
    timestamp: str

class ConversationMessage(BaseModel):
    role: str  # "user" ou "assistant"
    content: str
    timestamp: str

class ConversationHistory(BaseModel):
    id: str
    messages: List[ConversationMessage]
    created_at: str
    last_updated: str

class DoctorChatRequest(BaseModel):
    question: str
    conversation_id: Optional[str] = None
    show_sources: bool = False


# =====================================================================
# GOOGLE DRIVE SERVICE
# =====================================================================
class GoogleDriveService:
    def __init__(self):
        self.drive_service = None
        self.folder_id = None
        if Config.GOOGLE_DRIVE_ENABLED:
            self.initialize()

    def initialize(self):
        try:
            credentials = Credentials(
                token=None,
                refresh_token=Config.GOOGLE_REFRESH_TOKEN,
                token_uri="https://oauth2.googleapis.com/token",
                client_id=Config.GOOGLE_CLIENT_ID,
                client_secret=Config.GOOGLE_CLIENT_SECRET
            )
            
            # Rafraîchir le token si nécessaire
            if credentials.expired:
                credentials.refresh(Request())
            
            self.drive_service = build('drive', 'v3', credentials=credentials)
            self.create_or_get_main_folder()
            logger.info("✅ Google Drive initialisé avec succès")
        except Exception as e:
            logger.error(f"❌ Erreur initialisation Drive: {e}")
            Config.GOOGLE_DRIVE_ENABLED = False

    def create_or_get_main_folder(self):
        try:
            # Chercher le dossier existant
            response = self.drive_service.files().list(
                q="name='KORAI-Medical' and mimeType='application/vnd.google-apps.folder' and trashed=false",
                fields="files(id, name)"
            ).execute()
            
            if response.get('files'):
                self.folder_id = response['files'][0]['id']
                logger.info(f"📁 Dossier existant: {self.folder_id}")
            else:
                # Créer le dossier
                file_metadata = {
                    'name': 'KORAI-Medical',
                    'mimeType': 'application/vnd.google-apps.folder'
                }
                file = self.drive_service.files().create(body=file_metadata, fields='id').execute()
                self.folder_id = file.get('id')
                logger.info(f"📁 Nouveau dossier créé: {self.folder_id}")
            
            # Créer les sous-dossiers
            self.create_subfolder('cases')
            self.create_subfolder('validations')
            self.create_subfolder('exports')
            
        except Exception as e:
            logger.error(f"Erreur création dossier: {e}")

    def create_subfolder(self, folder_name):
        try:
            response = self.drive_service.files().list(
                q=f"name='{folder_name}' and '{self.folder_id}' in parents and trashed=false",
                fields="files(id)"
            ).execute()
            
            if not response.get('files'):
                file_metadata = {
                    'name': folder_name,
                    'mimeType': 'application/vnd.google-apps.folder',
                    'parents': [self.folder_id]
                }
                self.drive_service.files().create(body=file_metadata, fields='id').execute()
                logger.info(f"📁 Sous-dossier créé: {folder_name}")
        except Exception as e:
            logger.error(f"Erreur création sous-dossier {folder_name}: {e}")

    def upload_image(self, image_bytes: bytes, filename: str, case_id: str) -> Tuple[Optional[str], Optional[str]]:
        if not self.drive_service:
            return None, None
        
        try:
            # Créer dossier par date
            date_folder = datetime.now().strftime("%Y/%m/%d")
            date_path = date_folder.split('/')
            
            current_parent = self.folder_id
            for folder in date_path:
                current_parent = self.get_or_create_subfolder(current_parent, folder)
            
            # Upload de l'image
            media = MediaIoBaseUpload(
                io.BytesIO(image_bytes),
                mimetype='image/jpeg',
                resumable=True
            )
            
            file_metadata = {
                'name': filename,
                'parents': [current_parent]
            }
            
            file = self.drive_service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id, webViewLink'
            ).execute()
            
            file_id = file.get('id')
            view_link = file.get('webViewLink')
            
            if Config.GOOGLE_DRIVE_PUBLIC_LINKS:
                self.drive_service.permissions().create(
                    fileId=file_id,
                    body={'type': 'anyone', 'role': 'reader'}
                ).execute()
            
            direct_link = f"https://drive.google.com/uc?export=view&id={file_id}"
            
            logger.info(f"✅ Image uploadée: {filename} (ID: {file_id})")
            return file_id, direct_link
            
        except Exception as e:
            logger.error(f"Erreur upload image: {e}")
            return None, None

    def get_or_create_subfolder(self, parent_id: str, folder_name: str) -> str:
        try:
            response = self.drive_service.files().list(
                q=f"name='{folder_name}' and '{parent_id}' in parents and trashed=false",
                fields="files(id)"
            ).execute()
            
            if response.get('files'):
                return response['files'][0]['id']
            
            file_metadata = {
                'name': folder_name,
                'mimeType': 'application/vnd.google-apps.folder',
                'parents': [parent_id]
            }
            file = self.drive_service.files().create(body=file_metadata, fields='id').execute()
            return file.get('id')
        except Exception as e:
            logger.error(f"Erreur création dossier {folder_name}: {e}")
            return parent_id

    def upload_dataset_image(self, image_bytes: bytes, filename: str, pathology: str) -> Tuple[Optional[str], Optional[str]]:
        """Upload une image dans KORAI-Medical/dataset/{pathologie}/ pour enrichir le dataset."""
        if not self.drive_service:
            return None, None
        try:
            dataset_folder = self.get_or_create_subfolder(self.folder_id, 'dataset')
            pathology_folder = self.get_or_create_subfolder(dataset_folder, pathology)

            media = MediaIoBaseUpload(
                io.BytesIO(image_bytes),
                mimetype='image/jpeg',
                resumable=True
            )
            file_metadata = {'name': filename, 'parents': [pathology_folder]}
            file = self.drive_service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id, webViewLink'
            ).execute()

            file_id = file.get('id')
            if Config.GOOGLE_DRIVE_PUBLIC_LINKS:
                self.drive_service.permissions().create(
                    fileId=file_id,
                    body={'type': 'anyone', 'role': 'reader'}
                ).execute()

            direct_link = f"https://drive.google.com/uc?export=view&id={file_id}"
            logger.info(f"✅ Dataset: {filename} → dataset/{pathology}/")
            return file_id, direct_link
        except Exception as e:
            logger.error(f"Erreur upload dataset image: {e}")
            return None, None

    def save_validation_data(self, case_data: Dict, filename: str) -> Optional[str]:
        if not self.drive_service:
            return None
        
        try:
            exports_folder = self.get_or_create_subfolder(self.folder_id, 'exports')
            
            json_content = json.dumps(case_data, ensure_ascii=False, indent=2, default=str)
            media = MediaIoBaseUpload(
                io.BytesIO(json_content.encode('utf-8')),
                mimetype='application/json',
                resumable=True
            )
            
            file_metadata = {
                'name': filename,
                'parents': [exports_folder]
            }
            
            file = self.drive_service.files().create(
                body=file_metadata,
                media_body=media,
                fields='webViewLink'
            ).execute()
            
            logger.info(f"✅ Validation sauvegardée: {filename}")
            return file.get('webViewLink')
            
        except Exception as e:
            logger.error(f"Erreur sauvegarde validation: {e}")
            return None


# =====================================================================
# CHATBOT ORL (RAG)
# =====================================================================
_CONSULTATION_PROMPT = PromptTemplate(
    template="""Tu es KORAI, un assistant médical ORL utilisé en consultation.

RÈGLE ABSOLUE ANTI-HALLUCINATION :
Réponds UNIQUEMENT à partir des informations du CONTEXTE MÉDICAL fourni ci-dessous.
Si une information est absente du contexte, réponds exactement : "Non documenté dans la base ORL."
N'utilise jamais tes connaissances générales pour compléter une réponse.

FORMAT (terminologie médicale précise, pas de markdown, pas de titres en gras) :
1. Causes probables : les 2-3 pathologies probables avec explication brève
2. Signes associés : symptômes et signes cliniques attendus
3. Conduite à tenir : traitement et suivi recommandé ainsi que les types de médicaments à prescrire

CONTEXTE MÉDICAL :
{context}

QUESTION / SYMPTÔMES :
{question}

RÉPONSE (basée exclusivement sur le contexte) :
""",
    input_variables=["context", "question"],
)

_DOCTOR_PROMPT = PromptTemplate(
    template="""Tu es KORAI, un assistant médical ORL expert. Réponds à la question de façon naturelle, en paragraphes fluides, comme un collègue médecin expérimenté qui explique oralement. Ne numérote pas, n'utilise ni tirets ni listes, n'écris pas de titres. Rédige directement ta réponse sans formule d'introduction.

Appuie-toi sur le CONTEXTE DOCUMENTAIRE ci-dessous. Si le contexte est insuffisant pour un point précis, complète avec tes connaissances médicales en le signalant par [KG]. Longueur adaptée à la question.
Donne les sources si possible.

CONTEXTE DOCUMENTAIRE :
{context}

QUESTION :
{question}

RÉPONSE :
""",
    input_variables=["context", "question"],
)


def _source_reference(metadata: Dict) -> Tuple[str, Optional[object]]:
    """
    Nom du document et page imprimée. La base a été indexée sous Windows : `source` contient le
    chemin complet du poste de l'auteur (C:\\Users\\…), qui ne doit pas sortir du service.
    """
    name = metadata.get("filename") or re.split(r"[\\/]", str(metadata.get("source") or ""))[-1]
    page = metadata.get("page_label")
    if page in (None, ""):
        raw = metadata.get("page")
        page = raw + 1 if isinstance(raw, int) else raw  # `page` commence à 0
    return name, page


class ORLChatbot:
    def __init__(self):
        self.vectorstore: Optional[Chroma] = None
        self.qa_chain = None           # consultation : court, strict, anti-hallucination
        self.qa_chain_doctor = None    # médecin : libre, long, peut utiliser connaissances générales
        self._init_rag()

    def _init_rag(self):
        os.environ["MISTRAL_API_KEY"] = Config.MISTRAL_API_KEY

        print("📚 Chargement des embeddings (multilingual-e5-base)...")
        try:
            embeddings = _E5Embeddings(
                model_name=Config.EMBEDDING_MODEL,
                model_kwargs={"device": "cpu"},
                encode_kwargs={"normalize_embeddings": True},
            )
            print("✅ Embeddings chargés avec succès")
        except Exception as e:
            print(f"❌ Erreur lors du chargement des embeddings: {e}")
            raise

        persist_dir = Config.CHROMA_DIR
        if not os.path.exists(persist_dir):
            error_msg = f"Chroma DB introuvable : {persist_dir}\nChemin absolu attendu: {os.path.abspath(persist_dir)}"
            print(f"❌ {error_msg}")
            raise RuntimeError(error_msg)

        print(f"🔍 Connexion à Chroma DB: {persist_dir} (collection: {Config.COLLECTION})")
        try:
            self.vectorstore = Chroma(
                persist_directory=persist_dir,
                embedding_function=embeddings,
                collection_name=Config.COLLECTION,
            )
            print("✅ Chroma DB connectée avec succès")
        except Exception as e:
            print(f"❌ Erreur de connexion à Chroma DB: {e}")
            raise

        # MMR : k=6 résultats finaux parmi fetch_k=25 candidats, lambda=0.7 (pertinence > diversité)
        self.retriever = self.vectorstore.as_retriever(
            search_type="mmr",
            search_kwargs={"k": 6, "fetch_k": 25, "lambda_mult": 0.7},
        )

        print(f"🤖 Initialisation des modèles Mistral ({Config.LLM_MODEL})...")
        # 1500 jetons : à 1000, les réponses en trois parties étaient coupées en pleine phrase.
        llm_consultation = ChatMistralAI(
            model=Config.LLM_MODEL,
            temperature=0.0,   # déterministe pour éviter les hallucinations
            max_tokens=1500,
            timeout=Config.LLM_TIMEOUT_S,
            max_retries=Config.LLM_MAX_RETRIES,
        )
        self.llm_doctor = ChatMistralAI(
            model=Config.LLM_MODEL,
            temperature=0.2,
            max_tokens=1500,
            timeout=Config.LLM_TIMEOUT_S,
            max_retries=Config.LLM_MAX_RETRIES,
        )
        llm_doctor = self.llm_doctor

        self.qa_chain = RetrievalQA.from_chain_type(
            llm=llm_consultation,
            retriever=self.retriever,
            chain_type="stuff",
            chain_type_kwargs={"prompt": _CONSULTATION_PROMPT},
            return_source_documents=True,
        )
        self.qa_chain_doctor = RetrievalQA.from_chain_type(
            llm=llm_doctor,
            retriever=self.retriever,
            chain_type="stuff",
            chain_type_kwargs={"prompt": _DOCTOR_PROMPT},
            return_source_documents=True,
        )

        print("✅ Chatbot ORL RAG initialisé avec succès")

    def _extract(self, result: Dict, show_sources: bool) -> Dict:
        answer = result["result"]
        for char in ["**", "*", "_", "•"]:
            answer = answer.replace(char, "")
        answer = answer.strip()

        raw_context = " ".join([doc.page_content for doc in result.get("source_documents", [])])

        sources = None
        if show_sources:
            def _preview(text: str, limit: int = 400) -> str:
                if len(text) <= limit:
                    return text
                cut = text[:limit].rsplit(' ', 1)[0]
                return cut + '…'

            sources = []
            for doc in result.get("source_documents", [])[:3]:
                name, page = _source_reference(doc.metadata)
                sources.append({"source": name, "page": page, "content": _preview(doc.page_content)})

        return {"response": answer, "sources": sources, "raw_context": raw_context}

    def query(self, message: str, show_sources: bool = False) -> Dict:
        """Consultation mode — short, strict, anti-hallucination."""
        result = self.qa_chain.invoke({"query": message})
        return self._extract(result, show_sources)

    def doctor_query(self, question: str, show_sources: bool = False) -> Dict:
        """Doctor mode — comprehensive, may supplement with general knowledge."""
        result = self.qa_chain_doctor.invoke({"query": question})
        return self._extract(result, show_sources)

    async def stream_doctor_query(self, question: str) -> AsyncGenerator[str, None]:
        """Async generator: streams LLM tokens as SSE via a sync thread (Windows DNS fix)."""
        # 1. Retrieve context in thread pool (blocking operation)
        docs = await asyncio.to_thread(lambda: self.retriever.invoke(question))

        # 2. Build prompt
        context = "\n\n".join(doc.page_content for doc in docs)
        prompt_text = _DOCTOR_PROMPT.format(context=context, question=question)

        # 3. Stream tokens via sync stream() in a background thread.
        #    astream() fails on Windows due to httpx async DNS resolution (getaddrinfo).
        #    stream() uses the standard requests stack which resolves correctly.
        loop = asyncio.get_running_loop()
        queue: asyncio.Queue = asyncio.Queue()
        _strip = ["**", "*", "_", "•"]

        def _sync_worker():
            try:
                for chunk in self.llm_doctor.stream(prompt_text):
                    token = getattr(chunk, "content", "") or ""
                    for ch in _strip:
                        token = token.replace(ch, "")
                    if token:
                        loop.call_soon_threadsafe(queue.put_nowait, token)
            except Exception as exc:
                loop.call_soon_threadsafe(queue.put_nowait, f"__ERR__:{exc}")
            finally:
                loop.call_soon_threadsafe(queue.put_nowait, None)

        threading.Thread(target=_sync_worker, daemon=True).start()

        while True:
            token = await queue.get()
            if token is None:
                break
            if isinstance(token, str) and token.startswith("__ERR__:"):
                logger.error(f"[Stream] {token}")
                break
            yield f"data: {json.dumps({'token': token, 'done': False})}\n\n"

        # 4. Final event with sources
        sources = []
        for doc in docs[:3]:
            name, page = _source_reference(doc.metadata)
            sources.append({"source": name or "Document ORL", "page": page})
        yield f"data: {json.dumps({'token': '', 'done': True, 'sources': sources})}\n\n"


# =====================================================================
# FASTAPI APP
# =====================================================================
# Accessibles sans jeton : état du service, documentation interactive (/docs permet de saisir le jeton
# via « Authorize ») et interface web compilée servie sous /app.
_PUBLIC_PATHS = {"/", "/health", "/docs", "/docs/oauth2-redirect", "/redoc", "/openapi.json"}


def _is_public_path(path: str) -> bool:
    return path in _PUBLIC_PATHS or path == "/app" or path.startswith("/app/")


class ServiceTokenMiddleware:
    """
    Refuse toute requête sans le jeton partagé (SERVICE_API_TOKEN), AVANT la lecture du corps :
    un inconnu ne peut ni lancer d'analyse (crédit Mistral), ni lire les cas, ni faire décoder un envoi.
    """

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        token = Config.SERVICE_API_TOKEN
        if scope["type"] != "http" or not token or _is_public_path(scope["path"]):
            await self.app(scope, receive, send)
            return
        authorization = dict(scope["headers"]).get(b"authorization", b"").decode("latin-1")
        scheme, _, supplied = authorization.partition(" ")
        if scheme.lower() == "bearer" and hmac.compare_digest(supplied.strip().encode(), token.encode()):
            await self.app(scope, receive, send)
            return
        response = JSONResponse(
            {"detail": "Jeton d'accès au service IA manquant ou invalide."},
            status_code=401,
            headers={"WWW-Authenticate": "Bearer"},
        )
        await response(scope, receive, send)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    _startup()
    yield


app = FastAPI(
    title="KORAI ORL API v3",
    version="3.0.0",
    lifespan=lifespan,
    # Bouton « Authorize » de /docs ; le contrôle réel est fait par ServiceTokenMiddleware.
    dependencies=[Depends(HTTPBearer(auto_error=False))],
)

# Le dernier middleware ajouté est le plus extérieur : CORS enveloppe le contrôle du jeton pour que
# les refus (401) restent lisibles par un navigateur.
app.add_middleware(ServiceTokenMiddleware)

# Configuration CORS robuste pour multipart/form-data
app.add_middleware(
    CORSMiddleware,
    allow_origins=Config.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=[
        "Content-Type",
        "Authorization",
        "Accept",
        "Origin",
        "Access-Control-Allow-Headers",
    ],
    expose_headers=["Content-Disposition"],
    max_age=600,
)

chatbot: Optional[ORLChatbot] = None
dl_model = None
case_store: Dict[str, Dict] = {}
drive_service: Optional[GoogleDriveService] = None
conversation_history: Dict[str, List[Dict]] = {}  # Historique des conversations

# Messages renvoyés au client : le détail technique (quota, clé, modèle, réseau) reste dans les
# journaux du service.
RAG_UNAVAILABLE = "L'analyse des symptômes est indisponible pour le moment."
INTERNAL_ERROR = "Erreur interne du service IA."


def _remember_case(case_id: str, case: Dict) -> None:
    """Garde au plus CASE_HISTORY_SIZE cas en mémoire (les plus anciens sont oubliés)."""
    if Config.CASE_HISTORY_SIZE <= 0:
        return
    case_store[case_id] = case
    while len(case_store) > Config.CASE_HISTORY_SIZE:
        case_store.pop(next(iter(case_store)))


def _conversation(conv_id: str) -> List[Dict]:
    """Historique d'une conversation ; au-delà de MAX_CONVERSATIONS, la plus ancienne est oubliée."""
    if conv_id not in conversation_history:
        conversation_history[conv_id] = []
        while len(conversation_history) > Config.MAX_CONVERSATIONS:
            conversation_history.pop(next(iter(conversation_history)))
    return conversation_history[conv_id]


async def _read_image(file: UploadFile) -> bytes:
    """Lit l'image envoyée, sans dépasser MAX_UPLOAD_MB."""
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Fichier image requis (jpg, png, webp…)")
    contents = await file.read(Config.MAX_UPLOAD_BYTES + 1)
    if len(contents) > Config.MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Image trop lourde (maximum {Config.MAX_UPLOAD_BYTES // (1024 * 1024)} Mo).",
        )
    return contents


def _predict_vision(contents: bytes) -> VisionDiagnosticResponse:
    """Décodage + inférence ONNX (bloquant : appelé dans un thread)."""
    try:
        image = Image.open(io.BytesIO(contents)).convert("RGB")
    except Exception:
        raise HTTPException(status_code=400, detail="Image illisible : envoyez une photo JPEG, PNG ou WebP.")
    top3 = [
        {"class": str(pred["class"]), "confidence": float(pred["confidence"])}
        for pred in predict_top3(dl_model, image)
    ]
    return VisionDiagnosticResponse(
        prediction=top3[0]["class"],
        confidence=top3[0]["confidence"],
        top3=top3,
        timestamp=datetime.now().isoformat(),
    )


# =====================================================================
# STARTUP
# =====================================================================
def _startup():
    global chatbot, dl_model, drive_service

    print("🚀 Démarrage KORAI ORL v3 (RAG + Vision séparés)")
    if not Config.SERVICE_API_TOKEN:
        logger.warning(
            "⚠️ SERVICE_API_TOKEN non défini : toutes les routes sont ouvertes. "
            "À définir avant toute exposition (ngrok, serveur)."
        )

    try:
        chatbot = ORLChatbot()
        print("✅ Chatbot RAG initialisé")
        
        model_path = Config.MODEL_PATH
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Modèle ONNX non trouvé: {model_path}")
        
        dl_model = load_model(model_path)
        print(f"✅ EfficientNetB0 ONNX chargé depuis: {model_path}")
        
        # Initialiser Google Drive si configuré
        if Config.GOOGLE_DRIVE_ENABLED:
            drive_service = GoogleDriveService()
        
        print("✅ Système KORAI v3 prêt")
    except Exception as e:
        print(f"❌ Erreur au démarrage: {e}")
        raise


# =====================================================================
# ROUTES
# =====================================================================

@app.get("/")
async def root():
    return {"status": "running", "version": "3.0.0", "drive_enabled": Config.GOOGLE_DRIVE_ENABLED}

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "chatbot_ready": chatbot is not None,
        "model_ready": dl_model is not None,
        "drive_ready": Config.GOOGLE_DRIVE_ENABLED and drive_service is not None,
        "llm_model": Config.LLM_MODEL,
        "auth_required": bool(Config.SERVICE_API_TOKEN),
    }

@app.post("/chat")
async def chat_endpoint(req: ChatRequest):
    if chatbot is None:
        raise HTTPException(status_code=503, detail="Chatbot non prêt")

    conv_id = req.conversation_id or datetime.now().strftime("%Y%m%d_%H%M%S")
    try:
        result = await asyncio.to_thread(chatbot.query, req.message, req.show_sources)
    except Exception:
        logger.exception("Erreur dans /chat")
        raise HTTPException(status_code=502, detail=RAG_UNAVAILABLE)

    return ChatResponse(
        response=result["response"],
        sources=result["sources"],
        conversation_id=conv_id,
        timestamp=datetime.now().isoformat()
    )

@app.post("/chat/simple")
async def simple_chat_endpoint(req: SimpleChatRequest):
    """
    Route simplifiée pour chatbot Q&A avec gestion d'historique
    - Valide l'entrée
    - Gère l'historique conversationnel
    - Retourne une réponse structurée
    """
    if chatbot is None:
        raise HTTPException(status_code=503, detail="Chatbot non prêt")
    
    # ── Validation ──────────────────────────────────────────
    question = req.question.strip()
    if not question:
        raise HTTPException(status_code=400, detail="Question vide")
    if len(question) < 3:
        raise HTTPException(status_code=400, detail="Question trop courte (min 3 caractères)")
    if len(question) > 2000:
        question = question[:2000]
        logger.warning(f"Question tronquée à 2000 caractères")
    
    # ── Initialiser/récupérer conversation ───────────────────
    conv_id = req.conversation_id or str(uuid.uuid4())[:12].upper()
    history = _conversation(conv_id)

    # ── Ajouter la question à l'historique ───────────────────
    now_iso = datetime.now().isoformat()
    history.append({
        "role": "user",
        "content": question,
        "timestamp": now_iso
    })

    # Jamais le texte de la question dans les journaux (données de santé possibles)
    logger.info(f"[Chat Simple] Conv:{conv_id} | question de {len(question)} caractères")

    try:
        # ── Interroger le RAG ───────────────────────────────
        result = await asyncio.to_thread(chatbot.doctor_query, question, req.show_sources)
        answer = result["response"]

        # ── Ajouter la réponse à l'historique ───────────────
        history.append({
            "role": "assistant",
            "content": answer,
            "timestamp": datetime.now().isoformat()
        })

        # ── Limiter l'historique à 50 messages (25 tours) ────
        if len(history) > 50:
            del history[:-50]

        logger.info(f"[Chat Simple] Conv:{conv_id} ✅ | Réponse: {len(answer)} chars")

        return SimpleChatResponse(
            answer=answer,
            conversation_id=conv_id,
            sources=result["sources"],
            timestamp=now_iso
        )

    except Exception:
        logger.exception(f"[Chat Simple] Conv:{conv_id} ❌ échec de l'analyse")
        raise HTTPException(status_code=502, detail=RAG_UNAVAILABLE)

@app.post("/chat/stream")
async def stream_chat_endpoint(req: SimpleChatRequest):
    """Route streaming SSE — envoie les tokens Mistral au fil de leur génération."""
    if chatbot is None:
        raise HTTPException(status_code=503, detail="Chatbot non prêt")
    question = req.question.strip()
    if not question:
        raise HTTPException(status_code=400, detail="Question vide")

    return StreamingResponse(
        chatbot.stream_doctor_query(question),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )

@app.get("/chat/history/{conversation_id}")
async def get_conversation_history(conversation_id: str):
    """
    Récupère l'historique d'une conversation
    """
    if conversation_id not in conversation_history:
        raise HTTPException(status_code=404, detail=f"Conversation {conversation_id} introuvable")
    
    messages = conversation_history[conversation_id]
    return {
        "conversation_id": conversation_id,
        "message_count": len(messages),
        "messages": messages,
        "created_at": messages[0]["timestamp"] if messages else datetime.now().isoformat(),
        "last_updated": messages[-1]["timestamp"] if messages else datetime.now().isoformat()
    }

@app.delete("/chat/history/{conversation_id}")
async def clear_conversation_history(conversation_id: str):
    """
    Supprime l'historique d'une conversation
    """
    if conversation_id not in conversation_history:
        raise HTTPException(status_code=404, detail=f"Conversation {conversation_id} introuvable")

    del conversation_history[conversation_id]
    logger.info(f"Historique supprimé: {conversation_id}")

    return {"status": "deleted", "conversation_id": conversation_id}

@app.post("/chat/doctor", response_model=SimpleChatResponse)
async def doctor_chat_endpoint(req: DoctorChatRequest):
    """
    Chatbot libre pour le médecin — réponses longues, exhaustives.
    Peut compléter avec ses connaissances générales (signalé par [KG]).
    Pas de structure imposée : adapté aux questions sur les pathologies,
    les protocoles, les médicaments, les références bibliographiques, etc.
    """
    if chatbot is None:
        raise HTTPException(status_code=503, detail="Chatbot non prêt")

    question = req.question.strip()
    if not question:
        raise HTTPException(status_code=400, detail="Question vide")
    if len(question) > 4000:
        question = question[:4000]

    conv_id = req.conversation_id or str(uuid.uuid4())[:12].upper()
    history = _conversation(conv_id)

    now_iso = datetime.now().isoformat()
    history.append({"role": "user", "content": question, "timestamp": now_iso})

    # Jamais le texte de la question dans les journaux (données de santé possibles)
    logger.info(f"[Doctor] Conv:{conv_id} | question de {len(question)} caractères")

    try:
        result = await asyncio.to_thread(chatbot.doctor_query, question, req.show_sources)
        answer = result["response"]

        history.append({"role": "assistant", "content": answer, "timestamp": datetime.now().isoformat()})
        if len(history) > 100:
            del history[:-100]

        logger.info(f"[Doctor] Conv:{conv_id} ✅ | Réponse: {len(answer)} chars")

        return SimpleChatResponse(
            answer=answer,
            conversation_id=conv_id,
            sources=result["sources"],
            timestamp=now_iso,
        )

    except Exception:
        logger.exception(f"[Doctor] Conv:{conv_id} ❌ échec de l'analyse")
        raise HTTPException(status_code=502, detail=RAG_UNAVAILABLE)

@app.post("/vision/predict")
async def vision_predict(file: UploadFile = File(...)):
    """Prédiction UNIQUEMENT par le modèle de vision"""
    if dl_model is None:
        raise HTTPException(status_code=503, detail="Modèle non chargé")
    contents = await _read_image(file)
    try:
        return await asyncio.to_thread(_predict_vision, contents)
    except HTTPException:
        raise
    except Exception:
        logger.exception("Erreur dans /vision/predict")
        raise HTTPException(status_code=500, detail=INTERNAL_ERROR)

@app.post("/rag/analyze")
async def rag_analyze(symptoms: str = Form(...), show_sources: bool = Form(False)):
    """Analyse UNIQUEMENT par RAG (symptômes)"""
    if chatbot is None:
        raise HTTPException(status_code=503, detail="Chatbot non prêt")

    try:
        result = await asyncio.to_thread(chatbot.query, symptoms[:Config.MAX_SYMPTOMS_CHARS], show_sources)
    except Exception:
        logger.exception("Erreur dans /rag/analyze")
        raise HTTPException(status_code=502, detail=RAG_UNAVAILABLE)

    return RAGDiagnosticResponse(
        summary=result["response"],
        sources=result["sources"],
        timestamp=datetime.now().isoformat()
    )

@app.post("/diagnose-separate")
async def diagnose_separate(
    symptoms: str = Form(...),
    show_sources: bool = Form(False),
    file: UploadFile = File(...),
):
    """
    Diagnostic SÉPARÉ :
    - Vision → prédiction image
    - RAG → analyse symptômes
    Pas de fusion, l'expert verra les deux côte à côte. Si l'analyse des symptômes échoue, la
    prédiction de l'image est quand même renvoyée (`rag` vide, `rag_error` renseigné).
    """
    if chatbot is None or dl_model is None:
        raise HTTPException(status_code=503, detail="Système non prêt")

    contents = await _read_image(file)

    # 1. Prédiction Vision (dans un thread : le serveur continue de répondre pendant l'analyse)
    try:
        vision_diagnostic = await asyncio.to_thread(_predict_vision, contents)
    except HTTPException:
        raise
    except Exception:
        logger.exception("Erreur vision dans /diagnose-separate")
        raise HTTPException(status_code=500, detail=INTERNAL_ERROR)

    # 2. Analyse RAG : son échec ne fait pas perdre la prédiction de l'image
    rag_diagnostic: Optional[RAGDiagnosticResponse] = None
    rag_error: Optional[str] = None
    try:
        rag_result = await asyncio.to_thread(chatbot.query, symptoms[:Config.MAX_SYMPTOMS_CHARS], show_sources)
        rag_diagnostic = RAGDiagnosticResponse(
            summary=rag_result["response"],
            sources=rag_result["sources"],
            timestamp=datetime.now().isoformat()
        )
    except Exception:
        logger.exception("Analyse des symptômes impossible dans /diagnose-separate")
        rag_error = RAG_UNAVAILABLE

    # 3. Stockage sur Google Drive
    case_id = str(uuid.uuid4())[:8].upper()
    drive_image_url = None
    drive_file_id = None

    if drive_service and Config.GOOGLE_DRIVE_ENABLED:
        filename = f"case_{case_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
        drive_file_id, drive_image_url = await asyncio.to_thread(drive_service.upload_image, contents, filename, case_id)

    # 4. Stockage local (borné, désactivable avec CASE_HISTORY_SIZE=0)
    timestamp = datetime.now().isoformat()
    _remember_case(case_id, {
        "case_id": case_id,
        "timestamp": timestamp,
        "symptoms": symptoms,
        "vision": {
            "prediction": vision_diagnostic.prediction,
            "confidence": vision_diagnostic.confidence,
            "top3": vision_diagnostic.top3
        },
        "rag": {
            "summary": rag_diagnostic.summary,
            "sources": rag_diagnostic.sources
        } if rag_diagnostic else None,
        "drive_image_url": drive_image_url,
        "drive_file_id": drive_file_id,
        "validation": None,
        "requires_expert_validation": True  # Toujours vrai car on veut validation experte
    })

    return SeparateDiagnosticResponse(
        case_id=case_id,
        timestamp=timestamp,
        vision=vision_diagnostic,
        rag=rag_diagnostic,
        rag_error=rag_error,
        requires_expert_validation=True,
        drive_image_url=drive_image_url,
        drive_file_id=drive_file_id
    )

@app.post("/validate", response_model=ExpertValidationResponse)
async def expert_validate(validation: ExpertValidation):
    """
    Validation par expert ORL
    L'expert peut voir les deux diagnostics (vision et RAG) et donner le bon
    """
    if validation.case_id not in case_store:
        raise HTTPException(status_code=404, detail=f"Cas {validation.case_id} introuvable")
    
    case = case_store[validation.case_id]
    
    # Déterminer le diagnostic validé
    validated_diagnosis = validation.expert_diagnosis
    
    # Sauvegarde de la validation
    validation_data = {
        "expert_id": validation.expert_id,
        "expert_diagnosis": validation.expert_diagnosis,
        "expert_comment": validation.expert_comment,
        "validated_at": datetime.now().isoformat(),
        "vision_original": case["vision"]["prediction"],
        "rag_original": ((case.get("rag") or {}).get("summary") or "")[:200],  # Extrait
        "vision_confidence": case["vision"]["confidence"],
        "validation_source": validation.validation_source,
        "vision_validated": validation.vision_validated,
        "rag_validated": validation.rag_validated,
        "vision_comment": validation.vision_comment,
        "rag_comment": validation.rag_comment,
    }
    
    case["validation"] = validation_data
    
    # Sauvegarde sur Google Drive
    drive_export_url = None
    if drive_service and Config.GOOGLE_DRIVE_ENABLED:
        export_filename = f"validation_{validation.case_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        export_data = {
            "case_id": validation.case_id,
            "original_data": case,
            "validation": validation_data
        }
        
        drive_export_url = await asyncio.to_thread(drive_service.save_validation_data, export_data, export_filename)
    
    status = "validé" if validation.validation_source == "expert" else "confirmé"
    message = f"Diagnostic {status} par l'expert {validation.expert_id}"
    
    if not validation.expert_diagnosis == case["vision"]["prediction"]:
        message += f" (correction: {case['vision']['prediction']} → {validation.expert_diagnosis})"
    
    return ExpertValidationResponse(
        case_id=validation.case_id,
        saved=True,
        message=message,
        drive_export_url=drive_export_url
    )

@app.post("/validate-batch")
async def expert_validate_batch(validations: List[ExpertValidation]):
    """Validation en lot de plusieurs cas"""
    results = []
    for validation in validations:
        try:
            result = await expert_validate(validation)
            results.append({"case_id": validation.case_id, "status": "success"})
        except HTTPException as e:
            results.append({"case_id": validation.case_id, "status": "error", "error": e.detail})
        except Exception:
            logger.exception("Erreur dans /validate-batch")
            results.append({"case_id": validation.case_id, "status": "error", "error": INTERNAL_ERROR})
    
    return {"total": len(validations), "results": results}

@app.get("/export/json/{case_id}")
async def export_case_json(case_id: str):
    """Exporter un cas spécifique en JSON"""
    if case_id not in case_store:
        raise HTTPException(status_code=404, detail=f"Cas {case_id} introuvable")
    
    content = json.dumps(case_store[case_id], ensure_ascii=False, indent=2, default=str)
    return StreamingResponse(
        io.BytesIO(content.encode("utf-8")),
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="case_{case_id}.json"'}
    )

@app.get("/export/all/json")
async def export_all_json(validated_only: bool = True):
    """Exporter tous les cas en JSON"""
    data = list(case_store.values())
    if validated_only:
        data = [c for c in data if c.get("validation") is not None]
    
    filename = f"korai_cases_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    content = json.dumps(data, ensure_ascii=False, indent=2, default=str)
    
    return StreamingResponse(
        io.BytesIO(content.encode("utf-8")),
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'}
    )

@app.get("/export/all/csv")
async def export_all_csv(validated_only: bool = True):
    """Exporter tous les cas en CSV"""
    data = list(case_store.values())
    if validated_only:
        data = [c for c in data if c.get("validation") is not None]
    
    output = io.StringIO()
    fieldnames = [
        "case_id", "timestamp", "symptoms",
        "vision_prediction", "vision_confidence",
        "vision_top3",
        "rag_summary",
        "drive_image_url",
        "expert_diagnosis", "expert_comment", "expert_id", "validated_at"
    ]
    writer = csv.DictWriter(output, fieldnames=fieldnames)
    writer.writeheader()
    
    for case in data:
        v = case.get("validation") or {}
        writer.writerow({
            "case_id": case["case_id"],
            "timestamp": case["timestamp"],
            "symptoms": case["symptoms"],
            "vision_prediction": case["vision"]["prediction"],
            "vision_confidence": case["vision"]["confidence"],
            "vision_top3": json.dumps(case["vision"]["top3"]),
            "rag_summary": (case.get("rag") or {}).get("summary", ""),
            "drive_image_url": case.get("drive_image_url", ""),
            "expert_diagnosis": v.get("expert_diagnosis", ""),
            "expert_comment": v.get("expert_comment", ""),
            "expert_id": v.get("expert_id", ""),
            "validated_at": v.get("validated_at", ""),
        })
    
    filename = f"korai_cases_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    output.seek(0)
    return StreamingResponse(
        io.BytesIO(output.getvalue().encode("utf-8")),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'}
    )

@app.get("/cases")
async def list_cases(validated_only: bool = False):
    """Lister tous les cas"""
    data = list(case_store.values())
    if validated_only:
        data = [c for c in data if c.get("validation") is not None]
    
    # Version simplifiée pour l'affichage
    simplified = []
    for case in data:
        simplified.append({
            "case_id": case["case_id"],
            "timestamp": case["timestamp"],
            "vision_prediction": case["vision"]["prediction"],
            "vision_confidence": case["vision"]["confidence"],
            "validated": case.get("validation") is not None,
            "expert_diagnosis": case.get("validation", {}).get("expert_diagnosis") if case.get("validation") else None,
            "drive_image_url": case.get("drive_image_url")
        })
    
    return {"total": len(simplified), "cases": simplified}

@app.get("/statistics")
async def get_statistics():
    """Statistiques des validations"""
    total_cases = len(case_store)
    validated_cases = len([c for c in case_store.values() if c.get("validation")])
    
    # Comparaison vision vs expert
    vision_vs_expert = []
    for case in case_store.values():
        if case.get("validation"):
            vision_pred = case["vision"]["prediction"]
            expert_diag = case["validation"]["expert_diagnosis"]
            vision_vs_expert.append({
                "case_id": case["case_id"],
                "vision": vision_pred,
                "expert": expert_diag,
                "matches": vision_pred.lower() in expert_diag.lower() or expert_diag.lower() in vision_pred.lower()
            })
    
    matches = sum(1 for v in vision_vs_expert if v["matches"])
    accuracy = (matches / len(vision_vs_expert) * 100) if vision_vs_expert else 0
    
    return {
        "total_cases": total_cases,
        "validated_cases": validated_cases,
        "pending_validation": total_cases - validated_cases,
        "vision_accuracy": round(accuracy, 2),
        "comparisons": vision_vs_expert
    }


# =====================================================================
# COLLECTE DATASET — enrichissement des données d'entraînement
# =====================================================================
@app.get("/dataset/pathologies")
async def list_pathologies():
    """Retourne la liste des 10 pathologies valides pour la collecte de dataset."""
    return {"pathologies": VALID_PATHOLOGIES, "total": len(VALID_PATHOLOGIES)}


@app.post("/dataset/upload")
async def upload_dataset_image_endpoint(
    pathology: str = Form(...),
    file: UploadFile = File(...),
):
    """
    Upload une image otoscopique dans Google Drive sous :
    KORAI-Medical/dataset/{pathologie}/{timestamp}_{nom_fichier}

    Paramètres form-data :
      - pathology : l'une des 10 classes du modèle de vision
      - file      : fichier image (jpg, png, webp…)
    """
    if pathology not in VALID_PATHOLOGIES:
        raise HTTPException(
            status_code=400,
            detail=f"Pathologie invalide. Valeurs acceptées : {VALID_PATHOLOGIES}"
        )

    contents = await _read_image(file)

    try:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        # Nom seul, sans dossier : un nom « ../../x » ne doit pas sortir de dataset/
        safe_name = Path(file.filename or 'image.jpg').name.replace(' ', '_') or 'image.jpg'
        filename = f"{timestamp}_{safe_name}"

        use_drive = drive_service and Config.GOOGLE_DRIVE_ENABLED

        if use_drive:
            # ── Envoi sur Google Drive ─────────────────────────────────────
            file_id, drive_url = await asyncio.to_thread(
                drive_service.upload_dataset_image, contents, filename, pathology
            )
            if not file_id:
                raise HTTPException(status_code=500, detail="Échec de l'upload sur Drive")
            logger.info(f"Dataset Drive: {filename} → dataset/{pathology}/")
            return {
                "success": True,
                "storage": "drive",
                "filename": filename,
                "pathology": pathology,
                "drive_url": drive_url,
                "file_id": file_id,
                "message": f"Image enregistrée sur Drive — {pathology}",
            }
        else:
            # ── Fallback : sauvegarde locale dans dataset/{pathologie}/ ────
            local_dir = Path(os.path.abspath(".")) / "dataset" / pathology
            local_dir.mkdir(parents=True, exist_ok=True)
            dest = local_dir / filename
            dest.write_bytes(contents)
            logger.info(f"Dataset local: {filename} → dataset/{pathology}/ (Drive désactivé)")
            return {
                "success": True,
                "storage": "local",
                "filename": filename,
                "pathology": pathology,
                "drive_url": None,
                "file_id": None,
                "message": f"Image enregistrée localement (Drive désactivé) — {pathology}",
            }

    except HTTPException:
        raise
    except Exception:
        logger.exception("Erreur /dataset/upload")
        raise HTTPException(status_code=500, detail=INTERNAL_ERROR)


# =====================================================================
# SERVIR LE FRONTEND COMPILÉ (pour ngrok / accès distant)
# =====================================================================
# Seul le résultat de `npm run build` (frontend/dist) est servi, jamais les sources du frontend
# (elles contiennent les comptes de démonstration).
# __file__ = .../serviceIA/backend/utils/rag_api.py
_FRONTEND_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "frontend", "dist")
)

if os.path.isdir(_FRONTEND_DIR):
    app.mount("/app", StaticFiles(directory=_FRONTEND_DIR, html=True), name="frontend")
    print(f"✅ Frontend servi depuis: {_FRONTEND_DIR}")
else:
    print(f"ℹ️ Frontend non compilé ({_FRONTEND_DIR} absent) : /app n'est pas servi")


if __name__ == "__main__":
    import uvicorn
    is_production = hasattr(sys, 'frozen')
    
    print(f"🚀 Démarrage KORAI ORL API v3")
    print(f"   Mode: {'Production (PyInstaller)' if is_production else 'Développement'}")
    print(f"   Host: {Config.API_HOST}")
    print(f"   Port: {Config.API_PORT}")
    print(f"   Google Drive: {'Activé' if Config.GOOGLE_DRIVE_ENABLED else 'Désactivé'}")
    
    uvicorn.run(
        app,
        host=Config.API_HOST,
        port=Config.API_PORT,
        reload=not is_production,
        log_level="info"
    )