import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AuthGuard } from './auth.guard';
import { PrismaService } from '../../prisma/prisma.service';

describe('AuthGuard', () => {
  let guard: AuthGuard;
  let mockConfigService: Partial<ConfigService>;
  let mockPrismaService: {
    user: {
      upsert: jest.Mock;
      findFirst: jest.Mock;
    };
  };

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
      get: jest.fn().mockImplementation((key: string) => {
        if (key === 'NODE_ENV') return 'development';
        return undefined;
      }),
    };

    mockPrismaService = {
      user: {
        upsert: jest.fn().mockImplementation(({ where, create }) =>
          Promise.resolve({
            id: where.id,
            email: create.email,
            appleSubject: null,
          }),
        ),
        findFirst: jest.fn(),
      },
    };

    guard = new AuthGuard(
      mockConfigService as ConfigService,
      mockPrismaService as unknown as PrismaService,
    );
  });

  describe('Non-production environment (development/test)', () => {
    it('authenticates successfully using x-dev-user-id header and upserts user', async () => {
      const context = createMockContext({
        'x-dev-user-id': 'dev-user-123',
      });

      const canActivate = await guard.canActivate(context);
      expect(canActivate).toBe(true);

      const request = context.switchToHttp().getRequest();
      expect(request.user).toEqual({
        id: 'dev-user-123',
        email: 'dev-user-123@dev.splitbill.local',
        appleSubject: null,
      });
      expect(mockPrismaService.user.upsert).toHaveBeenCalledWith({
        where: { id: 'dev-user-123' },
        update: {},
        create: {
          id: 'dev-user-123',
          email: 'dev-user-123@dev.splitbill.local',
        },
      });
    });

    it('authenticates successfully using Bearer dev-token:<userId>', async () => {
      const context = createMockContext({
        authorization: 'Bearer dev-token:special-user-456',
      });

      const canActivate = await guard.canActivate(context);
      expect(canActivate).toBe(true);

      const request = context.switchToHttp().getRequest();
      expect(request.user.id).toBe('special-user-456');
      expect(mockPrismaService.user.upsert).toHaveBeenCalledWith({
        where: { id: 'special-user-456' },
        update: {},
        create: {
          id: 'special-user-456',
          email: 'special-user-456@dev.splitbill.local',
        },
      });
    });

    it('throws UnauthorizedException if no headers provided', async () => {
      const context = createMockContext({});

      await expect(guard.canActivate(context)).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('throws UnauthorizedException if Authorization header does not start with Bearer', async () => {
      const context = createMockContext({
        authorization: 'Basic dXNlcjpwYXNz',
      });

      await expect(guard.canActivate(context)).rejects.toThrow(
        UnauthorizedException,
      );
    });
  });

  describe('Production environment (NODE_ENV=production)', () => {
    beforeEach(() => {
      (mockConfigService.get as jest.Mock).mockReturnValue('production');
    });

    it('ignores x-dev-user-id header and rejects if no valid bearer token is present', async () => {
      const context = createMockContext({
        'x-dev-user-id': 'attacker-spoofed-id',
      });

      await expect(guard.canActivate(context)).rejects.toThrow(
        UnauthorizedException,
      );
      expect(mockPrismaService.user.upsert).not.toHaveBeenCalled();
    });

    it('does not allow dev-token: in production and looks up user in database', async () => {
      mockPrismaService.user.findFirst.mockResolvedValue(null);

      const context = createMockContext({
        authorization: 'Bearer dev-token:admin',
      });

      await expect(guard.canActivate(context)).rejects.toThrow(
        UnauthorizedException,
      );
      expect(mockPrismaService.user.upsert).not.toHaveBeenCalled();
      expect(mockPrismaService.user.findFirst).toHaveBeenCalledWith({
        where: { id: 'dev-token:admin' },
      });
    });

    it('authenticates valid production bearer token if user exists in database', async () => {
      const existingUser = {
        id: 'real-user-uuid',
        email: 'user@example.com',
        appleSubject: 'apple-sub-123',
      };
      mockPrismaService.user.findFirst.mockResolvedValue(existingUser);

      const context = createMockContext({
        authorization: 'Bearer real-user-uuid',
      });

      const canActivate = await guard.canActivate(context);
      expect(canActivate).toBe(true);

      const request = context.switchToHttp().getRequest();
      expect(request.user).toEqual(existingUser);
    });

    it('throws UnauthorizedException if user not found in database', async () => {
      mockPrismaService.user.findFirst.mockResolvedValue(null);

      const context = createMockContext({
        authorization: 'Bearer non-existent-token',
      });

      await expect(guard.canActivate(context)).rejects.toThrow(
        UnauthorizedException,
      );
    });
  });
});
