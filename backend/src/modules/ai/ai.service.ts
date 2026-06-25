import FormData from 'form-data';
import sharp from 'sharp';
import { env } from '../../config/env.js';
import { HttpError } from '../../common/errors/http-error.js';
import type { AiSummary } from '../../common/types.js';

type DiagnoseInput = {
  image: Express.Multer.File;
  symptoms: string;
  showSources: boolean;
};

const pickString = (value: unknown): string | undefined => {
  if (typeof value === 'string' && value.trim()) return value;
  return undefined;
};

const collectSources = (value: unknown): string[] => {
  if (!value || typeof value !== 'object') return [];
  const objectValue = value as Record<string, unknown>;
  const candidates = [objectValue.sources, objectValue.rag_sources, objectValue.references];
  return candidates.flatMap((candidate) => {
    if (!Array.isArray(candidate)) return [];
    return candidate.map(String).filter(Boolean);
  });
};

export type AiResponseExtract = {
  imageOpinion?: string;
  ragOpinion?: string;
  likelyDiagnosis?: string;
  confidenceLabel: 'LOW' | 'MEDIUM' | 'HIGH' | 'UNKNOWN';
  warnings: string[];
  sources: string[];
};

/** Extraction des champs derives a partir de rawJson (une seule fois a la persistance). */
export const extractAiFieldsFromRaw = (
  raw: unknown,
  options?: { hadOtoscopicImage?: boolean }
): AiResponseExtract => {
  const objectValue = raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {};
  const imageAi = (objectValue.image_ai ?? objectValue.imageDiagnosis ?? objectValue.image_result) as
    | Record<string, unknown>
    | undefined;
  const ragAi = (objectValue.rag_ai ?? objectValue.ragDiagnosis ?? objectValue.rag_result) as
    | Record<string, unknown>
    | undefined;
  const ragSummary = pickString(objectValue.summary);
  const hasRagContent = Boolean(ragAi || ragSummary || pickString(objectValue.rag_diagnosis));

  const confidence = Number(
    objectValue.confidence ??
      imageAi?.confidence ??
      imageAi?.probability ??
      ragAi?.confidence ??
      Number.NaN
  );

  const confidenceLabel =
    Number.isNaN(confidence) ? 'UNKNOWN' : confidence >= 0.75 ? 'HIGH' : confidence >= 0.45 ? 'MEDIUM' : 'LOW';

  const expectImage = options?.hadOtoscopicImage ?? false;

  return {
    imageOpinion:
      pickString(imageAi?.diagnosis) ??
      pickString(imageAi?.label) ??
      pickString(objectValue.image_diagnosis),
    ragOpinion:
      pickString(ragAi?.diagnosis) ??
      pickString(ragAi?.answer) ??
      pickString(objectValue.rag_diagnosis) ??
      ragSummary,
    likelyDiagnosis:
      pickString(objectValue.likely_diagnosis) ??
      pickString(objectValue.final_diagnosis) ??
      pickString(imageAi?.diagnosis) ??
      pickString(ragAi?.diagnosis) ??
      ragSummary,
    confidenceLabel,
    warnings: [
      ...(confidenceLabel === 'LOW' ? ['Confiance IA faible: demander une validation ORL.'] : []),
      ...(expectImage && !imageAi ? ['Avis IA image absent ou non reconnu dans la reponse.'] : []),
      ...(!hasRagContent ? ['Avis IA symptomes/RAG absent ou non reconnu dans la reponse.'] : [])
    ],
    sources: [...collectSources(objectValue), ...collectSources(ragAi)]
  };
};

export const toAiSummary = (raw: unknown, extract: AiResponseExtract): AiSummary => ({
  imageOpinion: extract.imageOpinion,
  ragOpinion: extract.ragOpinion,
  likelyDiagnosis: extract.likelyDiagnosis,
  confidenceLabel: extract.confidenceLabel,
  warnings: extract.warnings,
  sources: extract.sources,
  raw
});

/** Retire les metadonnees EXIF et re-encode l'image avant envoi Deep4ORL. */
export async function anonymizeImageForExternalAi(file: Express.Multer.File): Promise<Buffer> {
  const pipeline = sharp(file.buffer, { failOn: 'none' }).rotate();
  if (file.mimetype === 'image/png') return pipeline.png().toBuffer();
  if (file.mimetype === 'image/webp') return pipeline.webp().toBuffer();
  return pipeline.jpeg({ quality: 92, mozjpeg: true }).toBuffer();
}

