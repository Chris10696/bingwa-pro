// bingwa-pro-backend/src/wallets/wallets.module.ts
// W1: TokenPackage and TokenTransaction entities removed (replaced by
// SubscriptionsModule's three entities). ScheduleModule.forRoot() moved to
// SubscriptionsModule per primer. SubscriptionsModule imported so
// WalletsService.getBalance can compose plans + hasUsableTokens.
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WalletsController } from './wallets.controller';
import { WalletsService } from './wallets.service';
import { Wallet } from './entities/wallet.entity';
import { Agent } from '../agents/entities/agent.entity';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Wallet, Agent]),
    SubscriptionsModule,
  ],
  controllers: [WalletsController],
  providers: [WalletsService],
  exports: [WalletsService],
})
export class WalletsModule {}