// bingwa-pro-backend/src/transactions/transactions.controller.ts
// W3.G + W3.K backend slice:
//   - PATCH /transactions/:id/status — declared BEFORE /:id (route order
//     matters; otherwise :id swallows /status). Device pipeline reports
//     terminal outcomes here (SUCCESS / FAILED / RESCHEDULED / …).
//   - POST /transactions/sms-create — backend-first SMS flow (D-W3-13).
//     The device hands the M-Pesa SMS payload here; backend runs the SAME
//     guard→create→debit sequence as createQuickDial (consistency lock).
//     Dedup is at the DB level via @Unique(mpesaTransactionId, agentId);
//     a duplicate returns 409 — the device then doesn't dial.
//   - Existing record-sms-payment kept for back-compat during the device
//     migration window. Will be deprecated once W3.K device code lands.
// All W2 routes unchanged. Route declaration order preserved (specific
// paths BEFORE param routes).
import {
  Controller,
  Get,
  Post,
  Patch,
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
import { UpdateTransactionStatusDto } from './dto/update-transaction-status.dto';

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

  // ===== W3.K backend-first SMS create (D-W3-13, D-W3-17) =====
  // Replaces the dial-then-record pattern. The device parses an M-Pesa SMS,
  // sends the parsed payload here, and gets back an SmsCreateResult:
  //   - MATCH  → { transaction (SCHEDULED), autoReplyType: null, shouldDial: true }
  //     The device dials the persisted ussdCode immediately. Token already
  //     debited (dial-time, Hybrid parity).
  //   - NO MATCH → { transaction (UNMATCHED), autoReplyType: 'OFFER_UNAVAILABLE',
  //     shouldDial: false }. Device does NOT dial; it fires the W3.M auto-reply.
  //     No token debited.
  // On idempotent collision (same mpesaTransactionId for this agent) the
  // service throws ConflictException → 409 and the device MUST NOT dial.
  @Post('sms-create')
  @UseGuards(JwtAuthGuard)
  async createFromSms(
    @Request() req,
    @Body()
    body: {
      mpesaTransactionId: string;
      amount: number;
      customerPhone: string;
      customerName?: string;
      mpesaMessage?: string;
    },
  ) {
    return this.transactionsService.createFromSms(req.user.sub, body);
  }

  // POST /transactions/airtime-subscription  { "packageId": "..." }
  @Post('airtime-subscription')
  @UseGuards(JwtAuthGuard)
  async createAirtimeSubscription(
    @Request() req,
    @Body() body: { packageId: string },
  ) {
    return this.transactionsService.createAirtimeSubscription(
      req.user.sub,
      body.packageId,
    );
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

  // ===== existing history/summary — BEFORE /:id =====
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
    return this.transactionsService.getTransactionSummary(req.user.sub, period);
  }

  // W5.A — agent commission summary (this week + today + last-7-days breakdown). BEFORE /:id.
  @Get('commission')
  @UseGuards(JwtAuthGuard)
  async getCommissionSummary(@Request() req) {
    return this.transactionsService.getCommissionSummary(req.user.sub);
  }

  // ===== W3.G device→backend status reporting — BEFORE /:id =====
  // The native pipeline calls this when a transaction settles. Includes the
  // captured USSD response text for SUCCESS-with-content cases (W3.B Express).
  @Patch(':id/status')
  @UseGuards(JwtAuthGuard)
  async updateTransactionStatus(
    @Request() req,
    @Param('id') id: string,
    @Body() body: UpdateTransactionStatusDto,
  ) {
    return this.transactionsService.updateTransactionStatus(id, body.status, {
      errorMessage: body.errorMessage,
      ussdResponse: body.ussdResponse,
      safaricomReference: body.safaricomReference,
      agentId: req.user.sub, // ownership guard (B4-part-1 flag, now closed)
    });
  }

  // ===== /:id routes — declared LAST =====
  @Get(':id')
  @UseGuards(JwtAuthGuard)
  async getTransactionDetails(@Request() req, @Param('id') id: string) {
    return this.transactionsService.getTransactionDetails(id, req.user.sub);
  }

  @Get(':id/status')
  @UseGuards(JwtAuthGuard)
  async getTransactionStatus(@Request() req, @Param('id') id: string) {
    const transaction = await this.transactionsService.getTransactionDetails(
      id,
      req.user.sub,
    );
    return {
      id: transaction.id,
      status: transaction.status,
      reference: transaction.reference,
      errorMessage: transaction.errorMessage,
      ussdResponse: transaction.ussdResponse,
    };
  }

  // ===== Back-compat: legacy device-autonomous SMS record path =====
  // Kept so the current native MpesaMessageListener keeps working until W3.K
  // device code migrates to /sms-create. Will be removed after migration.
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
    return this.transactionsService.recordSmsPayment(body, req.user.sub);
  }
}
