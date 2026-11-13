import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { firstValueFrom, take, toArray } from 'rxjs';
import { ReceiptsService } from '../receipts/receipts.service';
import { CollaborationEventsService } from './collaboration.events';
import {
  AUTO_QUARANTINE_THRESHOLD,
  CollaborationService,
} from './collaboration.service';

describe('CollaborationService & CollaborationEventsService', () => {
  const buildReceiptDto = () => ({
    title: '<b>Cena Taqueria</b>',
    date: '2026-11-12T20:00:00.000Z',
    currency: 'MXN',
    subtotalCents: 2000,
    taxCents: 320,
    tipCents: 200,
    totalCents: 2520,
    clientCreatedAt: '2026-11-12T20:00:00.000Z',
    clientUpdatedAt: '2026-11-12T20:00:00.000Z',
    items: [
      {
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Tacos al Pastor',
        quantity: 2,
        priceCents: 1000,
      },
    ],
    participants: [
      {
        id: '22222222-2222-4222-8222-222222222222',
        name: 'Gera',
      },
    ],
  });

  const makeMockPrisma = (initialState?: {
    version?: number;
    reportCount?: number;
    status?: 'ACTIVE' | 'CLOSED' | 'QUARANTINED';
    existingReport?: boolean;
  }) => {
    let sessionState = {
      id: 'sess-1',
      shareCode: 'ABCD2345',
      receiptId: 'rec-1',
      hostTokenHash: 'host-hash',
      status: initialState?.status ?? 'ACTIVE',
      version: initialState?.version ?? 1,
      includeImage: false,
      imageHiddenByModeration: false,
      imageBase64OptIn: null as string | null,
      reportCount: initialState?.reportCount ?? 0,
      expiresAt: new Date(Date.now() + 86_400_000),
    };

    const items = [
      {
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Tacos al Pastor',
        quantity: 2,
        priceCents: BigInt(1000),
        claims: [] as Array<{ itemId: string; participantId: string }>,
      },
    ];
    const participants = [
      {
        id: '22222222-2222-4222-8222-222222222222',
        name: 'Gera',
      },
    ];
    const sharedParticipants = [
      {
        id: 'sp-host',
        participantId: '22222222-2222-4222-8222-222222222222',
        displayName: 'Gera',
        isHost: true,
        revokedAt: null,
      },
    ];

    const tx = {
      receipt: { create: jest.fn().mockResolvedValue({}) },
      sharedSession: {
        create: jest.fn().mockImplementation(({ data }) => {
          sessionState = { ...sessionState, ...data };
          return Promise.resolve(sessionState);
        }),
        findUnique: jest.fn().mockImplementation(() => Promise.resolve(sessionState)),
        updateMany: jest.fn().mockImplementation(({ where }) => {
          if (
            where.version !== undefined &&
            where.version !== sessionState.version
          ) {
            return Promise.resolve({ count: 0 });
          }
          if (where.status && where.status !== sessionState.status) {
            return Promise.resolve({ count: 0 });
          }
          sessionState.version += 1;
          return Promise.resolve({ count: 1 });
        }),
        update: jest.fn().mockImplementation(({ data }) => {
          sessionState = {
            ...sessionState,
            ...data,
            reportCount:
              typeof data.reportCount === 'object' && data.reportCount?.increment
                ? sessionState.reportCount + data.reportCount.increment
                : (data.reportCount ?? sessionState.reportCount),
            version:
              typeof data.version === 'object' && data.version?.increment
                ? sessionState.version + data.version.increment
                : (data.version ?? sessionState.version),
          };
          return Promise.resolve(sessionState);
        }),
      },
      receiptItem: {
        findFirst: jest.fn().mockResolvedValue(items[0]),
      },
      receiptParticipant: {
        create: jest.fn().mockImplementation(({ data }) => {
          participants.push({ id: data.id, name: data.name });
          return Promise.resolve(data);
        }),
      },
      sharedParticipant: {
        create: jest.fn().mockImplementation(({ data }) => {
          sharedParticipants.push({ ...data, id: 'sp-new', revokedAt: null });
          return Promise.resolve(data);
        }),
        update: jest.fn().mockResolvedValue({}),
      },
      itemClaim: {
        upsert: jest.fn().mockImplementation(({ create }) => {
          if (
            !items[0].claims.some(
              (c) =>
                c.itemId === create.itemId &&
                c.participantId === create.participantId,
            )
          ) {
            items[0].claims.push(create);
          }
          return Promise.resolve(create);
        }),
        deleteMany: jest.fn().mockImplementation(({ where }) => {
          items[0].claims = items[0].claims.filter(
            (c) =>
              !(
                c.itemId === where.itemId &&
                c.participantId === where.participantId
              ),
          );
          return Promise.resolve({ count: 1 });
        }),
      },
      sessionReport: {
        findUnique: jest
          .fn()
          .mockResolvedValue(
            initialState?.existingReport ? { id: 'rep-1' } : null,
          ),
        create: jest.fn().mockResolvedValue({}),
      },
    };

    const prisma: any = {
      $transaction: jest.fn((cb: (t: typeof tx) => unknown) => cb(tx)),
      sharedSession: {
        findUnique: jest.fn().mockImplementation(() =>
          Promise.resolve({
            ...sessionState,
            sharedParticipants,
            receipt: {
              id: 'rec-1',
              title: 'Cena Taqueria',
              date: new Date('2026-11-12T20:00:00.000Z'),
              currency: 'MXN',
              subtotalCents: BigInt(2000),
              taxCents: BigInt(320),
              tipCents: BigInt(200),
              totalCents: BigInt(2520),
              items,
              participants,
            },
          }),
        ),
        update: tx.sharedSession.update,
      },
      sharedParticipant: tx.sharedParticipant,
    };

    return { prisma, tx, getSessionState: () => sessionState };
  };

  it('creates a session without storing photo unless includeImage opt-in is true', async () => {
    const { prisma, tx } = makeMockPrisma();
    const events = new CollaborationEventsService();
    const service = new CollaborationService(
      prisma,
      new ReceiptsService(prisma),
      events,
    );

    const result = await service.createSession({
      receipt: buildReceiptDto(),
      hostDisplayName: 'Gera',
      includeImage: false,
      imageBase64OptIn: 'SHOULD_NOT_BE_SAVED',
    });

    expect(result.shareCode).toHaveLength(8);
    expect(result.sessionToken.length).toBeGreaterThan(20);
    const createdArgs = tx.sharedSession.create.mock.calls[0][0].data;
    expect(createdArgs.includeImage).toBe(false);
    expect(createdArgs.imageBase64OptIn).toBeNull();
    expect(createdArgs.hostTokenHash).not.toBe(result.sessionToken);
  });

  it('rejects guest claim with 409 Conflict when expectedVersion is stale', async () => {
    const { prisma } = makeMockPrisma({ version: 5 });
    const events = new CollaborationEventsService();
    const service = new CollaborationService(
      prisma,
      new ReceiptsService(prisma),
      events,
    );

    await expect(
      service.toggleClaim(
        'ABCD2345',
        {
          sessionId: 'sess-1',
          shareCode: 'ABCD2345',
          participantId: '22222222-2222-4222-8222-222222222222',
          sharedParticipantId: 'sp-host',
          displayName: 'Gera',
          isHost: true,
          tokenHash: 'hash',
        },
        {
          itemId: '11111111-1111-4111-8111-111111111111',
          action: 'claim',
          expectedVersion: 2,
        },
      ),
    ).rejects.toThrow(ConflictException);
  });

  it('auto-quarantines session and clears image when reportCount reaches threshold', async () => {
    const { prisma, getSessionState } = makeMockPrisma({
      reportCount: AUTO_QUARANTINE_THRESHOLD - 1,
    });
    const events = new CollaborationEventsService();
    const service = new CollaborationService(
      prisma,
      new ReceiptsService(prisma),
      events,
    );

    const response = await service.reportSession(
      'ABCD2345',
      {
        sessionId: 'sess-1',
        shareCode: 'ABCD2345',
        participantId: 'p-guest',
        sharedParticipantId: 'sp-guest',
        displayName: 'Invitado',
        isHost: false,
        tokenHash: 'guest-hash',
      },
      { reason: 'INAPPROPRIATE_IMAGE', note: '<script>x</script>Ofensivo' },
    );

    expect(response.quarantined).toBe(true);
    expect(response.reportCount).toBe(AUTO_QUARANTINE_THRESHOLD);
    expect(getSessionState().status).toBe('QUARANTINED');
    expect(getSessionState().imageBase64OptIn).toBeNull();
  });

  it('forbids non-host guest from closing session', async () => {
    const { prisma } = makeMockPrisma();
    const events = new CollaborationEventsService();
    const service = new CollaborationService(
      prisma,
      new ReceiptsService(prisma),
      events,
    );

    await expect(
      service.closeSession('ABCD2345', {
        sessionId: 'sess-1',
        shareCode: 'ABCD2345',
        participantId: 'p-guest',
        sharedParticipantId: 'sp-guest',
        displayName: 'Invitado',
        isHost: false,
        tokenHash: 'guest-hash',
      }),
    ).rejects.toThrow(ForbiddenException);
  });

  it('rejects empty sanitized host display name', async () => {
    const { prisma } = makeMockPrisma();
    const events = new CollaborationEventsService();
    const service = new CollaborationService(
      prisma,
      new ReceiptsService(prisma),
      events,
    );

    await expect(
      service.createSession({
        receipt: buildReceiptDto(),
        hostDisplayName: '<b></b>   ',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('emits SSE MessageEvents to subscribers and closes on session_closed', async () => {
    const events = new CollaborationEventsService();
    const collectedPromise = firstValueFrom(
      events.subscribe('ABCD2345').pipe(take(2), toArray()),
    );

    events.emit('ABCD2345', {
      shareCode: 'ABCD2345',
      version: 2,
      status: 'ACTIVE',
      eventType: 'snapshot_updated',
    });
    events.emit('ABCD2345', {
      shareCode: 'ABCD2345',
      version: 3,
      status: 'CLOSED',
      eventType: 'session_closed',
    });

    const collected = await collectedPromise;
    expect(collected).toHaveLength(2);
    expect(collected[0].type).toBe('snapshot_updated');
    expect(collected[1].type).toBe('session_closed');
  });
});
