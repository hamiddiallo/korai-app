/// <reference types="vite/client" />
export const COLORS = {
  primary: '#1D6AE5',
  secondary: '#0EA5E9',
  success: '#10B981',
  warning: '#F59E0B',
  danger: '#EF4444',
  background: '#F0F4F8',
  cardBg: '#FFFFFF',
  border: '#E2E8F0',
  textPrimary: '#1A2332',
  textSecondary: '#64748B',
  sidebar: '#0F172A',
  sidebarEnd: '#1a3a6b',
};

export const SYMPTOMS_LIST = [
  'Otalgie (douleur à l\'oreille)',
  'Otorrhée (écoulement)',
  'Hypoacousie (diminution audition)',
  'Acouphènes (bourdonnements)',
  'Vertiges',
  'Fièvre',
  'Prurit auriculaire',
  'Sensation d\'oreille bouchée',
  'Douleur à la mastication',
  'Otorragie (saignement)',
  'Douleur rétroauriculaire',
  'Tuméfaction',
  'Autre',
];

export const ANTECEDENTS_LIST = [
  'Otites récidivantes',
  'Chirurgie ORL',
  'Diabète',
  'Immunodépression',
  'Traumatisme crânien',
  'Baignade fréquente',
  'Exposition au bruit',
  'Bouchon de cérumen',
  'Rhinite/sinusite',
  'Aucun antécédent notable',
  'Autre',
];

export const PHYSICAL_EXAM_LIST = [
  'Paralysie faciale',
  'Écoulement auriculaire',
  'Fistule préauriculaire',
  'Douleur rétroauriculaire à la palpation',
  'Douleur tragus/pavillon à la palpation',
  'Autre',
];

export const CONDUIT_AUDITIF_OPTIONS = [
  'Normal',
  'Rétréci / Inflammatoire',
  'Bouchon de cérumen',
  'Squames',
];

export const TYMPAN_OPTIONS = [
  'Normal',
  'Rouge (érythémateux)',
  'Mat',
  'Perforation',
  'Polype',
  'Mousse noire',
  'Bombé',
  'Rétracté',
  'Épanchement rétro-tympanique',
];

export const ORL_ZONES = [
  { key: 'ear', label: 'Oreille', icon: 'ear', available: true, desc: 'Pathologies de l\'oreille externe, moyenne et interne' },
  { key: 'nose', label: 'Nez', icon: 'nose', available: false, desc: 'Rhinite, sinusite, déviation septale' },
  { key: 'throat', label: 'Gorge', icon: 'throat', available: false, desc: 'Pharyngite, amygdalite, laryngite' },
];

export interface User {
  username: string;
  password: string;
  role: string;
  initials: string;
}

export interface Consultation {
  id: string;
  caseId: string | null;
  driveImageUrl: string | null;
  driveExportUrl: string | null;
  date: string;
  time: string;
  patient: {
    nom: string;
    prenom: string;
    telephone: string;
    adresse: string;
    age: number;
    sexe: string;
  };
  zone: string;
  symptoms: string[];
  physicalExam: string[];
  antecedents: string[];
  hasImage: boolean;
  leftEar?: { conduit: string; tympan: string[]; notes: string };
  rightEar?: { conduit: string; tympan: string[]; notes: string };
  vision: { prediction: string; confidence: number; top3: [string, number][] } | null;
  leftVision?: { prediction: string; confidence: number; top3: [string, number][] } | null;
  rightVision?: { prediction: string; confidence: number; top3: [string, number][] } | null;
  rag: { causes: string; signes: string; conduite: string; sources?: { source: string; page?: number; content?: string }[] } | null;
  expertDiagnosis: string;
  expertComment: string;
  expertName?: string;
  expertRole?: string;
  status: 'Validée' | 'Corrigée';
  visionValidated: boolean | null;
  ragValidated: boolean | null;
  visionComment: string | null;
  ragComment: string | null;
}

const STORAGE_KEYS = {
  users: 'korai_users_v3',
  consultations: 'korai_consultations_v3',
  dossierCounter: 'korai_dossier_counter_v3',
};

const DEFAULT_USERS: User[] = [
  { username: 'Pr Ciré', password: 'module', role: 'Professeur ORL', initials: 'PC' },
  { username: 'Dr Fatou', password: 'demo', role: 'Médecin ORL', initials: 'DF' },
];

