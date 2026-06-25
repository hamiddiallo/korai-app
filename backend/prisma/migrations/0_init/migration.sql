-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "Role" AS ENUM ('NURSE', 'SPECIALIST', 'PATIENT', 'ADMIN');

-- CreateEnum
CREATE TYPE "Sex" AS ENUM ('F', 'M');

-- CreateEnum
CREATE TYPE "ConsultationStatus" AS ENUM ('DRAFT', 'PENDING_AI', 'AI_FAILED', 'AI_COMPLETED', 'PENDING_SPECIALIST_REVIEW', 'SPECIALIST_COMPLETED');

-- CreateEnum
CREATE TYPE "UrgencyLevel" AS ENUM ('LOW', 'MEDIUM', 'HIGH');

-- CreateEnum
CREATE TYPE "EarSide" AS ENUM ('LEFT', 'RIGHT', 'BOTH');

-- CreateEnum
CREATE TYPE "ClinicalReferenceType" AS ENUM ('SYMPTOM', 'MEDICAL_HISTORY', 'TOUCH_CHECK');

-- CreateEnum
CREATE TYPE "ExpertiseStatus" AS ENUM ('PENDING', 'IN_REVIEW', 'COMPLETED');

-- CreateEnum
CREATE TYPE "ExpertDecision" AS ENUM ('VALIDATED', 'CORRECTED', 'INSUFFICIENT');

-- CreateEnum
CREATE TYPE "ChatMessageRole" AS ENUM ('USER', 'ASSISTANT');

