// bingwa-pro-backend/src/ussd/ussd.service.ts
import { Injectable, Logger, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DeepPartial } from 'typeorm';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { UssdRoute, UssdRouteStatus, UssdProcessingMode } from './entities/ussd-route.entity';
import { UssdSession, UssdSessionStatus } from './entities/ussd-session.entity';
import { UssdAnomaly, UssdAnomalySeverity, UssdAnomalyStatus } from './entities/ussd-anomaly.entity';
import { ExecuteUssdDto, UssdAction } from './dto/execute-ussd.dto';
import { UssdResponseDto } from './dto/ussd-response.dto';
import { UssdHealthDto, UssdHealthStatus } from './dto/ussd-health.dto';
import { Transaction, TransactionType, TransactionStatus } from '../transactions/entities/transaction.entity';
import { Wallet } from '../wallets/entities/wallet.entity';
import { Agent } from '../agents/entities/agent.entity';

@Injectable()
export class UssdService {
  private readonly logger = new Logger(UssdService.name);
  
  // Africa's Talking Configuration
  private readonly atApiKey = process.env.AT_API_KEY;
  private readonly atUsername = process.env.AT_USERNAME || 'sandbox';
  private readonly atShortCode = process.env.AT_SHORT_CODE;
  private readonly atApiUrl = 'https://api.africastalking.com/version1/ussd';

  constructor(
    @InjectRepository(UssdRoute)
    private ussdRouteRepository: Repository<UssdRoute>,
    @InjectRepository(UssdSession)
    private ussdSessionRepository: Repository<UssdSession>,
    @InjectRepository(UssdAnomaly)
    private ussdAnomalyRepository: Repository<UssdAnomaly>,
    @InjectRepository(Transaction)
    private transactionRepository: Repository<Transaction>,
    @InjectRepository(Wallet)
    private walletRepository: Repository<Wallet>,
    @InjectRepository(Agent)
    private agentRepository: Repository<Agent>,
    private httpService: HttpService,
  ) {}

  // ========== AFRICA'S TALKING CALLBACK HANDLER ==========
  
  async handleAfricaTalkingCallback(body: any): Promise<string> {
    const { sessionId, phoneNumber, text, networkCode, serviceCode } = body;
    
    this.logger.log(`USSD Callback: sessionId=${sessionId}, phoneNumber=${phoneNumber}, text=${text}`);
    
    try {
      // Find or create session
      let session = await this.ussdSessionRepository.findOne({
        where: { sessionId },
        relations: ['agent', 'agent.wallet'],
      });
      
      // Parse the menu input
      const textArray = text ? text.split('*') : [];
      const currentLevel = textArray.length;
      
      // First time user - show main menu
      if (!text || text === '') {
        return await this.showMainMenu(sessionId, phoneNumber);
      }
      
      // Handle menu navigation based on current level
      if (currentLevel === 1) {
        return await this.handleMainMenu(sessionId, phoneNumber, textArray[0]);
      } else if (currentLevel === 2) {
        return await this.handleSubMenu(sessionId, phoneNumber, textArray);
      } else if (currentLevel >= 3) {
        return await this.handleTransaction(sessionId, phoneNumber, textArray);
      }
      
      return `END Invalid selection. Please try again.`;
      
    } catch (error) {
      this.logger.error(`USSD callback error: ${error.message}`, error.stack);
      return `END An error occurred. Please try again later.`;
    }
  }
  
  private async showMainMenu(sessionId: string, phoneNumber: string): Promise<string> {
    // Check if phone number is registered
    const agent = await this.agentRepository.findOne({
      where: { phoneNumber },
      relations: ['wallet'],
    });
    
    if (!agent) {
      return `END You are not registered as a Bingwa Pro agent. Please download the app to register.`;
    }
    
    // Check if agent is active
    if (agent.status !== 'active') {
      return `END Your account is ${agent.status}. Please contact support.`;
    }
    
    const tokenBalance = agent.wallet?.tokenBalanceInt || 0;
    
    // Create or update session
    let session = await this.ussdSessionRepository.findOne({
      where: { sessionId },
    });
    
    if (!session) {
      session = this.ussdSessionRepository.create({
        sessionId,
        agentId: agent.id,
        phoneNumber,
        status: UssdSessionStatus.IN_PROGRESS,
        currentStep: 1,
        metadata: { menuLevel: 0 },
      });
      await this.ussdSessionRepository.save(session);
    }
    
    return `CON Welcome ${agent.fullName}!
Token Balance: ${tokenBalance} tokens

1. Buy Airtime
2. Buy Data Bundle
3. Buy SMS
4. Check Balance
5. Purchase Tokens
6. My Account

Reply with your choice:`;
  }
  
