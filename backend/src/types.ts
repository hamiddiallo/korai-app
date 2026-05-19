export type Role = 'NURSE' | 'SPECIALIST' | 'PATIENT' | 'ADMIN';

export type User = {
  id: string;
  fullName: string;
  email: string;
  passwordHash: string;
  role: Role;
  phone?: string;
  healthFacility?: string;
  professionalId?: string;
  linkedPatientId?: string;
  createdAt: string;
};

export type Patient = {
  id: string;
  userId?: string;
  createdByUserId: string;
  firstName: string;
  lastName: string;
  birthDate?: string;
  sex?: 'F' | 'M' | 'OTHER';
  phone?: string;
  address?: string;
  consentForAi: boolean;
  consentForTeleExpertise: boolean;
  isValidated: boolean;
  createdAt: string;
  updatedAt: string;
};

export type CaseStatus =
  | 'DRAFT'
  | 'PENDING_AI'
  | 'AI_COMPLETED'
  | 'PENDING_SPECIALIST_REVIEW'
  | 'SPECIALIST_COMPLETED';

export type OrlCase = {
  id: string;
  externalAiCaseId?: string;
  patientId: string;
  createdByUserId: string;
  assignedSpecialistId?: string;
  symptoms: string;
  clinicalNotes?: string;
  aiResponse?: unknown;
  organizedAiSummary?: AiSummary;
  status: CaseStatus;
  urgency: 'LOW' | 'MEDIUM' | 'HIGH';
  createdAt: string;
  updatedAt: string;
};

export type AiSummary = {
  imageOpinion?: string;
  ragOpinion?: string;
  likelyDiagnosis?: string;
  confidenceLabel: 'LOW' | 'MEDIUM' | 'HIGH' | 'UNKNOWN';
  warnings: string[];
  sources: string[];
  raw: unknown;
};
