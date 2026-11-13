import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  GoneException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { ReceiptsService } from '../receipts/receipts.service';
import {
  CreateSharedSessionDto,
  JoinSharedSessionDto,
  ReportSessionDto,
  ToggleClaimDto,
} from './dto/collaboration.dto';
import { CollaborationActor } from './guards/session-token.guard';
import { CollaborationEventsService } from './collaboration.events';
import {
  generateCapabilityToken,
  generateShareCode,
  isValidShareCode,
  normalizeShareCode,
  sanitizeUserText,
  sha256Hex,
} from './utils/sanitize.util';

const SESSION_TTL_MS = 24 * 60 * 60 * 1000;
export const AUTO_QUARANTINE_THRESHOLD = 3;

export interface CollaborationSnapshotDto {
  sessionId: string;
  shareCode: string;
  status: 'ACTIVE' | 'CLOSED' | 'QUARANTINED';
  version: number;
  includeImage: boolean;
  imageHiddenByModeration: boolean;
  imageBase64OptIn: string | null;
  reportCount: number;
  expiresAt: string;
  receipt: {
    id: string;
    title: string;
    date: string;
    currency: string;
    subtotalCents: number;
    taxCents: number;
    tipCents: number;
    totalCents: number;
    items: Array<{
      id: string;
      name: string;
      quantity: number;
      priceCents: number;
      claimantIds: string[];
    }>;
    participants: Array<{
      id: string;
      name: string;
      isHost: boolean;
    }>;
  };
}

