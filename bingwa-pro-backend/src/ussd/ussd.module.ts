import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';
import { UssdController } from './ussd.controller';
import { UssdService } from './ussd.service';
import { UssdSession } from './entities/ussd-session.entity';
import { UssdRoute } from './entities/ussd-route.entity';
import { UssdAnomaly } from './entities/ussd-anomaly.entity';
import { Transaction } from '../transactions/entities/transaction.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([UssdSession, UssdRoute, UssdAnomaly, Transaction]),
    HttpModule.register({
      timeout: 30000,
      maxRedirects: 5,
    }),
  ],
  controllers: [UssdController],
  providers: [UssdService],
  exports: [UssdService],
})
export class UssdModule {}