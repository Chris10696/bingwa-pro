// bingwa-pro-backend/src/transactions/transactions.module.ts
// W1: no structural changes. Transaction entity carries a subscriptionPlanId
// FK now, but the SubscriptionPlan entity is registered in SubscriptionsModule
// — TypeORM resolves the relation via entity-decorator metadata.
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TransactionsController } from './transactions.controller';
import { TransactionsService } from './transactions.service';
import { Transaction } from './entities/transaction.entity';
import { Agent } from '../agents/entities/agent.entity';
import { Wallet } from '../wallets/entities/wallet.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Transaction, Agent, Wallet]),
  ],
  controllers: [TransactionsController],
  providers: [TransactionsService],
  exports: [TransactionsService],
})
export class TransactionsModule {}