/**
 * Normalise les sources renvoyées par le service IA en libellés lisibles.
 * Le service peut renvoyer des chaînes ou des objets ({ title, page, ... }) :
 * un simple String(objet) donnerait « [object Object] ».
 */
const TITLE_KEYS = ['title', 'name', 'document', 'source', 'filename', 'file', 'label', 'url', 'id'];
const PAGE_KEYS = ['page', 'page_number', 'pageNumber'];

const formatSource = (value: unknown): string => {
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
