// bingwa-pro-backend/src/coupons/dto/create-coupon.dto.ts
// W2.B: admin/testing coupon creation. No admin UI in W2 — coupons created via
// this endpoint (JWT-guarded) or direct SQL for testing.
import {
  IsString,
  IsNotEmpty,
  IsUUID,
  IsOptional,
  IsDateString,
} from 'class-validator';

export class CreateCouponDto {
  @IsString()
  @IsNotEmpty()
  code: string;

  @IsUUID()
  packageId: string;

  @IsOptional()
  @IsDateString()
  expiresAt?: string;
}
