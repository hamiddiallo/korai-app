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

    const itemsToSeed = [
      // SYMPTOMS
      { type: 'SYMPTOM', label: 'Otalgie', description: "Douleur à l'oreille, pouvant être d'origine interne ou irradiée.", sortOrder: 10 },
      { type: 'SYMPTOM', label: 'Otorrhée', description: "Écoulement de liquide (clair, purulent ou sanguin) provenant du conduit auditif.", sortOrder: 20 },
      { type: 'SYMPTOM', label: 'Hypoacousie', description: "Baisse partielle de l'acuité auditive.", sortOrder: 30 },
      { type: 'SYMPTOM', label: 'Acouphènes', description: "Perception de bruits parasites (sifflements, bourdonnements) sans source externe.", sortOrder: 40 },
      { type: 'SYMPTOM', label: 'Fièvre', description: "Élévation de la température corporelle, souvent associée à une infection.", sortOrder: 50 },
      { type: 'SYMPTOM', label: 'Vertiges', description: "Sensation de rotation ou de perte d'équilibre, souvent liée à l'oreille interne.", sortOrder: 60 },
      { type: 'SYMPTOM', label: 'Prurit auriculaire', description: "Démangeaisons à l'intérieur ou autour du conduit auditif.", sortOrder: 70 },
      { type: 'SYMPTOM', label: 'Sensation de plénitude', description: "Sensation désagréable d'oreille pleine ou bouchée.", sortOrder: 80 },
      { type: 'SYMPTOM', label: 'Écoulement purulent', description: "Sécrétion épaisse et jaunâtre/verdâtre, signe d'une surinfection.", sortOrder: 90 },
      { type: 'SYMPTOM', label: 'Perforation tympanique', description: "Rupture ou trou dans la membrane du tympan.", sortOrder: 100 },
      { type: 'SYMPTOM', label: 'Rhinorrhée', description: "Écoulement nasal, pouvant aggraver les troubles ORL via la trompe d'Eustache.", sortOrder: 110 },
      { type: 'SYMPTOM', label: 'Obstruction nasale', description: "Nez bouché, gênant la respiration et la ventilation de l'oreille.", sortOrder: 120 },
      { type: 'SYMPTOM', label: 'Douleur mastoïdienne', description: "Douleur derrière l'oreille, au niveau de l'os mastoïde.", sortOrder: 130 },
      { type: 'SYMPTOM', label: 'Paralysie faciale', description: "Perte de mobilité d'une moitié du visage, complication grave possible.", sortOrder: 140 },

      // MEDICAL HISTORY (ANTECEDENTS)
      { type: 'MEDICAL_HISTORY', label: 'Otites récurrentes', description: "Antécédent d'otites moyennes aiguës à répétition (au moins 3 épisodes en 6 mois ou 4 en un an).", sortOrder: 10 },
      { type: 'MEDICAL_HISTORY', label: 'Chirurgie ORL', description: "Antécédent d'intervention chirurgicale de la sphère ORL (tympanoplastie, aérateurs transtympaniques, etc.).", sortOrder: 20 },
      { type: 'MEDICAL_HISTORY', label: 'Traumatisme auriculaire', description: "Antécédent de choc physique, d'agression sonore, d'introduction d'objet ou d'accident barométrique sur l'oreille.", sortOrder: 30 },
      { type: 'MEDICAL_HISTORY', label: 'Perforation tympanique ancienne', description: "Présence connue d'une brèche non cicatrisée ou d'une séquelle de perforation de la membrane du tympan.", sortOrder: 40 },
      { type: 'MEDICAL_HISTORY', label: 'Cholestéatome', description: "Antécédent de cholestéatome de l'oreille moyenne, nécessitant une surveillance régulière.", sortOrder: 50 },
      { type: 'MEDICAL_HISTORY', label: 'Diabète', description: "Diabète de type 1 ou 2, facteur favorisant les infections ORL sévères.", sortOrder: 60 },
      { type: 'MEDICAL_HISTORY', label: 'Immunodépression', description: "Déficit immunitaire congénital ou acquis (VIH, chimiothérapie, traitement immunosuppresseur).", sortOrder: 70 },
      { type: 'MEDICAL_HISTORY', label: 'Allergie', description: "Terrain allergique (rhinite allergique, asthme) pouvant provoquer un dysfonctionnement tubaire.", sortOrder: 80 },
      { type: 'MEDICAL_HISTORY', label: 'Tabagisme', description: "Consommation de tabac (active ou passive), irritant les muqueuses respiratoires.", sortOrder: 90 },
      { type: 'MEDICAL_HISTORY', label: 'Barotraumatisme', description: "Lésion de l'oreille causée par des variations rapides de pression (plongée, avion).", sortOrder: 100 },
      { type: 'MEDICAL_HISTORY', label: 'HTA', description: "Hypertension artérielle, pouvant être liée à des acouphènes ou des troubles vasculaires.", sortOrder: 110 },

      // TOUCH CHECKS
      { type: 'TOUCH_CHECK', label: 'Douleur à la traction du pavillon', description: "Douleur provoquée par la mobilisation du pavillon de l'oreille, évocatrice d'une otite externe.", sortOrder: 10 },
      { type: 'TOUCH_CHECK', label: 'Douleur à la pression du tragus', description: "Signe du tragus positif, douleur lors de la pression sur le tragus.", sortOrder: 20 },
      { type: 'TOUCH_CHECK', label: 'Sensibilité mastoïdienne', description: "Douleur provoquée par la palpation de la zone osseuse située derrière l'oreille (mastoïde).", sortOrder: 30 },
      { type: 'TOUCH_CHECK', label: 'Ganglions cervicaux palpables', description: "Présence d'adénopathies cervicales sensibles ou non dans le territoire de drainage de l'oreille.", sortOrder: 40 }
    ];

    for (const item of itemsToSeed) {
      const existing = await prisma.clinicalReferenceItem.findFirst({
        where: { type: item.type, label: item.label }
      });
      if (!existing) {
        await prisma.clinicalReferenceItem.create({ data: item });
      } else {
        await prisma.clinicalReferenceItem.update({
          where: { id: existing.id },
          data: {
            description: item.description,
            sortOrder: item.sortOrder
          }
        });
      }
    }
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
