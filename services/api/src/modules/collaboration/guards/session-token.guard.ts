import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  GoneException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from '../../../prisma/prisma.service';
import {
  isValidShareCode,
  normalizeShareCode,
  sha256Hex,
  timingSafeEqualHex,
} from '../utils/sanitize.util';

export interface CollaborationActor {
  sessionId: string;
  shareCode: string;
  participantId: string;
  sharedParticipantId: string;
  displayName: string;
  isHost: boolean;
  tokenHash: string;
}

@Injectable()
export class SessionTokenGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const rawToken = this.extractSessionToken(request);

    if (!rawToken) {
      throw new UnauthorizedException(
        'Missing collaboration session token (x-session-token or Authorization: Session <token>)',
      );
    }

    const tokenHash = sha256Hex(rawToken);
    const participant = await this.prisma.sharedParticipant.findUnique({
      where: { guestTokenHash: tokenHash },
      include: { session: true },
    });

    if (
      !participant ||
      !timingSafeEqualHex(participant.guestTokenHash, tokenHash)
    ) {
      throw new UnauthorizedException('Invalid collaboration session token');
    }

    if (participant.revokedAt) {
      throw new UnauthorizedException('Session token has been revoked');
    }

    const session = participant.session;
    const paramCode = request.params?.code;
    if (paramCode !== undefined) {
      if (!isValidShareCode(String(paramCode))) {
        throw new ForbiddenException('Invalid share code format');
      }
      if (normalizeShareCode(String(paramCode)) !== session.shareCode) {
        throw new ForbiddenException(
          'Session token does not belong to the requested share code',
        );
      }
    }

    if (session.expiresAt <= new Date()) {
      throw new GoneException('Shared session has expired');
    }

    if (session.status === 'CLOSED') {
      throw new GoneException('Shared session has been closed by host');
    }

    const actor: CollaborationActor = {
      sessionId: session.id,
      shareCode: session.shareCode,
      participantId: participant.participantId,
      sharedParticipantId: participant.id,
      displayName: participant.displayName,
      isHost: participant.isHost,
      tokenHash,
    };

    request.collaborationActor = actor;
    return true;
  }

  private extractSessionToken(request: any): string | null {
    const headerToken = request.headers?.['x-session-token'];
    if (typeof headerToken === 'string' && headerToken.trim().length > 0) {
      return headerToken.trim();
    }

    const authHeader = request.headers?.authorization;
    if (
      typeof authHeader === 'string' &&
      authHeader.startsWith('Session ')
    ) {
      const extracted = authHeader.slice('Session '.length).trim();
      return extracted.length > 0 ? extracted : null;
    }

    return null;
  }
}
