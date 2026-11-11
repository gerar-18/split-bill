import { Type } from 'class-transformer';
import {
  IsArray,
  IsDateString,
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

export class ReceiptItemDto {
  @IsUUID()
  @IsNotEmpty()
  id!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  name!: string;

  @IsInt()
  @Min(1)
  @Max(10000)
  quantity!: number;

  @IsInt()
  @Min(0)
  @Max(Number.MAX_SAFE_INTEGER)
  priceCents!: number; // Stored in minor units (e.g., $10.50 -> 1050)
}

export class ReceiptParticipantDto {
  @IsUUID()
  @IsNotEmpty()
  id!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  name!: string;
}

export class UpsertReceiptDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  title!: string;

  @IsDateString()
  @IsNotEmpty()
  date!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(3)
  currency!: string; // ISO 4217, e.g. "USD", "MXN", "EUR"

  @IsInt()
  @Min(0)
  @Max(Number.MAX_SAFE_INTEGER)
  subtotalCents!: number;

  @IsInt()
  @Min(0)
  @Max(Number.MAX_SAFE_INTEGER)
  taxCents!: number;

  @IsInt()
  @Min(0)
  @Max(Number.MAX_SAFE_INTEGER)
  tipCents!: number;

  @IsInt()
  @Min(0)
  @Max(Number.MAX_SAFE_INTEGER)
  totalCents!: number;

  @IsInt()
  @IsOptional()
  version?: number;

  @IsDateString()
  @IsNotEmpty()
  clientCreatedAt!: string;

  @IsDateString()
  @IsNotEmpty()
  clientUpdatedAt!: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ReceiptItemDto)
  items!: ReceiptItemDto[];

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ReceiptParticipantDto)
  participants!: ReceiptParticipantDto[];
}
