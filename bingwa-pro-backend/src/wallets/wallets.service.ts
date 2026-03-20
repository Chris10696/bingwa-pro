// bingwa-pro-backend/src/wallets/wallets.service.ts
import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Cron, CronExpression } from '@nestjs/schedule';
import { Wallet } from './entities/wallet.entity';
import { TokenPackage } from './entities/token-package.entity';
import { TokenTransaction, TokenTransactionType, TokenTransactionStatus } from './entities/token-transaction.entity';
import { Agent } from '../agents/entities/agent.entity';

@Injectable()
export class WalletsService {
  private readonly logger = new Logger(WalletsService.name); // ADD THIS for logging

  constructor(
    @InjectRepository(Wallet)
    private walletsRepository: Repository<Wallet>,
    @InjectRepository(Agent)
    private agentsRepository: Repository<Agent>,
    @InjectRepository(TokenPackage)
    private tokenPackagesRepository: Repository<TokenPackage>,
    @InjectRepository(TokenTransaction)
    private tokenTransactionsRepository: Repository<TokenTransaction>,
    private dataSource: DataSource,
  ) {}

  async getWalletByAgentId(agentId: string): Promise<Wallet> {
    const wallet = await this.walletsRepository.findOne({
      where: { agent: { id: agentId } },
      relations: ['agent'],
    });

    if (!wallet) {
      // Create wallet if it doesn't exist
      return this.createWalletForAgent(agentId);
    }

    return wallet;
  }

  async getBalance(agentId: string): Promise<{ 
    availableBalance: number; 
    tokenBalanceInt: number;
    pendingBalance: number;
    totalDeposits: number;
    totalWithdrawals: number;
    lifetimeTokens: number;
    tokensConsumed: number;
  }> {
    const wallet = await this.getWalletByAgentId(agentId);
    
    return {
      availableBalance: wallet.tokenBalance,
      tokenBalanceInt: wallet.tokenBalanceInt,
      pendingBalance: 0,
      totalDeposits: wallet.lifetimeTokens,
      totalWithdrawals: wallet.tokensConsumed,
      lifetimeTokens: wallet.lifetimeTokens,
      tokensConsumed: wallet.tokensConsumed,
    };
  }

  /**
   * Purchase tokens using a token package
   */
  async purchaseTokens(
    agentId: string, 
    packageId: string, 
    paymentReference: string,
    metadata?: Record<string, any>
  ): Promise<{ wallet: Wallet; transaction: TokenTransaction }> {
    // Use transaction to ensure data consistency
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // Get the token package
      const tokenPackage = await this.tokenPackagesRepository.findOne({
        where: { id: packageId, isActive: true },
      });

      if (!tokenPackage) {
        throw new NotFoundException('Token package not found or inactive');
      }

      // Get wallet
      let wallet = await this.walletsRepository.findOne({
        where: { agent: { id: agentId } },
        relations: ['agent'],
      });

      if (!wallet) {
        wallet = await this.createWalletForAgent(agentId);
      }

      // Calculate expiry date
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + tokenPackage.validityDays);

      // Create token transaction
      const transaction = this.tokenTransactionsRepository.create({
        agentId,
        type: TokenTransactionType.PURCHASE,
        status: TokenTransactionStatus.COMPLETED,
        amount: tokenPackage.tokens,
        balanceBefore: wallet.tokenBalanceInt,
        balanceAfter: wallet.tokenBalanceInt + tokenPackage.tokens,
        reference: paymentReference,
        packageId: tokenPackage.id,
        expiresAt,
        metadata,
      });

      // Update wallet
      wallet.tokenBalanceInt += tokenPackage.tokens;
      wallet.tokenBalance = wallet.tokenBalanceInt; // Sync decimal field
      wallet.lifetimeTokens += tokenPackage.tokens;
      wallet.lastTopupAt = new Date();

      // Save everything
      await queryRunner.manager.save(wallet);
      await queryRunner.manager.save(transaction);

      await queryRunner.commitTransaction();

