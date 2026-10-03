/// <reference types="vite/client" />
import { createClient } from '@supabase/supabase-js';
import type { Consultation } from './shared';

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL ?? '';
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY ?? '';

// Guard: createClient throws with empty strings — only initialise when configured
const supabase = SUPABASE_URL && SUPABASE_ANON_KEY
  ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
  : null;

// ─── DB row type (snake_case) ─────────────────────────────────────────────────
interface DBRow {
  id: string;
  case_id: string | null;
  drive_image_url: string | null;
  drive_export_url: string | null;
  date: string;
  time: string;
  patient_nom: string;
  patient_prenom: string;
  patient_telephone: string;
  patient_adresse: string;
  patient_age: number;
  patient_sexe: string;
  zone: string;
  symptoms: string[] | null;
  physical_exam: string[] | null;
  antecedents: string[] | null;
  has_image: boolean;
  left_ear: { conduit: string; tympan: string[]; notes: string } | null;
  right_ear: { conduit: string; tympan: string[]; notes: string } | null;
  vision: { prediction: string; confidence: number; top3: [string, number][] } | null;
  left_vision: { prediction: string; confidence: number; top3: [string, number][] } | null;
  right_vision: { prediction: string; confidence: number; top3: [string, number][] } | null;
  rag: { causes: string; signes: string; conduite: string } | null;
  expert_diagnosis: string;
  expert_comment: string;
  expert_name: string | null;
  expert_role: string | null;
  status: string;
  vision_validated: boolean | null;
  rag_validated: boolean | null;
  vision_comment: string | null;
  rag_comment: string | null;
}

// ─── Mapping helpers ──────────────────────────────────────────────────────────
const toDB = (c: Consultation): DBRow => ({
  id: c.id,
  case_id: c.caseId,
  drive_image_url: c.driveImageUrl,
  drive_export_url: c.driveExportUrl,
  date: c.date,
  time: c.time,
  patient_nom: c.patient.nom,
  patient_prenom: c.patient.prenom,
  patient_telephone: c.patient.telephone,
  patient_adresse: c.patient.adresse,
  patient_age: c.patient.age,
  patient_sexe: c.patient.sexe,
  zone: c.zone,
  symptoms: c.symptoms,
  physical_exam: c.physicalExam,
  antecedents: c.antecedents,
  has_image: c.hasImage,
  left_ear: c.leftEar ?? null,
  right_ear: c.rightEar ?? null,
  vision: c.vision,
  left_vision: c.leftVision ?? null,
  right_vision: c.rightVision ?? null,
  rag: c.rag,
  expert_diagnosis: c.expertDiagnosis,
  expert_comment: c.expertComment,
  expert_name: c.expertName ?? null,
  expert_role: c.expertRole ?? null,
  status: c.status,
  vision_validated: c.visionValidated,
  rag_validated: c.ragValidated,
  vision_comment: c.visionComment,
  rag_comment: c.ragComment,
});

const fromDB = (r: DBRow): Consultation => ({
  id: r.id,
  caseId: r.case_id,
  driveImageUrl: r.drive_image_url,
  driveExportUrl: r.drive_export_url,
  date: r.date,
  time: r.time,
  patient: {
    nom: r.patient_nom,
    prenom: r.patient_prenom,
    telephone: r.patient_telephone,
    adresse: r.patient_adresse,
    age: r.patient_age,
    sexe: r.patient_sexe,
  },
  zone: r.zone,
  symptoms: r.symptoms ?? [],
  physicalExam: r.physical_exam ?? [],
  antecedents: r.antecedents ?? [],
  hasImage: r.has_image,
  leftEar: r.left_ear ?? undefined,
  rightEar: r.right_ear ?? undefined,
  vision: r.vision,
  leftVision: r.left_vision ?? undefined,
  rightVision: r.right_vision ?? undefined,
  rag: r.rag,
  expertDiagnosis: r.expert_diagnosis,
  expertComment: r.expert_comment,
  expertName: r.expert_name ?? undefined,
  expertRole: r.expert_role ?? undefined,
  status: r.status as 'Validée' | 'Corrigée',
  visionValidated: r.vision_validated,
  ragValidated: r.rag_validated,
  visionComment: r.vision_comment,
  ragComment: r.rag_comment,
});

// ─── Public DB API ────────────────────────────────────────────────────────────
export const DB = {
  get configured() {
    return supabase !== null;
  },

  loadConsultations: async (): Promise<Consultation[]> => {
    if (!supabase) throw new Error('Supabase non configuré — variables VITE_SUPABASE_URL et VITE_SUPABASE_ANON_KEY manquantes');
    const { data, error } = await supabase
      .from('consultations')
      .select('*')
      .order('date', { ascending: false });
    if (error) throw error;
    return (data as DBRow[]).map(fromDB);
  },

  saveConsultation: async (c: Consultation): Promise<void> => {
    if (!supabase) return; // silently skip when not configured
    const { error } = await supabase.from('consultations').upsert(toDB(c));
    if (error) throw error;
  },

  deleteConsultation: async (id: string): Promise<void> => {
    if (!supabase) return;
    const { error } = await supabase.from('consultations').delete().eq('id', id);
    if (error) throw error;
  },
};

// ─── SQL schema (run once in Supabase SQL editor) ────────────────────────────
/*
CREATE TABLE consultations (
  id                TEXT PRIMARY KEY,
  case_id           TEXT,
  drive_image_url   TEXT,
  drive_export_url  TEXT,
  date              DATE        NOT NULL,
  time              TEXT        NOT NULL,
  patient_nom       TEXT        NOT NULL,
  patient_prenom    TEXT        NOT NULL,
  patient_telephone TEXT,
  patient_adresse   TEXT,
  patient_age       INTEGER,
  patient_sexe      TEXT,
  zone              TEXT        NOT NULL,
  symptoms          JSONB,
  physical_exam     JSONB,
  antecedents       JSONB,
  has_image         BOOLEAN     DEFAULT FALSE,
  left_ear          JSONB,
  right_ear         JSONB,
  vision            JSONB,
  left_vision       JSONB,
  right_vision      JSONB,
  rag               JSONB,
  expert_diagnosis  TEXT,
  expert_comment    TEXT,
  expert_name       TEXT,
  expert_role       TEXT,
  status            TEXT        DEFAULT 'Validée',
  vision_validated  BOOLEAN,
  rag_validated     BOOLEAN,
  vision_comment    TEXT,
  rag_comment       TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON consultations (date DESC);
CREATE INDEX ON consultations (expert_name);
CREATE INDEX ON consultations (status);
*/