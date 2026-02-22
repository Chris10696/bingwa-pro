import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between, LessThan, MoreThan } from 'typeorm';
import { Transaction, TransactionType, TransactionStatus } from './entities/transaction.entity';
import { Agent } from '../agents/entities/agent.entity';
import { Wallet } from '../wallets/entities/wallet.entity';

@Injectable()
export class TransactionsService {
  constructor(
    @InjectRepository(Transaction)
    private transactionsRepository: Repository<Transaction>,
    @InjectRepository(Agent)
    private agentsRepository: Repository<Agent>,
    @InjectRepository(Wallet)
    private walletsRepository: Repository<Wallet>,
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
  ): Promise<{ transactions: Transaction[]; total: number; page: number; pageSize: number }> {
    const queryBuilder = this.transactionsRepository.createQueryBuilder('transaction')
      .leftJoinAndSelect('transaction.agent', 'agent')
      .where('agent.id = :agentId', { agentId })
      .skip((filter.page - 1) * filter.pageSize)
      .take(filter.pageSize);

    // Apply filters
    if (filter.startDate) {
      queryBuilder.andWhere('transaction.createdAt >= :startDate', { startDate: filter.startDate });
    }
    if (filter.endDate) {
      queryBuilder.andWhere('transaction.createdAt <= :endDate', { endDate: filter.endDate });
    }
    if (filter.types && filter.types.length > 0) {
      queryBuilder.andWhere('transaction.type IN (:...types)', { types: filter.types });
    }
    if (filter.statuses && filter.statuses.length > 0) {
      queryBuilder.andWhere('transaction.status IN (:...statuses)', { statuses: filter.statuses });
    }
    if (filter.customerPhone) {
      queryBuilder.andWhere('transaction.recipientPhone LIKE :phone', { phone: `%${filter.customerPhone}%` });
    }
    if (filter.minAmount) {
      queryBuilder.andWhere('transaction.amount >= :minAmount', { minAmount: filter.minAmount });
    }
    if (filter.maxAmount) {
      queryBuilder.andWhere('transaction.amount <= :maxAmount', { maxAmount: filter.maxAmount });
    }
    if (filter.reference) {
      queryBuilder.andWhere('transaction.reference LIKE :ref', { ref: `%${filter.reference}%` });
    }

    // Apply sorting
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
    const agent = await this.agentsRepository.findOne({ where: { id: agentId } });
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
      status: TransactionStatus.INITIATED,
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
        startDate = new Date(0); // Beginning of time
    }

    const transactions = await this.transactionsRepository.find({
      where: {
        agent: { id: agentId },
        createdAt: MoreThan(startDate),
      },
    });

    const total = transactions.length;
    const successful = transactions.filter(t => t.status === TransactionStatus.SUCCESS).length;
    const failed = transactions.filter(t => t.status === TransactionStatus.FAILED).length;
    const pending = transactions.filter(t => t.status === TransactionStatus.PENDING).length;
    const totalAmount = transactions
      .filter(t => t.status === TransactionStatus.SUCCESS)
      .reduce((sum, t) => sum + Number(t.amount), 0);

    return {
      total,
      successful,
      failed,
      pending,
      totalAmount,
      period,
    };
  }
}