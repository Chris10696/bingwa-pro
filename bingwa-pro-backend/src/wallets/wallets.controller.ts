// bingwa-pro-backend/src/wallets/wallets.controller.ts
// W2.B: added PATCH /wallet/processing-mode (Q-W2-21). Other endpoints unchanged.
import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  UseGuards,
  Request,
  Query,
  Param,
} from '@nestjs/common';
import { WalletsService } from './wallets.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ProcessingMode } from './entities/wallet.entity';

@Controller('wallet')
export class WalletsController {
  constructor(private readonly walletsService: WalletsService) {}

  @Get('balance')
  @UseGuards(JwtAuthGuard)
  async getBalance(@Request() req) {
    return this.walletsService.getBalance(req.user.sub);
  }

  @Get('purchases')
  @UseGuards(JwtAuthGuard)
  async getPurchases(
    @Request() req,
    @Query('limit') limit: string = '20',
    @Query('offset') offset: string = '0',
  ) {
    const purchases = await this.walletsService.getPurchases(
      req.user.sub,
      parseInt(limit),
      parseInt(offset),
    );
    return { purchases };
  }

  @Post('purchase-subscription')
  @UseGuards(JwtAuthGuard)
  async purchaseSubscription(
    @Request() req,
    @Body() body: { packageId: string; phoneNumber?: string },
  ) {
    return this.walletsService.purchaseSubscription(
      req.user.sub,
      body.packageId,
      body.phoneNumber,
    );
  }

  @Post('confirm/:purchaseId')
  @UseGuards(JwtAuthGuard)
  async confirmPayment(
    @Request() req,
    @Param('purchaseId') purchaseId: string,
  ) {
    return this.walletsService.confirmPayment(req.user.sub, purchaseId);
  }

  @Patch('processing-mode')
  @UseGuards(JwtAuthGuard)
  async setProcessingMode(
    @Request() req,
    @Body() body: { processingMode: ProcessingMode },
  ) {
    return this.walletsService.setProcessingMode(
      req.user.sub,
      body.processingMode,
    );
  }

  // GET /wallet/admin-subscription-number
  @Get('admin-subscription-number')
  @UseGuards(JwtAuthGuard)
  getAdminSubscriptionNumber() {
    return this.walletsService.getAdminSubscriptionNumber();
  }

  // POST /wallet/purchase-subscription-airtime  { "packageId": "..." }
  @Post('purchase-subscription-airtime')
  @UseGuards(JwtAuthGuard)
  purchaseSubscriptionWithAirtime(
    @Request() req,
    @Body() body: { packageId: string },
  ) {
    return this.walletsService.purchaseSubscriptionWithAirtime(
      req.user.sub,
      body.packageId,
    );
  }
}