export const Storage = {
  getUsers: (): User[] => {
    try {
      const raw = localStorage.getItem(STORAGE_KEYS.users);
      if (!raw) {
        // Initialize with default users if not present
        localStorage.setItem(STORAGE_KEYS.users, JSON.stringify(DEFAULT_USERS));
        return DEFAULT_USERS;
      }
      const users = JSON.parse(raw);
      // Ensure we always have at least the default users
      if (!Array.isArray(users) || users.length === 0) {
        localStorage.setItem(STORAGE_KEYS.users, JSON.stringify(DEFAULT_USERS));
        return DEFAULT_USERS;
      }
      return users;
    } catch { 
      localStorage.setItem(STORAGE_KEYS.users, JSON.stringify(DEFAULT_USERS));
      return DEFAULT_USERS; 
    }
  },
  saveUsers: (users: User[]) => {
    localStorage.setItem(STORAGE_KEYS.users, JSON.stringify(users));
  },
  getConsultations: (): Consultation[] => {
    try {
      const raw = localStorage.getItem(STORAGE_KEYS.consultations);
      return raw ? JSON.parse(raw) : DEMO_CONSULTATIONS;
    } catch { return DEMO_CONSULTATIONS; }
  },
  saveConsultations: (consultations: Consultation[]) => {
    localStorage.setItem(STORAGE_KEYS.consultations, JSON.stringify(consultations));
  },
  nextDossierId: (consultations: Consultation[]): string => {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const prefix = `${year}-${month}-`;
    const sameMonth = consultations.filter(c => c.id.startsWith(prefix));
    const next = sameMonth.length + 1;
    return prefix + String(next).padStart(3, '0');
  },
};

