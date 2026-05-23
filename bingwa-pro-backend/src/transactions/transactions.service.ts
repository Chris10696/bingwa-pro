// bingwa-pro-backend/src/transactions/transactions.service.ts
// W2.D: added createQuickDial (hasUsableTokens 402 guard, create QUICK_DIAL
// transaction, debit on success) and scheduled-transaction methods
// (findScheduled / schedule / cancelScheduled — auto-renewals as SCHEDULED
// transactions, D-W2-5). recordSmsPayment agentId now from req.user.sub
// (controller fix). Batch-1 methods unchanged.
import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan } from 'typeorm';
import {
  Transaction,
  TransactionType,
  TransactionStatus,
} from './entities/transaction.entity';
import { Agent } from '../agents/entities/agent.entity';
import { Wallet } from '../wallets/entities/wallet.entity';
import { Offer } from '../offers/entities/offer.entity';
import { SubscriptionPlansService } from '../subscriptions/subscription-plans.service';

@Injectable()
export class TransactionsService {
  constructor(
    @InjectRepository(Transaction)
    private transactionsRepository: Repository<Transaction>,
    @InjectRepository(Agent)
    private agentsRepository: Repository<Agent>,
    @InjectRepository(Wallet)
    private walletsRepository: Repository<Wallet>,
    @InjectRepository(Offer)
    private offersRepository: Repository<Offer>,
    private subscriptionPlansService: SubscriptionPlansService,
  ) {}

  async getTransactionHistory(
    agentId: string,
    filter: {
      startDate?: Date;
      endDate?: Date;
      types?: TransactionType[];
      statuses?: TransactionStatus[];
      customerPhone?: string;
      minAmount?: number;
      maxAmount?: number;
      reference?: string;
      page: number;
      pageSize: number;
      sortBy: string;
      sortDesc: boolean;
    },
  ): Promise<{
    transactions: Transaction[];
    total: number;
    page: number;
    pageSize: number;
  }> {
    const queryBuilder = this.transactionsRepository
      .createQueryBuilder('transaction')
      .leftJoinAndSelect('transaction.agent', 'agent')
      .where('agent.id = :agentId', { agentId })
      .skip((filter.page - 1) * filter.pageSize)
      .take(filter.pageSize);

    if (filter.startDate) {
      queryBuilder.andWhere('transaction.createdAt >= :startDate', {
        startDate: filter.startDate,
      });
    }
    if (filter.endDate) {
      queryBuilder.andWhere('transaction.createdAt <= :endDate', {
        endDate: filter.endDate,
      });
    }
    if (filter.types && filter.types.length > 0) {
      queryBuilder.andWhere('transaction.type IN (:...types)', {
        types: filter.types,
      });
    }
    if (filter.statuses && filter.statuses.length > 0) {
      queryBuilder.andWhere('transaction.status IN (:...statuses)', {
        statuses: filter.statuses,
      });
    }
    if (filter.customerPhone) {
      queryBuilder.andWhere('transaction.recipientPhone LIKE :phone', {
        phone: `%${filter.customerPhone}%`,
      });
    }
    if (filter.minAmount) {
      queryBuilder.andWhere('transaction.amount >= :minAmount', {
        minAmount: filter.minAmount,
      });
    }
    if (filter.maxAmount) {
      queryBuilder.andWhere('transaction.amount <= :maxAmount', {
        maxAmount: filter.maxAmount,
      });
    }
    if (filter.reference) {
      queryBuilder.andWhere('transaction.reference LIKE :ref', {
        ref: `%${filter.reference}%`,
      });
    }

    const order = filter.sortDesc ? 'DESC' : 'ASC';
    queryBuilder.orderBy(`transaction.${filter.sortBy}`, order);

    const [transactions, total] = await queryBuilder.getManyAndCount();
    return {
      transactions,
      total,
      page: filter.page,
      pageSize: filter.pageSize,
    };
  }

