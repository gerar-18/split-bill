import { Injectable } from '@nestjs/common';
import {
  AiReconciliationDto,
  AiReconciliationStatus,
  ParsedAiItemDto,
  ParseAiReceiptResponseDto,
} from './dto/parse-ai-receipt.dto';
import { RawExtractedReceipt } from './providers/ai-extraction-provider.interface';

@Injectable()
export class AiDomainValidator {
  validateAndReconcile(
    raw: RawExtractedReceipt,
    fallbackCurrency: string,
    providerUsed: string,
    fallbackUsed: boolean,
  ): ParseAiReceiptResponseDto {
    // 1. Sanitización de nombre de comercio
    let merchantName: string | null = null;
    if (typeof raw.merchantName === 'string') {
      const clean = raw.merchantName.trim();
      const lower = clean.toLowerCase();
      if (
        clean.length > 0 &&
        lower !== 'null' &&
        lower !== 'unknown' &&
        lower !== 'n/a' &&
        lower !== 'ticket' &&
        lower !== 'factura'
      ) {
        merchantName = clean.slice(0, 255);
      }
    }

    // 2. Sanitización de fecha
    let date: string | null = null;
    if (typeof raw.date === 'string') {
      const cleanDate = raw.date.trim();
      if (/^\d{4}-\d{2}-\d{2}$/.test(cleanDate)) {
        date = cleanDate;
      } else {
        const parsed = new Date(cleanDate);
        if (!isNaN(parsed.getTime())) {
          date = parsed.toISOString().slice(0, 10);
        }
      }
    }

    // 3. Moneda ISO 4217 (3 letras mayúsculas)
    let currency = fallbackCurrency.toUpperCase().trim();
    if (
      typeof raw.currency === 'string' &&
      /^[A-Z]{3}$/i.test(raw.currency.trim())
    ) {
      currency = raw.currency.trim().toUpperCase();
    }

    // 4. Sanitización de ítems
    const items: ParsedAiItemDto[] = [];
    if (Array.isArray(raw.items)) {
      for (const item of raw.items) {
        if (!item || typeof item !== 'object') continue;
        const rawName = String(item.name || '').trim();
        if (!rawName) continue;
        const name = rawName.slice(0, 255);

        // Cantidad: entero >= 1
        let quantity = 1;
        const numQty = Number(item.quantity);
        if (Number.isFinite(numQty) && numQty >= 1) {
          quantity = Math.floor(numQty);
        }

        // Precio unitario: centavos enteros >= 0
        let priceCents = 0;
        if (typeof item.priceCents === 'number') {
          if (!Number.isFinite(item.priceCents) || item.priceCents < 0) {
            priceCents = 0;
          } else if (!Number.isInteger(item.priceCents)) {
            // Protección contra alucinaciones de flotantes e.g. 12.50 -> 1250
            priceCents = Math.round(item.priceCents * 100);
          } else {
            priceCents = Math.min(item.priceCents, Number.MAX_SAFE_INTEGER);
          }
        } else if (item.rawPrice !== undefined) {
          priceCents = this.parsePriceToCents(item.rawPrice);
        }

        items.push({ name, quantity, priceCents });
      }
    }

    // 5. Sanitización de totales
    let subtotalCents = this.sanitizeCents(raw.subtotalCents ?? raw.rawSubtotal);
    let taxCents = this.sanitizeCents(raw.taxCents ?? raw.rawTax);
    let tipCents = this.sanitizeCents(raw.tipCents ?? raw.rawTip);
    let totalCents = this.sanitizeCents(raw.totalCents ?? raw.rawTotal);

    // 6. Invariantes de Reconciliación con BigInt
    const computedItemsSubtotal = items.reduce(
      (acc, item) => acc + BigInt(item.quantity) * BigInt(item.priceCents),
      0n,
    );
    const computedItemsSubtotalCents = Number(computedItemsSubtotal);

    if (subtotalCents === 0 && computedItemsSubtotalCents > 0) {
      subtotalCents = computedItemsSubtotalCents;
    }

    if (totalCents === 0 && (subtotalCents > 0 || taxCents > 0 || tipCents > 0)) {
      totalCents = subtotalCents + taxCents + tipCents;
    }

    const subtotalBig = BigInt(subtotalCents);
    const taxBig = BigInt(taxCents);
    const tipBig = BigInt(tipCents);
    const totalBig = BigInt(totalCents);
    const expectedTotal = subtotalBig + taxBig + tipBig;

    const hasDetectedTotal =
      (raw.totalCents !== undefined && raw.totalCents !== null) ||
      (raw.rawTotal !== undefined && raw.rawTotal !== null);
    const hasDetectedSubtotal =
      (raw.subtotalCents !== undefined && raw.subtotalCents !== null) ||
      (raw.rawSubtotal !== undefined && raw.rawSubtotal !== null);

    const subtotalMatches =
      items.length > 0 ? computedItemsSubtotal === subtotalBig : null;
    const totalMatches = hasDetectedTotal ? totalBig === expectedTotal : null;
    const differenceInMinorUnits = Number(totalBig - expectedTotal);

    let status: AiReconciliationStatus;
    if (items.length === 0) {
      status = 'empty';
    } else if (hasDetectedTotal) {
      if (totalBig === expectedTotal) {
        status = 'verified';
      } else {
        status = 'discrepancy';
      }
    } else if (hasDetectedSubtotal) {
      if (subtotalMatches) {
        status = 'verified';
      } else {
        status = 'discrepancy';
      }
    } else {
      status = 'partial';
    }

    const reconciliation: AiReconciliationDto = {
      status,
      computedItemsSubtotalCents,
      differenceInMinorUnits,
      subtotalMatches,
      totalMatches,
    };

    return {
      merchantName,
      date,
      currency,
      subtotalCents,
      taxCents,
      tipCents,
      totalCents,
      items,
      reconciliation,
      providerUsed,
      fallbackUsed,
    };
  }

  private sanitizeCents(value: unknown): number {
    if (typeof value === 'number') {
      if (!Number.isFinite(value) || value < 0) return 0;
      if (!Number.isInteger(value)) {
        return Math.round(value * 100);
      }
      return Math.min(value, Number.MAX_SAFE_INTEGER);
    }
    if (typeof value === 'string') {
      return this.parsePriceToCents(value);
    }
    return 0;
  }

  private parsePriceToCents(val: string | number): number {
    if (typeof val === 'number') {
      if (!Number.isFinite(val) || val < 0) return 0;
      return Number.isInteger(val) ? val : Math.round(val * 100);
    }
    if (typeof val !== 'string') return 0;
    const cleaned = val.replace(/[^0-9.,]/g, '').trim();
    if (!cleaned) return 0;

    let normalized = cleaned;
    const lastComma = cleaned.lastIndexOf(',');
    const lastDot = cleaned.lastIndexOf('.');

    if (lastComma > lastDot) {
      normalized = cleaned.replace(/\./g, '').replace(',', '.');
    } else if (lastDot > lastComma) {
      normalized = cleaned.replace(/,/g, '');
    }

    const parts = normalized.split('.');
    const whole = parseInt(parts[0] || '0', 10);
    const centsStr = (parts[1] || '').slice(0, 2).padEnd(2, '0');
    const cents = parseInt(centsStr, 10);

    const total = whole * 100 + cents;
    return isNaN(total) || total < 0 ? 0 : total;
  }
}
