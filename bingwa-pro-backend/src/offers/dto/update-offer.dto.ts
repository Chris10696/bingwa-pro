// bingwa-pro-backend/src/offers/dto/update-offer.dto.ts
// W1: renamed from UpdateProductDto. PartialType supports toggle-only and
// full updates from the same PATCH /offers/:id endpoint (Q10).
import { PartialType } from '@nestjs/mapped-types';
import { CreateOfferDto } from './create-offer.dto';

export class UpdateOfferDto extends PartialType(CreateOfferDto) {}