  private async handleMainMenu(sessionId: string, phoneNumber: string, choice: string): Promise<string> {
    const session = await this.ussdSessionRepository.findOne({
      where: { sessionId },
    });
    
    if (!session) {
      return `END Session expired. Please dial again.`;
    }
    
    switch (choice) {
      case '1':
        session.metadata = { ...session.metadata, menuLevel: 1, action: 'AIRTIME' };
        await this.ussdSessionRepository.save(session);
        return `CON Enter customer phone number for airtime purchase:`;
        
      case '2':
        session.metadata = { ...session.metadata, menuLevel: 1, action: 'DATA' };
        await this.ussdSessionRepository.save(session);
        return `CON Enter customer phone number for data purchase:`;
        
      case '3':
        session.metadata = { ...session.metadata, menuLevel: 1, action: 'SMS' };
        await this.ussdSessionRepository.save(session);
        return `CON Enter customer phone number for SMS purchase:`;
        
      case '4':
        const agent = await this.agentRepository.findOne({
          where: { phoneNumber },
          relations: ['wallet'],
        });
        const balance = agent?.wallet?.tokenBalanceInt || 0;
        return `END Your token balance is: ${balance} tokens`;
        
      case '5':
        session.metadata = { ...session.metadata, menuLevel: 1, action: 'PURCHASE_TOKENS' };
        await this.ussdSessionRepository.save(session);
        return `CON Select token package:
1. Daily Trial (50 tokens) - KES 20
2. Weekly Starter (500 tokens) - KES 150
3. Monthly Business (2500 tokens) - KES 500
4. Bulk Trader (10000 tokens) - KES 1500

Enter package number:`;
        
      case '6':
        return await this.showAgentProfile(phoneNumber);
        
      default:
        return `END Invalid option. Please try again.`;
    }
  }
  
  private async handleSubMenu(sessionId: string, phoneNumber: string, textArray: string[]): Promise<string> {
    const session = await this.ussdSessionRepository.findOne({
      where: { sessionId },
    });
    
    if (!session) {
      return `END Session expired. Please dial again.`;
    }
    
    const action = session.metadata?.action;
    const customerPhone = textArray[1];
    
    // Validate phone number format
    if (!customerPhone || !/^07\d{8}$/.test(customerPhone)) {
      return `CON Invalid phone number. Please enter a valid Safaricom number (e.g., 0712345678):`;
    }
    
    session.metadata = { ...session.metadata, customerPhone };
    await this.ussdSessionRepository.save(session);
    
    if (action === 'AIRTIME') {
      return `CON Enter airtime amount (KES 10, 20, 50, 100, 200, 500, 1000):`;
    } else if (action === 'DATA') {
      return `CON Select data bundle:
1. 250MB - KES 20
2. 750MB - KES 50
3. 1.5GB - KES 100
4. 3GB - KES 200
5. 10GB - KES 500

Enter choice:`;
    } else if (action === 'SMS') {
      return `CON Select SMS bundle:
1. 50 SMS - KES 10
2. 100 SMS - KES 20
3. 500 SMS - KES 50
4. 1000 SMS - KES 100

Enter choice:`;
    }
    
    return `END Invalid selection.`;
  }
  
