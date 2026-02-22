import { Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Agent } from './entities/agent.entity';
import { Wallet } from '../wallets/entities/wallet.entity';

@Injectable()
export class AgentsService {
  constructor(
    @InjectRepository(Agent)
    private agentsRepository: Repository<Agent>,
    @InjectRepository(Wallet)
    private walletsRepository: Repository<Wallet>,
  ) {}

  async findById(id: string): Promise<Agent> {
    const agent = await this.agentsRepository.findOne({
      where: { id },
      relations: ['wallet'],
    });

    if (!agent) {
      throw new NotFoundException('Agent not found');
    }

    return agent;
  }

  async findByPhoneNumber(phoneNumber: string): Promise<Agent> {
    const agent = await this.agentsRepository.findOne({
      where: { phoneNumber },
      relations: ['wallet'],
    });

    if (!agent) {
      throw new NotFoundException('Agent not found');
    }

    return agent;
  }

  async getProfile(agentId: string): Promise<any> {
    const agent = await this.findById(agentId);

    return {
      id: agent.id,
      fullName: agent.fullName,
      phoneNumber: agent.phoneNumber,
      email: agent.email || '',
      nationalId: agent.nationalId,
      businessName: agent.businessName || '',
      location: agent.location || '',
      status: agent.status,
      tokenBalance: agent.wallet?.tokenBalance || 0,
      registeredAt: agent.createdAt,
      lastLoginAt: agent.updatedAt,
    };
  }

  async getStats(agentId: string): Promise<any> {
    const agent = await this.findById(agentId);

    // In a real implementation, you would query transactions table
    // For now, return mock data
    return {
      totalTransactions: 0,
      successfulTransactions: 0,
      failedTransactions: 0,
      totalCommission: 0,
      todayTransactions: 0,
      todayCommission: 0,
      successRate: 0,
    };
  }

  async updateStatus(agentId: string, status: 'ACTIVE' | 'SUSPENDED'): Promise<Agent> {
    const agent = await this.findById(agentId);
    
    agent.status = status;
    return this.agentsRepository.save(agent);
  }

  async updateProfile(agentId: string, updateData: Partial<Agent>): Promise<Agent> {
    const agent = await this.findById(agentId);
    
    Object.assign(agent, updateData);
    return this.agentsRepository.save(agent);
  }

  async getAllAgents(
    page: number = 1,
    limit: number = 10,
    status?: string,
  ): Promise<{ agents: Agent[]; total: number; page: number; limit: number }> {
    const queryBuilder = this.agentsRepository.createQueryBuilder('agent')
      .leftJoinAndSelect('agent.wallet', 'wallet')
      .skip((page - 1) * limit)
      .take(limit)
      .orderBy('agent.createdAt', 'DESC');

    if (status) {
      queryBuilder.where('agent.status = :status', { status });
    }

    const [agents, total] = await queryBuilder.getManyAndCount();

    return {
      agents,
      total,
      page,
      limit,
    };
  }

  async searchAgents(query: string): Promise<Agent[]> {
    return this.agentsRepository.createQueryBuilder('agent')
      .where('agent.phoneNumber ILIKE :query', { query: `%${query}%` })
      .orWhere('agent.fullName ILIKE :query', { query: `%${query}%` })
      .orWhere('agent.nationalId ILIKE :query', { query: `%${query}%` })
      .leftJoinAndSelect('agent.wallet', 'wallet')
      .limit(10)
      .getMany();
  }
}