export const API = {
  baseUrl: import.meta.env.VITE_API_URL || '/api',
  chat: async (message: string, withSources = false) => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 60_000);
    try {
      const resp = await fetch(`${API.baseUrl}/chat/simple`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question: message, show_sources: withSources }),
        signal: controller.signal,
      });
      if (!resp.ok) throw new Error(`Chat error: ${resp.status}`);
      return resp.json();
    } finally {
      clearTimeout(timer);
    }
  },
  chatStream: async (
    message: string,
    onToken: (token: string) => void,
    onDone: (sources: { source: string; page?: number }[]) => void,
    onError: (err: Error) => void,
  ) => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 90_000);
    try {
      const resp = await fetch(`${API.baseUrl}/chat/stream`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question: message, show_sources: true }),
        signal: controller.signal,
      });
      if (!resp.ok) throw new Error(`Stream error: ${resp.status}`);
      const reader = resp.body!.getReader();
      const decoder = new TextDecoder();
      let buffer = '';
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const parts = buffer.split('\n\n');
        buffer = parts.pop() ?? '';
        for (const part of parts) {
          const line = part.trim();
          if (!line.startsWith('data: ')) continue;
          const data = JSON.parse(line.slice(6));
          if (data.done) onDone(data.sources ?? []);
          else onToken(data.token);
        }
      }
    } catch (err) {
      onError(err as Error);
    } finally {
      clearTimeout(timer);
    }
  },
  diagnoseSeparate: async (symptomsText: string, imageFile: File, withSources = false, _dossierId?: string) => {
    const form = new FormData();
    form.append('symptoms', symptomsText);
    form.append('file', imageFile);
    form.append('show_sources', String(withSources));
    const resp = await fetch(`${API.baseUrl}/diagnose-separate`, { method: 'POST', body: form });
    if (!resp.ok) throw new Error(`Diagnose error: ${resp.status}`);
    return resp.json();
  },
  // Analyse RAG seule en mode consultation (prompt strict, réponse structurée en 3 rubriques)
  ragAnalyze: async (symptomsText: string, withSources = false): Promise<{ summary: string; sources?: { source: string; page?: number; content?: string }[] }> => {
    const form = new FormData();
    form.append('symptoms', symptomsText);
    form.append('show_sources', String(withSources));
    const resp = await fetch(`${API.baseUrl}/rag/analyze`, { method: 'POST', body: form });
    if (!resp.ok) throw new Error(`RAG error: ${resp.status}`);
    return resp.json();
  },
  // Classification d'image seule (évite un second appel RAG pour la deuxième oreille)
  visionPredict: async (imageFile: File): Promise<{ prediction: string; confidence: number; top3: { class: string; confidence: number }[] }> => {
    const form = new FormData();
    form.append('file', imageFile);
    const resp = await fetch(`${API.baseUrl}/vision/predict`, { method: 'POST', body: form });
    if (!resp.ok) throw new Error(`Vision error: ${resp.status}`);
    return resp.json();
  },
  uploadDatasetImage: async (file: File, pathology: string): Promise<{ success: boolean; drive_url: string; filename: string; pathology: string }> => {
    const form = new FormData();
    form.append('file', file);
    form.append('pathology', pathology);
    const resp = await fetch(`${API.baseUrl}/dataset/upload`, { method: 'POST', body: form });
    if (!resp.ok) {
      const err = await resp.json().catch(() => ({ detail: 'Erreur inconnue' }));
      throw new Error((err as { detail?: string }).detail ?? 'Erreur inconnue');
    }
    return resp.json() as Promise<{ success: boolean; drive_url: string; filename: string; pathology: string }>;
  },
  validate: async (payload: Record<string, unknown>) => {
    const resp = await fetch(`${API.baseUrl}/validate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!resp.ok) throw new Error(`Validate error: ${resp.status}`);
    return resp.json();
  },
};

const DEMO_CONSULTATIONS: Consultation[] = [
  {
    id: '2024-05-001', caseId: null, driveImageUrl: null, driveExportUrl: null,
    date: '2024-05-01', time: '09:15',
    patient: { nom: 'Diallo', prenom: 'Aïssatou', telephone: '+221 77 123 4567', adresse: 'Plateau, Dakar', age: 34, sexe: 'Féminin' },
    zone: 'ear',
    symptoms: ['Otalgie (douleur à l\'oreille)', 'Fièvre', 'Otorrhée (écoulement)'],
    physicalExam: ['Tympan érythémateux', 'Épanchement rétro-tympanique'],
    antecedents: ['Otites récidivantes'],
    hasImage: true,
    vision: { prediction: 'otite moyenne aiguë', confidence: 91.2, top3: [['otite moyenne aiguë', 91.2], ['tympan normal', 6.1], ['otomycose', 2.7]] },
    rag: { causes: 'Infection bactérienne (Streptococcus pneumoniae, Haemophilus influenzae) souvent précédée d\'une IVRS.', signes: 'Otalgie intense, fièvre, otorrhée, hypoacousie, bombement tympanique.', conduite: 'Amoxicilline 80 mg/kg/j pendant 5-7 jours. Analgésiques. Réévaluation à 48h.' },
    expertDiagnosis: 'Otite moyenne aiguë purulente',
    expertComment: 'Antibiothérapie initiée.',
    expertName: 'Pr Ciré', expertRole: 'Professeur ORL',
    status: 'Validée', visionValidated: true, ragValidated: true, visionComment: null, ragComment: null,
  },
  {
    id: '2024-05-002', caseId: null, driveImageUrl: null, driveExportUrl: null,
    date: '2024-05-03', time: '11:30',
    patient: { nom: 'Sow', prenom: 'Ibrahima', telephone: '+221 76 987 6543', adresse: 'HLM, Dakar', age: 52, sexe: 'Masculin' },
    zone: 'ear',
    symptoms: ['Hypoacousie (diminution audition)', 'Sensation d\'oreille bouchée'],
    physicalExam: ['Bouchon de cérumen'],
    antecedents: ['Bouchon de cérumen'],
    hasImage: false,
    vision: null,
    rag: { causes: 'Accumulation excessive de cérumen obstruant le conduit auditif externe.', signes: 'Hypoacousie progressive, sensation de plénitude auriculaire, acouphènes possibles.', conduite: 'Ceruminolyse (huile d\'olive 3j) puis lavage auriculaire. Éviter coton-tiges.' },
    expertDiagnosis: 'Bouchon de cérumen bilatéral',
    expertComment: 'Irrigation réalisée en consultation.',
    expertName: 'Pr Ciré', expertRole: 'Professeur ORL',
    status: 'Validée', visionValidated: null, ragValidated: true, visionComment: null, ragComment: null,
  },
  {
    id: '2024-05-003', caseId: null, driveImageUrl: null, driveExportUrl: null,
    date: '2024-05-06', time: '14:00',
    patient: { nom: 'Ndiaye', prenom: 'Mariama', telephone: '+221 78 555 0001', adresse: 'Almadies, Dakar', age: 28, sexe: 'Féminin' },
    zone: 'ear',
    symptoms: ['Prurit auriculaire', 'Otorrhée (écoulement)'],
    physicalExam: ['Dépôts blanchâtres / mycose', 'Conduit œdémateux'],
    antecedents: ['Baignade fréquente'],
    hasImage: true,
    vision: { prediction: 'otomycose', confidence: 84.5, top3: [['otomycose', 84.5], ['otite externe', 12.1], ['tympan normal', 3.4]] },
    rag: { causes: 'Infection fongique (Aspergillus niger, Candida) favorisée par l\'humidité.', signes: 'Prurit intense, otorrhée blanchâtre ou noirâtre, douleur modérée.', conduite: 'Nettoyage soigneux. Antifongiques topiques (clotrimazole) 2-3 semaines. Éviter humidité.' },
    expertDiagnosis: 'Otomycose externe',
    expertComment: '', expertName: 'Dr Fatou', expertRole: 'Médecin ORL',
    status: 'Validée',
    visionValidated: null, ragValidated: null, visionComment: null, ragComment: null,
  },
];
