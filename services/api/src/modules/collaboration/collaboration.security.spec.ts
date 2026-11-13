import {
  ExecutionContext,
  ForbiddenException,
  GoneException,
  HttpException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import {
  generateCapabilityToken,
  generateShareCode,
  isValidShareCode,
  sanitizeUserText,
  sha256Hex,
  timingSafeEqualHex,
} from './utils/sanitize.util';
import { SessionTokenGuard } from './guards/session-token.guard';
import { CollaborationRateLimitGuard } from './guards/collaboration-rate-limit.guard';

describe('Collaboration Security Utilities & Guards', () => {
  describe('sanitizeUserText & ShareCode utilities', () => {
    it('strips HTML tags, control characters, and bounds length', () => {
      const dirty = '  <b>Hola\u0000\u0007</b> <script>alert(1)</script>   Mesa 4  ';
      expect(sanitizeUserText(dirty, 30)).toBe('Hola alert(1) Mesa 4');
      expect(sanitizeUserText('A'.repeat(100), 60)).toHaveLength(60);
    });

    it('generates valid 8-character Crockford Base32 share codes', () => {
      for (let i = 0; i < 50; i++) {
        const code = generateShareCode();
        expect(code).toHaveLength(8);
        expect(isValidShareCode(code)).toBe(true);
        expect(code).not.toMatch(/[ILOU]/);
      }
      expect(isValidShareCode('ABCD123O')).toBe(false);
      expect(isValidShareCode('SHORT')).toBe(false);
    });

    it('hashes capability tokens and compares digests in constant time', () => {
      const token = generateCapabilityToken();
      const digest = sha256Hex(token);
      expect(digest).toHaveLength(64);
      expect(timingSafeEqualHex(digest, sha256Hex(token))).toBe(true);
      expect(timingSafeEqualHex(digest, sha256Hex(token + 'x'))).toBe(false);
    });
  });

  describe('SessionTokenGuard', () => {
    const mockContext = (headers: Record<string, string>, params: Record<string, string>) => {
      const req: any = { headers, params };
      return {
        req,
        ctx: {
          switchToHttp: () => ({ getRequest: () => req }),
        } as unknown as ExecutionContext,
      };
    };

    const validToken = 'raw-secret-token';
    const validHash = sha256Hex(validToken);

    const makePrisma = (override: Record<string, unknown> | null) =>
      ({
        sharedParticipant: {
          findUnique: jest.fn().mockResolvedValue(override),
        },
      }) as any;

    it('authorizes valid guest token matching session shareCode', async () => {
      const guard = new SessionTokenGuard(
        makePrisma({
          id: 'sp-1',
          participantId: 'p-1',
          displayName: 'Ana',
          guestTokenHash: validHash,
          isHost: false,
          revokedAt: null,
          session: {
            id: 'sess-1',
            shareCode: 'ABCD2345',
            status: 'ACTIVE',
            expiresAt: new Date(Date.now() + 60_000),
          },
        }),
      );

      const { ctx, req } = mockContext(
        { 'x-session-token': validToken },
        { code: 'abcd2345' },
      );

      await expect(guard.canActivate(ctx)).resolves.toBe(true);
      expect(req.collaborationActor).toMatchObject({
        sessionId: 'sess-1',
        participantId: 'p-1',
        isHost: false,
      });
    });

    it('rejects missing or revoked tokens with UnauthorizedException', async () => {
      const guard = new SessionTokenGuard(makePrisma(null));
      const { ctx: noHeaderCtx } = mockContext({}, { code: 'ABCD2345' });
      await expect(guard.canActivate(noHeaderCtx)).rejects.toThrow(
        UnauthorizedException,
      );

      const revokedGuard = new SessionTokenGuard(
        makePrisma({
          id: 'sp-1',
          participantId: 'p-1',
          displayName: 'Ana',
          guestTokenHash: validHash,
          isHost: false,
          revokedAt: new Date(),
          session: {
            id: 'sess-1',
            shareCode: 'ABCD2345',
            status: 'ACTIVE',
            expiresAt: new Date(Date.now() + 60_000),
          },
        }),
      );
      const { ctx: revokedCtx } = mockContext(
        { authorization: `Session ${validToken}` },
        { code: 'ABCD2345' },
      );
      await expect(revokedGuard.canActivate(revokedCtx)).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('rejects cross-session token replay with ForbiddenException', async () => {
      const guard = new SessionTokenGuard(
        makePrisma({
          id: 'sp-1',
          participantId: 'p-1',
          displayName: 'Ana',
          guestTokenHash: validHash,
          isHost: false,
          revokedAt: null,
          session: {
            id: 'sess-1',
            shareCode: 'ABCD2345',
            status: 'ACTIVE',
            expiresAt: new Date(Date.now() + 60_000),
          },
        }),
      );
      const { ctx } = mockContext(
        { 'x-session-token': validToken },
        { code: 'ZZZZ9999' },
      );
      await expect(guard.canActivate(ctx)).rejects.toThrow(ForbiddenException);
    });

    it('rejects expired or closed sessions with GoneException', async () => {
      const expiredGuard = new SessionTokenGuard(
        makePrisma({
          id: 'sp-1',
          participantId: 'p-1',
          displayName: 'Ana',
          guestTokenHash: validHash,
          isHost: false,
          revokedAt: null,
          session: {
            id: 'sess-1',
            shareCode: 'ABCD2345',
            status: 'ACTIVE',
            expiresAt: new Date(Date.now() - 1000),
          },
        }),
      );
      const { ctx } = mockContext(
        { 'x-session-token': validToken },
        { code: 'ABCD2345' },
      );
      await expect(expiredGuard.canActivate(ctx)).rejects.toThrow(GoneException);
    });
  });

  describe('CollaborationRateLimitGuard', () => {
    it('blocks requests exceeding sliding window limit with 429', () => {
      const reflector = {
        getAllAndOverride: jest.fn().mockReturnValue(3),
      } as unknown as Reflector;
      const config = {
        get: jest.fn().mockReturnValue(undefined),
      } as unknown as ConfigService;

      const guard = new CollaborationRateLimitGuard(reflector, config);
      const ctx = {
        switchToHttp: () => ({
          getRequest: () => ({ ip: '10.0.0.1', route: { path: '/join' } }),
        }),
        getHandler: () => ({}),
        getClass: () => ({}),
      } as unknown as ExecutionContext;

      expect(guard.canActivate(ctx)).toBe(true);
      expect(guard.canActivate(ctx)).toBe(true);
      expect(guard.canActivate(ctx)).toBe(true);
      expect(() => guard.canActivate(ctx)).toThrow(HttpException);
    });
  });
});
