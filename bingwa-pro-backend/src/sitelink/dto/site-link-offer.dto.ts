// bingwa-pro-backend/src/sitelink/dto/site-link-offer.dto.ts
import { IsBoolean, IsOptional, IsString, IsUUID } from 'class-validator';

// Publish one of the agent's existing offers to the SiteLink store.
export class AddSiteLinkOfferDto {
  @IsUUID()
  offerId: string;
}

export class SetOfferActiveDto {
  @IsBoolean()
  isActive: boolean;
}

// W5.G (fleet) — assign which device dials this offer when ordered. Empty/omitted clears it.
export class UpdateRelayDeviceDto {
  @IsOptional()
  @IsString()
  relayDevice?: string;
}
