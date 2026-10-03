"""
Tests de l'API serviceIA sans Mistral ni modèles : le chatbot RAG et la vision sont simulés.

Lancer depuis serviceIA/backend :
    .venv/bin/python -m unittest discover -s tests -t . -v
"""
import asyncio
import io
import os
import time
import unittest
from unittest import mock

# Avant l'import de l'application : configuration de test (load_dotenv n'écrase pas ces valeurs).
os.environ["SERVICE_API_TOKEN"] = "jeton-de-test"
os.environ["CASE_HISTORY_SIZE"] = "2"

import httpx  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from PIL import Image  # noqa: E402

from utils import rag_api  # noqa: E402

AUTH = {"Authorization": "Bearer jeton-de-test"}
SUMMARY = "1. Causes probables : Otite moyenne aiguë.\n2. Signes associés : fièvre.\n3. Conduite à tenir : antalgiques."


class FakeChatbot:
    """Remplace ORLChatbot : pas d'appel à Mistral."""

    def __init__(self):
        self.fail = False
        self.delay = 0.0
        self.calls = []

    def query(self, message, show_sources=False):
        self.calls.append(message)
        if self.delay:
            time.sleep(self.delay)
        if self.fail:
            raise RuntimeError("Error response 403: tier_not_allowed (détail interne)")
        sources = [{"source": "Guide_ORL.pdf", "page": 3, "content": "…"}] if show_sources else None
        return {"response": SUMMARY, "sources": sources, "raw_context": ""}

    doctor_query = query


def fake_top3(_model, _image):
    return [
        {"class": "otite moyenne aigue", "confidence": 91.5},
        {"class": "tympan normal", "confidence": 5.0},
        {"class": "otomycose", "confidence": 3.5},
    ]


def jpeg_bytes() -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (32, 32), (200, 100, 50)).save(buffer, format="JPEG")
    return buffer.getvalue()


class ApiTestCase(unittest.TestCase):
    def setUp(self):
        self.bot = FakeChatbot()
        patches = [
            mock.patch.object(rag_api, "chatbot", self.bot),
            mock.patch.object(rag_api, "dl_model", object()),
            mock.patch.object(rag_api, "predict_top3", fake_top3),
        ]
        for patch in patches:
            patch.start()
            self.addCleanup(patch.stop)
        rag_api.case_store.clear()
        self.client = TestClient(rag_api.app)

    def diagnose(self, symptoms="Otalgie, fièvre", image=None, headers=AUTH):
        return self.client.post(
            "/diagnose-separate",
            data={"symptoms": symptoms, "show_sources": "true"},
            files={"file": ("otoscopie.jpg", image if image is not None else jpeg_bytes(), "image/jpeg")},
            headers=headers,
        )


class TokenTests(ApiTestCase):
    def test_etat_du_service_public(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["auth_required"])

    def test_jeton_exige(self):
        self.assertEqual(self.client.post("/rag/analyze", data={"symptoms": "x"}).status_code, 401)
        wrong = {"Authorization": "Bearer faux"}
        self.assertEqual(self.client.post("/rag/analyze", data={"symptoms": "x"}, headers=wrong).status_code, 401)
        self.assertEqual(self.client.get("/cases").status_code, 401)
        self.assertEqual(self.client.get("/export/all/csv").status_code, 401)
        self.assertEqual(self.client.post("/rag/analyze", data={"symptoms": "x"}, headers=AUTH).status_code, 200)
        self.assertEqual(self.bot.calls, ["x"], "seule la requête avec le bon jeton est analysée")

    def test_refus_avant_lecture_du_corps(self):
        body = b"--zzz\r\ncorps multipart invalide"
        headers = {"Content-Type": "multipart/form-data; boundary=zzz"}
        self.assertEqual(self.client.post("/diagnose-separate", content=body, headers=headers).status_code, 401)
        # Avec le jeton, le même corps est bien lu (et refusé comme invalide).
        response = self.client.post("/diagnose-separate", content=body, headers={**headers, **AUTH})
        self.assertIn(response.status_code, (400, 422))

    def test_sources_du_frontend_non_servies(self):
        self.assertEqual(self.client.get("/app/src/shared.ts").status_code, 404)


