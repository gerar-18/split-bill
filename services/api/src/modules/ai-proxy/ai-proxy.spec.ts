import { HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AiDomainValidator } from './ai-domain-validator';
import { AiProxyService } from './ai-proxy.service';
import { ParseAiReceiptRequestDto } from './dto/parse-ai-receipt.dto';
import { AiRateLimitGuard } from './guards/ai-rate-limit.guard';
import { HeuristicFallbackProvider } from './providers/heuristic-fallback.provider';

describe('AI Proxy Module', () => {
  describe('HeuristicFallbackProvider', () => {
    let provider: HeuristicFallbackProvider;

    beforeEach(() => {
      provider = new HeuristicFallbackProvider();
    });

    it('extracts merchant, date, items, subtotal, tax, tip and total cleanly', async () => {
      const ocrText = `
        La Taqueria CDMX
        RFC: TAC123456789
        Fecha: 2026-11-12
        -------------------------
        2 Tacos Pastor @ 25.00 50.00
        1 Refresco Cola 25.00
        -------------------------
        Subtotal: 75.00
        IVA: 12.00
        Propina: 10.00
        Total: 97.00
      `;

      const result = await provider.extractReceipt(ocrText, 'MXN');

      expect(result.merchantName).toBe('La Taqueria CDMX');
      expect(result.date).toBe('2026-11-12');
      expect(result.subtotalCents).toBe(7500);
      expect(result.taxCents).toBe(1200);
      expect(result.tipCents).toBe(1000);
      expect(result.totalCents).toBe(9700);
      expect(result.items?.length).toBe(2);
      expect(result.items?.[0]).toEqual({
        name: 'Tacos Pastor',
        quantity: 2,
        priceCents: 2500,
      });
      expect(result.items?.[1]).toEqual({
        name: 'Refresco Cola',
        quantity: 1,
        priceCents: 2500,
      });
    });

    it('handles euro/latin date formats like 12/11/2026', async () => {
      const ocrText = `
        Café París
        Fecha: 15/08/2026
        1 Croissant 45.00
        Total: 45.00
      `;

      const result = await provider.extractReceipt(ocrText, 'EUR');
      expect(result.date).toBe('2026-08-15');
    });
  });

  describe('AiDomainValidator', () => {
    let validator: AiDomainValidator;

    beforeEach(() => {
      validator = new AiDomainValidator();
    });

    it('reconciles status "verified" when math matches exactly with BigInt', () => {
      const raw = {
        merchantName: 'Super Bistro',
        date: '2026-11-12',
        currency: 'USD',
        subtotalCents: 5000,
        taxCents: 500,
        tipCents: 500,
        totalCents: 6000,
        items: [
          { name: 'Pizza', quantity: 2, priceCents: 2500 },
        ],
      };

      const response = validator.validateAndReconcile(
        raw,
        'USD',
        'heuristic-fallback',
        false,
      );

      expect(response.reconciliation.status).toBe('verified');
      expect(response.reconciliation.subtotalMatches).toBe(true);
      expect(response.reconciliation.totalMatches).toBe(true);
      expect(response.reconciliation.differenceInMinorUnits).toBe(0);
      expect(response.reconciliation.computedItemsSubtotalCents).toBe(5000);
    });

    it('converts LLM floating point hallucinations to safe integer minor units', () => {
      const raw = {
        merchantName: 'Coffee Shop',
        date: '2026-11-12',
        currency: 'USD',
        subtotalCents: (15.5 as unknown) as number, // float hallucination
        taxCents: (1.55 as unknown) as number,
        tipCents: 0,
        totalCents: (17.05 as unknown) as number,
        items: [
          { name: 'Latte', quantity: 1, priceCents: (15.5 as unknown) as number },
        ],
      };

      const response = validator.validateAndReconcile(
        raw,
        'USD',
        'deepseek',
        false,
      );

      expect(response.subtotalCents).toBe(1550);
      expect(response.taxCents).toBe(155);
      expect(response.totalCents).toBe(1705);
      expect(response.items[0].priceCents).toBe(1550);
      expect(response.reconciliation.status).toBe('verified');
    });

    it('flags "discrepancy" status when receipt total does not equal sum', () => {
      const raw = {
        subtotalCents: 5000,
        taxCents: 500,
        tipCents: 0,
        totalCents: 5600, // Expected 5500, discrepancy of 100 cents
        items: [{ name: 'Burger', quantity: 1, priceCents: 5000 }],
      };

      const response = validator.validateAndReconcile(
        raw,
        'USD',
        'heuristic-fallback',
        false,
      );

      expect(response.reconciliation.status).toBe('discrepancy');
      expect(response.reconciliation.differenceInMinorUnits).toBe(100);
      expect(response.reconciliation.totalMatches).toBe(false);
    });

    it('flags "empty" status when no items are detected', () => {
      const raw = {
        subtotalCents: 1000,
        totalCents: 1000,
        items: [],
      };

      const response = validator.validateAndReconcile(
        raw,
        'USD',
        'heuristic-fallback',
        false,
      );

      expect(response.reconciliation.status).toBe('empty');
      expect(response.reconciliation.subtotalMatches).toBeNull();
    });
  });

  describe('AiRateLimitGuard', () => {
    let guard: AiRateLimitGuard;
    let configService: ConfigService;

    beforeEach(() => {
      configService = {
        get: jest.fn().mockReturnValue(3), // Limit of 3 for testing
      } as unknown as ConfigService;
      guard = new AiRateLimitGuard(configService);
    });

    it('allows requests up to the max limit and throws 429 when exceeded', () => {
      const createMockContext = (userId: string) =>
        ({
          switchToHttp: () => ({
            getRequest: () => ({ user: { id: userId }, headers: {} }),
          }),
        } as any);

      const ctx = createMockContext('user-rate-limited');

      expect(guard.canActivate(ctx)).toBe(true);
      expect(guard.canActivate(ctx)).toBe(true);
      expect(guard.canActivate(ctx)).toBe(true);

      // 4th request must throw 429
      expect(() => guard.canActivate(ctx)).toThrow(HttpException);
      try {
        guard.canActivate(ctx);
      } catch (err: any) {
        expect(err.getStatus()).toBe(HttpStatus.TOO_MANY_REQUESTS);
      }
    });
  });

  describe('AiProxyService Orchestration & Fallback', () => {
    let service: AiProxyService;
    let configService: any;
    let heuristicProvider: any;
    let openAiProvider: any;
    let ollamaProvider: any;
    let domainValidator: AiDomainValidator;

    beforeEach(() => {
      configService = {
        get: jest.fn((key: string) => {
          if (key === 'AI_PROVIDER') return 'deepseek';
          if (key === 'AI_FALLBACK_ON_ERROR') return 'true';
          return undefined;
        }),
      };
      heuristicProvider = {
        extractReceipt: jest.fn().mockResolvedValue({
          merchantName: 'Fallback Merchant',
          subtotalCents: 1000,
          totalCents: 1000,
          items: [{ name: 'Item', quantity: 1, priceCents: 1000 }],
        }),
      };
      openAiProvider = {
        extractReceipt: jest.fn(),
      };
      ollamaProvider = {
        extractReceipt: jest.fn(),
      };
      domainValidator = new AiDomainValidator();

      service = new AiProxyService(
        configService,
        heuristicProvider,
        openAiProvider,
        ollamaProvider,
        domainValidator,
      );
    });

    it('transparently falls back to HeuristicFallbackProvider when external provider fails', async () => {
      openAiProvider.extractReceipt.mockRejectedValue(new Error('Network timeout / 503 Service Unavailable'));

      const dto: ParseAiReceiptRequestDto = {
        rawText: 'Item 10.00 Total 10.00',
        currency: 'USD',
        userConsentConfirmed: true,
      };

      const result = await service.parseReceipt(dto, 'user-123');

      expect(openAiProvider.extractReceipt).toHaveBeenCalled();
      expect(heuristicProvider.extractReceipt).toHaveBeenCalled();
      expect(result.fallbackUsed).toBe(true);
      expect(result.providerUsed).toBe('heuristic-fallback');
      expect(result.merchantName).toBe('Fallback Merchant');
    });

    it('throws BadGatewayException when external provider fails and AI_FALLBACK_ON_ERROR is false', async () => {
      configService.get.mockImplementation((key: string) => {
        if (key === 'AI_PROVIDER') return 'deepseek';
        if (key === 'AI_FALLBACK_ON_ERROR') return 'false';
        return undefined;
      });

      openAiProvider.extractReceipt.mockRejectedValue(new Error('DeepSeek API connection refused'));

      const dto: ParseAiReceiptRequestDto = {
        rawText: 'Item 10.00',
        currency: 'USD',
        userConsentConfirmed: true,
      };

      await expect(service.parseReceipt(dto, 'user-123')).rejects.toThrow(
        HttpException,
      );
      expect(heuristicProvider.extractReceipt).not.toHaveBeenCalled();
    });
  });
});
