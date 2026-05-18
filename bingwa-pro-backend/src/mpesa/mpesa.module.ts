// bingwa-pro-backend/src/mpesa/mpesa.module.ts
// W1: unchanged. Wallet entity in forFeature is currently unused (creditTokensToWallet
// is stubbed) but will be needed again in W2. TODO(wave-2): re-evaluate after
// MpesaService is rewired to SubscriptionPlansService.
import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MpesaController } from './mpesa.controller';
import { MpesaService } from './mpesa.service';
import { MpesaTransaction } from './entities/mpesa-transaction.entity';
import { Wallet } from '../wallets/entities/wallet.entity';
import { Agent } from '../agents/entities/agent.entity';

@Module({
  imports: [
    HttpModule.register({
      timeout: 30000,
      maxRedirects: 5,
    }),
    TypeOrmModule.forFeature([MpesaTransaction, Wallet, Agent]),
  ],
  controllers: [MpesaController],
  providers: [MpesaService],
  exports: [MpesaService],
})
export class MpesaModule {}