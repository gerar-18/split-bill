export interface RawExtractedItem {
  name: string;
  quantity?: number;
  priceCents?: number;
  rawPrice?: number | string;
}

export interface RawExtractedReceipt {
  merchantName?: string | null;
  date?: string | null;
  currency?: string;
  subtotalCents?: number;
  taxCents?: number;
  tipCents?: number;
  totalCents?: number;
  items?: RawExtractedItem[];
  rawSubtotal?: number | string;
  rawTax?: number | string;
  rawTip?: number | string;
  rawTotal?: number | string;
}

export interface AiExtractionProvider {
  readonly providerName: string;
  extractReceipt(
    rawText: string,
    currency: string,
    options?: {
      timeoutMs?: number;
      model?: string;
      isDeepSeek?: boolean;
    },
  ): Promise<RawExtractedReceipt>;
}
