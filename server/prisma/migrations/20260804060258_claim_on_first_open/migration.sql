-- AlterTable
ALTER TABLE "Letter" ADD COLUMN     "claimedAt" TIMESTAMP(3),
ADD COLUMN     "claimedByUserId" TEXT;
