import bcrypt from 'bcryptjs';
import { prisma } from './prisma.js';
import type { AiSummary, OrlCase, Patient, Role, User } from '../types.js';

type DbUser = NonNullable<Awaited<ReturnType<typeof prisma.user.findUnique>>>;
type DbPatient = NonNullable<Awaited<ReturnType<typeof prisma.patient.findUnique>>>;
type DbCase = NonNullable<Awaited<ReturnType<typeof prisma.orlCase.findUnique>>>;

const nullable = <T>(value: T | null): T | undefined => value ?? undefined;

const parseJson = (value: string | null): unknown | undefined => {
  if (!value) return undefined;
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
};

const mapUser = (user: DbUser): User => ({
  id: user.id,
  fullName: user.fullName,
  email: user.email,
  passwordHash: user.passwordHash,
  role: user.role as Role,
  phone: nullable(user.phone),
  healthFacility: nullable(user.healthFacility),
  professionalId: nullable(user.professionalId),
  linkedPatientId: nullable(user.linkedPatientId),
  createdAt: user.createdAt.toISOString()
});

const mapPatient = (patient: DbPatient): Patient => ({
  id: patient.id,
  userId: nullable(patient.userId),
  createdByUserId: patient.createdByUserId,
  firstName: patient.firstName,
  lastName: patient.lastName,
  birthDate: nullable(patient.birthDate),
  sex: patient.sex ? (patient.sex as Patient['sex']) : undefined,
  phone: nullable(patient.phone),
  address: nullable(patient.address),
  consentForAi: patient.consentForAi,
  consentForTeleExpertise: patient.consentForTeleExpertise,
  isValidated: patient.isValidated,
  createdAt: patient.createdAt.toISOString(),
  updatedAt: patient.updatedAt.toISOString()
});

const mapCase = (orlCase: DbCase): OrlCase => ({
  id: orlCase.id,
  externalAiCaseId: nullable(orlCase.externalAiCaseId),
  patientId: orlCase.patientId,
  createdByUserId: orlCase.createdByUserId,
  assignedSpecialistId: nullable(orlCase.assignedSpecialistId),
  symptoms: orlCase.symptoms,
  clinicalNotes: nullable(orlCase.clinicalNotes),
  aiResponse: parseJson(orlCase.aiResponseJson),
  organizedAiSummary: parseJson(orlCase.organizedAiSummaryJson) as AiSummary | undefined,
  status: orlCase.status as OrlCase['status'],
  urgency: orlCase.urgency as OrlCase['urgency'],
  createdAt: orlCase.createdAt.toISOString(),
  updatedAt: orlCase.updatedAt.toISOString()
});

export class DataStore {
  async seed() {
    const userCount = await prisma.user.count();
    if (userCount === 0) {
      await this.createUser({
        fullName: 'Infirmier Demo',
        email: 'nurse@korai.local',
        password: 'Password123!',
        role: 'NURSE'
      });
      await this.createUser({
        fullName: 'ORL Demo',
        email: 'orl@korai.local',
        password: 'Password123!',
        role: 'SPECIALIST'
      });
      await this.createUser({
        fullName: 'Admin Demo',
        email: 'admin@korai.local',
        password: 'Password123!',
        role: 'ADMIN'
      });
    }

    const clinicalItemCount = await prisma.clinicalReferenceItem.count();
    if (clinicalItemCount > 0) return;

    await prisma.clinicalReferenceItem.createMany({
      data: [
        { type: 'SYMPTOM', label: 'Douleur oreille', sortOrder: 1 },
        { type: 'SYMPTOM', label: 'Ecoulement auriculaire', sortOrder: 2 },
        { type: 'SYMPTOM', label: 'Baisse audition', sortOrder: 3 },
        { type: 'SYMPTOM', label: 'Fievre', sortOrder: 4 },
        { type: 'SYMPTOM', label: 'Vertiges', sortOrder: 5 },
        { type: 'MEDICAL_HISTORY', label: 'Otites repetees', sortOrder: 1 },
        { type: 'MEDICAL_HISTORY', label: 'Chirurgie ORL', sortOrder: 2 },
        { type: 'MEDICAL_HISTORY', label: 'Allergies connues', sortOrder: 3 },
        { type: 'MEDICAL_HISTORY', label: 'Diabete', sortOrder: 4 },
        { type: 'TOUCH_CHECK', label: 'Douleur a la traction du pavillon', sortOrder: 1 },
        { type: 'TOUCH_CHECK', label: 'Douleur a la pression du tragus', sortOrder: 2 },
        { type: 'TOUCH_CHECK', label: 'Sensibilite mastoidienne', sortOrder: 3 },
        { type: 'TOUCH_CHECK', label: 'Ganglions cervicaux palpables', sortOrder: 4 }
      ]
    });
  }

