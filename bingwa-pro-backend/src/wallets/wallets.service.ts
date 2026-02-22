import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Wallet } from './entities/wallet.entity';
import { Agent } from '../agents/entities/agent.entity';

@Injectable()
export class WalletsService {
  constructor(
    @InjectRepository(Wallet)
    private walletsRepository: Repository<Wallet>,
    @InjectRepository(Agent)
    private agentsRepository: Repository<Agent>,
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
    pendingBalance: number;
    totalDeposits: number;
    totalWithdrawals: number;
  }> {
    const wallet = await this.getWalletByAgentId(agentId);
    
    // In a real implementation, you would calculate these from transactions
    return {
      availableBalance: wallet.tokenBalance,
      pendingBalance: 0,
      totalDeposits: wallet.tokenBalance, // Simplified for now
      totalWithdrawals: 0,
    };
  }

  async creditWallet(agentId: string, amount: number, description: string): Promise<Wallet> {
    if (amount <= 0) {
      throw new BadRequestException('Amount must be greater than zero');
    }

    const wallet = await this.getWalletByAgentId(agentId);
    wallet.tokenBalance = Number(wallet.tokenBalance) + amount;
    
    // Here you would also create a transaction record
    // For now, just update the wallet
    
    return this.walletsRepository.save(wallet);
  }

  async debitWallet(agentId: string, amount: number, description: string): Promise<Wallet> {
    if (amount <= 0) {
      throw new BadRequestException('Amount must be greater than zero');
    }

    const wallet = await this.getWalletByAgentId(agentId);
    
    if (wallet.tokenBalance < amount) {
      throw new BadRequestException('Insufficient balance');
    }

    wallet.tokenBalance = Number(wallet.tokenBalance) - amount;
    
    // Here you would also create a transaction record
    // For now, just update the wallet
    
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
    });

    return this.walletsRepository.save(wallet);
  }

  async getTransactions(agentId: string, limit: number = 20, offset: number = 0): Promise<any[]> {
    // For now, return empty array since we haven't implemented transactions yet
    return [];
  }
}