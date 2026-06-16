// bingwa-pro-backend/src/subscriptions/subscriptions.module.ts
// W1 new module: single SubscriptionsModule containing packages + plans +
// purchases. ScheduleModule.forRoot() moves here from WalletsModule per
// primer cron rule. Services exported so WalletsModule can compose
// /wallet/balance from active plans + hasUsableTokens.
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule';
import { SubscriptionPackagesController } from './subscription-packages.controller';
import { SubscriptionPackagesService } from './subscription-packages.service';
import { SubscriptionPlansController } from './subscription-plans.controller';
import { SubscriptionPlansService } from './subscription-plans.service';
import { SubscriptionPurchasesController } from './subscription-purchases.controller';
import { SubscriptionPurchasesService } from './subscription-purchases.service';
import { SubscriptionsSeed } from './subscriptions.seed';
import { SubscriptionPackage } from './entities/subscription-package.entity';
import { SubscriptionPlan } from './entities/subscription-plan.entity';
import { SubscriptionPurchase } from './entities/subscription-purchase.entity';
import { Agent } from '../agents/entities/agent.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      SubscriptionPackage,
      SubscriptionPlan,
      SubscriptionPurchase,
      Agent,
    ]),
    ScheduleModule.forRoot(),
  ],
  controllers: [
    SubscriptionPackagesController,
    SubscriptionPlansController,
    SubscriptionPurchasesController,
  ],
  providers: [
    SubscriptionPackagesService,
    SubscriptionPlansService,
    SubscriptionPurchasesService,
    SubscriptionsSeed,
  ],
  exports: [
    SubscriptionPackagesService,
    SubscriptionPlansService,
    SubscriptionPurchasesService,
  ],
})
export class SubscriptionsModule {}
