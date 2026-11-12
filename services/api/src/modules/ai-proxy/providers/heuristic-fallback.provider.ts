import { Injectable, Logger } from '@nestjs/common';
import {
  AiExtractionProvider,
  RawExtractedItem,
  RawExtractedReceipt,
} from './ai-extraction-provider.interface';

@Injectable()
export class HeuristicFallbackProvider implements AiExtractionProvider {
  private readonly logger = new Logger(HeuristicFallbackProvider.name);
  readonly providerName = 'heuristic-fallback';

  async extractReceipt(
    rawText: string,
    currency: string,
  ): Promise<RawExtractedReceipt> {
    const lines = rawText
      .split(/\r?\n/)
      .map((l) => l.trim())
      .filter((l) => l.length > 0);

    const merchantName = this.extractMerchant(lines);
    const date = this.extractDate(rawText);

    let subtotalCents: number | undefined;
    let taxCents: number | undefined;
    let tipCents: number | undefined;
    let totalCents: number | undefined;

    const items: RawExtractedItem[] = [];

    for (const line of lines) {
      if (this.isSubtotalLine(line)) {
        subtotalCents = this.parseAmount(line);
        continue;
      }
      if (this.isTaxLine(line)) {
        taxCents = this.parseAmount(line);
        continue;
      }
      if (this.isTipLine(line)) {
        tipCents = this.parseAmount(line);
        continue;
      }
      if (this.isTotalLine(line)) {
        totalCents = this.parseAmount(line);
        continue;
      }

      if (this.isNoiseLine(line)) {
        continue;
      }

      const item = this.parseItemLine(line);
      if (item) {
        items.push(item);
      }
    }

    return {
      merchantName,
      date,
      currency: currency.toUpperCase().trim(),
      subtotalCents,
      taxCents,
      tipCents,
      totalCents,
      items,
    };
  }

  private extractMerchant(lines: string[]): string | null {
    for (let i = 0; i < Math.min(5, lines.length); i++) {
      const line = lines[i];
      if (
        this.isNoiseLine(line) ||
        this.isSubtotalLine(line) ||
        this.isTotalLine(line) ||
        this.isTaxLine(line) ||
        this.isTipLine(line)
      ) {
        continue;
      }
      if (/[a-zA-ZáéíóúÁÉÍÓÚñÑ]/.test(line) && line.length >= 3 && line.length <= 60) {
        return line
          .replace(/^(comercio|restaurante|tienda|sucursal|merchant):\s*/i, '')
          .trim();
      }
    }
    return null;
  }

  private extractDate(text: string): string | null {
    // YYYY-MM-DD o YYYY/MM/DD
    const isoMatch = text.match(/\b(20\d{2}[-/.]\d{1,2}[-/.]\d{1,2})\b/);
    if (isoMatch) {
      return isoMatch[1].replace(/[/.]/g, '-');
    }

    // DD/MM/YYYY o DD-MM-YYYY
    const euroMatch = text.match(/\b(\d{1,2})[-/.](\d{1,2})[-/.](20\d{2}|\d{2})\b/);
    if (euroMatch) {
      const day = euroMatch[1].padStart(2, '0');
      const month = euroMatch[2].padStart(2, '0');
      let year = euroMatch[3];
      if (year.length === 2) year = `20${year}`;
      return `${year}-${month}-${day}`;
    }

    return null;
  }

  private isSubtotalLine(line: string): boolean {
    return /(?:^|\b)(subtotal|sub-total|sub\s*total|importe|neto)\b/i.test(line);
  }

  private isTaxLine(line: string): boolean {
    return /(?:^|\b)(iva|tax|impuestos?|vat)\b/i.test(line);
  }

  private isTipLine(line: string): boolean {
    return /(?:^|\b)(propina|tip|servicio|gratuity)\b/i.test(line);
  }

  private isTotalLine(line: string): boolean {
    return /(?:^|\b)(total|importe\s*total|total\s*a\s*pagar|monto\s*total)\b/i.test(line);
  }

  private isNoiseLine(line: string): boolean {
    if (/^[-=_*]{3,}$/.test(line)) return true;
    return /^(ticket|factura|recibo|folio|mesa|caja|cajero|rfc|tel|fecha|hora|direcci[oó]n|calle|av\.)\b/i.test(
      line,
    );
  }

  private parseAmount(line: string): number {
    const match = line.match(
      /[$€£]?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})|[0-9]+[.,][0-9]{2}|[0-9]+)/,
    );
    if (!match) return 0;
    return this.parseStringToCents(match[1]);
  }

  private parseItemLine(line: string): RawExtractedItem | null {
    // 1. "2 Tacos Pastor @ 25.00 50.00"
    const atMatch = line.match(
      /^(\d+)\s*[xX*]?\s+(.+?)\s*@\s*[$€£]?\s*([0-9.,]+)(?:\s+[$€£]?\s*([0-9.,]+))?$/,
    );
    if (atMatch) {
      const quantity = Math.max(1, parseInt(atMatch[1], 10));
      const name = atMatch[2].trim();
      const unitPriceCents = this.parseStringToCents(atMatch[3]);
      return { name, quantity, priceCents: unitPriceCents };
    }

    // 2. "2 Tacos Pastor 50.00"
    const qtyMatch = line.match(/^(\d+)\s*[xX*]?\s+(.+?)\s+[$€£]?\s*([0-9.,]+)$/);
    if (qtyMatch) {
      const quantity = Math.max(1, parseInt(qtyMatch[1], 10));
      const name = qtyMatch[2].trim();
      const rawAmountCents = this.parseStringToCents(qtyMatch[3]);
      const priceCents =
        quantity > 1 && rawAmountCents % quantity === 0
          ? Math.floor(rawAmountCents / quantity)
          : rawAmountCents;
      return { name, quantity, priceCents };
    }

    // 3. "Hamburguesa Especial 85.50"
    const singleMatch = line.match(/^(.+?)\s+[$€£]?\s*([0-9]+[.,][0-9]{2})$/);
    if (singleMatch) {
      const name = singleMatch[1].trim();
      if (name.length < 2) return null;
      const priceCents = this.parseStringToCents(singleMatch[2]);
      return { name, quantity: 1, priceCents };
    }

    return null;
  }

  private parseStringToCents(val: string): number {
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
