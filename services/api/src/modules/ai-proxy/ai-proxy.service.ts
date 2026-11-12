import {
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AiDomainValidator } from './ai-domain-validator';
import {
  ParseAiReceiptRequestDto,
  ParseAiReceiptResponseDto,
} from './dto/parse-ai-receipt.dto';
import { RawExtractedReceipt } from './providers/ai-extraction-provider.interface';
import { HeuristicFallbackProvider } from './providers/heuristic-fallback.provider';
import { OllamaProvider } from './providers/ollama.provider';
import { OpenAiCompatibleProvider } from './providers/openai-compatible.provider';

@Injectable()
export class AiProxyService {
  private readonly logger = new Logger(AiProxyService.name);

  constructor(
    private readonly configService: ConfigService,
    private readonly heuristicProvider: HeuristicFallbackProvider,
    private readonly openAiProvider: OpenAiCompatibleProvider,
    private readonly ollamaProvider: OllamaProvider,
    private readonly domainValidator: AiDomainValidator,
  ) {}

  async parseReceipt(
    dto: ParseAiReceiptRequestDto,
    userId?: string,
  ): Promise<ParseAiReceiptResponseDto> {
    const configuredProvider =
      dto.providerOverride ||
      this.configService.get<string>('AI_PROVIDER') ||
      'heuristic-fallback';

    let rawResult: RawExtractedReceipt | null = null;
    let providerUsed = configuredProvider;
    let fallbackUsed = false;

    try {
      if (configuredProvider === 'deepseek') {
        rawResult = await this.openAiProvider.extractReceipt(
          dto.rawText,
          dto.currency,
          { isDeepSeek: true },
        );
      } else if (configuredProvider === 'openai') {
        rawResult = await this.openAiProvider.extractReceipt(
          dto.rawText,
          dto.currency,
          { isDeepSeek: false },
        );
      } else if (configuredProvider === 'ollama') {
        rawResult = await this.ollamaProvider.extractReceipt(
          dto.rawText,
          dto.currency,
        );
      } else if (configuredProvider === 'heuristic-fallback') {
        rawResult = await this.heuristicProvider.extractReceipt(
          dto.rawText,
          dto.currency,
        );
      } else {
        throw new Error(`Unsupported AI provider: ${configuredProvider}`);
      }
    } catch (error) {
      const fallbackOnError =
        this.configService.get<string>('AI_FALLBACK_ON_ERROR') !== 'false';

      if (fallbackOnError && configuredProvider !== 'heuristic-fallback') {
        this.logger.warn(
          `AI provider '${configuredProvider}' failed for user '${userId}': ${
            error instanceof Error ? error.message : error
          }. Falling back to HeuristicFallbackProvider.`,
        );
        rawResult = await this.heuristicProvider.extractReceipt(
          dto.rawText,
          dto.currency,
        );
        providerUsed = 'heuristic-fallback';
        fallbackUsed = true;
      } else {
        this.logger.error(
          `AI provider '${configuredProvider}' failed and fallback is disabled: ${
            error instanceof Error ? error.message : error
          }`,
        );
        throw new HttpException(
          `AI extraction service error: ${
            error instanceof Error ? error.message : 'Unknown error'
          }`,
          HttpStatus.BAD_GATEWAY,
        );
      }
    }

    return this.domainValidator.validateAndReconcile(
      rawResult!,
      dto.currency,
      providerUsed,
      fallbackUsed,
    );
  }
}
