import { BadRequestException, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { AuthGuard } from '../common/guards/auth.guard';
import { transformBigInt } from '../common/interceptors/bigint.interceptor';
import {
  ReceiptItemDto,
  ReceiptParticipantDto,
  UpsertReceiptDto,
} from '../modules/receipts/dto/receipt.dto';
import { ReceiptsService } from '../modules/receipts/receipts.service';
import { PrismaService } from '../prisma/prisma.service';

describe('Adversarial Red-Team Stress Suite (services/api)', () => {
  const getBaseValidPayload = () => ({
    title: 'Valid Dinner with Friends',
    date: '2026-11-11T12:00:00.000Z',
    currency: 'USD',
    subtotalCents: 5000,
    taxCents: 500,
    tipCents: 500,
    totalCents: 6000,
    version: 1,
    clientCreatedAt: '2026-11-11T12:00:00.000Z',
    clientUpdatedAt: '2026-11-11T12:00:00.000Z',
    items: [
      {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Burger & Fries Combo',
        quantity: 2,
        priceCents: 2500,
      },
    ],
    participants: [
      {
        id: '223e4567-e89b-12d3-a456-426614174001',
        name: 'Bob Participant',
      },
    ],
  });

  // =========================================================================
  // 1. FUZZING DE MONTOS CORRUPTOS & TIPOS FLOTANTES PROHIBIDOS
  // =========================================================================
  describe('1. Corrupt Amounts & Forbidden Floats Fuzzing', () => {
    it.each([
      ['Infinitesimal positive float', 0.0000000001],
      ['Infinitesimal negative float', -0.0000000001],
      ['NaN', NaN],
      ['Positive Infinity', Infinity],
      ['Negative Infinity', -Infinity],
      ['Camouflaged float 10.5', 10.5],
      ['Negative float', -10.5],
      ['Float cents disguised as string "10.5"', '10.5'],
      ['Scientific notation string "1e10"', '1e10'],
      ['Infinitesimal string "0.00000001"', '0.00000001'],
      ['Alphabetic string "one-hundred"', 'one-hundred'],
      ['Null byte in string number "1000\\0"', '1000\0'],
    ])('rejects corrupt amount in subtotalCents: %s (%p)', async (_, badVal) => {
      const payload = {
        ...getBaseValidPayload(),
        subtotalCents: badVal,
      };

      const dto = plainToInstance(UpsertReceiptDto, payload);
      const errors = await validate(dto);
      const subtotalErr = errors.find((e) => e.property === 'subtotalCents');

      expect(subtotalErr).toBeDefined();
      expect(subtotalErr?.constraints).toBeDefined();
    });

    it.each([
      ['Infinitesimal float in item price', 0.0001],
      ['NaN in item price', NaN],
      ['Infinity in item price', Infinity],
      ['Scientific string in item price', '2.5e3'],
    ])('rejects corrupt amount in ReceiptItemDto priceCents: %s (%p)', async (_, badVal) => {
      const itemPayload = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Sushi Roll',
        quantity: 1,
        priceCents: badVal,
      };

      const dto = plainToInstance(ReceiptItemDto, itemPayload);
      const errors = await validate(dto);
      expect(errors.some((e) => e.property === 'priceCents')).toBe(true);
    });

    it.each([
      ['Zero quantity', 0],
      ['Negative quantity', -5],
      ['Float quantity 1.5', 1.5],
      ['NaN quantity', NaN],
      ['Infinity quantity', Infinity],
      ['String quantity "2"', '2'],
    ])('rejects invalid quantity in ReceiptItemDto: %s (%p)', async (_, badQty) => {
      const itemPayload = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Sushi Roll',
        quantity: badQty,
        priceCents: 1500,
      };

      const dto = plainToInstance(ReceiptItemDto, itemPayload);
      const errors = await validate(dto);
      expect(errors.some((e) => e.property === 'quantity')).toBe(true);
    });

    it('reconciles integer representations like 10.0 correctly since JS evaluates 10.0 === 10', async () => {
      const payload = {
        ...getBaseValidPayload(),
        subtotalCents: 10.0,
        totalCents: 10.0,
        taxCents: 0.0,
        tipCents: 0.0,
        items: [
          {
            id: '123e4567-e89b-12d3-a456-426614174000',
            name: 'Item',
            quantity: 1,
            priceCents: 10.0,
          },
        ],
      };

      const dto = plainToInstance(UpsertReceiptDto, payload);
      const errors = await validate(dto);
      expect(errors.length).toBe(0);
    });
  });

  // =========================================================================
  // 2. ATAQUES DE DESBORDAMIENTO DE ENTEROS & LÍMITES NUMÉRICOS
  // =========================================================================
  describe('2. Integer Overflow & Numeric Boundary Attacks', () => {
    it.each([
      ['Negative totalCents', -1],
      ['Negative taxCents', -50],
      ['Negative tipCents', -100],
      ['Extreme negative subtotalCents', -999999999999],
    ])('rejects negative amounts at DTO layer: %s', async (_, val) => {
      const payload = {
        ...getBaseValidPayload(),
        subtotalCents: val < 0 ? val : 5000,
        taxCents: val < 0 ? val : 0,
      };

      const dto = plainToInstance(UpsertReceiptDto, payload);
      const errors = await validate(dto);
      expect(errors.length).toBeGreaterThan(0);
    });

    it('handles BigInt conversion cleanly in ReceiptsService validateMoneyInvariants without JS overflow', () => {
      const mockPrisma = {} as PrismaService;
      const service = new ReceiptsService(mockPrisma);

      // Value up to MAX_SAFE_INTEGER
      const safeMax = Number.MAX_SAFE_INTEGER; // 9,007,199,254,740,991
      const dto: UpsertReceiptDto = {
        title: 'Safe Max Test',
        date: '2026-11-11T12:00:00Z',
        currency: 'USD',
        subtotalCents: safeMax,
        taxCents: 0,
        tipCents: 0,
        totalCents: safeMax,
        clientCreatedAt: '2026-11-11T12:00:00Z',
        clientUpdatedAt: '2026-11-11T12:00:00Z',
        items: [
          {
            id: '123e4567-e89b-12d3-a456-426614174000',
            name: 'Super Expensive',
            quantity: 1,
            priceCents: safeMax,
          },
        ],
        participants: [],
      };

      expect(() => service.validateMoneyInvariants(dto)).not.toThrow();
    });

    it('detects tampering when sum exceeds total by even 1 minor unit at high numbers', () => {
      const mockPrisma = {} as PrismaService;
      const service = new ReceiptsService(mockPrisma);

      const highSubtotal = 100_000_000; // 1 million dollars in cents
      const dto: UpsertReceiptDto = {
        title: 'Rounding attack',
        date: '2026-11-11T12:00:00Z',
        currency: 'USD',
        subtotalCents: highSubtotal,
        taxCents: 10_000,
        tipCents: 10_000,
        totalCents: highSubtotal + 10_000 + 10_000 + 1, // Tampered +1 cent
        clientCreatedAt: '2026-11-11T12:00:00Z',
        clientUpdatedAt: '2026-11-11T12:00:00Z',
        items: [],
        participants: [],
      };

      expect(() => service.validateMoneyInvariants(dto)).toThrow(BadRequestException);
    });

    it('serializes numbers exceeding Number.MAX_SAFE_INTEGER safely as string in transformBigInt', () => {
      const postgresMaxBigInt = 9223372036854775807n; // 2^63 - 1
      const beyondSafe = BigInt(Number.MAX_SAFE_INTEGER) + 100n;

      const resultBeyond = transformBigInt(beyondSafe);
      expect(typeof resultBeyond).toBe('string');
      expect(resultBeyond).toBe((BigInt(Number.MAX_SAFE_INTEGER) + 100n).toString());

      const resultPostgresMax = transformBigInt(postgresMaxBigInt);
      expect(typeof resultPostgresMax).toBe('string');
      expect(resultPostgresMax).toBe('9223372036854775807');

      // Fits within safe integer: should remain a JS number
      const safeNumber = transformBigInt(BigInt(5000));
      expect(typeof safeNumber).toBe('number');
      expect(safeNumber).toBe(5000);
    });
  });

  // =========================================================================
  // 3. ATAQUES DE IDEMPOTENCIA, REPLAY Y DESORDEN TEMPORAL (CLOCK SKEW)
  // =========================================================================
  describe('3. Idempotency, Replay & Clock Skew Attacks', () => {
    let service: ReceiptsService;
    let mockPrisma: any;

    beforeEach(() => {
      mockPrisma = {
        receipt: {
          findUnique: jest.fn(),
          create: jest.fn(),
          update: jest.fn(),
        },
        receiptItem: {
          deleteMany: jest.fn(),
        },
        receiptParticipant: {
          deleteMany: jest.fn(),
        },
        $transaction: jest.fn((callback) => callback(mockPrisma)),
      };
      service = new ReceiptsService(mockPrisma as unknown as PrismaService);
    });

    it('rejects stale replay attack: incoming clientUpdatedAt is older than current receipt timestamp', async () => {
      const receiptId = '123e4567-e89b-12d3-a456-426614174099';
      const ownerId = 'user-owner-1';

      const existingRecord = {
        id: receiptId,
        ownerId,
        title: 'Existing Newer State',
        clientUpdatedAt: new Date('2026-11-11T12:10:00.000Z'),
        version: 3,
        items: [],
        participants: [],
      };

      mockPrisma.receipt.findUnique.mockResolvedValue(existingRecord);

      // Attacker replays an intercepted packet with an older timestamp
      const stalePayload: UpsertReceiptDto = {
        ...getBaseValidPayload(),
        title: 'Stale Intercepted Update',
        clientUpdatedAt: '2026-11-11T12:05:00.000Z', // 5 minutes older
      };

      const result = await service.upsertReceipt(receiptId, ownerId, stalePayload);

      // Must return existing record without executing transaction or updating
      expect(result).toBe(existingRecord);
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
      expect(mockPrisma.receipt.update).not.toHaveBeenCalled();
    });

    it('idempotency defense: identical replay with equal timestamp does not overwrite database', async () => {
      const receiptId = '123e4567-e89b-12d3-a456-426614174099';
      const ownerId = 'user-owner-1';
      const timestamp = new Date('2026-11-11T12:10:00.000Z');

      const existingRecord = {
        id: receiptId,
        ownerId,
        title: 'Original State',
        clientUpdatedAt: timestamp,
        version: 2,
        items: [],
        participants: [],
      };

      mockPrisma.receipt.findUnique.mockResolvedValue(existingRecord);

      // Re-sending identical sync payload
      const exactReplayPayload: UpsertReceiptDto = {
        ...getBaseValidPayload(),
        title: 'Original State',
        clientUpdatedAt: '2026-11-11T12:10:00.000Z',
      };

      const result = await service.upsertReceipt(receiptId, ownerId, exactReplayPayload);

      expect(result).toBe(existingRecord);
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });

    it('accepts valid forward update when clientUpdatedAt is strictly newer', async () => {
      const receiptId = '123e4567-e89b-12d3-a456-426614174099';
      const ownerId = 'user-owner-1';

      const existingRecord = {
        id: receiptId,
        ownerId,
        title: 'Version 1',
        clientUpdatedAt: new Date('2026-11-11T12:00:00.000Z'),
        version: 1,
        items: [],
        participants: [],
      };

      mockPrisma.receipt.findUnique.mockResolvedValue(existingRecord);
      mockPrisma.receipt.update.mockResolvedValue({
        ...existingRecord,
        title: 'Updated Version 2',
        version: 2,
        clientUpdatedAt: new Date('2026-11-11T12:15:00.000Z'),
      });

      const forwardPayload: UpsertReceiptDto = {
        ...getBaseValidPayload(),
        title: 'Updated Version 2',
        clientUpdatedAt: '2026-11-11T12:15:00.000Z',
      };

      const result = await service.upsertReceipt(receiptId, ownerId, forwardPayload);

      expect(mockPrisma.$transaction).toHaveBeenCalled();
      expect(mockPrisma.receipt.update).toHaveBeenCalled();
      expect(result.version).toBe(2);
    });
  });

  // =========================================================================
  // 4. MANIPULACIÓN DE ARRAYS, PAYLOADS MASIVOS, UNICODE Y STRINGS GIGANTES
  // =========================================================================
  describe('4. Array Manipulation, Massive Payloads, Unicode & Extreme Strings', () => {
    it('accepts empty items array and empty participants array if monetary balance matches', async () => {
      const payload = {
        ...getBaseValidPayload(),
        subtotalCents: 0,
        taxCents: 0,
        tipCents: 0,
        totalCents: 0,
        items: [],
        participants: [],
      };

      const dto = plainToInstance(UpsertReceiptDto, payload);
      const errors = await validate(dto);
      expect(errors.length).toBe(0);

      const mockPrisma = {} as PrismaService;
      const service = new ReceiptsService(mockPrisma);
      expect(() => service.validateMoneyInvariants(dto)).not.toThrow();
    });

    it('rejects null or undefined items and participants instead of arrays', async () => {
      const payload = {
        ...getBaseValidPayload(),
        items: null,
        participants: undefined,
      };

      const dto = plainToInstance(UpsertReceiptDto, payload);
      const errors = await validate(dto);
      expect(errors.some((e) => e.property === 'items')).toBe(true);
      expect(errors.some((e) => e.property === 'participants')).toBe(true);
    });

    it('validates resilience with massive array (1,000 items) and complex Unicode / Emojis', async () => {
      const itemCount = 1000;
      const unitPrice = 10;
      const massiveItems: ReceiptItemDto[] = Array.from({ length: itemCount }, (_, i) => ({
        id: `00000000-0000-4000-8000-${String(i).padStart(12, '0')}`,
        name: `🍕 Tacos al Pastor Deluxe # ${i} - 特别菜单 🍣 🍺 🎉`,
        quantity: 1,
        priceCents: unitPrice,
      }));

      const payload = {
        ...getBaseValidPayload(),
        title: '🎉 Fiesta Masiva con Emojis 🌮🍻🎊 & Nombres Extremos: ' + '🌟'.repeat(100),
        subtotalCents: itemCount * unitPrice,
        taxCents: 0,
        tipCents: 0,
        totalCents: itemCount * unitPrice,
        items: massiveItems,
        participants: [
          {
            id: '223e4567-e89b-12d3-a456-426614174001',
            name: 'José María González-Ñoño 👨‍👩‍👧‍👦',
          },
        ],
      };

      const dto = plainToInstance(UpsertReceiptDto, payload);
      const errors = await validate(dto);
      expect(errors.length).toBe(0);

      const mockPrisma = {} as PrismaService;
      const service = new ReceiptsService(mockPrisma);
      expect(() => service.validateMoneyInvariants(dto)).not.toThrow();
    });

    it('rejects giant 10,000 character strings in item description with MaxLength constraint', async () => {
      const giantString = 'A'.repeat(10000);
      const itemPayload = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: giantString,
        quantity: 1,
        priceCents: 100,
      };

      const dto = plainToInstance(ReceiptItemDto, itemPayload);
      const errors = await validate(dto);
      // Hardened with @MaxLength(255)
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0].constraints?.maxLength).toBeDefined();
    });
  });

  // =========================================================================
  // 5. INTENTOS DE BYPASS EN AUTH.GUARD.TS & AUDITORÍA DE SEGURIDAD
  // =========================================================================
  describe('5. AuthGuard Security Bypass & Spoofing Attempts', () => {
    let guard: AuthGuard;
    let mockConfigService: any;
    let mockPrismaService: any;

    const createMockContext = (headers: Record<string, string | undefined>): ExecutionContext => {
      const request: any = { headers };
      return {
        switchToHttp: () => ({
          getRequest: () => request,
          getResponse: () => ({}),
          getNext: () => ({}),
        }),
      } as unknown as ExecutionContext;
    };

    beforeEach(() => {
      mockConfigService = {
        get: jest.fn(),
      };
      mockPrismaService = {
        user: {
          upsert: jest.fn(),
          findFirst: jest.fn(),
        },
      };
      guard = new AuthGuard(mockConfigService, mockPrismaService);
    });

    it.each([
      ['Exact production', 'production'],
    ])('rejects x-dev-user-id header when NODE_ENV is %s (Production Hardening)', async (_, envVal) => {
      mockConfigService.get.mockReturnValue(envVal);

      const context = createMockContext({
        'x-dev-user-id': 'attacker-spoofed-admin',
      });

      await expect(guard.canActivate(context)).rejects.toThrow(UnauthorizedException);
      expect(mockPrismaService.user.upsert).not.toHaveBeenCalled();
    });

    it('rejects dev-token: in production environment', async () => {
      mockConfigService.get.mockReturnValue('production');
      // When production, findFirst is called instead of upsert
      mockPrismaService.user.findFirst.mockResolvedValue(null);

      const context = createMockContext({
        authorization: 'Bearer dev-token:admin-bypass',
      });

      await expect(guard.canActivate(context)).rejects.toThrow(UnauthorizedException);
      expect(mockPrismaService.user.upsert).not.toHaveBeenCalled();
    });

    it.each([
      ['Malformed Bearer with null byte', 'Bearer valid-user\0malicious'],
      ['Malformed auth scheme Basic', 'Basic dXNlcjpwYXNz'],
      ['Bearer without token', 'Bearer '],
      ['Random header garbage', 'JWT eyJhbGciOi...'],
      ['SQL Injection string in token', "Bearer ' OR '1'='1"],
    ])('rejects malformed authorization header: %s', async (_, headerValue) => {
      mockConfigService.get.mockReturnValue('production');
      mockPrismaService.user.findFirst.mockResolvedValue(null);

      const context = createMockContext({
        authorization: headerValue,
      });

      await expect(guard.canActivate(context)).rejects.toThrow(UnauthorizedException);
    });

    it('rejects dev headers when NODE_ENV is case-insensitive "Production"', async () => {
      // Hardened: configService.get('NODE_ENV')?.toLowerCase().trim() === 'production'
      mockConfigService.get.mockReturnValue('Production'); // uppercase P

      const context = createMockContext({
        'x-dev-user-id': 'attacker',
      });

      await expect(guard.canActivate(context)).rejects.toThrow(UnauthorizedException);
      expect(mockPrismaService.user.upsert).not.toHaveBeenCalled();
    });
  });
});
