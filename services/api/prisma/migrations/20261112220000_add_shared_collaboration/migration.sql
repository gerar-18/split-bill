-- CreateEnum
CREATE TYPE "SharedSessionStatus" AS ENUM ('ACTIVE', 'CLOSED', 'QUARANTINED');

-- CreateTable
CREATE TABLE "item_claims" (
    "id" TEXT NOT NULL,
    "itemId" TEXT NOT NULL,
    "participantId" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "item_claims_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "shared_sessions" (
    "id" TEXT NOT NULL,
    "shareCode" TEXT NOT NULL,
    "receiptId" TEXT NOT NULL,
    "hostTokenHash" TEXT NOT NULL,
    "status" "SharedSessionStatus" NOT NULL DEFAULT 'ACTIVE',
    "version" INTEGER NOT NULL DEFAULT 1,
    "includeImage" BOOLEAN NOT NULL DEFAULT false,
    "imageHiddenByModeration" BOOLEAN NOT NULL DEFAULT false,
    "imageBase64OptIn" TEXT,
    "reportCount" INTEGER NOT NULL DEFAULT 0,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "shared_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "shared_participants" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "participantId" TEXT NOT NULL,
    "displayName" TEXT NOT NULL,
    "guestTokenHash" TEXT NOT NULL,
    "isHost" BOOLEAN NOT NULL DEFAULT false,
    "revokedAt" TIMESTAMPTZ(3),
    "joinedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "shared_participants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "session_reports" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "reporterHash" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "note" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "session_reports_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "receipt_items_receiptId_idx" ON "receipt_items"("receiptId");

-- CreateIndex
CREATE INDEX "receipt_participants_receiptId_idx" ON "receipt_participants"("receiptId");

-- CreateIndex
CREATE INDEX "item_claims_participantId_idx" ON "item_claims"("participantId");

-- CreateIndex
CREATE UNIQUE INDEX "item_claims_itemId_participantId_key" ON "item_claims"("itemId", "participantId");

-- CreateIndex
CREATE UNIQUE INDEX "shared_sessions_shareCode_key" ON "shared_sessions"("shareCode");

-- CreateIndex
CREATE UNIQUE INDEX "shared_sessions_receiptId_key" ON "shared_sessions"("receiptId");

-- CreateIndex
CREATE INDEX "shared_sessions_expiresAt_idx" ON "shared_sessions"("expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "shared_participants_guestTokenHash_key" ON "shared_participants"("guestTokenHash");

-- CreateIndex
CREATE INDEX "shared_participants_sessionId_idx" ON "shared_participants"("sessionId");

-- CreateIndex
CREATE INDEX "shared_participants_participantId_idx" ON "shared_participants"("participantId");

-- CreateIndex
CREATE UNIQUE INDEX "session_reports_sessionId_reporterHash_key" ON "session_reports"("sessionId", "reporterHash");

-- AddForeignKey
ALTER TABLE "item_claims" ADD CONSTRAINT "item_claims_itemId_fkey" FOREIGN KEY ("itemId") REFERENCES "receipt_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "item_claims" ADD CONSTRAINT "item_claims_participantId_fkey" FOREIGN KEY ("participantId") REFERENCES "receipt_participants"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shared_sessions" ADD CONSTRAINT "shared_sessions_receiptId_fkey" FOREIGN KEY ("receiptId") REFERENCES "receipts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shared_participants" ADD CONSTRAINT "shared_participants_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "shared_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shared_participants" ADD CONSTRAINT "shared_participants_participantId_fkey" FOREIGN KEY ("participantId") REFERENCES "receipt_participants"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "session_reports" ADD CONSTRAINT "session_reports_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "shared_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