  async createUser(input: {
    fullName: string;
    email: string;
    password: string;
    role: Role;
    phone?: string;
    healthFacility?: string;
    professionalId?: string;
    linkedPatientId?: string;
  }) {
    const existing = await this.findUserByEmail(input.email);
    if (existing) return existing;

    const user = await prisma.user.create({
      data: {
        fullName: input.fullName,
        email: input.email.toLowerCase(),
        passwordHash: await bcrypt.hash(input.password, 10),
        role: input.role,
        phone: input.phone,
        healthFacility: input.healthFacility,
        professionalId: input.professionalId,
        linkedPatientId: input.linkedPatientId
      }
    });
    return mapUser(user);
  }

  async findUserByEmail(email: string) {
    const user = await prisma.user.findUnique({
      where: { email: email.toLowerCase() }
    });
    return user ? mapUser(user) : undefined;
  }

  async findUserById(id: string) {
    const user = await prisma.user.findUnique({ where: { id } });
    return user ? mapUser(user) : undefined;
  }

  async updateUser(id: string, patch: Partial<Omit<User, 'id' | 'createdAt' | 'passwordHash'>>) {
    const user = await prisma.user.update({
      where: { id },
      data: {
        fullName: patch.fullName,
        email: patch.email?.toLowerCase(),
        role: patch.role,
        phone: patch.phone,
        healthFacility: patch.healthFacility,
        professionalId: patch.professionalId,
        linkedPatientId: patch.linkedPatientId
      }
    });
    return mapUser(user);
  }

  async createPatient(input: Omit<Patient, 'id' | 'createdAt' | 'updatedAt'>) {
    const patient = await prisma.patient.create({
      data: {
        userId: input.userId,
        createdByUserId: input.createdByUserId,
        firstName: input.firstName,
        lastName: input.lastName,
        birthDate: input.birthDate,
        sex: input.sex,
        phone: input.phone,
        address: input.address,
        consentForAi: input.consentForAi,
        consentForTeleExpertise: input.consentForTeleExpertise,
        isValidated: input.isValidated
      }
    });
    return mapPatient(patient);
  }

  async listPatients(createdByUserId?: string) {
    const patients = await prisma.patient.findMany({
      where: createdByUserId ? { createdByUserId } : undefined,
      orderBy: { updatedAt: 'desc' }
    });
    return patients.map(mapPatient);
  }

  async findPatientById(id: string) {
    const patient = await prisma.patient.findUnique({ where: { id } });
    return patient ? mapPatient(patient) : undefined;
  }

  async createCase(input: Omit<OrlCase, 'id' | 'createdAt' | 'updatedAt'>) {
    const orlCase = await prisma.orlCase.create({
      data: {
        externalAiCaseId: input.externalAiCaseId,
        patientId: input.patientId,
        createdByUserId: input.createdByUserId,
        assignedSpecialistId: input.assignedSpecialistId,
        symptoms: input.symptoms,
        clinicalNotes: input.clinicalNotes,
        aiResponseJson: input.aiResponse === undefined ? undefined : JSON.stringify(input.aiResponse),
        organizedAiSummaryJson:
          input.organizedAiSummary === undefined ? undefined : JSON.stringify(input.organizedAiSummary),
        status: input.status,
        urgency: input.urgency
      }
    });
    return mapCase(orlCase);
  }

  async updateCase(id: string, patch: Partial<OrlCase>) {
    const current = await this.findCaseById(id);
    if (!current) return undefined;

    const orlCase = await prisma.orlCase.update({
      where: { id },
      data: {
        externalAiCaseId: patch.externalAiCaseId,
        patientId: patch.patientId,
        createdByUserId: patch.createdByUserId,
        assignedSpecialistId: patch.assignedSpecialistId,
        symptoms: patch.symptoms,
        clinicalNotes: patch.clinicalNotes,
        aiResponseJson: patch.aiResponse === undefined ? undefined : JSON.stringify(patch.aiResponse),
        organizedAiSummaryJson:
          patch.organizedAiSummary === undefined ? undefined : JSON.stringify(patch.organizedAiSummary),
        status: patch.status,
        urgency: patch.urgency
      }
    });
    return mapCase(orlCase);
  }

  async findCaseById(id: string) {
    const orlCase = await prisma.orlCase.findUnique({ where: { id } });
    return orlCase ? mapCase(orlCase) : undefined;
  }

  async listCases() {
    const cases = await prisma.orlCase.findMany({
      orderBy: { updatedAt: 'desc' }
    });
    return cases.map(mapCase);
  }
}

export const store = new DataStore();
