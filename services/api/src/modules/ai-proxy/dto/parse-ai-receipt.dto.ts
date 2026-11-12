import {
  Equals,
  IsBoolean,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  Length,
  MaxLength,
} from 'class-validator';

export type AiProviderName =
  | 'deepseek'
  | 'ollama'
  | 'openai'
  | 'heuristic-fallback';

export class ParseAiReceiptRequestDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(15000)
  rawText!: string;

  @IsString()
  @IsNotEmpty()
  @Length(3, 3)
  currency!: string;

  @IsBoolean()
  @Equals(true, {
    message:
      'Explicit user consent is strictly required to process receipt text via AI (Apple Guideline 5.1.2(i))',
  })
  userConsentConfirmed!: boolean;

  @IsOptional()
  @IsIn(['deepseek', 'ollama', 'openai', 'heuristic-fallback'])
  providerOverride?: AiProviderName;
}

export class ParsedAiItemDto {
  name!: string;
  quantity!: number;
  priceCents!: number;
}

export type AiReconciliationStatus =
  | 'verified'
  | 'discrepancy'
  | 'partial'
  | 'empty';

export interface AiReconciliationDto {
  status: AiReconciliationStatus;
  computedItemsSubtotalCents: number;
  differenceInMinorUnits: number;
  subtotalMatches: boolean | null;
  totalMatches: boolean | null;
}

export class ParseAiReceiptResponseDto {
  merchantName!: string | null;
  date!: string | null;
  currency!: string;
  subtotalCents!: number;
  taxCents!: number;
  tipCents!: number;
  totalCents!: number;
  items!: ParsedAiItemDto[];
  reconciliation!: AiReconciliationDto;
  providerUsed!: string;
  fallbackUsed!: boolean;
}