@Injectable()
export class CollaborationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly receiptsService: ReceiptsService,
    private readonly eventsService: CollaborationEventsService,
  ) {}

  async createSession(
    dto: CreateSharedSessionDto,
    ownerId?: string,
  ): Promise<{
    shareCode: string;
    sessionToken: string;
    participantId: string;
    snapshot: CollaborationSnapshotDto;
  }> {
    this.receiptsService.validateMoneyInvariants(dto.receipt);

    const cleanHostName = sanitizeUserText(dto.hostDisplayName, 60);
    const cleanTitle = sanitizeUserText(dto.receipt.title, 255);
    if (!cleanHostName || !cleanTitle) {
      throw new BadRequestException(
        'Host display name and receipt title cannot be empty after sanitization',
      );
    }

    const sanitizedItems = dto.receipt.items.map((item) => {
      const cleanName = sanitizeUserText(item.name, 255);
      if (!cleanName) {
        throw new BadRequestException(
          `Item '${item.id}' name cannot be empty after sanitization`,
        );
      }
      return { ...item, name: cleanName };
    });

    const sanitizedParticipants = dto.receipt.participants.map((p) => {
      const cleanName = sanitizeUserText(p.name, 60);
      if (!cleanName) {
        throw new BadRequestException(
          `Participant '${p.id}' name cannot be empty after sanitization`,
        );
      }
      return { ...p, name: cleanName };
    });

    const receiptId = randomUUID();
    const matchedHostParticipant = sanitizedParticipants.find(
      (p) => p.name.toLowerCase() === cleanHostName.toLowerCase(),
    );
    const hostParticipantId = matchedHostParticipant?.id ?? randomUUID();
    const shareCode = generateShareCode();
    const hostToken = generateCapabilityToken();
    const hostTokenHash = sha256Hex(hostToken);
    const expiresAt = new Date(Date.now() + SESSION_TTL_MS);

    // Privacy-first: store image ONLY when explicit opt-in flag is true
    const includeImage = Boolean(dto.includeImage && dto.imageBase64OptIn);
    const storedImage = includeImage ? dto.imageBase64OptIn ?? null : null;

    const participantsToCreate = matchedHostParticipant
      ? sanitizedParticipants
      : [...sanitizedParticipants, { id: hostParticipantId, name: cleanHostName }];

    await this.prisma.$transaction(async (tx) => {
      await tx.receipt.create({
        data: {
          id: receiptId,
          ownerId: ownerId ?? null,
          title: cleanTitle,
          date: new Date(dto.receipt.date),
          currency: dto.receipt.currency.toUpperCase(),
          subtotalCents: BigInt(dto.receipt.subtotalCents),
          taxCents: BigInt(dto.receipt.taxCents),
          tipCents: BigInt(dto.receipt.tipCents),
          totalCents: BigInt(dto.receipt.totalCents),
          version: 1,
          clientCreatedAt: new Date(dto.receipt.clientCreatedAt),
          clientUpdatedAt: new Date(dto.receipt.clientUpdatedAt),
          items: {
            create: sanitizedItems.map((item) => ({
              id: item.id,
              name: item.name,
              quantity: item.quantity,
              priceCents: BigInt(item.priceCents),
            })),
          },
          participants: {
            create: participantsToCreate.map((p) => ({
              id: p.id,
              name: p.name,
            })),
          },
        },
      });

      const createdSession = await tx.sharedSession.create({
        data: {
          shareCode,
          receiptId,
          hostTokenHash,
          status: 'ACTIVE',
          version: 1,
          includeImage,
          imageHiddenByModeration: false,
          imageBase64OptIn: storedImage,
          reportCount: 0,
          expiresAt,
        },
      });

      await tx.sharedParticipant.create({
        data: {
          sessionId: createdSession.id,
          participantId: hostParticipantId,
          displayName: cleanHostName,
          guestTokenHash: hostTokenHash,
          isHost: true,
        },
      });
    });

    const snapshot = await this.loadSnapshotByCode(shareCode);
    return {
      shareCode,
      sessionToken: hostToken,
      participantId: hostParticipantId,
      snapshot,
    };
  }

  async joinSession(
    rawCode: string,
    dto: JoinSharedSessionDto,
  ): Promise<{
    shareCode: string;
    sessionToken: string;
    participantId: string;
    snapshot: CollaborationSnapshotDto;
  }> {
    const shareCode = this.assertValidCode(rawCode);
    const cleanName = sanitizeUserText(dto.displayName, 60);
    if (!cleanName) {
      throw new BadRequestException(
        'Display name cannot be empty after sanitization',
      );
    }

    const session = await this.prisma.sharedSession.findUnique({
      where: { shareCode },
    });
    if (!session) {
      throw new NotFoundException(`Shared session '${shareCode}' not found`);
    }
    this.assertSessionJoinable(session);

    const guestToken = generateCapabilityToken();
    const guestTokenHash = sha256Hex(guestToken);
    const participantId = randomUUID();

    await this.prisma.$transaction(async (tx) => {
      const bumped = await tx.sharedSession.updateMany({
        where: { id: session.id, status: 'ACTIVE' },
        data: { version: { increment: 1 } },
      });
      if (bumped.count === 0) {
        throw new ForbiddenException('Shared session is no longer active');
      }

      await tx.receiptParticipant.create({
        data: {
          id: participantId,
          receiptId: session.receiptId,
          name: cleanName,
        },
      });

      await tx.sharedParticipant.create({
        data: {
          sessionId: session.id,
          participantId,
          displayName: cleanName,
          guestTokenHash,
          isHost: false,
        },
      });
    });

    const snapshot = await this.loadSnapshotByCode(shareCode);
    this.eventsService.emit(shareCode, {
      shareCode,
      version: snapshot.version,
      status: snapshot.status,
      eventType: 'snapshot_updated',
    });

    return {
      shareCode,
      sessionToken: guestToken,
      participantId,
      snapshot,
    };
  }

  async getSnapshot(
    rawCode: string,
    sinceVersion?: number,
  ): Promise<
    CollaborationSnapshotDto | { unchanged: true; version: number; status: string }
  > {
    const shareCode = this.assertValidCode(rawCode);
    const snapshot = await this.loadSnapshotByCode(shareCode);
    if (sinceVersion !== undefined && snapshot.version <= sinceVersion) {
      return {
        unchanged: true,
        version: snapshot.version,
        status: snapshot.status,
      };
    }
    return snapshot;
  }

  async toggleClaim(
    rawCode: string,
    actor: CollaborationActor,
    dto: ToggleClaimDto,
  ): Promise<CollaborationSnapshotDto> {
    const shareCode = this.assertValidCode(rawCode);

    const updatedVersion = await this.prisma.$transaction(async (tx) => {
      const session = await tx.sharedSession.findUnique({
        where: { id: actor.sessionId },
      });
      if (!session) {
        throw new NotFoundException('Shared session not found');
      }
      this.assertSessionMutable(session);

      const item = await tx.receiptItem.findFirst({
        where: { id: dto.itemId, receiptId: session.receiptId },
      });
      if (!item) {
        throw new NotFoundException(
          `Item '${dto.itemId}' not found in shared receipt`,
        );
      }

      const bumped = await tx.sharedSession.updateMany({
        where: {
          id: session.id,
          version: dto.expectedVersion,
          status: 'ACTIVE',
        },
        data: { version: { increment: 1 } },
      });

      if (bumped.count === 0) {
        const latest = await tx.sharedSession.findUnique({
          where: { id: session.id },
          select: { version: true },
        });
        throw new ConflictException({
          message:
            'Version conflict: session was updated by another participant',
          serverVersion: latest?.version ?? session.version,
        });
      }

      if (dto.action === 'claim') {
        await tx.itemClaim.upsert({
          where: {
            itemId_participantId: {
              itemId: dto.itemId,
              participantId: actor.participantId,
            },
          },
          create: {
            itemId: dto.itemId,
            participantId: actor.participantId,
          },
          update: {},
        });
      } else {
        await tx.itemClaim.deleteMany({
          where: {
            itemId: dto.itemId,
            participantId: actor.participantId,
          },
        });
      }

      return dto.expectedVersion + 1;
    });

    const snapshot = await this.loadSnapshotByCode(shareCode);
    this.eventsService.emit(shareCode, {
      shareCode,
      version: updatedVersion,
      status: snapshot.status,
      eventType: 'snapshot_updated',
    });

    return snapshot;
  }

  async reportSession(
    rawCode: string,
    actor: CollaborationActor,
    dto: ReportSessionDto,
  ): Promise<{
    reported: boolean;
    quarantined: boolean;
    reportCount: number;
  }> {
    const shareCode = this.assertValidCode(rawCode);
    const cleanNote = dto.note ? sanitizeUserText(dto.note, 300) : null;
    const reporterHash = sha256Hex(`${actor.sessionId}:${actor.tokenHash}`);

    const outcome = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.sessionReport.findUnique({
        where: {
          sessionId_reporterHash: {
            sessionId: actor.sessionId,
            reporterHash,
          },
        },
      });

      const currentSession = await tx.sharedSession.findUnique({
        where: { id: actor.sessionId },
      });
      if (!currentSession) {
        throw new NotFoundException('Shared session not found');
      }

      if (existing) {
        return {
          reported: true,
          quarantined: currentSession.status === 'QUARANTINED',
          reportCount: currentSession.reportCount,
          version: currentSession.version,
          newlyQuarantined: false,
        };
      }

      await tx.sessionReport.create({
        data: {
          sessionId: actor.sessionId,
          reporterHash,
          reason: dto.reason,
          note: cleanNote,
        },
      });

      const nextCount = currentSession.reportCount + 1;
      const shouldQuarantine = nextCount >= AUTO_QUARANTINE_THRESHOLD;

      const updated = await tx.sharedSession.update({
        where: { id: actor.sessionId },
        data: {
          reportCount: nextCount,
          version: { increment: 1 },
          ...(shouldQuarantine
            ? {
                status: 'QUARANTINED',
                imageHiddenByModeration: true,
                includeImage: false,
                imageBase64OptIn: null,
              }
            : {}),
        },
      });

      return {
        reported: true,
        quarantined: updated.status === 'QUARANTINED',
        reportCount: updated.reportCount,
        version: updated.version,
        newlyQuarantined:
          shouldQuarantine && currentSession.status !== 'QUARANTINED',
      };
    });

    this.eventsService.emit(shareCode, {
      shareCode,
      version: outcome.version,
      status: outcome.quarantined ? 'QUARANTINED' : 'ACTIVE',
      eventType: outcome.quarantined
        ? 'session_quarantined'
        : 'snapshot_updated',
    });

    return {
      reported: outcome.reported,
      quarantined: outcome.quarantined,
      reportCount: outcome.reportCount,
    };
  }

  async leaveSession(
    rawCode: string,
    actor: CollaborationActor,
  ): Promise<{ left: boolean }> {
    this.assertValidCode(rawCode);
    await this.prisma.sharedParticipant.update({
      where: { id: actor.sharedParticipantId },
      data: { revokedAt: new Date() },
    });
    return { left: true };
  }

  async closeSession(
    rawCode: string,
    actor: CollaborationActor,
  ): Promise<{ closed: boolean }> {
    const shareCode = this.assertValidCode(rawCode);
    if (!actor.isHost) {
      throw new ForbiddenException(
        'Only the session host can close a shared receipt',
      );
    }

    const updated = await this.prisma.sharedSession.update({
      where: { id: actor.sessionId },
      data: {
        status: 'CLOSED',
        includeImage: false,
        imageBase64OptIn: null,
        version: { increment: 1 },
      },
    });

    this.eventsService.emit(shareCode, {
      shareCode,
      version: updated.version,
      status: 'CLOSED',
      eventType: 'session_closed',
    });

    return { closed: true };
  }

  private assertValidCode(rawCode: string): string {
    if (!isValidShareCode(rawCode)) {
      throw new BadRequestException('Invalid share code format');
    }
    return normalizeShareCode(rawCode);
  }

  private assertSessionJoinable(session: {
    status: string;
    expiresAt: Date;
  }): void {
    if (session.expiresAt <= new Date()) {
      throw new GoneException('Shared session has expired');
    }
    if (session.status === 'CLOSED') {
      throw new GoneException('Shared session has been closed by host');
    }
    if (session.status === 'QUARANTINED') {
      throw new ForbiddenException(
        'Shared session has been quarantined due to moderation reports',
      );
    }
  }

  private assertSessionMutable(session: {
    status: string;
    expiresAt: Date;
  }): void {
    this.assertSessionJoinable(session);
  }

  private async loadSnapshotByCode(
    shareCode: string,
  ): Promise<CollaborationSnapshotDto> {
    const session = await this.prisma.sharedSession.findUnique({
      where: { shareCode },
      include: {
        sharedParticipants: {
          where: { revokedAt: null },
        },
        receipt: {
          include: {
            items: {
              include: { claims: true },
            },
            participants: true,
          },
        },
      },
    });

    if (!session) {
      throw new NotFoundException(`Shared session '${shareCode}' not found`);
    }
    if (session.expiresAt <= new Date()) {
      throw new GoneException('Shared session has expired');
    }

    const hostParticipantIds = new Set(
      session.sharedParticipants
        .filter((sp) => sp.isHost)
        .map((sp) => sp.participantId),
    );

    const hideImage =
      session.status === 'QUARANTINED' ||
      session.imageHiddenByModeration ||
      !session.includeImage;

    return {
      sessionId: session.id,
      shareCode: session.shareCode,
      status: session.status,
      version: session.version,
      includeImage: hideImage ? false : session.includeImage,
      imageHiddenByModeration: session.imageHiddenByModeration,
      imageBase64OptIn: hideImage ? null : session.imageBase64OptIn,
      reportCount: session.reportCount,
      expiresAt: session.expiresAt.toISOString(),
      receipt: {
        id: session.receipt.id,
        title: session.receipt.title,
        date: session.receipt.date.toISOString(),
        currency: session.receipt.currency,
        subtotalCents: Number(session.receipt.subtotalCents),
        taxCents: Number(session.receipt.taxCents),
        tipCents: Number(session.receipt.tipCents),
        totalCents: Number(session.receipt.totalCents),
        items: session.receipt.items.map((item) => ({
          id: item.id,
          name: item.name,
          quantity: item.quantity,
          priceCents: Number(item.priceCents),
          claimantIds: item.claims.map((claim) => claim.participantId),
        })),
        participants: session.receipt.participants.map((p) => ({
          id: p.id,
          name: p.name,
          isHost: hostParticipantIds.has(p.id),
        })),
      },
    };
  }
}
