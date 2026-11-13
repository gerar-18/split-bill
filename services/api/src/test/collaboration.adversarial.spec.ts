import {
  BadRequestException,
  ConflictException,
  ExecutionContext,
  ForbiddenException,
  GoneException,
  HttpException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ReceiptsService } from '../modules/receipts/receipts.service';
import { CollaborationEventsService } from '../modules/collaboration/collaboration.events';
import {
  AUTO_QUARANTINE_THRESHOLD,
  CollaborationService,
} from '../modules/collaboration/collaboration.service';
import {
  CreateSharedSessionDto,
  JoinSharedSessionDto,
  ReportSessionDto,
  ToggleClaimDto,
} from '../modules/collaboration/dto/collaboration.dto';
import { CollaborationRateLimitGuard } from '../modules/collaboration/guards/collaboration-rate-limit.guard';
import { SessionTokenGuard } from '../modules/collaboration/guards/session-token.guard';
import {
  isValidImageBase64,
  sanitizeUserText,
  sha256Hex,
} from '../modules/collaboration/utils/sanitize.util';

describe('Adversarial Red-Team Suite — M8 Shared Collaboration', () => {
  const buildAtomicConcurrencyPrisma = () => {
    let version = 1;
    let status: 'ACTIVE' | 'CLOSED' | 'QUARANTINED' = 'ACTIVE';
    let reportCount = 0;
    let imageBase64OptIn: string | null = 'BASE64_IMAGE';
    const claims: Array<{ itemId: string; participantId: string }> = [];
    const reports = new Set<string>();
    const revokedParticipants = new Set<string>();

    const items = [
      {
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Nachos',
        quantity: 1,
        priceCents: BigInt(1500),
        claims,
      },
    ];
    const participants = [
      { id: 'p-host', name: 'Host' },
      { id: 'p-guest-a', name: 'GuestA' },
      { id: 'p-guest-b', name: 'GuestB' },
    ];
    const sharedParticipants = [
      {
        id: 'sp-host',
        participantId: 'p-host',
        displayName: 'Host',
        guestTokenHash: sha256Hex('host-token'),
        isHost: true,
        revokedAt: null as Date | null,
      },
      {
        id: 'sp-guest-a',
        participantId: 'p-guest-a',
        displayName: 'GuestA',
        guestTokenHash: sha256Hex('guest-a-token'),
        isHost: false,
        revokedAt: null as Date | null,
      },
      {
        id: 'sp-guest-b',
        participantId: 'p-guest-b',
        displayName: 'GuestB',
        guestTokenHash: sha256Hex('guest-b-token'),
        isHost: false,
        revokedAt: null as Date | null,
      },
    ];

    const tx = {
      sharedSession: {
        findUnique: jest.fn().mockImplementation(() =>
          Promise.resolve({
            id: 'sess-1',
            shareCode: 'ABCD2345',
            receiptId: 'rec-1',
            status,
            version,
            reportCount,
            includeImage: true,
            imageHiddenByModeration: status === 'QUARANTINED',
            imageBase64OptIn,
            expiresAt: new Date(Date.now() + 3_600_000),
          }),
        ),
        updateMany: jest.fn().mockImplementation(({ where }) => {
          if (where.version !== version || where.status !== status) {
            return Promise.resolve({ count: 0 });
          }
          version += 1;
          return Promise.resolve({ count: 1 });
        }),
        update: jest.fn().mockImplementation(({ data }) => {
          if (data.status) status = data.status;
          if (typeof data.reportCount === 'number') {
            reportCount = data.reportCount;
          } else if (typeof data.reportCount === 'object' && data.reportCount?.increment) {
            reportCount += data.reportCount.increment;
          }
          if (data.imageBase64OptIn !== undefined) {
            imageBase64OptIn = data.imageBase64OptIn;
          }
          version += 1;
          return Promise.resolve({
            id: 'sess-1',
            shareCode: 'ABCD2345',
            status,
            version,
            reportCount,
            imageBase64OptIn,
          });
        }),
      },
      receiptItem: {
        findFirst: jest.fn().mockResolvedValue(items[0]),
      },
      itemClaim: {
        upsert: jest.fn().mockImplementation(({ create }) => {
          if (
            !claims.some(
              (c) =>
                c.itemId === create.itemId &&
                c.participantId === create.participantId,
            )
          ) {
            claims.push(create);
          }
          return Promise.resolve(create);
        }),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      sessionReport: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          const key = where.sessionId_reporterHash.reporterHash;
          return Promise.resolve(reports.has(key) ? { id: key } : null);
        }),
        create: jest.fn().mockImplementation(({ data }) => {
          reports.add(data.reporterHash);
          return Promise.resolve(data);
        }),
      },
    };

    const prisma: any = {
      $transaction: jest.fn((cb: (t: typeof tx) => unknown) => cb(tx)),
      sharedSession: {
        findUnique: jest.fn().mockImplementation(() =>
          Promise.resolve({
            id: 'sess-1',
            shareCode: 'ABCD2345',
            receiptId: 'rec-1',
            status,
            version,
            reportCount,
            includeImage: true,
            imageHiddenByModeration: status === 'QUARANTINED',
            imageBase64OptIn,
            expiresAt: new Date(Date.now() + 3_600_000),
            sharedParticipants,
            receipt: {
              id: 'rec-1',
              title: 'Cena',
              date: new Date(),
              currency: 'MXN',
              subtotalCents: BigInt(1500),
              taxCents: BigInt(0),
              tipCents: BigInt(0),
              totalCents: BigInt(1500),
              items,
              participants,
            },
          }),
        ),
        update: tx.sharedSession.update,
      },
      sharedParticipant: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          const found = sharedParticipants.find(
            (sp) => sp.guestTokenHash === where.guestTokenHash,
          );
          if (!found) return Promise.resolve(null);
          return Promise.resolve({
            ...found,
            revokedAt: revokedParticipants.has(found.id) ? new Date() : null,
            session: {
              id: 'sess-1',
              shareCode: 'ABCD2345',
              status,
              expiresAt: new Date(Date.now() + 3_600_000),
            },
          });
        }),
        update: jest.fn().mockImplementation(({ where }) => {
          revokedParticipants.add(where.id);
          return Promise.resolve({});
        }),
      },
    };

    return { prisma, claims, getVersion: () => version, getStatus: () => status };
  };

  it('prevents lost updates during simultaneous claim race via deterministic 409 Conflict', async () => {
    const { prisma, claims, getVersion } = buildAtomicConcurrencyPrisma();
    const service = new CollaborationService(
      prisma,
      new ReceiptsService(prisma),
      new CollaborationEventsService(),
    );

    const guestA = {
      sessionId: 'sess-1',
      shareCode: 'ABCD2345',
      participantId: 'p-guest-a',
      sharedParticipantId: 'sp-guest-a',
      displayName: 'GuestA',
      isHost: false,
      tokenHash: sha256Hex('guest-a-token'),
    };
    const guestB = {
      sessionId: 'sess-1',
      shareCode: 'ABCD2345',
      participantId: 'p-guest-b',
      sharedParticipantId: 'sp-guest-b',
      displayName: 'GuestB',
      isHost: false,
      tokenHash: sha256Hex('guest-b-token'),
    };

    const [resA, resB] = await Promise.allSettled([
      service.toggleClaim('ABCD2345', guestA, {
        itemId: '11111111-1111-4111-8111-111111111111',
        action: 'claim',
        expectedVersion: 1,
      }),
      service.toggleClaim('ABCD2345', guestB, {
        itemId: '11111111-1111-4111-8111-111111111111',
        action: 'claim',
        expectedVersion: 1,
      }),
    ]);

    const fulfilled = [resA, resB].filter((r) => r.status === 'fulfilled');
    const rejected = [resA, resB].filter((r) => r.status === 'rejected');

    expect(fulfilled).toHaveLength(1);
    expect(rejected).toHaveLength(1);
    expect((rejected[0] as PromiseRejectedResult).reason).toBeInstanceOf(
      ConflictException,
    );
    expect(getVersion()).toBe(2);
    expect(claims).toHaveLength(1);

    // Retry Guest B using fresh version=2 -> additive sharing preserves BOTH claims!
    await service.toggleClaim('ABCD2345', guestB, {
      itemId: '11111111-1111-4111-8111-111111111111',
      action: 'claim',
      expectedVersion: 2,
    });
    expect(getVersion()).toBe(3);
    expect(claims.map((c) => c.participantId)).toEqual([
      'p-guest-a',
      'p-guest-b',
    ]);
  });

  it('rejects malformed floats, negative cents, XSS payloads, and oversized inputs at DTO & sanitizer boundary', async () => {
    const invalidClaim = plainToInstance(ToggleClaimDto, {
      itemId: 'not-a-uuid',
      action: 'steal',
      expectedVersion: 0,
    });
    expect(await validate(invalidClaim)).not.toHaveLength(0);

    const invalidJoin = plainToInstance(JoinSharedSessionDto, {
      displayName: 'X'.repeat(61),
    });
    expect(await validate(invalidJoin)).not.toHaveLength(0);

    const invalidReport = plainToInstance(ReportSessionDto, {
      reason: 'INVALID_REASON',
      note: 'A'.repeat(301),
    });
    expect(await validate(invalidReport)).not.toHaveLength(0);

    const floatSession = plainToInstance(CreateSharedSessionDto, {
      hostDisplayName: 'Gera',
      receipt: {
        title: 'Dinner',
        date: '2026-11-12T20:00:00.000Z',
        currency: 'USD',
        subtotalCents: 10.5, // float must fail @IsInt()
        taxCents: -1, // negative must fail @Min(0)
        tipCents: 0,
        totalCents: 10,
        clientCreatedAt: '2026-11-12T20:00:00.000Z',
        clientUpdatedAt: '2026-11-12T20:00:00.000Z',
        items: [],
        participants: [],
      },
    });
    expect(await validate(floatSession)).not.toHaveLength(0);

    // Fuzz injection & control-char vectors
    const vectors = [
      '<img src=x onerror=alert(1)>',
      '\u0000\u001B[31mEvil\u007F',
      '<script>fetch("http://evil.tld")</script>Pedro',
    ];
    for (const v of vectors) {
      const cleaned = sanitizeUserText(v, 60);
      expect(cleaned).not.toMatch(/[<>]/);
      expect(cleaned).not.toMatch(/[\u0000-\u001F\u007F]/);
    }
  });

  it('enforces deduplicated moderation reports and locks quarantined sessions', async () => {
    const { prisma, getStatus } = buildAtomicConcurrencyPrisma();
    const service = new CollaborationService(
      prisma,
      new ReceiptsService(prisma),
      new CollaborationEventsService(),
    );

    const actorA = {
      sessionId: 'sess-1',
      shareCode: 'ABCD2345',
      participantId: 'p-guest-a',
      sharedParticipantId: 'sp-guest-a',
      displayName: 'GuestA',
      isHost: false,
      tokenHash: sha256Hex('guest-a-token'),
    };
    const actorB = { ...actorA, participantId: 'p-guest-b', tokenHash: sha256Hex('guest-b-token') };
    const actorC = { ...actorA, participantId: 'p-host', isHost: true, tokenHash: sha256Hex('host-token') };

    // Spamming 3 identical reports from actorA only counts once!
    await service.reportSession('ABCD2345', actorA, { reason: 'SPAM_OR_SCAM' });
    const dup = await service.reportSession('ABCD2345', actorA, { reason: 'SPAM_OR_SCAM' });
    expect(dup.reportCount).toBe(1);
    expect(dup.quarantined).toBe(false);

    // Second & third distinct reporters trigger auto-quarantine
    await service.reportSession('ABCD2345', actorB, { reason: 'INAPPROPRIATE_IMAGE' });
    const finalReport = await service.reportSession('ABCD2345', actorC, { reason: 'OTHER' });
    expect(finalReport.reportCount).toBe(AUTO_QUARANTINE_THRESHOLD);
    expect(finalReport.quarantined).toBe(true);
    expect(getStatus()).toBe('QUARANTINED');

    // Quarantined session blocks further joins & claims
    await expect(
      service.joinSession('ABCD2345', { displayName: 'LateGuest' }),
    ).rejects.toThrow(ForbiddenException);
    await expect(
      service.toggleClaim('ABCD2345', actorB, {
        itemId: '11111111-1111-4111-8111-111111111111',
        action: 'claim',
        expectedVersion: 5,
      }),
    ).rejects.toThrow(ForbiddenException);
  });

  it('revokes token immediately on leaveSession and blocks replay via SessionTokenGuard', async () => {
    const { prisma } = buildAtomicConcurrencyPrisma();
    const service = new CollaborationService(
      prisma,
      new ReceiptsService(prisma),
      new CollaborationEventsService(),
    );
    const guard = new SessionTokenGuard(prisma);

    const ctx = {
      switchToHttp: () => ({
        getRequest: () => ({
          headers: { 'x-session-token': 'guest-a-token' },
          params: { code: 'ABCD2345' },
        }),
      }),
    } as unknown as ExecutionContext;

    await expect(guard.canActivate(ctx)).resolves.toBe(true);

    await service.leaveSession('ABCD2345', {
      sessionId: 'sess-1',
      shareCode: 'ABCD2345',
      participantId: 'p-guest-a',
      sharedParticipantId: 'sp-guest-a',
      displayName: 'GuestA',
      isHost: false,
      tokenHash: sha256Hex('guest-a-token'),
    });

    await expect(guard.canActivate(ctx)).rejects.toThrow(UnauthorizedException);
  });

  it('enforces BigInt money invariants and sliding-window burst rate limiting', async () => {
    const { prisma } = buildAtomicConcurrencyPrisma();
    const service = new CollaborationService(
      prisma,
      new ReceiptsService(prisma),
      new CollaborationEventsService(),
    );

    await expect(
      service.createSession({
        hostDisplayName: 'Gera',
        receipt: {
          title: 'Bad Math',
          date: '2026-11-12T20:00:00.000Z',
          currency: 'USD',
          subtotalCents: 1000,
          taxCents: 100,
          tipCents: 100,
          totalCents: 1201, // 1 cent mismatch must reject!
          clientCreatedAt: '2026-11-12T20:00:00.000Z',
          clientUpdatedAt: '2026-11-12T20:00:00.000Z',
          items: [
            {
              id: '11111111-1111-4111-8111-111111111111',
              name: 'Salad',
              quantity: 1,
              priceCents: 1000,
            },
          ],
          participants: [],
        },
      }),
    ).rejects.toThrow(BadRequestException);

    const guard = new CollaborationRateLimitGuard(
      { getAllAndOverride: jest.fn().mockReturnValue(10) } as unknown as Reflector,
      { get: jest.fn() } as unknown as ConfigService,
    );
    const reqCtx = {
      switchToHttp: () => ({
        getRequest: () => ({ ip: '203.0.113.5', route: { path: '/v1/shared-sessions/:code/join' } }),
      }),
      getHandler: () => ({}),
      getClass: () => ({}),
    } as unknown as ExecutionContext;

    for (let i = 0; i < 10; i++) {
      expect(guard.canActivate(reqCtx)).toBe(true);
    }
    expect(() => guard.canActivate(reqCtx)).toThrow(HttpException);
  });

  it('ignores spoofed X-Forwarded-For headers and rejects disguised base64 XSS image payloads', async () => {
    const guard = new CollaborationRateLimitGuard(
      { getAllAndOverride: jest.fn().mockReturnValue(2) } as unknown as Reflector,
      { get: jest.fn() } as unknown as ConfigService,
    );
    const makeSpoofedCtx = (spoofedIp: string) =>
      ({
        switchToHttp: () => ({
          getRequest: () => ({
            ip: '198.51.100.10',
            headers: { 'x-forwarded-for': spoofedIp },
            route: { path: '/v1/shared-sessions/:code/join' },
          }),
        }),
        getHandler: () => ({}),
        getClass: () => ({}),
      }) as unknown as ExecutionContext;

    expect(guard.canActivate(makeSpoofedCtx('1.1.1.1'))).toBe(true);
    expect(guard.canActivate(makeSpoofedCtx('2.2.2.2'))).toBe(true);
    expect(() => guard.canActivate(makeSpoofedCtx('3.3.3.3'))).toThrow(HttpException);

    // Image magic-byte check blocks HTML/SVG disguised as base64 while permitting valid JPEG/PNG
    const fakeSvgBase64 = Buffer.from('<svg onload=alert(1)>').toString('base64');
    const validJpegBase64 = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]).toString('base64');
    expect(isValidImageBase64(fakeSvgBase64)).toBe(false);
    expect(isValidImageBase64(validJpegBase64)).toBe(true);
  });

  it('prevents SSE teardown race from deleting a newly active channel and rejects duplicate item UUIDs', async () => {
    const events = new CollaborationEventsService();
    const received: string[] = [];

    const sub1 = events.subscribe('ABCD2345').subscribe((ev) => {
      received.push(`sub1:${ev.type}`);
    });
    // Closing session tears down channel 1
    events.emit('ABCD2345', {
      shareCode: 'ABCD2345',
      version: 2,
      status: 'CLOSED',
      eventType: 'session_closed',
    });

    // New subscriber creates channel 2 before sub1 unsubscribes explicitly
    const sub2 = events.subscribe('ABCD2345').subscribe((ev) => {
      received.push(`sub2:${ev.type}`);
    });
    sub1.unsubscribe();

    events.emit('ABCD2345', {
      shareCode: 'ABCD2345',
      version: 3,
      status: 'ACTIVE',
      eventType: 'snapshot_updated',
    });
    sub2.unsubscribe();

    expect(received).toContain('sub2:snapshot_updated');

    const { prisma } = buildAtomicConcurrencyPrisma();
    const service = new CollaborationService(
      prisma,
      new ReceiptsService(prisma),
      events,
    );
    const dupId = '11111111-1111-4111-8111-111111111111';
    await expect(
      service.createSession({
        hostDisplayName: 'Gera',
        receipt: {
          title: 'Dup Items',
          date: '2026-11-12T20:00:00.000Z',
          currency: 'USD',
          subtotalCents: 2000,
          taxCents: 0,
          tipCents: 0,
          totalCents: 2000,
          clientCreatedAt: '2026-11-12T20:00:00.000Z',
          clientUpdatedAt: '2026-11-12T20:00:00.000Z',
          items: [
            { id: dupId, name: 'A', quantity: 1, priceCents: 1000 },
            { id: dupId, name: 'B', quantity: 1, priceCents: 1000 },
          ],
          participants: [],
        },
      }),
    ).rejects.toThrow(BadRequestException);
  });
});
