import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';

export interface AuthenticatedUser {
  id: string;
  email?: string | null;
  appleSubject?: string | null;
}

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const isProd =
      this.configService.get<string>('NODE_ENV')?.toLowerCase().trim() ===
      'production';

    // 1. Dev Auth Support via x-dev-user-id header in non-production
    const devUserId = request.headers['x-dev-user-id'];
    if (!isProd && devUserId) {
      const userId = String(devUserId);
      // Upsert dev user to ensure foreign keys work cleanly
      const user = await this.prisma.user.upsert({
        where: { id: userId },
        update: {},
        create: {
          id: userId,
          email: `${userId}@dev.splitbill.local`,
        },
      });
      request.user = user;
      return true;
    }

    // 2. Bearer Token Auth (Apple JWT or dev session token)
    const authHeader = request.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException(
        'Missing or invalid authorization header (Bearer token or x-dev-user-id required)',
      );
    }

    const token = authHeader.split(' ')[1];

    // For non-production or test environments, allow format "dev-token:<userId>"
    if (!isProd && token.startsWith('dev-token:')) {
      const userId = token.replace('dev-token:', '');
      const user = await this.prisma.user.upsert({
        where: { id: userId },
        update: {},
        create: {
          id: userId,
          email: `${userId}@dev.splitbill.local`,
        },
      });
      request.user = user;
      return true;
    }

    // In production, token should be verified against Apple public keys / session store
    const user = await this.prisma.user.findFirst({
      where: { id: token },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid authentication credentials');
    }

    request.user = user;
    return true;
  }
}
