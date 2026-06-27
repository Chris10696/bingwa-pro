// bingwa-pro-backend/src/transactions/transactions.module.ts
// W2.D: imports SubscriptionsModule so the Quick Dial flow can check
// hasUsableTokens (402 guard) and debit a LIMITED token after a successful dial.
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TransactionsController } from './transactions.controller';
import { TransactionsService } from './transactions.service';
import { Transaction } from './entities/transaction.entity';
import { Agent } from '../agents/entities/agent.entity';
import { Wallet } from '../wallets/entities/wallet.entity';
import { Offer } from '../offers/entities/offer.entity';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { CustomersModule } from '../customers/customers.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Transaction, Agent, Wallet, Offer]),
    SubscriptionsModule,
    CustomersModule,
  ],
  controllers: [TransactionsController],
  providers: [TransactionsService],
  exports: [TransactionsService],
})
export class TransactionsModule {}
