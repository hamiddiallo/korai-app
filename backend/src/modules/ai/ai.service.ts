import sharp from 'sharp';
import { env } from '../../config/env.js';
import { HttpError } from '../../common/errors/http-error.js';
import type { AiSummary } from '../../common/types.js';
import { collectSources } from '../../common/utils/sources.js';

type DiagnoseInput = {
  image: Express.Multer.File;
  symptoms: string;
  showSources: boolean;
  /** Image déjà nettoyée (`anonymizeImageForExternalAi`) : pas de second ré-encodage. */
  sanitized?: boolean;
};

const pickString = (value: unknown): string | undefined => {
  if (typeof value === 'string' && value.trim()) return value;
  return undefined;
};

export type AiResponseExtract = {
  imageOpinion?: string;
  ragOpinion?: string;
  likelyDiagnosis?: string;
  confidenceLabel: 'LOW' | 'MEDIUM' | 'HIGH' | 'UNKNOWN';
  warnings: string[];
  sources: string[];
};

/** Libellés lisibles des 10 classes du modèle de vision (`serviceIA`, même ordre que l'entraînement). */
const VISION_LABELS: Record<string, string> = {
  'aspect post tympanoplastie': 'Aspect post-tympanoplastie',
  'bouchon de cerumen': 'Bouchon de cérumen',
  'cholestéatome': 'Cholestéatome',
  'corps étranger oreille': 'Corps étranger de l’oreille',
  'myringosclerose': 'Myringosclérose',
  'otite moyenne aigue': 'Otite moyenne aiguë',
  'otite séromuqueuse': 'Otite séromuqueuse',
  'otomycose': 'Otomycose',
  'perforation tympanique': 'Perforation tympanique',
  'tympan normal': 'Tympan normal'
};

const visionLabel = (raw: string) => {
  const key = raw.normalize('NFC').trim().toLowerCase();
  return VISION_LABELS[key] ?? key.charAt(0).toUpperCase() + key.slice(1);
};

/** Confiance d'un format inconnu, ramenée entre 0 et 1 (au-delà de 1 : pourcentage). */
const toUnit = (value: number) => (value > 1 ? value / 100 : value);
/** Le modèle de vision de serviceIA donne toujours sa confiance en pourcentage (0–100). */
const fromVisionPercent = (value: number) => value / 100;
const percent = (unit: number) => `${Math.round(unit * 100)} %`;

/** « Otite moyenne aiguë (97 %). Autres possibilités : … » à partir de la réponse du modèle de vision. */
const describeVision = (vision: Record<string, unknown>) => {
  const prediction = visionLabel(String(vision.prediction));
  const confidence = Number(vision.confidence);
  const head = Number.isFinite(confidence) ? `${prediction} (${percent(fromVisionPercent(confidence))})` : prediction;
  const others = (Array.isArray(vision.top3) ? vision.top3 : [])
    .slice(1)
    .map((entry) => {
      const item = entry as Record<string, unknown>;
      const label = pickString(item.class) ?? pickString(item.label);
      const value = Number(item.confidence);
      return label ? `${visionLabel(label)}${Number.isFinite(value) ? ` (${percent(fromVisionPercent(value))})` : ''}` : undefined;
    })
    .filter(Boolean);
  return others.length ? `${head}. Autres possibilités : ${others.join(', ')}.` : `${head}.`;
};

const EAR_NAMES: Record<string, string> = { LEFT: 'oreille gauche', RIGHT: 'oreille droite' };
const earName = (side: string) => EAR_NAMES[side] ?? 'oreille';
const capitalize = (text: string) => text.charAt(0).toUpperCase() + text.slice(1);

type EarVision = { side: string; vision: Record<string, unknown>; label: string; unit: number };

/**
 * Diagnostic de deux tympans : la ou les oreilles atteintes, « (deux oreilles) » quand le
 * résultat est le même des deux côtés.
 */
const combineEarDiagnoses = (ears: EarVision[]) => {
  const normal = VISION_LABELS['tympan normal'];
  const abnormal = ears.filter((ear) => ear.label !== normal);
  if (!abnormal.length) return `${normal} (deux oreilles)`;
  if (abnormal.length === ears.length && new Set(abnormal.map((ear) => ear.label)).size === 1) {
    return `${abnormal[0].label} (deux oreilles)`;
  }
  return abnormal.map((ear) => `${ear.label} (${earName(ear.side)})`).join(' · ');
};

/**
 * Première cause probable d'une analyse documentaire structurée
 * (« 1. Causes probables : X (…), Y… » ou « X : explication… ») : seul le nom
 * de la pathologie est gardé, la virgule à l'intérieur d'une parenthèse ne
 * coupe pas. `undefined` si la base n'a rien trouvé.
 */
