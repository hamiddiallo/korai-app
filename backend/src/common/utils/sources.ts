/**
 * Normalise les sources renvoyées par le service IA en libellés lisibles.
 * Le service peut renvoyer des chaînes ou des objets ({ title, page, ... }) :
 * un simple String(objet) donnerait « [object Object] ».
 */
const TITLE_KEYS = ['title', 'name', 'document', 'source', 'filename', 'file', 'label', 'url', 'id'];
const PAGE_KEYS = ['page', 'page_number', 'pageNumber'];

/**
 * Libellé sans chemin de dossier : « C:\Users\…\EMC-ORL.pdf · p. 97 » → « EMC-ORL.pdf · p. 97 ».
 * La base documentaire de serviceIA a été indexée sous Windows et garde le chemin complet de
 * chaque PDF (nom d'utilisateur de son auteur compris). Les URL et les titres ordinaires
 * contenant « / » restent intacts.
 */
export const cleanSourceLabel = (label: string): string => {
  const trimmed = label.trim();
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(trimmed)) return trimmed;
  const separator = trimmed.indexOf(' · ');
  const title = separator < 0 ? trimmed : trimmed.slice(0, separator);
  if (!title.includes('\\') && !title.startsWith('/')) return trimmed;
  const name = title.split(/[\\/]/).filter((part) => part.trim()).pop() ?? title;
  return separator < 0 ? name : `${name}${trimmed.slice(separator)}`;
};

const formatSource = (value: unknown): string => cleanSourceLabel(formatRawSource(value));

const formatRawSource = (value: unknown): string => {
  if (typeof value === 'string') return value.trim();
  if (typeof value === 'number') return String(value);
  if (!value || typeof value !== 'object') return '';

  const record = value as Record<string, unknown>;
  const titleKey = TITLE_KEYS.find((key) => typeof record[key] === 'string' && (record[key] as string).trim());
  if (!titleKey) return '';
  const title = (record[titleKey] as string).trim();

  const pageKey = PAGE_KEYS.find((key) => typeof record[key] === 'number' || typeof record[key] === 'string');
  const page = pageKey ? String(record[pageKey]).trim() : '';
  return page ? `${title} · p. ${page}` : title;
};

export const collectSources = (value: unknown): string[] => {
  if (!value || typeof value !== 'object') return [];
  const objectValue = value as Record<string, unknown>;
  const candidates = [objectValue.sources, objectValue.rag_sources, objectValue.references];
  const labels = candidates.flatMap((candidate) => (Array.isArray(candidate) ? candidate.map(formatSource) : []));
  return [...new Set(labels.filter((label) => label && label !== '[object Object]'))];
};
