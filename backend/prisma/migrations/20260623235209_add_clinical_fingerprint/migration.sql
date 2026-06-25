-- AlterTable
ALTER TABLE "Consultation" ADD COLUMN     "clinicalFingerprint" TEXT;

-- CreateIndex
CREATE INDEX "Consultation_clinicalFingerprint_idx" ON "Consultation"("clinicalFingerprint");
