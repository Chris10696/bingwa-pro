// bingwa-pro-backend/src/offers/dto/offer-filter.dto.ts
// W1: renamed from ProductFilterDto. Stripped filters for dropped fields
// (type, network, isPopular, isFeatured, minPrice, maxPrice).
import {
  IsOptional,
  IsBoolean,
  IsString,
  IsUUID,
  IsInt,
  Min,
} from 'class-validator';
import { Type, Transform } from 'class-transformer';

export class OfferFilterDto {
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @IsOptional()
  @IsUUID()
  agentId?: string;

  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number;
}