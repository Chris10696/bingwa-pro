import { Controller, Post, Get, Body, Param, Query, UseGuards, HttpCode, HttpStatus, Req } from '@nestjs/common';
import { MpesaService } from './mpesa.service';  // This import is correct
import { StkPushRequestDto } from './dto/stk-push-request.dto';
import { MpesaCallbackDto } from './dto/mpesa-callback.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Throttle } from '@nestjs/throttler';

@Controller('mpesa')
export class MpesaController {
  constructor(private readonly mpesaService: MpesaService) {}

  /**
   * Initiate STK Push (protected endpoint for agents)
   */
  @Post('stkpush')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  async initiateStkPush(@Body() requestDto: StkPushRequestDto, @Req() req) {
    const agentId = req.user.sub;
    return this.mpesaService.initiateStkPush(requestDto, agentId);
  }

  /**
   * M-Pesa callback endpoint (public - called by Safaricom)
   */
  @Post('callback')
  @HttpCode(HttpStatus.OK)
  async handleCallback(@Body() callbackDto: MpesaCallbackDto) {
    await this.mpesaService.handleCallback(callbackDto);
    return { 
      ResultCode: 0, 
      ResultDesc: 'Success' 
    };
  }

  /**
   * Query transaction status
   */
  @Get('status/:checkoutRequestId')
  @UseGuards(JwtAuthGuard)
  async queryStatus(@Param('checkoutRequestId') checkoutRequestId: string) {
    return this.mpesaService.queryStatus(checkoutRequestId);
  }

  /**
   * Get transaction details
   */
  @Get('transactions/:id')
  @UseGuards(JwtAuthGuard)
  async getTransaction(@Param('id') id: string) {
    return this.mpesaService.getTransaction(id);
  }

  /**
   * Get agent's M-Pesa transactions
   */
  @Get('transactions')
  @UseGuards(JwtAuthGuard)
  async getAgentTransactions(
    @Req() req,
    @Query('limit') limit?: string,
  ) {
    const agentId = req.user.sub;
    return this.mpesaService.getAgentTransactions(agentId, limit ? parseInt(limit) : 50);
  }

  /**
   * Simulate callback (sandbox only)
   */
  @Post('simulate/:transactionId')
  @UseGuards(JwtAuthGuard)
  async simulateCallback(
    @Param('transactionId') transactionId: string,
    @Body('success') success: boolean = true,
  ) {
    return this.mpesaService.simulateCallback(transactionId, success);
  }
}