export const firstProbableCause = (summary: string | undefined): string | undefined => {
  if (!summary) return undefined;
  const section = summary.match(/causes?\s+probables?\s*:?\s*([\s\S]*?)(?:\n\s*2[.)]|$)/i)?.[1]?.trim();
  if (!section) return undefined;
  let depth = 0;
  let end = section.length;
  for (let i = 0; i < section.length; i++) {
    const c = section[i];
    if (c === '(') depth++;
    else if (c === ')') depth = Math.max(0, depth - 1);
    else if (
      depth === 0 &&
      (c === ',' || c === ';' || c === ':' || c === '\n' || (c === '.' && !/\d/.test(section[i + 1] ?? '')))
    ) {
      end = i;
      break;
    }
  }
  const first = section
    .slice(0, end)
    .replace(/^[\s\-–•\d.)]+/, '')
    .trim();
  // « Non documenté dans la base ORL » en première cause : la base n'a rien trouvé. Plus loin
  // dans une explication (« (non documenté dans le contexte) »), ce n'est pas un refus.
  if (!first || /^non document/i.test(first)) return undefined;
  return first.charAt(0).toUpperCase() + first.slice(1, 160);
};

/**
 * Extraction des champs dérivés à partir de rawJson (une seule fois à la persistance).
 * Formats acceptés : celui de `serviceIA` (`vision` / `rag` pour /diagnose-separate,
 * `summary` pour /rag/analyze) et l'ancien format (`image_ai` / `rag_ai`).
 */
