-- AlterTable
ALTER TABLE "OtoscopicImage" ADD COLUMN     "storageKey" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "OtoscopicImage_storageKey_key" ON "OtoscopicImage"("storageKey");

