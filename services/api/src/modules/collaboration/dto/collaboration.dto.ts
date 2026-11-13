import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { UpsertReceiptDto } from '../../receipts/dto/receipt.dto';

export const MODERATION_REASONS = [
  'INAPPROPRIATE_IMAGE',
  'SPAM_OR_SCAM',
  'HARASSMENT_OR_OFFENSIVE_TEXT',
  'OTHER',
] as const;

export type ModerationReason = (typeof MODERATION_REASONS)[number];

export class CreateSharedSessionDto {
  @ValidateNested()
  @Type(() => UpsertReceiptDto)
  @IsNotEmpty()
  receipt!: UpsertReceiptDto;

  @IsString()
  @IsNotEmpty()
  @MaxLength(60)
  hostDisplayName!: string;

  @IsBoolean()
  @IsOptional()
  includeImage?: boolean;

  @IsString()
  @IsOptional()
  @MaxLength(1_400_000) // ~1 MB JPEG base64 ceiling
  imageBase64OptIn?: string;
}

export class JoinSharedSessionDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(60)
  displayName!: string;
}

export class ToggleClaimDto {
  @IsUUID()
  @IsNotEmpty()
  itemId!: string;

  @IsIn(['claim', 'unclaim'])
  @IsNotEmpty()
  action!: 'claim' | 'unclaim';

  @IsInt()
  @Min(1)
  @Max(1_000_000)
  expectedVersion!: number;
}

export class ReportSessionDto {
  @IsIn(MODERATION_REASONS)
  @IsNotEmpty()
  reason!: ModerationReason;

  @IsString()
  @IsOptional()
  @MaxLength(300)
  note?: string;
}
