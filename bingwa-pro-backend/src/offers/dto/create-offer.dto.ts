// bingwa-pro-backend/src/offers/dto/create-offer.dto.ts
// W1: renamed from CreateProductDto. Validates the exact W1 Offer fields.
import {
  IsString,
  IsInt,
  Min,
  IsUUID,
  IsBoolean,
  IsOptional,
  Matches,
} from 'class-validator';

export class CreateOfferDto {
  @IsString()
  name: string;

  // USSD template must start with *, end with #, and contain BH placeholder.
  @IsString()
  @Matches(/^\*[\d*]+BH[\d*]*#$/, {
    message:
      'ussdTemplate must be a valid USSD code containing the BH placeholder (e.g. *180*5*2*BH*1*1#)',
  })
  ussdTemplate: string;

  @IsInt()
  @Min(1)
  price: number;

  @IsString()
  validityLabel: string;

  @IsUUID()
  categoryId: string;

  @IsUUID()
  agentId: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}