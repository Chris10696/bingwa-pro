// bingwa-pro-backend/src/subscriptions/subscription-purchases.controller.ts
// W1 new controller. Read-only audit access to past purchases.
import { Controller, Get, Query, Request, UseGuards } from '@nestjs/common';
import { SubscriptionPurchasesService } from './subscription-purchases.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('subscriptions/purchases')
export class SubscriptionPurchasesController {
  constructor(
    private readonly subscriptionPurchasesService: SubscriptionPurchasesService,
  ) {}

  @Get('me')
  @UseGuards(JwtAuthGuard)
  async findMyPurchases(
    @Request() req,
    @Query('limit') limit: string = '20',
    @Query('offset') offset: string = '0',
  ) {
    const agentId = req.user.sub;
    return this.subscriptionPurchasesService.findByAgent(
      agentId,
      parseInt(limit),
      parseInt(offset),
    );
  }
}