  /**
   * W2.D Quick Dial. Guards with hasUsableTokens (402 if none). Creates a
   * QUICK_DIAL transaction in SUCCESS (intent-based dial is fire-and-forget;
   * the agent reads the real response on the system dialer), then debits a
   * LIMITED token if applicable (UNLIMITED active → no debit).
   */
  async createQuickDial(
    agentId: string,
    data: { offerId: string; customerPhone: string },
  ): Promise<Transaction> {
    const usable = await this.subscriptionPlansService.hasUsableTokens(agentId);
    if (!usable) {
      throw new HttpException(
        'No active subscription. Please subscribe to a plan.',
        HttpStatus.PAYMENT_REQUIRED, // 402
      );
    }

    const offer = await this.offersRepository.findOne({
      where: { id: data.offerId },
    });
    if (!offer) {
      throw new NotFoundException('Offer not found');
    }
    if (offer.agentId !== agentId) {
      throw new ForbiddenException('Offer does not belong to this agent');
    }

    const reference = `TXN${Date.now()}${Math.floor(Math.random() * 1000)}`;
    const transaction = this.transactionsRepository.create({
      agentId,
      reference,
      type: TransactionType.QUICK_DIAL,
      status: TransactionStatus.SUCCESS,
      amount: offer.price,
      offerId: offer.id,
      offerName: offer.name,
      customerPhone: data.customerPhone,
      ussdCode: offer.ussdCode,
    });
    const saved = await this.transactionsRepository.save(transaction);

    // Plan debit (Hybrid checkIfShouldUpdateTokens).
    const debited = await this.subscriptionPlansService.decrementLimitedToken(
      agentId,
    );
    if (debited) {
      const wallet = await this.walletsRepository.findOne({
        where: { agentId },
      });
      if (wallet) {
        wallet.lifetimeTokensConsumed += 1;
        await this.walletsRepository.save(wallet);
      }
    }

    return saved;
  }

  /**
   * W2.F auto-renewals: list SCHEDULED transactions (D-W2-5). Ordered by the
   * scheduled time stored in rescheduleInfo.scheduledFor.
   */
  async findScheduled(agentId: string): Promise<Transaction[]> {
    const rows = await this.transactionsRepository.find({
      where: { agentId, status: TransactionStatus.SCHEDULED },
    });
    return rows.sort((a, b) => {
      const aT = a.rescheduleInfo?.scheduledFor ?? '';
      const bT = b.rescheduleInfo?.scheduledFor ?? '';
      return aT < bT ? -1 : aT > bT ? 1 : 0;
    });
  }

  /**
   * W2.F: schedule an offer for a customer (a "Reschedule Offer"). Persists a
   * SCHEDULED transaction with rescheduleInfo. W2 does NOT execute it — W3's
   * pipeline picks up SCHEDULED rows whose scheduledFor <= now.
   */
  async schedule(
    agentId: string,
    data: {
      offerId: string;
      customerPhone: string;
      scheduledFor: string;
      isRecurring: boolean;
      daysToRecur?: number;
    },
  ): Promise<Transaction> {
    const offer = await this.offersRepository.findOne({
      where: { id: data.offerId },
    });
    if (!offer) {
      throw new NotFoundException('Offer not found');
    }
    if (offer.agentId !== agentId) {
      throw new ForbiddenException('Offer does not belong to this agent');
    }

    const reference = `SCH${Date.now()}${Math.floor(Math.random() * 1000)}`;
    const transaction = this.transactionsRepository.create({
      agentId,
      reference,
      type: TransactionType.SUBSCRIPTION_RENEWAL,
      status: TransactionStatus.SCHEDULED,
      amount: offer.price,
      offerId: offer.id,
      offerName: offer.name,
      customerPhone: data.customerPhone,
      ussdCode: offer.ussdCode,
      rescheduleInfo: {
        scheduledFor: data.scheduledFor,
        isRecurring: data.isRecurring,
        daysRemaining: data.isRecurring ? data.daysToRecur ?? null : null,
      },
    });
    return this.transactionsRepository.save(transaction);
  }

