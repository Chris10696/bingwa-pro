// bingwa-pro-backend/src/wallets/wallets.module.ts
// W2.B: imports MpesaModule so purchaseSubscription can initiate a real STK
// push. SubscriptionsModule still imported for balance composition.
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WalletsController } from './wallets.controller';
import { WalletsService } from './wallets.service';
import { Wallet } from './entities/wallet.entity';
import { Agent } from '../agents/entities/agent.entity';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { MpesaModule } from '../mpesa/mpesa.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Wallet, Agent]),
    SubscriptionsModule,
    MpesaModule,
  ],
  controllers: [WalletsController],
  providers: [WalletsService],
  exports: [WalletsService],
})
export class WalletsModule {}