      return { wallet, transaction };
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  /**
   * Consume tokens for a transaction (USSD execution)
   */
  async consumeTokens(
    agentId: string,
    amount: number,
    transactionId: string,
    customerPhone: string,
    productId?: string,
    metadata?: Record<string, any>
  ): Promise<{ wallet: Wallet; transaction: TokenTransaction }> {
    if (amount <= 0) {
      throw new BadRequestException('Token amount must be greater than zero');
    }

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const wallet = await this.walletsRepository.findOne({
        where: { agent: { id: agentId } },
      });

      if (!wallet) {
        throw new NotFoundException('Wallet not found');
      }

      if (wallet.tokenBalanceInt < amount) {
        throw new BadRequestException('Insufficient token balance');
      }

      // Create token transaction
      const tokenTransaction = this.tokenTransactionsRepository.create({
        agentId,
        type: TokenTransactionType.CONSUMPTION,
        status: TokenTransactionStatus.COMPLETED,
        amount: -amount, // Negative for consumption
        balanceBefore: wallet.tokenBalanceInt,
        balanceAfter: wallet.tokenBalanceInt - amount,
        reference: `TXN-${transactionId}`,
        transactionId,
        customerPhone,
        metadata: {
          ...metadata,
          productId,
        },
      });

      // Update wallet
      wallet.tokenBalanceInt -= amount;
      wallet.tokenBalance = wallet.tokenBalanceInt; // Sync decimal field
      wallet.tokensConsumed += amount;
      wallet.lastConsumptionAt = new Date();

      await queryRunner.manager.save(wallet);
      await queryRunner.manager.save(tokenTransaction);

      await queryRunner.commitTransaction();

      return { wallet, transaction: tokenTransaction };
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  /**
   * Get all available token packages
   */
  async getTokenPackages(includeInactive: boolean = false): Promise<TokenPackage[]> {
    const where = includeInactive ? {} : { isActive: true };
    return this.tokenPackagesRepository.find({
      where,
      order: { sortOrder: 'ASC' },
    });
  }

  /**
   * Get token transaction history for an agent
   */
  async getTokenTransactions(
    agentId: string,
    limit: number = 20,
    offset: number = 0,
  ): Promise<{ transactions: TokenTransaction[]; total: number }> {
    const [transactions, total] = await this.tokenTransactionsRepository.findAndCount({
      where: { agentId },
      order: { createdAt: 'DESC' },
      take: limit,
      skip: offset,
    });

    return { transactions, total };
  }

  /**
   * Get wallet with full transaction history
   */
  async getWalletWithHistory(agentId: string): Promise<{
    wallet: Wallet;
    recentTokenTransactions: TokenTransaction[];
    recentMpesaTransactions?: any[];
  }> {
    const wallet = await this.getWalletByAgentId(agentId);
    
    const tokenTransactions = await this.tokenTransactionsRepository.find({
      where: { agentId },
      order: { createdAt: 'DESC' },
      take: 10,
    });

    return {
      wallet,
      recentTokenTransactions: tokenTransactions,
    };
  }

  async creditWallet(agentId: string, amount: number, description: string): Promise<Wallet> {
    if (amount <= 0) {
      throw new BadRequestException('Amount must be greater than zero');
    }

    const wallet = await this.getWalletByAgentId(agentId);
    
    // Update both fields
    wallet.tokenBalance = Number(wallet.tokenBalance) + amount;
    wallet.tokenBalanceInt = wallet.tokenBalanceInt + Math.floor(amount);
    wallet.lifetimeTokens += Math.floor(amount);
    
    return this.walletsRepository.save(wallet);
  }

  async debitWallet(agentId: string, amount: number, description: string): Promise<Wallet> {
    if (amount <= 0) {
      throw new BadRequestException('Amount must be greater than zero');
    }

    const wallet = await this.getWalletByAgentId(agentId);
    
    const intAmount = Math.floor(amount);
    if (wallet.tokenBalanceInt < intAmount) {
      throw new BadRequestException('Insufficient balance');
    }

    // Update both fields
    wallet.tokenBalance = Number(wallet.tokenBalance) - amount;
    wallet.tokenBalanceInt -= intAmount;
    wallet.tokensConsumed += intAmount;
    
    return this.walletsRepository.save(wallet);
  }

  async createWalletForAgent(agentId: string): Promise<Wallet> {
    const agent = await this.agentsRepository.findOne({ where: { id: agentId } });
    if (!agent) {
      throw new NotFoundException('Agent not found');
    }

    const existingWallet = await this.walletsRepository.findOne({
      where: { agent: { id: agentId } },
    });

    if (existingWallet) {
      return existingWallet;
    }

    const wallet = this.walletsRepository.create({
      agent,
      tokenBalance: 0,
      tokenBalanceInt: 0,
      lifetimeTokens: 0,
      tokensConsumed: 0,
    });

    return this.walletsRepository.save(wallet);
  }

  async getTransactions(agentId: string, limit: number = 20, offset: number = 0): Promise<any[]> {
    // Now returns token transactions
    const { transactions } = await this.getTokenTransactions(agentId, limit, offset);
    return transactions;
  }

  /**
   * Check and process expired tokens
   */
  async processExpiredTokens(): Promise<number> {
    const now = new Date();
    
    const expiredTransactions = await this.tokenTransactionsRepository
      .createQueryBuilder('transaction')
      .where('transaction.expiresAt < :now', { now })
      .andWhere('transaction.status = :status', { status: TokenTransactionStatus.COMPLETED })
      .andWhere('transaction.type = :type', { type: TokenTransactionType.PURCHASE })
      .getMany();

    let totalExpired = 0;

    for (const transaction of expiredTransactions) {
      const wallet = await this.walletsRepository.findOne({
        where: { agentId: transaction.agentId },
      });

      if (wallet) {
        // Calculate expired tokens (remaining from this batch)
        // This is simplified - in production you'd need to track per-batch balances
        const expiredAmount = transaction.amount; // Simplified assumption
        
        if (expiredAmount > 0) {
          // Create expiry transaction
          await this.tokenTransactionsRepository.save({
            agentId: transaction.agentId,
            type: TokenTransactionType.EXPIRY,
            status: TokenTransactionStatus.COMPLETED,
            amount: -expiredAmount,
            balanceBefore: wallet.tokenBalanceInt,
            balanceAfter: wallet.tokenBalanceInt - expiredAmount,
            reference: `EXP-${transaction.id}`,
            metadata: { originalTransactionId: transaction.id },
          });

          // Update wallet
          wallet.tokenBalanceInt -= expiredAmount;
          wallet.tokenBalance = wallet.tokenBalanceInt;
          await this.walletsRepository.save(wallet);

          totalExpired += expiredAmount;
        }
      }

      // Mark original transaction as expired (or keep for history)
      transaction.status = TokenTransactionStatus.COMPLETED; // Keep as completed but with expiry record
      await this.tokenTransactionsRepository.save(transaction);
    }

    return totalExpired;
  }

  // ===== CRON JOB FOR TOKEN EXPIRY - ADD THIS AT THE END OF THE CLASS =====
  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async handleTokenExpiry() {
    this.logger.log('Running token expiry check...');
    try {
      const expired = await this.processExpiredTokens();
      this.logger.log(`Processed ${expired} expired tokens`);
    } catch (error) {
      this.logger.error('Failed to process token expiry', error.stack);
    }
  }
  // =========================================================================
}