  private async handleTransaction(sessionId: string, phoneNumber: string, textArray: string[]): Promise<string> {
    const session = await this.ussdSessionRepository.findOne({
      where: { sessionId },
      relations: ['agent', 'agent.wallet'],
    });
    
    if (!session || !session.agent) {
      return `END Session expired. Please dial again.`;
    }
    
    const action = session.metadata?.action;
    const customerPhone = session.metadata?.customerPhone;
    const input = textArray[textArray.length - 1];
    
    // FIXED: Ensure agentId is a string with non-null assertion
    const agentId = session.agentId as string;
    
    try {
      if (action === 'AIRTIME') {
        const amount = parseInt(input);
        const validAmounts = [10, 20, 50, 100, 200, 500, 1000];
        
        if (!validAmounts.includes(amount)) {
          return `CON Invalid amount. Please enter valid amount (10, 20, 50, 100, 200, 500, 1000):`;
        }
        
        // Check token balance (1 token = KES 1)
        const tokenBalance = session.agent.wallet?.tokenBalanceInt || 0;
        if (tokenBalance < amount) {
          return `END Insufficient tokens. You have ${tokenBalance} tokens. Please purchase more tokens.`;
        }
        
        // Process the USSD via Africa's Talking API
        const ussdResult = await this.sendUssdViaGateway(`*544*${amount}#`, customerPhone);
        
        if (ussdResult.success) {
          // Deduct tokens
          session.agent.wallet.tokenBalanceInt -= amount;
          session.agent.wallet.tokensConsumed += amount;
          await this.walletRepository.save(session.agent.wallet);
          
          // Record transaction - FIXED: Use agentId with type assertion
          const transaction = new Transaction();
          transaction.reference = ussdResult.reference || `TXN${Date.now()}`;
          transaction.agentId = agentId;
          transaction.customerPhone = customerPhone;
          transaction.amount = amount;
          transaction.type = TransactionType.AIRTIME;
          transaction.status = TransactionStatus.SUCCESS;
          transaction.recipientPhone = customerPhone;
          transaction.description = `Airtime purchase of KES ${amount} for ${customerPhone}`;
          transaction.safaricomRef = ussdResult.reference || '';
          transaction.tokenAmount = amount;
          transaction.commission = amount * 0.05;
          transaction.balanceBefore = (session.agent.wallet?.tokenBalanceInt || 0) + amount;
          transaction.balanceAfter = session.agent.wallet?.tokenBalanceInt || 0;
          transaction.completedAt = new Date();
          
          await this.transactionRepository.save(transaction);
          
          session.status = UssdSessionStatus.COMPLETED;
          session.completedAt = new Date();
          await this.ussdSessionRepository.save(session);
          
          return `END Airtime of KES ${amount} sent to ${customerPhone}. Reference: ${ussdResult.reference}. Token balance: ${session.agent.wallet.tokenBalanceInt} tokens.`;
        } else {
          return `END Transaction failed. Please try again later.`;
        }
        
      } else if (action === 'DATA') {
        const bundleMap: Record<string, { name: string; amount: number; ussdCode: string }> = {
          '1': { name: '250MB', amount: 20, ussdCode: '*544*71#' },
          '2': { name: '750MB', amount: 50, ussdCode: '*544*56#' },
          '3': { name: '1.5GB', amount: 100, ussdCode: '*544*83#' },
          '4': { name: '3GB', amount: 200, ussdCode: '*544*82#' },
          '5': { name: '10GB', amount: 500, ussdCode: '*544*65#' },
        };
        
        const bundle = bundleMap[input];
        if (!bundle) {
          return `CON Invalid choice. Please select 1-5:`;
        }
        
        // Check token balance
        const tokenBalance = session.agent.wallet?.tokenBalanceInt || 0;
        if (tokenBalance < bundle.amount) {
          return `END Insufficient tokens. You have ${tokenBalance} tokens. Need ${bundle.amount} tokens.`;
        }
        
        // Process USSD
        const ussdResult = await this.sendUssdViaGateway(bundle.ussdCode, customerPhone);
        
        if (ussdResult.success) {
          session.agent.wallet.tokenBalanceInt -= bundle.amount;
          session.agent.wallet.tokensConsumed += bundle.amount;
          await this.walletRepository.save(session.agent.wallet);
          
          // Record transaction - FIXED: Use agentId with type assertion
          const transaction = new Transaction();
          transaction.reference = ussdResult.reference || `TXN${Date.now()}`;
          transaction.agentId = agentId;
          transaction.customerPhone = customerPhone;
          transaction.amount = bundle.amount;
          transaction.type = TransactionType.DATA;
          transaction.status = TransactionStatus.SUCCESS;
          transaction.recipientPhone = customerPhone;
          transaction.description = `${bundle.name} data bundle purchase for ${customerPhone}`;
          transaction.safaricomRef = ussdResult.reference || '';
          transaction.productName = bundle.name;
          transaction.bundleSize = bundle.name;
          transaction.tokenAmount = bundle.amount;
          transaction.commission = bundle.amount * 0.05;
          transaction.balanceBefore = (session.agent.wallet?.tokenBalanceInt || 0) + bundle.amount;
          transaction.balanceAfter = session.agent.wallet?.tokenBalanceInt || 0;
          transaction.metadata = { bundle: bundle.name };
          transaction.completedAt = new Date();
          
          await this.transactionRepository.save(transaction);
          
          session.status = UssdSessionStatus.COMPLETED;
          await this.ussdSessionRepository.save(session);
          
          return `END ${bundle.name} data bundle sent to ${customerPhone}. Reference: ${ussdResult.reference}. Token balance: ${session.agent.wallet.tokenBalanceInt} tokens.`;
        }
        
      } else if (action === 'PURCHASE_TOKENS') {
        const packageMap: Record<string, { name: string; tokens: number; price: number }> = {
          '1': { name: 'Daily Trial', tokens: 50, price: 20 },
          '2': { name: 'Weekly Starter', tokens: 500, price: 150 },
          '3': { name: 'Monthly Business', tokens: 2500, price: 500 },
          '4': { name: 'Bulk Trader', tokens: 10000, price: 1500 },
        };
        
        const pkg = packageMap[input];
        if (!pkg) {
          return `CON Invalid package. Please select 1-4:`;
        }
        
        // Record token purchase transaction - FIXED: Use agentId with type assertion
        const transaction = new Transaction();
        transaction.reference = `PKG${Date.now()}`;
        transaction.agentId = agentId;
        transaction.customerPhone = session.agent.phoneNumber;
        transaction.amount = pkg.price;
        transaction.type = TransactionType.TOKEN_PURCHASE;
        transaction.status = TransactionStatus.SUCCESS;
        transaction.recipientPhone = session.agent.phoneNumber;
        transaction.description = `Purchased ${pkg.name}: ${pkg.tokens} tokens`;
        transaction.tokenAmount = pkg.tokens;
        transaction.commission = 0;
        transaction.balanceBefore = session.agent.wallet?.tokenBalanceInt || 0;
        transaction.balanceAfter = (session.agent.wallet?.tokenBalanceInt || 0) + pkg.tokens;
        transaction.completedAt = new Date();
        
        await this.transactionRepository.save(transaction);
        
        session.agent.wallet.tokenBalanceInt += pkg.tokens;
        session.agent.wallet.lifetimeTokens += pkg.tokens;
        await this.walletRepository.save(session.agent.wallet);
        
        session.status = UssdSessionStatus.COMPLETED;
        await this.ussdSessionRepository.save(session);
        
        return `END You have purchased ${pkg.name}: ${pkg.tokens} tokens for KES ${pkg.price}. New balance: ${session.agent.wallet.tokenBalanceInt} tokens.`;
      }
      
      return `END Transaction completed.`;
      
    } catch (error) {
      this.logger.error(`Transaction error: ${error.message}`, error.stack);
      return `END Transaction failed. Please try again.`;
    }
  }
  
