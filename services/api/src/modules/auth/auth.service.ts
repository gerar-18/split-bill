import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { AppleAuthDto, DevAuthDto } from './dto/auth.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
  ) {}

  async authenticateApple(dto: AppleAuthDto) {
    // In production, verify Apple JWT using apple-signin-auth or jsonwebtoken against Apple public keys.
    // For local cloud backend & development, we accept subject parsing or mock token.
    const isProd = this.configService.get<string>('NODE_ENV') === 'production';

    let appleSubject = 'apple-sub-test';
    if (dto.identityToken.includes('.')) {
      try {
        const parts = dto.identityToken.split('.');
        const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString());
        appleSubject = payload.sub || appleSubject;
      } catch {
        if (isProd) {
          throw new UnauthorizedException('Invalid Apple identity token');
        }
      }
    } else {
      appleSubject = dto.identityToken;
    }

    const user = await this.prisma.user.upsert({
      where: { appleSubject },
      update: {
        email: dto.email,
      },
      create: {
        appleSubject,
        email: dto.email,
      },
    });

    return {
      accessToken: `dev-token:${user.id}`,
      user: {
        id: user.id,
        email: user.email,
        appleSubject: user.appleSubject,
      },
    };
  }

  async authenticateDev(dto: DevAuthDto) {
    const isProd = this.configService.get<string>('NODE_ENV') === 'production';
    if (isProd) {
      throw new UnauthorizedException('Dev auth is not allowed in production');
    }

    const user = await this.prisma.user.upsert({
      where: { id: dto.userId },
      update: {
        email: dto.email,
      },
      create: {
        id: dto.userId,
        email: dto.email || `${dto.userId}@dev.splitbill.local`,
      },
    });

    return {
      accessToken: `dev-token:${user.id}`,
      user: {
        id: user.id,
        email: user.email,
        appleSubject: user.appleSubject,
      },
    };
  }
}
