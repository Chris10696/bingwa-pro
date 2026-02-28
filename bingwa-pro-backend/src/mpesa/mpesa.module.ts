import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MpesaController } from './mpesa.controller';
import { MpesaService } from './mpesa.service';  // This import is correct
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