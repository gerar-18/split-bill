import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
  SetMetadata,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';

export const COLLAB_RATE_LIMIT_KEY = 'collab_rate_limit_max';
export const CollabRateLimit = (maxRequestsPerMinute: number) =>
  SetMetadata(COLLAB_RATE_LIMIT_KEY, maxRequestsPerMinute);

interface RateLimitRecord {
  timestamps: number[];
}

@Injectable()
export class CollaborationRateLimitGuard implements CanActivate {
  private readonly records = new Map<string, RateLimitRecord>();
  private readonly windowMs = 60 * 1000;
  private readonly defaultMaxRequests = 30;

  constructor(
    private readonly reflector: Reflector,
    private readonly configService: ConfigService,
  ) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const clientIp =
      request.headers?.['x-forwarded-for'] ||
      request.ip ||
      request.socket?.remoteAddress ||
      'unknown-client';
    const routeKey = request.route?.path || request.url || 'collab';
    const key = `${clientIp}:${routeKey}`;

    const routeMax = this.reflector.getAllAndOverride<number>(
      COLLAB_RATE_LIMIT_KEY,
      [context.getHandler(), context.getClass()],
    );
    const configuredMax = this.configService.get<string | number>(
      'COLLAB_RATE_LIMIT_MAX',
    );
    const maxRequests =
      routeMax ??
      (configuredMax !== undefined
        ? Number(configuredMax)
        : this.defaultMaxRequests);

    const now = Date.now();
    let record = this.records.get(key);
    if (!record) {
      record = { timestamps: [] };
      this.records.set(key, record);
    }

    record.timestamps = record.timestamps.filter(
      (ts) => now - ts < this.windowMs,
    );

    if (record.timestamps.length >= maxRequests) {
      throw new HttpException(
        'Too many collaboration requests. Please wait before retrying.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    record.timestamps.push(now);

    if (this.records.size > 1000) {
      for (const [k, v] of this.records.entries()) {
        v.timestamps = v.timestamps.filter((ts) => now - ts < this.windowMs);
        if (v.timestamps.length === 0) {
          this.records.delete(k);
        }
      }
    }

    return true;
  }

  reset(): void {
    this.records.clear();
  }
}
