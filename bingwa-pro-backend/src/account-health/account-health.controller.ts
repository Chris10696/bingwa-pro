// bingwa-pro-backend/src/account-health/account-health.controller.ts
import { Controller, Get, UseGuards, Request } from '@nestjs/common';
import { AccountHealthService } from './account-health.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('account-health')
@UseGuards(JwtAuthGuard)
export class AccountHealthController {
  constructor(private readonly accountHealthService: AccountHealthService) {}

  @Get()
  getHealth(@Request() req) {
    return this.accountHealthService.getHealth(req.user.sub);
  }
}