export const extractAiFieldsFromRaw = (
  raw: unknown,
  options?: { hadOtoscopicImage?: boolean }
): AiResponseExtract => {
  const objectValue = raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {};
  const asRecord = (value: unknown) =>
    value && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : undefined;
  const imageAi = asRecord(objectValue.image_ai ?? objectValue.imageDiagnosis ?? objectValue.image_result);
  const ragAi = asRecord(objectValue.rag_ai ?? objectValue.ragDiagnosis ?? objectValue.rag_result);
  const vision = asRecord(objectValue.vision);
  const visionPrediction = pickString(vision?.prediction);
  const rag = asRecord(objectValue.rag);
  const ragSummary = pickString(objectValue.summary) ?? pickString(rag?.summary);
  const hasRagContent = Boolean(ragAi || ragSummary || pickString(objectValue.rag_diagnosis));
  // serviceIA renvoie la photo analysée même quand l'analyse des symptômes a échoué.
  const ragUnavailable = Boolean(pickString(objectValue.rag_error)) && !hasRagContent;
  // Deux tympans photographiés : une analyse d'image par oreille (`ears`), celle des symptômes une fois.
  const ears: EarVision[] = (Array.isArray(objectValue.ears) ? objectValue.ears : []).flatMap((entry) => {
    const ear = asRecord(entry);
    const earVision = asRecord(ear?.vision);
    const prediction = pickString(earVision?.prediction);
    const value = Number(earVision?.confidence);
    return ear && earVision && prediction && Number.isFinite(value)
      ? [{ side: String(ear.side), vision: earVision, label: visionLabel(prediction), unit: fromVisionPercent(value) }]
      : [];
  });
  const twoEars = ears.length >= 2;

  const visionConfidence = Number(vision?.confidence);
  // Deux oreilles : la confiance retenue est la plus faible, pour qu'un doute sur un seul
  // tympan suffise à demander la validation de l'ORL.
  const confidence = twoEars
    ? Math.min(...ears.map((ear) => ear.unit))
    : visionPrediction && Number.isFinite(visionConfidence)
      ? fromVisionPercent(visionConfidence)
      : toUnit(
          Number(
            objectValue.confidence ?? imageAi?.confidence ?? imageAi?.probability ?? ragAi?.confidence ?? Number.NaN
          )
        );

  const confidenceLabel =
    Number.isNaN(confidence) ? 'UNKNOWN' : confidence >= 0.75 ? 'HIGH' : confidence >= 0.45 ? 'MEDIUM' : 'LOW';
  const uncertainEars = ears.filter((ear) => ear.unit < 0.45).map((ear) => earName(ear.side));

  const expectImage = options?.hadOtoscopicImage ?? false;

  return {
    imageOpinion:
      (twoEars
        ? ears.map((ear) => `${capitalize(earName(ear.side))} : ${describeVision(ear.vision)}`).join('\n')
        : undefined) ??
      (vision && visionPrediction ? describeVision(vision) : undefined) ??
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
      (twoEars ? combineEarDiagnoses(ears) : undefined) ??
      (visionPrediction ? visionLabel(visionPrediction) : undefined) ??
      pickString(imageAi?.diagnosis) ??
      pickString(ragAi?.diagnosis) ??
      firstProbableCause(ragSummary),
    confidenceLabel,
    warnings: [
      ...(confidenceLabel === 'LOW'
        ? [
            twoEars && uncertainEars.length
              ? `Confiance IA faible (${uncertainEars.join(', ')}) : demander une validation ORL.`
              : 'Confiance IA faible : demander une validation ORL.'
          ]
        : []),
      ...(expectImage && !imageAi && !visionPrediction ? ['Avis IA sur l’image absent ou non reconnu dans la réponse.'] : []),
      ...(ragUnavailable
        ? ['Avis IA sur les symptômes indisponible (service d’analyse en panne) : seule la photo a été analysée.']
        : !hasRagContent
          ? ['Avis IA sur les symptômes absent ou non reconnu dans la réponse.']
          : [])
    ],
    sources: [...new Set([...collectSources(objectValue), ...collectSources(ragAi), ...collectSources(rag)])]
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

/**
 * Lignes d'identité du récit clinique (« Patient: Awa Diop », « Telephone: … »,
 * « Adresse: … »). Elles ne doivent jamais quitter le backend : seules les
 * données cliniques partent vers le service IA externe.
 */
const IDENTITY_LINE = /^\s*(patient|nom|pr[ée]nom|t[ée]l[ée]phone|t[ée]l|adresse|email|e-mail)\s*:/i;

/** Retire l'identité du patient du texte envoyé au service IA. */
export function redactIdentityForExternalAi(text: string): string {
  return text
    .split('\n')
    .filter((line) => !IDENTITY_LINE.test(line))
    .join('\n')
    .trim();
}

/** Nom de fichier neutre : le nom d'origine peut contenir celui du patient. */
export function neutralImageFilename(mimetype: string): string {
  if (mimetype === 'image/png') return 'otoscopie.png';
  if (mimetype === 'image/webp') return 'otoscopie.webp';
  return 'otoscopie.jpg';
}

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
  // Jeton partagé : le service IA refuse toute requête qui ne vient pas de ce backend.
  if (env.AI_SERVICE_API_KEY) {
    base.authorization = `Bearer ${env.AI_SERVICE_API_KEY}`;
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
      const errorText = (await response.text()).slice(0, 500);
      // Tunnel ou passerelle coupé (ngrok hors ligne, page HTML d'erreur) : le
      // service IA n'a jamais reçu la requête. Panne temporaire, à relancer —
      // pas un refus de la requête.
      const tunnelDown =
        Boolean(response.headers.get('ngrok-error-code')) ||
        /ERR_NGROK_\d+/.test(errorText) ||
        (response.headers.get('content-type') ?? '').includes('text/html');
      if (tunnelDown) {
        throw new HttpError(
          503,
          'AI_UNREACHABLE',
          "Le service d'analyse IA est injoignable pour le moment. Réessayez plus tard.",
          response.headers.get('ngrok-error-code') ?? `HTTP ${response.status}`
        );
      }
      // Jeton refusé : configuration à corriger côté serveur (AI_SERVICE_API_KEY ≠
      // SERVICE_API_TOKEN). L'analyse pourra être relancée une fois corrigée.
      if (response.status === 401 || response.status === 403) {
        throw new HttpError(
          503,
          'AI_SERVICE_ERROR',
          "Le service d'analyse IA refuse l'accès au serveur Korai (configuration). Prévenez l'administrateur, puis relancez l'analyse.",
          errorText
        );
      }
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
      symptoms: redactIdentityForExternalAi(input.symptoms),
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
    const sanitizedBuffer = input.sanitized ? input.image.buffer : await anonymizeImageForExternalAi(input.image);

    // FormData natif : `fetch` calcule lui-même l'en-tête multipart (avec sa
    // frontière). Le paquet `form-data` n'est pas compris par ce `fetch` : le
    // service IA recevait un corps illisible.
    const form = new FormData();
    form.append(
      'file',
      new Blob([new Uint8Array(sanitizedBuffer)], { type: input.image.mimetype }),
      neutralImageFilename(input.image.mimetype)
    );
    form.append('symptoms', redactIdentityForExternalAi(input.symptoms));
    form.append('show_sources', String(input.showSources));

    return callAiService('/diagnose-separate', { method: 'POST', body: form });
  },

  /**
   * Proxy multipart (image anonymisée) → FastAPI POST /vision/predict : analyse d'image seule,
   * pour le second tympan (le modèle classe une photo par appel ; les symptômes, eux, ne sont
   * analysés qu'une fois, avec le premier).
   */
  async visionPredict(input: { image: Express.Multer.File; sanitized?: boolean }) {
    const buffer = input.sanitized ? input.image.buffer : await anonymizeImageForExternalAi(input.image);
    const form = new FormData();
    form.append(
      'file',
      new Blob([new Uint8Array(buffer)], { type: input.image.mimetype }),
      neutralImageFilename(input.image.mimetype)
    );
    return callAiService('/vision/predict', { method: 'POST', body: form });
  }
};
