import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

interface RateLimitRecord {
  timestamps: number[];
}

@Injectable()
export class AiRateLimitGuard implements CanActivate {
  private readonly records = new Map<string, RateLimitRecord>();
  private readonly windowMs = 60 * 1000; // 1 minuto
  private readonly defaultMaxRequests = 20;

  constructor(private readonly configService: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const key =
      request.user?.id ||
      request.headers['x-forwarded-for'] ||
      request.ip ||
      request.socket?.remoteAddress ||
      'unknown-client';

    const configuredMax = this.configService.get<string | number>(
      'AI_RATE_LIMIT_MAX',
    );
    const maxRequests =
      configuredMax !== undefined ? Number(configuredMax) : this.defaultMaxRequests;

    const now = Date.now();
    let record = this.records.get(key);

    if (!record) {
      record = { timestamps: [] };
      this.records.set(key, record);
    }

    // Filtrar solicitudes fuera de la ventana de 60s
    record.timestamps = record.timestamps.filter(
      (ts) => now - ts < this.windowMs,
    );

    if (record.timestamps.length >= maxRequests) {
      throw new HttpException(
        'Rate limit exceeded: maximum AI requests per minute reached. Please wait before retrying.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    record.timestamps.push(now);

    // Limpieza periódica de registros inactivos para evitar fugas de memoria
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
