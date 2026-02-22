import { Controller, Get, Post, Body, Param, Query, UseGuards, Request } from '@nestjs/common';
import { TransactionsService } from './transactions.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TransactionType, TransactionStatus } from './entities/transaction.entity';

@Controller('transactions')
export class TransactionsController {
  constructor(private readonly transactionsService: TransactionsService) {}

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

    // Parse types
    let parsedTypes: TransactionType[] | undefined;
    if (types) {
      parsedTypes = types.split(',').map(t => t as TransactionType);
    }

    // Parse statuses
    let parsedStatuses: TransactionStatus[] | undefined;
    if (statuses) {
      parsedStatuses = statuses.split(',').map(s => s as TransactionStatus);
    }

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
    const agentId = req.user.sub;
    return this.transactionsService.getTransactionSummary(agentId, period);
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  async getTransactionDetails(@Param('id') id: string) {
    return this.transactionsService.getTransactionDetails(id);
  }

  @Get(':id/status')
  @UseGuards(JwtAuthGuard)
  async getTransactionStatus(@Param('id') id: string) {
    const transaction = await this.transactionsService.getTransactionDetails(id);
    return {
      id: transaction.id,
      status: transaction.status,
      reference: transaction.reference,
      errorMessage: transaction.errorMessage,
    };
  }
}