// bingwa-pro-backend/src/subscriptions/subscription-plans.controller.ts
// W1 new controller. Agents read their own active plans. /wallet/balance
// composes plans server-side via SubscriptionPlansService directly.
import { Controller, Get, Request, UseGuards } from '@nestjs/common';
import { SubscriptionPlansService } from './subscription-plans.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('subscriptions/plans')
export class SubscriptionPlansController {
  constructor(
    private readonly subscriptionPlansService: SubscriptionPlansService,
  ) {}

  @Get('me')
  @UseGuards(JwtAuthGuard)
  async findMyPlans(@Request() req) {
    const agentId = req.user.sub;
    return this.subscriptionPlansService.findActivePlansForAgent(agentId);
  }
}