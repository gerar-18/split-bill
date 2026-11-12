import { Module } from '@nestjs/common';
import { AiDomainValidator } from './ai-domain-validator';
import { AiProxyController } from './ai-proxy.controller';
import { AiProxyService } from './ai-proxy.service';
import { AiRateLimitGuard } from './guards/ai-rate-limit.guard';
import { HeuristicFallbackProvider } from './providers/heuristic-fallback.provider';
import { OllamaProvider } from './providers/ollama.provider';
import { OpenAiCompatibleProvider } from './providers/openai-compatible.provider';

@Module({
  controllers: [AiProxyController],
  providers: [
    AiProxyService,
    AiRateLimitGuard,
    HeuristicFallbackProvider,
    OpenAiCompatibleProvider,
    OllamaProvider,
    AiDomainValidator,
  ],
  exports: [AiProxyService, AiRateLimitGuard, AiDomainValidator],
})
export class AiProxyModule {}
