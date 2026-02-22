import { Controller, Get, Post, Body, UseGuards, Request, Query } from '@nestjs/common';
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

  @Get('transactions')
  @UseGuards(JwtAuthGuard)
  async getTransactions(
    @Request() req,
    @Query('limit') limit: string = '20',
    @Query('offset') offset: string = '0',
  ) {
    const agentId = req.user.sub;
    const transactions = await this.walletsService.getTransactions(
      agentId,
      parseInt(limit),
      parseInt(offset),
    );
    return { transactions };
  }

  @Post('credit')
  @UseGuards(JwtAuthGuard)
  async creditWallet(
    @Request() req,
    @Body() body: { amount: number; description: string },
  ) {
    const agentId = req.user.sub;
    return this.walletsService.creditWallet(agentId, body.amount, body.description);
  }

  @Post('debit')
  @UseGuards(JwtAuthGuard)
  async debitWallet(
    @Request() req,
    @Body() body: { amount: number; description: string },
  ) {
    const agentId = req.user.sub;
    return this.walletsService.debitWallet(agentId, body.amount, body.description);
  }
}