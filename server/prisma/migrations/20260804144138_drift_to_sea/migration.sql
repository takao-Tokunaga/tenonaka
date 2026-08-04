-- AlterTable
ALTER TABLE "Letter" DROP COLUMN "recipientAddress",
ADD COLUMN     "readReaderBpm" DOUBLE PRECISION;

-- CreateIndex
CREATE INDEX "Letter_claimedByUserId_sentAt_idx" ON "Letter"("claimedByUserId", "sentAt");

