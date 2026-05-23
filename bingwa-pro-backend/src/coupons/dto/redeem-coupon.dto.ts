// bingwa-pro-backend/src/coupons/dto/redeem-coupon.dto.ts
// W2.B: featureCode dropped — Hybrid-specific constant, irrelevant to Pro
// (coupons are inherently scoped to Pro). Client sends only the code.
import { IsString, IsNotEmpty } from 'class-validator';

export class RedeemCouponDto {
  @IsString()
  @IsNotEmpty()
  couponCode: string;
}