// bingwa-pro-backend/src/offers/dto/update-offer.dto.ts
// W3.H prep: extends PartialType(CreateOfferDto) with the 7 OfferSettings
// fields (locked B4-part-2). Previously, PATCH /offers/:id silently dropped
// any of these fields because CreateOfferDto deliberately omits them — they
// were entity-default-only. W3.H's screen needs to PATCH them, so the
// update DTO must whitelist + validate them.
//
// `relayDevice` is included for completeness (column exists, used by W5
// SiteLink routing) but is NOT surfaced by the W3.H UI per D-W3-10.
import { PartialType } from '@nestjs/mapped-types';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
} from 'class-validator';
import { CreateOfferDto } from './create-offer.dto';

export class UpdateOfferDto extends PartialType(CreateOfferDto) {
  // ===== Hybrid OfferSettings (W3.H) =====

  @IsOptional()
  @IsBoolean()
  autoReschedule?: boolean;

  // Stored as a string (Hybrid uses LocalTime serialized as "HH:mm" — the
  // time picker's output). Optional, only meaningful when autoReschedule=true.
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, {
    message: 'autoRescheduleRunTime must be in HH:mm format (e.g. "09:00")',
  })
  autoRescheduleRunTime?: string | null;

  @IsOptional()
  @IsBoolean()
  autoRetry?: boolean;

  @IsOptional()
  @IsBoolean()
  autoRetryConnectionProblems?: boolean;

  // 0 = no retries; reasonable upper bound to prevent runaway loops.
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(50)
  numberOfRetries?: number;

  // Retry interval in minutes; >= 1 to avoid zero-delay retries.
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1440) // 24h cap
  retryIntervalMins?: number;

  // USSD timeout in MILLISECONDS (client converts seconds ↔ ms at the UI
  // boundary). Hard floor 1s (1000ms), reasonable cap matching int range.
  @IsOptional()
  @IsInt()
  @Min(1000)
  @Max(600000) // 10-minute hard ceiling — Hybrid never goes near this
  ussdTimeoutMillis?: number;

  // ===== Hidden in W3.H UI but present in DTO (W5 SiteLink will edit) =====
  @IsOptional()
  @IsString()
  relayDevice?: string | null;
}