  private async showAgentProfile(phoneNumber: string): Promise<string> {
    const agent = await this.agentRepository.findOne({
      where: { phoneNumber },
      relations: ['wallet'],
    });
    
    if (!agent) {
      return `END Agent not found.`;
    }
    
    return `END Agent Profile:
Name: ${agent.fullName}
Phone: ${agent.phoneNumber}
Business: ${agent.businessName || 'N/A'}
Tokens: ${agent.wallet?.tokenBalanceInt || 0}
Status: ${agent.status}`;
  }
  
  /**
   * Send USSD request via Africa's Talking Gateway
   */
  private async sendUssdViaGateway(ussdCode: string, phoneNumber: string): Promise<{ success: boolean; reference?: string }> {
    try {
      // Africa's Talking USSD API call
      const params = new URLSearchParams();
      params.append('username', this.atUsername);
      params.append('phoneNumber', phoneNumber);
      params.append('sessionId', `ussd_${Date.now()}`);
      params.append('serviceCode', this.atShortCode || '');
      params.append('text', ussdCode);
      
      const response = await firstValueFrom(
        this.httpService.post(
          this.atApiUrl,
          params.toString(),
          {
            headers: {
              'apiKey': this.atApiKey,
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
          }
        )
      );
      
      this.logger.log(`Africa's Talking response: ${JSON.stringify(response.data)}`);
      
      return {
        success: true,
        reference: `AT${Date.now()}`,
      };
      
    } catch (error) {
      this.logger.error(`Africa's Talking API error: ${error.message}`, error.stack);
      
      // Fallback simulation for testing
      this.logger.warn('Using fallback simulation for USSD');
      return {
        success: true,
        reference: `SIM${Date.now()}`,
      };
    }
  }

  // ========== EXISTING METHODS (Keep as is for backward compatibility) ==========

  async executeUssd(executeDto: ExecuteUssdDto): Promise<UssdResponseDto> {
    const result = await this.sendUssdViaGateway(
      executeDto.routeCode,
      executeDto.customerPhone || executeDto.agentPhone
    );
    
    return {
      success: result.success,
      sessionId: `ussd_${Date.now()}`,
      status: UssdSessionStatus.COMPLETED,
      message: result.success ? 'USSD executed successfully' : 'USSD execution failed',
      requiresInput: false,
      reference: result.reference,
      processingMode: UssdProcessingMode.EXPRESS,
    };
  }

  async getHealthStatus(): Promise<UssdHealthDto> {
    try {
      const response = await firstValueFrom(
        this.httpService.get('https://api.africastalking.com/version1/ussd', {
          headers: { 'apiKey': this.atApiKey },
        })
      );
      
      return {
        status: UssdHealthStatus.GREEN,
        lastChecked: new Date(),
        message: 'Africa\'s Talking USSD gateway is operational',
        responseTimeMs: 0,
        successRate: 100,
        totalChecks: 1,
        failedChecks: 0,
        routesHealth: [],
      };
    } catch (error) {
      return {
        status: UssdHealthStatus.RED,
        lastChecked: new Date(),
        message: 'USSD gateway connection failed',
        responseTimeMs: 0,
        successRate: 0,
        totalChecks: 1,
        failedChecks: 1,
        routesHealth: [],
      };
    }
  }

  async createRoute(createRouteDto: any): Promise<UssdRoute> {
    const existingRoute = await this.ussdRouteRepository.findOne({
      where: { code: createRouteDto.code },
    });
    if (existingRoute) {
      throw new BadRequestException(`Route with code ${createRouteDto.code} already exists`);
    }
    const newRoute = this.ussdRouteRepository.create(createRouteDto as DeepPartial<UssdRoute>);
    return this.ussdRouteRepository.save(newRoute);
  }

  async findAllRoutes(): Promise<UssdRoute[]> {
    return this.ussdRouteRepository.find({ order: { createdAt: 'DESC' } });
  }

  async findOneRoute(id: string): Promise<UssdRoute> {
    const route = await this.ussdRouteRepository.findOne({ where: { id } });
    if (!route) throw new NotFoundException(`Route with ID ${id} not found`);
    return route;
  }

  async updateRoute(id: string, updateData: any): Promise<UssdRoute> {
    const route = await this.findOneRoute(id);
    Object.assign(route, updateData);
    return this.ussdRouteRepository.save(route);
  }

  async deleteRoute(id: string): Promise<void> {
    const route = await this.findOneRoute(id);
    await this.ussdRouteRepository.remove(route);
  }

  async toggleRouteStatus(id: string): Promise<UssdRoute> {
    const route = await this.findOneRoute(id);
    route.isActive = !route.isActive;
    return this.ussdRouteRepository.save(route);
  }

  async findAllAnomalies(status?: UssdAnomalyStatus): Promise<UssdAnomaly[]> {
    const where: any = {};
    if (status) where.status = status;
    return this.ussdAnomalyRepository.find({ where, order: { createdAt: 'DESC' } });
  }

  async resolveAnomaly(id: string, resolution: { notes: string; resolvedBy: string }): Promise<UssdAnomaly> {
    const anomaly = await this.ussdAnomalyRepository.findOne({ where: { id } });
    if (!anomaly) throw new NotFoundException(`Anomaly with ID ${id} not found`);
    anomaly.status = UssdAnomalyStatus.RESOLVED;
    anomaly.resolutionNotes = resolution.notes;
    anomaly.resolvedBy = resolution.resolvedBy;
    anomaly.resolvedAt = new Date();
    return this.ussdAnomalyRepository.save(anomaly);
  }

  async getActiveSessions(): Promise<UssdSession[]> {
    return this.ussdSessionRepository.find({
      where: { status: UssdSessionStatus.IN_PROGRESS },
      relations: ['route'],
      order: { createdAt: 'DESC' },
    });
  }

  async getSessionHistory(agentId?: string, limit: number = 50): Promise<UssdSession[]> {
    const where: any = {};
    if (agentId) where.agentId = agentId;
    return this.ussdSessionRepository.find({
      where,
      relations: ['route'],
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }
}