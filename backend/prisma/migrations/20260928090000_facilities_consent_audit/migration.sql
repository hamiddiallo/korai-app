-- AlterTable
ALTER TABLE "User" ADD COLUMN     "facilityId" TEXT;

-- AlterTable
ALTER TABLE "Patient" ADD COLUMN     "consentForAiAt" TIMESTAMP(3),
ADD COLUMN     "consentForTeleExpertiseAt" TIMESTAMP(3),
ADD COLUMN     "facilityId" TEXT;

-- CreateTable
CREATE TABLE "Facility" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "normalizedName" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Facility_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AuditLog" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "actorUserId" TEXT,
    "actorRole" "Role",
    "action" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT,
    "patientId" TEXT,
    "ip" TEXT,
    "details" JSONB,

    CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Facility_normalizedName_key" ON "Facility"("normalizedName");

-- CreateIndex
CREATE INDEX "AuditLog_createdAt_idx" ON "AuditLog"("createdAt");

-- CreateIndex
CREATE INDEX "AuditLog_patientId_createdAt_idx" ON "AuditLog"("patientId", "createdAt");

-- CreateIndex
CREATE INDEX "AuditLog_actorUserId_createdAt_idx" ON "AuditLog"("actorUserId", "createdAt");

-- CreateIndex
CREATE INDEX "Patient_facilityId_idx" ON "Patient"("facilityId");

-- AddForeignKey
ALTER TABLE "User" ADD CONSTRAINT "User_facilityId_fkey" FOREIGN KEY ("facilityId") REFERENCES "Facility"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Patient" ADD CONSTRAINT "Patient_facilityId_fkey" FOREIGN KEY ("facilityId") REFERENCES "Facility"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Reprise des données existantes ------------------------------------------
-- 1. Un établissement par structure déclarée par les soignants. Le nom
--    normalisé (minuscules, sans accents, espaces réduits) doit rester
--    identique à `normalizeFacilityName` (src/modules/facilities).
INSERT INTO "Facility" ("id", "name", "normalizedName", "createdAt", "updatedAt")
SELECT gen_random_uuid()::text, MIN(trim("healthFacility")), norm, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM (
  SELECT "healthFacility",
         regexp_replace(
           translate(lower(trim("healthFacility")),
                     'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ',
                     'aaaaaaceeeeiiiinooooouuuuyy'),
           '\s+', ' ', 'g') AS norm
  FROM "User"
  WHERE "role" = 'NURSE' AND "healthFacility" IS NOT NULL AND trim("healthFacility") <> ''
) AS declared
GROUP BY norm;

-- 2. Chaque soignant rejoint l'établissement qu'il a déclaré.
UPDATE "User" AS u
SET "facilityId" = f."id"
FROM "Facility" AS f
WHERE u."role" = 'NURSE'
  AND u."healthFacility" IS NOT NULL
  AND f."normalizedName" = regexp_replace(
        translate(lower(trim(u."healthFacility")),
                  'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ',
                  'aaaaaaceeeeiiiinooooouuuuyy'),
        '\s+', ' ', 'g');

-- 3. Un patient rejoint l'établissement du soignant qui a créé son dossier,
--    sinon celui du premier soignant qui l'a vu en consultation.
UPDATE "Patient" AS p
SET "facilityId" = u."facilityId"
FROM "User" AS u
WHERE p."createdByUserId" = u."id" AND u."facilityId" IS NOT NULL;

UPDATE "Patient" AS p
SET "facilityId" = first_nurse."facilityId"
FROM (
  SELECT DISTINCT ON (c."patientId") c."patientId", u."facilityId"
  FROM "Consultation" AS c
  JOIN "User" AS u ON u."id" = c."createdByUserId"
  WHERE u."facilityId" IS NOT NULL
  ORDER BY c."patientId", c."createdAt"
) AS first_nurse
WHERE p."id" = first_nurse."patientId" AND p."facilityId" IS NULL;

-- 4. Accords déjà donnés : datés du jour de la migration.
UPDATE "Patient" SET "consentForAiAt" = CURRENT_TIMESTAMP WHERE "consentForAi" = true;
UPDATE "Patient" SET "consentForTeleExpertiseAt" = CURRENT_TIMESTAMP WHERE "consentForTeleExpertise" = true;
