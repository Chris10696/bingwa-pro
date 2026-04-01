// bingwa-pro-backend/src/wallets/wallets.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule';
import { WalletsController } from './wallets.controller';
import { WalletsService } from './wallets.service';
import { Wallet } from './entities/wallet.entity';
import { TokenPackage } from './entities/token-package.entity';
import { TokenTransaction } from './entities/token-transaction.entity';
import { Agent } from '../agents/entities/agent.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Wallet, TokenPackage, TokenTransaction, Agent]),
    ScheduleModule.forRoot(),
  ],
  controllers: [WalletsController],
  providers: [WalletsService],
  exports: [WalletsService],  // ✅ Already exported
})
export class WalletsModule {}