// bingwa-pro-backend/src/account-health/account-health.module.ts
import { Module } from '@nestjs/common';
import { AccountHealthController } from './account-health.controller';
import { AccountHealthService } from './account-health.service';

@Module({
  controllers: [AccountHealthController],
  providers: [AccountHealthService],
})
export class AccountHealthModule {}
