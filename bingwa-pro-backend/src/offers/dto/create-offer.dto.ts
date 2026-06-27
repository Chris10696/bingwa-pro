// bingwa-pro-backend/src/offers/dto/create-offer.dto.ts
// W2.A: dropped validityLabel + categoryId + client-supplied agentId (agentId
// now comes from the JWT, Q-W2-17). Added type (OfferType). ussdTemplate →
// ussdCode (D-W2-F). The 8 retry fields are NOT accepted here — they take
// entity defaults; W3's OfferSettings UI edits them.
import {
  IsString,
  IsInt,
  Min,
  Max,
  IsNumber,
  IsBoolean,
  IsOptional,
  IsEnum,
  Matches,
} from 'class-validator';
import { OfferType } from '../entities/offer.entity';

export class CreateOfferDto {
  @IsString()
  name: string;

  // Must start with *, end with #, and contain the BH placeholder.
  @IsString()
  @Matches(/^\*[\d*]+BH[\d*]*#$/, {
    message:
      'ussdCode must be a valid USSD code containing the BH placeholder (e.g. *180*5*2*BH*1*1#)',
  })
  ussdCode: string;

  @IsInt()
  @Min(1)
  price: number;

  @IsEnum(OfferType)
  type: OfferType;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  // W5.A — agent commission percent of the sale (0–100). Optional; defaults to 0.
  @IsNumber()
  @IsOptional()
  @Min(0)
  @Max(100)
  commissionRate?: number;
}