const mergeAiHeaders = (init: RequestInit): HeadersInit => {
  const base =
    init.headers instanceof Headers
      ? Object.fromEntries(init.headers.entries())
      : { ...(init.headers as Record<string, string> | undefined) };

  if (env.AI_SERVICE_BASE_URL.includes('ngrok')) {
    base['ngrok-skip-browser-warning'] = 'true';
  }

  return base;
};

/**
 * Codes d'erreur IA exposés au frontend. Permettent d'afficher le bon message
 * (timeout vs service injoignable vs erreur applicative) et de décider d'un retry.
 */
export type AiErrorCode =
  | 'AI_TIMEOUT'
  | 'AI_UNREACHABLE'
  | 'AI_SERVICE_ERROR'
  | 'AI_BAD_REQUEST';

/** Toute erreur IA est retryable sauf une requête invalide (4xx applicatif). */
export const isRetryableAiError = (code: string | undefined): boolean =>
  code === 'AI_TIMEOUT' || code === 'AI_UNREACHABLE' || code === 'AI_SERVICE_ERROR';

/**
 * Normalise n'importe quelle erreur (HttpError IA, abort, réseau) en
 * `{ code, message }` réutilisable pour la persistance (consultation AI_FAILED).
 */
export const describeAiError = (error: unknown): { code: AiErrorCode; message: string } => {
  if (error instanceof HttpError && error.code.startsWith('AI_')) {
    return { code: error.code as AiErrorCode, message: error.message };
  }
  return { code: 'AI_UNREACHABLE', message: 'Le service IA est injoignable.' };
};

const callAiService = async (path: string, init: RequestInit): Promise<unknown> => {
  const controller = new AbortController();
  let timedOut = false;
  const timeout = setTimeout(() => {
    timedOut = true;
    controller.abort();
  }, env.AI_SERVICE_TIMEOUT_MS);

  try {
    const response = await fetch(`${env.AI_SERVICE_BASE_URL}${path}`, {
      ...init,
      headers: mergeAiHeaders(init),
      signal: controller.signal
    });

    if (!response.ok) {
      const errorText = await response.text();
      // 4xx applicatif (hors 408/429) = requête invalide, inutile de réessayer.
      const isClientError =
        response.status >= 400 &&
        response.status < 500 &&
        response.status !== 408 &&
        response.status !== 429;
      throw new HttpError(
        isClientError ? 422 : 502,
        isClientError ? 'AI_BAD_REQUEST' : 'AI_SERVICE_ERROR',
        isClientError
          ? "Le service IA a refusé la requête d'analyse."
          : `Le service d'analyse IA est temporairement indisponible (${response.status}).`,
        errorText
      );
    }

    return await response.json();
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (timedOut || (error instanceof Error && error.name === 'AbortError')) {
      throw new HttpError(
        504,
        'AI_TIMEOUT',
        "Le service d'analyse IA met trop de temps à répondre. Réessayez dans un instant.",
        String(error)
      );
    }
    throw new HttpError(
      503,
      'AI_UNREACHABLE',
      "Impossible de joindre le service d'analyse IA. Vérifiez votre connexion ou réessayez plus tard.",
      String(error)
    );
  } finally {
    clearTimeout(timeout);
  }
};

export const aiService = {
  /** Proxy JSON → FastAPI POST /chat */
  chat(input: { message: string; conversationId?: string; showSources?: boolean }) {
    return callAiService('/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: input.message,
        conversation_id: input.conversationId,
        show_sources: input.showSources ?? true
      })
    });
  },

  /** Proxy formulaire → FastAPI POST /rag/analyze */
  ragAnalyze(input: { symptoms: string; showSources?: boolean }) {
    const body = new URLSearchParams({
      symptoms: input.symptoms,
      show_sources: String(input.showSources ?? true)
    });

    return callAiService('/rag/analyze', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString()
    });
  },

  /** Proxy multipart (image anonymisee) → FastAPI POST /diagnose-separate — usage interne consultations uniquement. */
  async diagnoseSeparate(input: DiagnoseInput) {
    const sanitizedBuffer = await anonymizeImageForExternalAi(input.image);

    const form = new FormData();
    form.append('file', sanitizedBuffer, {
      filename: input.image.originalname,
      contentType: input.image.mimetype
    });
    form.append('symptoms', input.symptoms);
    form.append('show_sources', String(input.showSources));

    return callAiService('/diagnose-separate', {
      method: 'POST',
      body: form as unknown as BodyInit,
      headers: form.getHeaders()
    });
  }
};
