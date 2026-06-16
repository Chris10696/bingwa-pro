// bingwa-pro-backend/src/coupons/coupons.controller.ts
// W2.B: POST /coupons/redeem (agent) + POST /coupons (create, testing).
import { Controller, Post, Body, UseGuards, Request } from '@nestjs/common';
import { CouponsService } from './coupons.service';
import { RedeemCouponDto } from './dto/redeem-coupon.dto';
import { CreateCouponDto } from './dto/create-coupon.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('coupons')
export class CouponsController {
  constructor(private readonly couponsService: CouponsService) {}

  @Post('redeem')
  @UseGuards(JwtAuthGuard)
  async redeem(@Request() req, @Body() dto: RedeemCouponDto) {
    return this.couponsService.redeem(req.user.sub, dto.couponCode);
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  async create(@Body() dto: CreateCouponDto) {
    return this.couponsService.create(dto);
  }
}