class DiagnoseTests(ApiTestCase):
    def test_photo_et_symptomes(self):
        response = self.diagnose()
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["vision"]["prediction"], "otite moyenne aigue")
        self.assertEqual(body["vision"]["confidence"], 91.5)
        self.assertEqual(body["rag"]["summary"], SUMMARY)
        self.assertIsNone(body["rag_error"])

    def test_mistral_en_panne_la_photo_reste_analysee(self):
        self.bot.fail = True
        response = self.diagnose()
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["vision"]["prediction"], "otite moyenne aigue")
        self.assertIsNone(body["rag"])
        self.assertEqual(body["rag_error"], rag_api.RAG_UNAVAILABLE)
        self.assertNotIn("tier_not_allowed", response.text)

    def test_erreur_mistral_sans_detail_technique(self):
        self.bot.fail = True
        response = self.client.post("/rag/analyze", data={"symptoms": "Otalgie"}, headers=AUTH)
        self.assertEqual(response.status_code, 502)
        self.assertEqual(response.json()["detail"], rag_api.RAG_UNAVAILABLE)
        self.assertNotIn("403", response.text)

    def test_image_illisible(self):
        response = self.diagnose(image=b"ceci n'est pas une image")
        self.assertEqual(response.status_code, 400)
        self.assertIn("Image illisible", response.json()["detail"])

    def test_image_trop_lourde(self):
        with mock.patch.object(rag_api.Config, "MAX_UPLOAD_BYTES", 1000):
            response = self.diagnose(image=b"\xff\xd8" + b"0" * 2000)
        self.assertEqual(response.status_code, 413)

    def test_symptomes_tronques(self):
        self.diagnose(symptoms="a" * 5000)
        self.assertEqual(len(self.bot.calls[-1]), rag_api.Config.MAX_SYMPTOMS_CHARS)

    def test_historique_borne_et_desactivable(self):
        for _ in range(3):
            self.assertEqual(self.diagnose().status_code, 200)
        self.assertEqual(len(rag_api.case_store), 2, "CASE_HISTORY_SIZE=2 : le plus ancien est oublié")
        rag_api.case_store.clear()
        with mock.patch.object(rag_api.Config, "CASE_HISTORY_SIZE", 0):
            self.assertEqual(self.diagnose().status_code, 200)
        self.assertEqual(rag_api.case_store, {})

    def test_validation_d_un_cas_sans_analyse_des_symptomes(self):
        self.bot.fail = True
        case_id = self.diagnose().json()["case_id"]
        response = self.client.post(
            "/validate", json={"case_id": case_id, "expert_diagnosis": "otite moyenne aigue"}, headers=AUTH
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.client.get("/export/all/csv", headers=AUTH).status_code, 200)


class ConcurrencyAndPrivacyTests(ApiTestCase):
    def test_une_analyse_ne_bloque_pas_le_serveur(self):
        self.bot.delay = 1.0

        async def scenario():
            transport = httpx.ASGITransport(app=rag_api.app)
            async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
                slow = asyncio.create_task(client.post("/rag/analyze", data={"symptoms": "Otalgie"}, headers=AUTH))
                await asyncio.sleep(0.1)
                start = time.perf_counter()
                health = await client.get("/health")
                elapsed = time.perf_counter() - start
                still_running = not slow.done()
                return health.status_code, elapsed, still_running, (await slow).status_code

        health_status, elapsed, still_running, slow_status = asyncio.run(scenario())
        self.assertEqual(health_status, 200)
        self.assertLess(elapsed, 0.5, "/health répond pendant l'analyse")
        self.assertTrue(still_running)
        self.assertEqual(slow_status, 200)

    def test_question_absente_des_journaux(self):
        with self.assertLogs(rag_api.logger, level="INFO") as logs:
            response = self.client.post(
                "/chat/simple", json={"question": "Otalgie droite chez Awa Diop"}, headers=AUTH
            )
        self.assertEqual(response.status_code, 200)
        self.assertFalse(any("Awa" in line or "Otalgie" in line for line in logs.output), logs.output)

    def test_sources_sans_chemin_du_poste_de_l_auteur(self):
        windows = {"source": "C:\\Users\\Auteur\\Documents\\KORAI\\documents_orl\\EMC-ORL.pdf", "page": 95, "page_label": "96"}
        self.assertEqual(rag_api._source_reference(windows), ("EMC-ORL.pdf", "96"))
        self.assertEqual(rag_api._source_reference({"source": "/data/Guide.pdf", "page": 0}), ("Guide.pdf", 1))
        self.assertEqual(
            rag_api._source_reference({"filename": "Propre.pdf", "source": "C:\\x\\y.pdf", "page": 2}), ("Propre.pdf", 3)
        )

    def test_prefixes_e5_et_pas_de_blocage(self):
        recorded = []

        def fake_embed_documents(_self, texts):
            recorded.extend(texts)
            return [[0.0] for _ in texts]

        with mock.patch.object(rag_api.HuggingFaceEmbeddings, "embed_documents", fake_embed_documents):
            rag_api._E5Embeddings.embed_query(object(), "otalgie fébrile")
            rag_api._E5Embeddings.embed_documents(object(), ["texte A", "texte B"])
        self.assertEqual(recorded, ["query: otalgie fébrile", "passage: texte A", "passage: texte B"])


if __name__ == "__main__":
    unittest.main()
