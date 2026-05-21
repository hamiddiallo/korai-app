import FormData from 'form-data';
import sharp from 'sharp';
import { env } from '../../config/env.js';
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
export const extractAiFieldsFromRaw = (raw: unknown): AiResponseExtract => {
  const objectValue = raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {};
  const imageAi = (objectValue.image_ai ?? objectValue.imageDiagnosis ?? objectValue.image_result) as
    | Record<string, unknown>
    | undefined;
  const ragAi = (objectValue.rag_ai ?? objectValue.ragDiagnosis ?? objectValue.rag_result) as
    | Record<string, unknown>
    | undefined;

  const confidence = Number(
    objectValue.confidence ??
      imageAi?.confidence ??
      imageAi?.probability ??
      ragAi?.confidence ??
      Number.NaN
  );

  const confidenceLabel =
    Number.isNaN(confidence) ? 'UNKNOWN' : confidence >= 0.75 ? 'HIGH' : confidence >= 0.45 ? 'MEDIUM' : 'LOW';

  return {
    imageOpinion:
      pickString(imageAi?.diagnosis) ??
      pickString(imageAi?.label) ??
      pickString(objectValue.image_diagnosis),
    ragOpinion:
      pickString(ragAi?.diagnosis) ?? pickString(ragAi?.answer) ?? pickString(objectValue.rag_diagnosis),
    likelyDiagnosis:
      pickString(objectValue.likely_diagnosis) ??
      pickString(objectValue.final_diagnosis) ??
      pickString(imageAi?.diagnosis) ??
      pickString(ragAi?.diagnosis),
    confidenceLabel,
    warnings: [
      ...(confidenceLabel === 'LOW' ? ['Confiance IA faible: demander une validation ORL.'] : []),
      ...(!imageAi ? ['Avis IA image absent ou non reconnu dans la reponse.'] : []),
      ...(!ragAi ? ['Avis IA symptomes/RAG absent ou non reconnu dans la reponse.'] : [])
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

export const aiService = {
  async diagnoseSeparate(input: DiagnoseInput) {
    const sanitizedBuffer = await anonymizeImageForExternalAi(input.image);

    const form = new FormData();
    form.append('file', sanitizedBuffer, {
      filename: input.image.originalname,
      contentType: input.image.mimetype
    });
    form.append('symptoms', input.symptoms);
    form.append('show_sources', String(input.showSources));

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), env.AI_SERVICE_TIMEOUT_MS);

    try {
      const response = await fetch(`${env.AI_SERVICE_BASE_URL}/diagnose-separate`, {
        method: 'POST',
        body: form as unknown as BodyInit,
        headers: form.getHeaders(),
        signal: controller.signal
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`AI service failed ${response.status}: ${errorText}`);
      }

      return response.json();
    } finally {
      clearTimeout(timeout);
    }
  }
};
