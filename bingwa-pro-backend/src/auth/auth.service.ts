// bingwa-pro-backend/src/auth/auth.service.ts
// W1 ripple edit:
//   register(): wallet creation no longer sets token-balance fields (they no
//     longer exist on the entity). Sets only processingMode='express'.
//   login(): response's agent block no longer includes tokenBalance. Agents
//     read balance from /wallet/balance instead.
import {
  Injectable,
  ConflictException,
  BadRequestException,
  InternalServerErrorException,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Agent, AgentStatus } from '../agents/entities/agent.entity';
import { Wallet, ProcessingMode } from '../wallets/entities/wallet.entity';
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

  async register(
    registerDto: RegisterAgentDto,
  ): Promise<{ message: string; agentId: string }> {
    const existingAgent = await this.agentsRepository.findOne({
      where: { phoneNumber: registerDto.phoneNumber },
    });
    if (existingAgent) {
      throw new ConflictException('Phone number already registered');
    }

    const existingId = await this.agentsRepository.findOne({
      where: { nationalId: registerDto.nationalId },
    });
    if (existingId) {
      throw new ConflictException('National ID already registered');
    }

    if (registerDto.pin !== registerDto.confirmPin) {
      throw new BadRequestException('PIN and confirmation do not match');
    }

    const saltRounds = 10;
    const hashedPin = await bcrypt.hash(registerDto.pin, saltRounds);

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const agent = new Agent();
      agent.fullName = registerDto.fullName;
      agent.phoneNumber = registerDto.phoneNumber;
      agent.nationalId = registerDto.nationalId;
      agent.email = registerDto.email || ' ';
      agent.pinHash = hashedPin;
      agent.businessName = registerDto.businessName || ' ';
      agent.location = registerDto.location || ' ';
      agent.status = AgentStatus.ACTIVE;
      agent.deviceId = registerDto.deviceId;
      agent.platform = registerDto.platform || 'android';
      const savedAgent = await queryRunner.manager.save(agent);

      // W1: wallet creation no longer initializes token fields. Only
      // processingMode is set (defaults to EXPRESS but written explicitly
      // for clarity).
      const wallet = new Wallet();
      wallet.agent = savedAgent;
      wallet.agentId = savedAgent.id;
      wallet.processingMode = ProcessingMode.EXPRESS;
      await queryRunner.manager.save(wallet);

      await queryRunner.commitTransaction();
      return {
        message: 'Registration successful. Account pending admin approval.',
        agentId: savedAgent.id,
      };
    } catch (error) {
      await queryRunner.rollbackTransaction();
      console.error('Registration error:', error);
      throw new InternalServerErrorException(
        'Registration failed. Please try again.',
      );
    } finally {
      await queryRunner.release();
    }
  }

  async login(loginDto: LoginAgentDto): Promise<LoginResponseDto> {
    const agent = await this.agentsRepository.findOne({
      where: { phoneNumber: loginDto.phoneNumber },
    });
    if (!agent) {
      throw new UnauthorizedException('Invalid phone number or PIN');
    }

    if (agent.status !== AgentStatus.ACTIVE) {
      throw new UnauthorizedException(
        `Account is ${agent.status}. Please contact support.`,
      );
    }

    const isPinValid = await bcrypt.compare(loginDto.pin, agent.pinHash);
    if (!isPinValid) {
      throw new UnauthorizedException('Invalid phone number or PIN');
    }

    if (agent.deviceId !== loginDto.deviceId) {
      agent.deviceId = loginDto.deviceId;
      await this.agentsRepository.save(agent);
    }

    const payload = {
      sub: agent.id,
      phoneNumber: agent.phoneNumber,
      status: agent.status,
    };

    const accessToken = this.jwtService.sign(payload, { expiresIn: '7d' });
    const refreshToken = this.jwtService.sign(payload, { expiresIn: '30d' });

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    // W1: agent block no longer includes tokenBalance. Clients call
    // /wallet/balance for balance state (now plan-based).
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
      },
      requiresBiometricSetup: false,
    };
  }
}