-- CreateEnum
CREATE TYPE "ChatConversationStatus" AS ENUM ('ACTIVE', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "ChatDeliveryStatus" AS ENUM ('PENDING', 'COMPLETED', 'FAILED');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "fullName" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "role" "Role" NOT NULL,
    "phone" TEXT,
    "healthFacility" TEXT,
    "professionalId" TEXT,
    "linkedPatientId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Patient" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "createdByUserId" TEXT NOT NULL,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT NOT NULL,
    "birthDate" TEXT,
    "sex" "Sex",
    "phone" TEXT,
    "address" TEXT,
    "consentForAi" BOOLEAN NOT NULL DEFAULT false,
    "consentForTeleExpertise" BOOLEAN NOT NULL DEFAULT false,
    "isValidated" BOOLEAN NOT NULL DEFAULT true,
    "clientLocalId" TEXT,
    "clientMutationId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "Patient_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Consultation" (
    "id" TEXT NOT NULL,
    "externalAiCaseId" TEXT,
    "patientId" TEXT NOT NULL,
    "createdByUserId" TEXT NOT NULL,
    "assignedSpecialistId" TEXT,
    "earSide" "EarSide" NOT NULL DEFAULT 'BOTH',
    "symptomIds" TEXT[],
    "symptomLabels" TEXT[],
    "medicalHistoryIds" TEXT[],
    "medicalHistoryLabels" TEXT[],
    "touchCheckIds" TEXT[],
    "touchCheckLabels" TEXT[],
    "touchObservations" JSONB,
    "clinicalNotes" TEXT,
    "clinicalNarrative" TEXT NOT NULL,
    "status" "ConsultationStatus" NOT NULL DEFAULT 'DRAFT',
    "urgency" "UrgencyLevel" NOT NULL DEFAULT 'MEDIUM',
    "aiErrorCode" TEXT,
    "aiErrorMessage" TEXT,
    "clientLocalId" TEXT,
    "clientMutationId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "Consultation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OtoscopicImage" (
    "id" TEXT NOT NULL,
    "consultationId" TEXT NOT NULL,
    "earSide" "EarSide" NOT NULL,
    "mimeType" TEXT NOT NULL,
    "fileName" TEXT,
    "byteSize" INTEGER,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "OtoscopicImage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AiResponse" (
    "id" TEXT NOT NULL,
    "consultationId" TEXT NOT NULL,
    "rawJson" JSONB NOT NULL,
    "imageOpinion" TEXT,
    "ragOpinion" TEXT,
    "likelyDiagnosis" TEXT,
    "confidenceLabel" TEXT,
    "warnings" TEXT[],
    "sources" TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "AiResponse_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ExpertiseRequest" (
    "id" TEXT NOT NULL,
    "consultationId" TEXT NOT NULL,
    "requestedByUserId" TEXT NOT NULL,
    "assignedToUserId" TEXT,
    "status" "ExpertiseStatus" NOT NULL DEFAULT 'PENDING',
    "decision" "ExpertDecision",
    "comment" TEXT,
    "correctedLikelyDiagnosis" TEXT,
    "correctedRecommendation" TEXT,
    "correctedClinicalSummary" TEXT,
    "aiLikelyDiagnosisSnapshot" TEXT,
    "aiConfidenceLabelSnapshot" TEXT,
    "aiSummarySnapshot" JSONB,
    "summaryNote" TEXT,
    "noteAudio" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "ExpertiseRequest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ClinicalReferenceItem" (
    "id" TEXT NOT NULL,
    "type" "ClinicalReferenceType" NOT NULL,
    "label" TEXT NOT NULL,
    "description" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "ClinicalReferenceItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ChatConversation" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "title" TEXT NOT NULL DEFAULT 'Nouvelle conversation',
    "status" "ChatConversationStatus" NOT NULL DEFAULT 'ACTIVE',
    "externalConversationId" TEXT,
    "messageCount" INTEGER NOT NULL DEFAULT 0,
    "lastMessageAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "archivedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "ChatConversation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ChatMessage" (
    "id" TEXT NOT NULL,
    "conversationId" TEXT NOT NULL,
    "role" "ChatMessageRole" NOT NULL,
    "content" TEXT NOT NULL,
    "sources" TEXT[],
    "sequence" INTEGER NOT NULL,
    "deliveryStatus" "ChatDeliveryStatus" NOT NULL DEFAULT 'COMPLETED',
    "isRead" BOOLEAN NOT NULL DEFAULT false,
    "errorCode" TEXT,
    "externalRawJson" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "ChatMessage_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "Patient_userId_key" ON "Patient"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "Patient_createdByUserId_clientLocalId_key" ON "Patient"("createdByUserId", "clientLocalId");

-- CreateIndex
CREATE UNIQUE INDEX "Patient_createdByUserId_clientMutationId_key" ON "Patient"("createdByUserId", "clientMutationId");

-- CreateIndex
CREATE UNIQUE INDEX "Consultation_createdByUserId_clientLocalId_key" ON "Consultation"("createdByUserId", "clientLocalId");

-- CreateIndex
CREATE UNIQUE INDEX "Consultation_createdByUserId_clientMutationId_key" ON "Consultation"("createdByUserId", "clientMutationId");

-- CreateIndex
CREATE UNIQUE INDEX "AiResponse_consultationId_key" ON "AiResponse"("consultationId");

-- CreateIndex
CREATE UNIQUE INDEX "ExpertiseRequest_consultationId_key" ON "ExpertiseRequest"("consultationId");

-- CreateIndex
CREATE INDEX "ClinicalReferenceItem_type_isActive_idx" ON "ClinicalReferenceItem"("type", "isActive");

-- CreateIndex
CREATE INDEX "ChatConversation_userId_status_lastMessageAt_idx" ON "ChatConversation"("userId", "status", "lastMessageAt" DESC);

-- CreateIndex
CREATE INDEX "ChatMessage_conversationId_sequence_idx" ON "ChatMessage"("conversationId", "sequence");

-- CreateIndex
CREATE UNIQUE INDEX "ChatMessage_conversationId_sequence_key" ON "ChatMessage"("conversationId", "sequence");

-- AddForeignKey
ALTER TABLE "Patient" ADD CONSTRAINT "Patient_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Patient" ADD CONSTRAINT "Patient_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Consultation" ADD CONSTRAINT "Consultation_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "Patient"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Consultation" ADD CONSTRAINT "Consultation_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Consultation" ADD CONSTRAINT "Consultation_assignedSpecialistId_fkey" FOREIGN KEY ("assignedSpecialistId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "OtoscopicImage" ADD CONSTRAINT "OtoscopicImage_consultationId_fkey" FOREIGN KEY ("consultationId") REFERENCES "Consultation"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiResponse" ADD CONSTRAINT "AiResponse_consultationId_fkey" FOREIGN KEY ("consultationId") REFERENCES "Consultation"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ExpertiseRequest" ADD CONSTRAINT "ExpertiseRequest_consultationId_fkey" FOREIGN KEY ("consultationId") REFERENCES "Consultation"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ExpertiseRequest" ADD CONSTRAINT "ExpertiseRequest_requestedByUserId_fkey" FOREIGN KEY ("requestedByUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ExpertiseRequest" ADD CONSTRAINT "ExpertiseRequest_assignedToUserId_fkey" FOREIGN KEY ("assignedToUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChatConversation" ADD CONSTRAINT "ChatConversation_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChatMessage" ADD CONSTRAINT "ChatMessage_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "ChatConversation"("id") ON DELETE CASCADE ON UPDATE CASCADE;

