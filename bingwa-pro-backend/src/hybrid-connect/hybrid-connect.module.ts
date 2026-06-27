// bingwa-pro-backend/src/hybrid-connect/hybrid-connect.module.ts
import { Module } from '@nestjs/common';
import { HybridConnectController } from './hybrid-connect.controller';
import { HybridConnectService } from './hybrid-connect.service';
import { HybridConnectGateway } from './hybrid-connect.gateway';

@Module({
  controllers: [HybridConnectController],
  providers: [HybridConnectService, HybridConnectGateway],
})
export class HybridConnectModule {}
