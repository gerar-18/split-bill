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
  private readonly maxTrackedKeys = 2000;

  constructor(
    private readonly reflector: Reflector,
    private readonly configService: ConfigService,
  ) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    // Never trust raw X-Forwarded-For header on unauthenticated public routes;
    // rely on Express `request.ip` (which respects configured `trust proxy`) or socket remoteAddress.
    const clientIp =
      request.ip || request.socket?.remoteAddress || 'unknown-client';
    const routeKey = request.route?.path || request.url || 'collab';
    const key = `${clientIp}:${routeKey}`;

    const routeMax = this.reflector.getAllAndOverride<number>(
      COLLAB_RATE_LIMIT_KEY,
      [context.getHandler(), context.getClass()],
    );
    const configuredRaw = this.configService.get<string | number>(
      'COLLAB_RATE_LIMIT_MAX',
    );
    const parsedConfigured =
      configuredRaw !== undefined && String(configuredRaw).trim() !== ''
        ? Number(configuredRaw)
        : NaN;
    const maxRequests =
      routeMax ??
      (Number.isFinite(parsedConfigured) && parsedConfigured > 0
        ? parsedConfigured
        : this.defaultMaxRequests);

    const now = Date.now();
    let record = this.records.get(key);
    if (!record) {
      if (this.records.size >= this.maxTrackedKeys) {
        this.evictStaleOrOldest(now);
      }
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
    return true;
  }

  private evictStaleOrOldest(now: number): void {
    for (const [k, v] of this.records.entries()) {
      v.timestamps = v.timestamps.filter((ts) => now - ts < this.windowMs);
      if (v.timestamps.length === 0) {
        this.records.delete(k);
      }
    }
    if (this.records.size >= this.maxTrackedKeys) {
      const oldestKey = this.records.keys().next().value;
      if (oldestKey !== undefined) {
        this.records.delete(oldestKey);
      }
    }
  }

  reset(): void {
    this.records.clear();
  }
}
