// bingwa-pro-backend/src/offers/dto/update-offer.dto.ts
// W2.A: structurally unchanged — PartialType(CreateOfferDto) auto-follows the
// create DTO's W2 reshape. Supports toggle-only ({isActive}) and full edits
// from the same PATCH /offers/:id endpoint.
import { PartialType } from '@nestjs/mapped-types';
import { CreateOfferDto } from './create-offer.dto';

export class UpdateOfferDto extends PartialType(CreateOfferDto) {}