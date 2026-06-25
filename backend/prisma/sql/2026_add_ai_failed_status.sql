-- Migration manuelle : statut AI_FAILED + champs d'erreur IA sur Consultation.
--
-- Contexte : le dossier prisma/migrations/ a été supprimé pendant le refactor.
-- Appliquer ce script tel quel (idempotent) sur la base PostgreSQL existante,
-- OU le régénérer proprement via `npx prisma migrate dev --name add_ai_failed_status`
-- une fois le dossier de migrations réinitialisé.
--
-- À exécuter : psql "$DATABASE_URL" -f prisma/sql/2026_add_ai_failed_status.sql

-- 1) Nouvelle valeur d'enum (placée après PENDING_AI pour la lisibilité).
ALTER TYPE "ConsultationStatus" ADD VALUE IF NOT EXISTS 'AI_FAILED' AFTER 'PENDING_AI';

-- 2) Colonnes d'erreur IA (nullable, aucune valeur par défaut).
ALTER TABLE "Consultation" ADD COLUMN IF NOT EXISTS "aiErrorCode" TEXT;
ALTER TABLE "Consultation" ADD COLUMN IF NOT EXISTS "aiErrorMessage" TEXT;
