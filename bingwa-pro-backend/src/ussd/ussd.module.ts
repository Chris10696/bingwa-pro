// bingwa-pro-backend/src/ussd/ussd.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';
import { UssdController } from './ussd.controller';
import { UssdService } from './ussd.service';
import { UssdSession } from './entities/ussd-session.entity';
import { UssdRoute } from './entities/ussd-route.entity';
import { UssdAnomaly } from './entities/ussd-anomaly.entity';
import { Transaction } from '../transactions/entities/transaction.entity';
import { Wallet } from '../wallets/entities/wallet.entity';      // ADD THIS
import { Agent } from '../agents/entities/agent.entity';          // ADD THIS
import { WalletsModule } from '../wallets/wallets.module';
import { AgentsModule } from '../agents/agents.module';
import { TransactionsModule } from '../transactions/transactions.module';

@Module({
  imports: [
    // Register ALL entities that UssdService injects via @InjectRepository
    TypeOrmModule.forFeature([
      UssdSession, 
      UssdRoute, 
      UssdAnomaly, 
      Transaction,
      Wallet,      // ADD THIS - for WalletRepository
      Agent,       // ADD THIS - for AgentRepository
    ]),
    HttpModule.register({
      timeout: 30000,
      maxRedirects: 5,
    }),
    WalletsModule,
    AgentsModule,
    TransactionsModule,
  ],
  controllers: [UssdController],
  providers: [UssdService],
  exports: [UssdService],
})
export class UssdModule {}