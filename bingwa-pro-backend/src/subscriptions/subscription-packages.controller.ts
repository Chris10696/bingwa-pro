// bingwa-pro-backend/src/subscriptions/subscription-packages.controller.ts
// W1 new controller. Read-only — agents browse seeded packages.
import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { SubscriptionPackagesService } from './subscription-packages.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('subscriptions/packages')
export class SubscriptionPackagesController {
  constructor(
    private readonly subscriptionPackagesService: SubscriptionPackagesService,
  ) {}

  @Get()
  @UseGuards(JwtAuthGuard)
  async findAll(@Query('includeInactive') includeInactive?: string) {
    return this.subscriptionPackagesService.findAll(
      includeInactive === 'true',
    );
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  async findOne(@Param('id') id: string) {
    return this.subscriptionPackagesService.findOne(id);
  }
}