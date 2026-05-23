// bingwa-pro-backend/src/mpesa/mpesa.module.ts
// W2.B: imports SubscriptionsModule so MpesaService.creditTokensToWallet can
// call createPlanFromPurchase + updateStatus (the single plan-grant path).
import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MpesaController } from './mpesa.controller';
import { MpesaService } from './mpesa.service';
import { MpesaTransaction } from './entities/mpesa-transaction.entity';
import { Agent } from '../agents/entities/agent.entity';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';

@Module({
  imports: [
    HttpModule.register({
      timeout: 30000,
      maxRedirects: 5,
    }),
    TypeOrmModule.forFeature([MpesaTransaction, Agent]),
    SubscriptionsModule,
  ],
  controllers: [MpesaController],
  providers: [MpesaService],
  exports: [MpesaService],
})
export class MpesaModule {}