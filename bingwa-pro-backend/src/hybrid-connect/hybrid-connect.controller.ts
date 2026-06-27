// bingwa-pro-backend/src/hybrid-connect/hybrid-connect.controller.ts
// W5.F — Connect ID issuance. The app calls generate (on "Generate Connect ID") and shares the
// returned ID with the web portal; both then join the socket room for that ID.
import { Controller, Get, Post, UseGuards, Request } from '@nestjs/common';
import { HybridConnectService } from './hybrid-connect.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('hybrid-connect')
@UseGuards(JwtAuthGuard)
export class HybridConnectController {
  constructor(private readonly service: HybridConnectService) {}

  @Post('generate')
  generate(@Request() req) {
    return { connectId: this.service.generate(req.user.sub) };
  }

  @Get()
  current(@Request() req) {
    return { connectId: this.service.current(req.user.sub) };
  }
}
