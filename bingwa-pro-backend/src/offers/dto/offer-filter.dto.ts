// bingwa-pro-backend/src/offers/dto/offer-filter.dto.ts
// W2.A: categoryId filter dropped (D-W2-1), replaced with type (OfferType).
// agentId filter removed — the controller forces scoping to the JWT subject
// (Q-W2-17), so clients cannot query other agents' offers.
import { IsOptional, IsBoolean, IsString, IsEnum, IsInt, Min } from 'class-validator';
import { Type, Transform } from 'class-transformer';
import { OfferType } from '../entities/offer.entity';

export class OfferFilterDto {
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsEnum(OfferType)
  type?: OfferType;

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