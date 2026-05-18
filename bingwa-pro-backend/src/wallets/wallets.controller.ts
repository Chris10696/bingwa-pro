// bingwa-pro-backend/src/wallets/wallets.controller.ts
// W1: stripped to retained endpoints per primer. URL renames per Q9:
//   /wallet/credit         → /wallet/purchase-subscription
//   /wallet/transactions   → /wallet/purchases
// /wallet/balance stays — its payload shape changes (composes plans inside).
// TODO(post-w5): consider moving balance to /subscriptions/balance and
// deprecating /wallet/balance.
import {
  Controller,
  Get,
  Post,
  Body,
  UseGuards,
  Request,
  Query,
  Param,
} from '@nestjs/common';
import { WalletsService } from './wallets.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('wallet')
export class WalletsController {
  constructor(private readonly walletsService: WalletsService) {}

  @Get('balance')
  @UseGuards(JwtAuthGuard)
  async getBalance(@Request() req) {
    const agentId = req.user.sub;
    return this.walletsService.getBalance(agentId);
  }

  @Get('purchases')
  @UseGuards(JwtAuthGuard)
  async getPurchases(
    @Request() req,
    @Query('limit') limit: string = '20',
    @Query('offset') offset: string = '0',
  ) {
    const agentId = req.user.sub;
    const purchases = await this.walletsService.getPurchases(
      agentId,
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
    const agentId = req.user.sub;
    return this.walletsService.purchaseSubscription(
      agentId,
      body.packageId,
      body.phoneNumber,
    );
  }

  /**
   * W1 stub: manual payment confirmation. Used as fallback when STK callback
   * doesn't arrive within the client's 15-second timeout. In W1 the upstream
   * mpesa.creditTokensToWallet is stubbed (no plan granted), so this endpoint
   * returns a synthetic confirmation that lets the client UI complete the flow
   * without functional regression on the visual side.
   *
   * TODO(wave-2): query SubscriptionPurchase status; if COMPLETED, return
   * actual confirmation; if still PENDING, fall through to mpesa.queryStatus.
   */
  @Post('confirm/:purchaseId')
  @UseGuards(JwtAuthGuard)
  async confirmPayment(
    @Request() req,
    @Param('purchaseId') purchaseId: string,
  ) {
    const agentId = req.user.sub;
    return this.walletsService.confirmPayment(agentId, purchaseId);
  }
}