  async cancelScheduled(agentId: string, id: string): Promise<void> {
    const txn = await this.transactionsRepository.findOne({ where: { id } });
    if (!txn || txn.agentId !== agentId) {
      throw new NotFoundException('Scheduled transaction not found');
    }
    if (txn.status !== TransactionStatus.SCHEDULED) {
      throw new ForbiddenException('Transaction is not scheduled');
    }
    await this.transactionsRepository.remove(txn);
  }

  async createTransaction(
    agentId: string,
    data: {
      type: TransactionType;
      amount: number;
      recipientPhone?: string;
      description?: string;
      metadata?: Record<string, any>;
    },
  ): Promise<Transaction> {
    const agent = await this.agentsRepository.findOne({
      where: { id: agentId },
    });
    if (!agent) {
      throw new NotFoundException('Agent not found');
    }
    const reference = `TXN${Date.now()}${Math.floor(Math.random() * 1000)}`;
    const transaction = this.transactionsRepository.create({
      agent,
      reference,
      type: data.type,
      amount: data.amount,
      recipientPhone: data.recipientPhone,
      description: data.description,
      metadata: data.metadata,
      status: TransactionStatus.SCHEDULED,
    });
    return this.transactionsRepository.save(transaction);
  }

  async updateTransactionStatus(
    transactionId: string,
    status: TransactionStatus,
    errorMessage?: string,
    safaricomRef?: string,
  ): Promise<Transaction> {
    const transaction = await this.transactionsRepository.findOne({
      where: { id: transactionId },
      relations: ['agent'],
    });
    if (!transaction) {
      throw new NotFoundException('Transaction not found');
    }
    transaction.status = status;
    if (errorMessage) {
      transaction.errorMessage = errorMessage;
    }
    if (safaricomRef) {
      transaction.safaricomRef = safaricomRef;
    }
    return this.transactionsRepository.save(transaction);
  }

  async getTransactionDetails(transactionId: string): Promise<Transaction> {
    const transaction = await this.transactionsRepository.findOne({
      where: { id: transactionId },
      relations: ['agent'],
    });
    if (!transaction) {
      throw new NotFoundException('Transaction not found');
    }
    return transaction;
  }

  async getTransactionSummary(agentId: string, period: string): Promise<any> {
    const now = new Date();
    let startDate: Date;
    switch (period) {
      case 'today':
        startDate = new Date(now.setHours(0, 0, 0, 0));
        break;
      case 'week':
        startDate = new Date(now.setDate(now.getDate() - 7));
        break;
      case 'month':
        startDate = new Date(now.setMonth(now.getMonth() - 1));
        break;
      default:
        startDate = new Date(0);
    }
    const transactions = await this.transactionsRepository.find({
      where: { agent: { id: agentId }, createdAt: MoreThan(startDate) },
    });
    const total = transactions.length;
    const successful = transactions.filter(
      (t) => t.status === TransactionStatus.SUCCESS,
    ).length;
    const failed = transactions.filter(
      (t) => t.status === TransactionStatus.FAILED,
    ).length;
    const pending = transactions.filter(
      (t) =>
        t.status === TransactionStatus.PROCESSING ||
        t.status === TransactionStatus.SCHEDULED,
    ).length;
    const totalAmount = transactions
      .filter((t) => t.status === TransactionStatus.SUCCESS)
      .reduce((sum, t) => sum + Number(t.amount), 0);
    return { total, successful, failed, pending, totalAmount, period };
  }

  async recordSmsPayment(data: any, agentId: string) {
    const existing = await this.transactionsRepository.findOne({
      where: { mpesaTransactionId: data.mpesaTransactionId, agentId },
    });
    if (existing) {
      throw new ConflictException('Payment already processed');
    }
    const tx = this.transactionsRepository.create({
      ...data,
      agentId,
      status: TransactionStatus.SUCCESS,
      reference: data.mpesaTransactionId,
    });
    return this.transactionsRepository.save(tx);
  }
}