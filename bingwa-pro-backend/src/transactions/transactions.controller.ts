// bingwa-pro-backend/src/transactions/transactions.controller.ts
// W2.D: added POST /transactions (Quick Dial), GET /transactions/scheduled,
// POST /transactions/schedule, DELETE /transactions/scheduled/:id. Fixed
// recordSmsPayment agentId: req.user.id → req.user.sub (opportunistic).
// NOTE: route order — /scheduled and /schedule are declared BEFORE /:id so
// they aren't swallowed by the :id param route.
import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import { TransactionsService } from './transactions.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  TransactionType,
  TransactionStatus,
} from './entities/transaction.entity';

@Controller('transactions')
export class TransactionsController {
  constructor(private readonly transactionsService: TransactionsService) {}

  // ===== W2.D Quick Dial =====
  @Post()
  @UseGuards(JwtAuthGuard)
  async createQuickDial(
    @Request() req,
    @Body() body: { offerId: string; customerPhone: string },
  ) {
    return this.transactionsService.createQuickDial(req.user.sub, body);
  }

  // ===== W2.F scheduled (auto-renewals) — BEFORE /:id =====
  @Get('scheduled')
  @UseGuards(JwtAuthGuard)
  async getScheduled(@Request() req) {
    const scheduled = await this.transactionsService.findScheduled(
      req.user.sub,
    );
    return { scheduled, total: scheduled.length };
  }

  @Post('schedule')
  @UseGuards(JwtAuthGuard)
  async schedule(
    @Request() req,
    @Body()
    body: {
      offerId: string;
      customerPhone: string;
      scheduledFor: string;
      isRecurring: boolean;
      daysToRecur?: number;
    },
  ) {
    return this.transactionsService.schedule(req.user.sub, body);
  }

  @Delete('scheduled/:id')
  @UseGuards(JwtAuthGuard)
  async cancelScheduled(@Request() req, @Param('id') id: string) {
    await this.transactionsService.cancelScheduled(req.user.sub, id);
    return { success: true };
  }

  // ===== existing history/summary/details =====
  @Get('history')
  @UseGuards(JwtAuthGuard)
  async getTransactionHistory(
    @Request() req,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
    @Query('types') types?: string,
    @Query('statuses') statuses?: string,
    @Query('customerPhone') customerPhone?: string,
    @Query('minAmount') minAmount?: string,
    @Query('maxAmount') maxAmount?: string,
    @Query('reference') reference?: string,
    @Query('page') page: string = '1',
    @Query('pageSize') pageSize: string = '10',
    @Query('sortBy') sortBy: string = 'createdAt',
    @Query('sortDesc') sortDesc: string = 'true',
  ) {
    const agentId = req.user.sub;
    let parsedTypes: TransactionType[] | undefined;
    if (types) parsedTypes = types.split(',').map((t) => t as TransactionType);
    let parsedStatuses: TransactionStatus[] | undefined;
    if (statuses)
      parsedStatuses = statuses.split(',').map((s) => s as TransactionStatus);

    return this.transactionsService.getTransactionHistory(agentId, {
      startDate: startDate ? new Date(startDate) : undefined,
      endDate: endDate ? new Date(endDate) : undefined,
      types: parsedTypes,
      statuses: parsedStatuses,
      customerPhone,
      minAmount: minAmount ? parseFloat(minAmount) : undefined,
      maxAmount: maxAmount ? parseFloat(maxAmount) : undefined,
      reference,
      page: parseInt(page),
      pageSize: parseInt(pageSize),
      sortBy,
      sortDesc: sortDesc === 'true',
    });
  }

  @Get('summary/:period')
  @UseGuards(JwtAuthGuard)
  async getTransactionSummary(@Request() req, @Param('period') period: string) {
    return this.transactionsService.getTransactionSummary(
      req.user.sub,
      period,
    );
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  async getTransactionDetails(@Param('id') id: string) {
    return this.transactionsService.getTransactionDetails(id);
  }

  @Get(':id/status')
  @UseGuards(JwtAuthGuard)
  async getTransactionStatus(@Param('id') id: string) {
    const transaction = await this.transactionsService.getTransactionDetails(
      id,
    );
    return {
      id: transaction.id,
      status: transaction.status,
      reference: transaction.reference,
      errorMessage: transaction.errorMessage,
    };
  }

  @Post('record-sms-payment')
  @UseGuards(JwtAuthGuard)
  async recordSmsPayment(
    @Body()
    body: {
      mpesaTransactionId: string;
      amount: number;
      customerPhone: string;
      agentId: string;
    },
    @Request() req,
  ) {
    // W2.D fix: was req.user.id (undefined) → req.user.sub.
    return this.transactionsService.recordSmsPayment(body, req.user.sub);
  }
}