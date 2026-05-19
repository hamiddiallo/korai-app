import { notFound } from '../common/http-error.js';
import { store } from '../common/data-store.js';
import { aiService, organizeAiResponse } from '../ai/ai.service.js';

export const caseService = {
  async createDraft(input: {
    createdByUserId: string;
    patientId: string;
    symptoms: string;
    clinicalNotes?: string;
    urgency: 'LOW' | 'MEDIUM' | 'HIGH';
  }) {
    const patient = await store.findPatientById(input.patientId);
    if (!patient) throw notFound('Patient introuvable');

    return store.createCase({
      patientId: input.patientId,
      createdByUserId: input.createdByUserId,
      symptoms: input.symptoms,
      clinicalNotes: input.clinicalNotes,
      status: 'DRAFT',
      urgency: input.urgency
    });
  },

  async createWithAi(input: {
    createdByUserId: string;
    patientId: string;
    symptoms: string;
    clinicalNotes?: string;
    urgency: 'LOW' | 'MEDIUM' | 'HIGH';
    image: Express.Multer.File;
    showSources: boolean;
    requestSpecialistReview: boolean;
  }) {
    const patient = await store.findPatientById(input.patientId);
    if (!patient) throw notFound('Patient introuvable');

    const draft = await store.createCase({
      patientId: input.patientId,
      createdByUserId: input.createdByUserId,
      symptoms: input.symptoms,
      clinicalNotes: input.clinicalNotes,
      status: 'PENDING_AI',
      urgency: input.urgency
    });

    const aiResponse = await aiService.diagnoseSeparate({
      image: input.image,
      symptoms: input.symptoms,
      showSources: input.showSources
    });
    const organizedAiSummary = organizeAiResponse(aiResponse);
    const externalAiCaseId =
      aiResponse && typeof aiResponse === 'object' && 'case_id' in aiResponse
        ? String((aiResponse as { case_id: unknown }).case_id)
        : undefined;

    return store.updateCase(draft.id, {
      aiResponse,
      organizedAiSummary,
      externalAiCaseId,
      status: input.requestSpecialistReview ? 'PENDING_SPECIALIST_REVIEW' : 'AI_COMPLETED'
    });
  },

  async listForUser(user: { id: string; role: string; linkedPatientId?: string }) {
    const cases = await store.listCases();
    if (user.role === 'NURSE') return cases;
    if (user.role === 'SPECIALIST') {
      return cases.filter(
        (orlCase) => orlCase.status === 'PENDING_SPECIALIST_REVIEW' || orlCase.assignedSpecialistId === user.id
      );
    }
    if (user.role === 'PATIENT') {
      return cases.filter(
        (orlCase) =>
          orlCase.createdByUserId === user.id ||
          (user.linkedPatientId && orlCase.patientId === user.linkedPatientId)
      );
    }
    return cases;
  },

  async requestSpecialistReview(id: string) {
    const current = await store.findCaseById(id);
    if (!current) throw notFound('Cas introuvable');
    return store.updateCase(id, { status: 'PENDING_SPECIALIST_REVIEW' });
  },

  async completeSpecialistReview(id: string, specialistId: string, review: unknown) {
    const current = await store.findCaseById(id);
    if (!current) throw notFound('Cas introuvable');
    return store.updateCase(id, {
      assignedSpecialistId: specialistId,
      status: 'SPECIALIST_COMPLETED',
      aiResponse: {
        ...(typeof current.aiResponse === 'object' ? current.aiResponse : {}),
        specialistReview: review
      }
    });
  }
};
