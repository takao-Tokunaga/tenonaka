-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateTable
CREATE TABLE "Letter" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "senderName" TEXT,
    "recipientName" TEXT,
    "senderBpm" DOUBLE PRECISION,
    "senderUserId" TEXT NOT NULL,
    "sentAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "readHeldSeconds" DOUBLE PRECISION,
    "readReleaseCount" INTEGER,
    "readCompleted" BOOLEAN,
    "readAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Letter_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Letter_code_key" ON "Letter"("code");

-- CreateIndex
CREATE INDEX "Letter_senderUserId_sentAt_idx" ON "Letter"("senderUserId", "sentAt");

