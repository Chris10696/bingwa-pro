import { Injectable, ConflictException, BadRequestException, InternalServerErrorException, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Agent } from '../agents/entities/agent.entity';
import { Wallet } from '../wallets/entities/wallet.entity';
import * as bcrypt from 'bcrypt';
import { RegisterAgentDto } from './dto/register-agent.dto';
import { JwtService } from '@nestjs/jwt';
import { LoginAgentDto } from './dto/login-agent.dto';
import { LoginResponseDto } from './dto/login-response.dto';


@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(Agent)
    private agentsRepository: Repository<Agent>,
    @InjectRepository(Wallet)
    private walletsRepository: Repository<Wallet>,
    private dataSource: DataSource,
    private jwtService: JwtService,
  ) {}

  async register(registerDto: RegisterAgentDto): Promise<{ message: string; agentId: string }> {
    // Check if phone number already exists
    const existingAgent = await this.agentsRepository.findOne({
      where: { phoneNumber: registerDto.phoneNumber },
    });
    
    if (existingAgent) {
      throw new ConflictException('Phone number already registered');
    }

    // Check if national ID already exists
    const existingId = await this.agentsRepository.findOne({
      where: { nationalId: registerDto.nationalId },
    });
    
    if (existingId) {
      throw new ConflictException('National ID already registered');
    }

    // Validate PIN confirmation
    if (registerDto.pin !== registerDto.confirmPin) {
      throw new BadRequestException('PIN and confirmation do not match');
    }

    // Hash the PIN
    const saltRounds = 10;
    const pinHash = await bcrypt.hash(registerDto.pin, saltRounds);

    // Use QueryRunner for transaction (atomic operation)
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // Create agent - FIXED: Handle null values properly
      const agent = new Agent();
      agent.fullName = registerDto.fullName;
      agent.phoneNumber = registerDto.phoneNumber;
      agent.nationalId = registerDto.nationalId;
      agent.email = registerDto.email || ''; // Convert null to empty string
      agent.pinHash = pinHash;
      agent.businessName = registerDto.businessName || ''; // Convert null to empty string
      agent.location = registerDto.location || ''; // Convert null to empty string
      agent.deviceId = registerDto.deviceId;
      agent.platform = registerDto.platform;
      agent.status = 'PENDING';

      const savedAgent = await queryRunner.manager.save(agent);

      // Create wallet for agent
      const wallet = new Wallet();
      wallet.agent = savedAgent;
      wallet.tokenBalance = 0;

      await queryRunner.manager.save(wallet);

      // Commit transaction
      await queryRunner.commitTransaction();

      return {
        message: 'Registration successful. Account pending admin approval.',
        agentId: savedAgent.id,
      };
    } catch (error) {
      // Rollback on error
      await queryRunner.rollbackTransaction();
      console.error('Registration error:', error);
      throw new InternalServerErrorException('Registration failed. Please try again.');
    } finally {
      // Release query runner
      await queryRunner.release();
    }
  }

  async login(loginDto: LoginAgentDto): Promise<LoginResponseDto> {
  // Find agent by phone number
  const agent = await this.agentsRepository.findOne({
    where: { phoneNumber: loginDto.phoneNumber },
    relations: ['wallet'],
  });
  
  if (!agent) {
    throw new UnauthorizedException('Invalid phone number or PIN');
  }
  
  // Check if agent is active
  if (agent.status !== 'ACTIVE') {
    throw new UnauthorizedException(`Account is ${agent.status.toLowerCase()}. Please contact support.`);
  }
  
  // Verify PIN
  const isPinValid = await bcrypt.compare(loginDto.pin, agent.pinHash);
  if (!isPinValid) {
    throw new UnauthorizedException('Invalid phone number or PIN');
  }
  
  // Update device ID if changed
  if (agent.deviceId !== loginDto.deviceId) {
    agent.deviceId = loginDto.deviceId;
    await this.agentsRepository.save(agent);
  }
  
  // Generate JWT tokens
  const payload = {
    sub: agent.id,
    phoneNumber: agent.phoneNumber,
    status: agent.status,
  };
  
  const accessToken = this.jwtService.sign(payload, {
    expiresIn: '7d',
  });
  
  const refreshToken = this.jwtService.sign(payload, {
    expiresIn: '30d',
  });
  
  // Calculate expiry
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 7);
  
  return {
    accessToken,
    refreshToken,
    expiresAt,
    agent: {
      id: agent.id,
      fullName: agent.fullName,
      phoneNumber: agent.phoneNumber,
      email: agent.email || '',
      status: agent.status,
      tokenBalance: agent.wallet?.tokenBalance || 0,
    },
    requiresBiometricSetup: false,
  };
}
}
