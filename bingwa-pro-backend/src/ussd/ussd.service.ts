import { Injectable, Logger, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { HttpService } from '@nestjs/axios';
import { UssdRoute, UssdRouteStatus, UssdProcessingMode } from './entities/ussd-route.entity';
import { UssdSession, UssdSessionStatus } from './entities/ussd-session.entity';
import { UssdAnomaly, UssdAnomalySeverity, UssdAnomalyStatus } from './entities/ussd-anomaly.entity';
import { ExecuteUssdDto, UssdAction } from './dto/execute-ussd.dto';
import { UssdResponseDto } from './dto/ussd-response.dto';
import { UssdHealthDto, UssdHealthStatus } from './dto/ussd-health.dto';
import { Transaction } from '../transactions/entities/transaction.entity';

@Injectable()
export class UssdService {
  private readonly logger = new Logger(UssdService.name);
  private readonly USSD_GATEWAY_URL = process.env.USSD_GATEWAY_URL || 'http://localhost:9090/ussd';

  constructor(
    @InjectRepository(UssdRoute)
    private ussdRouteRepository: Repository<UssdRoute>,
    @InjectRepository(UssdSession)
    private ussdSessionRepository: Repository<UssdSession>,
    @InjectRepository(UssdAnomaly)
    private ussdAnomalyRepository: Repository<UssdAnomaly>,
    @InjectRepository(Transaction)
    private transactionRepository: Repository<Transaction>,
    private httpService: HttpService,
  ) {}

  // ========== USSD EXECUTION ==========

  async executeUssd(executeDto: ExecuteUssdDto): Promise<UssdResponseDto> {
    try {
      const { action, routeCode, agentPhone, customerPhone, sessionId, input, amount, productCode, processingMode, agentId, transactionId } = executeDto;

      // Get the USSD route
      const route = await this.ussdRouteRepository.findOne({
        where: { code: routeCode, isActive: true },
      }) as UssdRoute | null;

      if (!route) {
        throw new NotFoundException(`USSD route ${routeCode} not found or inactive`);
      }

      // Check route health
      if (route.status === UssdRouteStatus.FAILED) {
        throw new BadRequestException('USSD route is currently unavailable');
      }

      let session: UssdSession | null = null;

      if (action === UssdAction.INITIATE) {
        // Create new session
        const newSessionId = `ussd_${Date.now()}_${Math.random().toString(36).substring(7)}`;
        
        session = this.ussdSessionRepository.create({
          sessionId: newSessionId,
          agentId: agentId,
          transactionId: transactionId,
          routeId: route.id,
          phoneNumber: customerPhone,
          msisdn: agentPhone,
          status: UssdSessionStatus.INITIATED,
          currentStep: 1,
          requestHistory: [],
          rawResponses: [],
        });

        await this.ussdSessionRepository.save(session);
      } else if (action === UssdAction.RESPOND) {
        // Get existing session
        if (!sessionId) {
          throw new BadRequestException('Session ID required for RESPOND action');
        }

        session = await this.ussdSessionRepository.findOne({
          where: { sessionId },
          relations: ['route'],
        }) as UssdSession | null;

        if (!session) {
          throw new NotFoundException('USSD session not found');
        }

        if (session.status === UssdSessionStatus.COMPLETED || session.status === UssdSessionStatus.FAILED) {
          throw new BadRequestException(`Session already ${session.status}`);
        }
      } else if (action === UssdAction.CANCEL) {
        if (!sessionId) {
          throw new BadRequestException('Session ID required for CANCEL action');
        }

        await this.ussdSessionRepository.update(
          { sessionId },
          { status: UssdSessionStatus.ABORTED }
        );

        return {
          success: true,
          sessionId,
          status: UssdSessionStatus.ABORTED,
          message: 'USSD session cancelled',
          requiresInput: false,
        };
      }

      // Execute the USSD based on processing mode
      const startTime = Date.now();
      
      let ussdResponse;
      try {
        if (processingMode === UssdProcessingMode.ADVANCED || route.processingMode === UssdProcessingMode.ADVANCED) {
          ussdResponse = await this.executeAdvancedUssd(route, session!, input, amount, productCode);
        } else {
          ussdResponse = await this.executeExpressUssd(route, session!, input, amount, productCode);
        }
      } catch (error) {
        // Log failure
        route.failureCount = (route.failureCount || 0) + 1;
        route.successRate = route.successCount + route.failureCount > 0 
          ? (route.successCount / (route.successCount + route.failureCount)) * 100 
          : 100;
        await this.ussdRouteRepository.save(route);

        // Update session if exists
        if (session) {
          session.status = UssdSessionStatus.FAILED;
          session.errorMessage = error.message;
          await this.ussdSessionRepository.save(session);
        }

        throw error;
      }

      const endTime = Date.now();
      const responseTimeMs = endTime - startTime;

      // Update route stats
      route.successCount = (route.successCount || 0) + 1;
      route.successRate = route.successCount + route.failureCount > 0 
        ? (route.successCount / (route.successCount + route.failureCount)) * 100 
        : 100;
      route.avgResponseTimeMs = route.avgResponseTimeMs 
        ? (route.avgResponseTimeMs + responseTimeMs) / 2 
        : responseTimeMs;
      
      if (route.successRate < 90) {
        route.status = UssdRouteStatus.DEGRADED;
      } else {
        route.status = UssdRouteStatus.ACTIVE;
      }
      
      await this.ussdRouteRepository.save(route);

      // Update session if exists
      if (session) {
        session.status = ussdResponse.completed ? UssdSessionStatus.COMPLETED : UssdSessionStatus.IN_PROGRESS;
        session.currentStep = ussdResponse.currentStep || session.currentStep;
        session.extractedData = { ...session.extractedData, ...ussdResponse.extractedData };
        
        if (ussdResponse.completed) {
          session.completedAt = new Date();
        }

        await this.ussdSessionRepository.save(session);

        // Check for anomalies
        await this.detectAnomalies(route, session, ussdResponse);
      }

      return {
        success: true,
        sessionId: session?.sessionId || '',
        status: session?.status || UssdSessionStatus.COMPLETED,
        message: ussdResponse.message,
        requiresInput: ussdResponse.requiresInput || false,
        currentStep: session?.currentStep,
        totalSteps: route.requiredSteps?.length,
        extractedData: session?.extractedData,
        transactionId: session?.transactionId,
        reference: ussdResponse.reference,
        processingMode: route.processingMode,
      };

    } catch (error) {
      this.logger.error(`USSD execution failed: ${error.message}`, error.stack);
      throw error;
    }
  }

  private async executeExpressUssd(route: UssdRoute, session: UssdSession, input?: string, amount?: number, productCode?: string): Promise<any> {
    // Prepare USSD string with parameters
    let ussdString = route.ussdString
      .replace('{amount}', amount?.toString() || '')
      .replace('{phone}', session.phoneNumber)
      .replace('{product}', productCode || '');

    // In a real implementation, this would call an actual USSD gateway
    // For now, we'll simulate a response
    const simulatedResponse = await this.simulateUssdGateway(ussdString, input);

    // Extract data from response
    const extractedData: Record<string, any> = {};
    if (route.responseMapping) {
      for (const mapping of route.responseMapping) {
        const regex = new RegExp(mapping.pattern);
        const match = simulatedResponse.match(regex);
        if (match && match[1]) {
          extractedData[mapping.field] = match[1];
        }
      }
    }

    // Check if transaction was successful
    const success = simulatedResponse.includes('success') || 
                    simulatedResponse.includes('confirmed') ||
                    extractedData.reference;

    return {
      completed: success,
      message: simulatedResponse,
      requiresInput: !success,
      currentStep: 1,
      extractedData,
      reference: extractedData.reference,
    };
  }

  private async executeAdvancedUssd(route: UssdRoute, session: UssdSession, input?: string, amount?: number, productCode?: string): Promise<any> {
    // For advanced mode, we need to handle multi-step USSD flows
    const currentStep = session.currentStep || 1;
    
    // Prepare USSD string based on current step
    let ussdString = route.ussdString;
    
    if (currentStep === 1) {
      ussdString = ussdString
        .replace('{amount}', amount?.toString() || '')
        .replace('{phone}', session.phoneNumber)
        .replace('{product}', productCode || '');
    }

    // Simulate USSD gateway call
    const simulatedResponse = await this.simulateUssdGateway(ussdString, input);

    // Extract data
    const extractedData: Record<string, any> = {};
    if (route.responseMapping) {
      for (const mapping of route.responseMapping) {
        if (mapping.step === currentStep) {
          const regex = new RegExp(mapping.pattern);
          const match = simulatedResponse.match(regex);
          if (match && match[1]) {
            extractedData[mapping.field] = match[1];
          }
        }
      }
    }

    // Determine next step
    const nextStep = currentStep + 1;
    const isCompleted = !route.requiredSteps || nextStep > route.requiredSteps.length;

    return {
      completed: isCompleted,
      message: simulatedResponse,
      requiresInput: !isCompleted,
      currentStep: nextStep,
      extractedData,
      reference: extractedData.reference,
    };
  }

  private async simulateUssdGateway(ussdString: string, input?: string): Promise<string> {
    // This is a simulation - in production, this would call an actual USSD gateway
    await new Promise(resolve => setTimeout(resolve, 1000)); // Simulate network delay

    if (ussdString.includes('*544#')) {
      if (!input) {
        return '1. Buy Data\n2. Check Balance\n3. My Account';
      } else if (input === '1') {
        return 'Select bundle:\n1. 1GB - 200\n2. 3GB - 500\n3. 5GB - 1000';
      } else if (input === '1' || input === '2' || input === '3') {
        return `You have purchased bundle. Reference: REF${Math.floor(Math.random() * 1000000)}`;
      }
    } else if (ussdString.includes('*334#')) {
      if (!input) {
        return `Confirm purchase of KES ${ussdString.match(/\d+/)?.[0] || 'amount'}?`;
      } else if (input === '1') {
        return `Transaction successful. Reference: REF${Math.floor(Math.random() * 1000000)}`;
      }
    }

    return 'USSD simulation response';
  }

  // ========== ANOMALY DETECTION ==========

  private async detectAnomalies(route: UssdRoute, session: UssdSession, response: any): Promise<void> {
    try {
      // Check for expected responses
      if (route.expectedResponses && session.currentStep) {
        const expectedForStep = route.expectedResponses.find(e => e.step === session.currentStep);
        
        if (expectedForStep) {
          const regex = new RegExp(expectedForStep.pattern);
          if (!regex.test(response.message)) {
            // Anomaly detected
            const anomaly = this.ussdAnomalyRepository.create({
              routeId: route.id,
              routeCode: route.code,
              sessionId: session.sessionId,
              transactionId: session.transactionId,
              agentId: session.agentId,
              description: `Unexpected response at step ${session.currentStep}`,
              severity: UssdAnomalySeverity.MEDIUM,
              status: UssdAnomalyStatus.DETECTED,
              expectedResponse: { pattern: expectedForStep.pattern },
              actualResponse: { message: response.message },
              context: {
                step: session.currentStep,
                time: new Date(),
              },
              suggestedAction: 'REVIEW_ROUTE',
            });

            await this.ussdAnomalyRepository.save(anomaly);

            // Update route anomaly count
            route.anomalyCount = (route.anomalyCount || 0) + 1;
            await this.ussdRouteRepository.save(route);

            // If too many anomalies, mark route as degraded
            if (route.anomalyCount > 10) {
              route.status = UssdRouteStatus.DEGRADED;
              await this.ussdRouteRepository.save(route);
            }
          }
        }
      }
    } catch (error) {
      this.logger.error('Anomaly detection failed', error);
    }
  }

  // ========== HEALTH CHECK ==========

  async getHealthStatus(): Promise<UssdHealthDto> {
    try {
      const routes = await this.ussdRouteRepository.find() as UssdRoute[];
      
      const totalChecks = routes.reduce((sum, r) => sum + (r.successCount || 0) + (r.failureCount || 0), 0);
      const failedChecks = routes.reduce((sum, r) => sum + (r.failureCount || 0), 0);
      const successRate = totalChecks > 0 ? ((totalChecks - failedChecks) / totalChecks) * 100 : 100;
      
      const avgResponseTime = routes.length > 0 
        ? routes.reduce((sum, r) => sum + (r.avgResponseTimeMs || 0), 0) / routes.length 
        : 0;

      // Determine overall status
      let overallStatus: UssdHealthStatus = UssdHealthStatus.GREEN;
      let message = 'All systems normal';

      if (failedChecks > totalChecks * 0.1) { // More than 10% failures
        overallStatus = UssdHealthStatus.YELLOW;
        message = 'Degraded performance detected';
      }
      if (failedChecks > totalChecks * 0.3) { // More than 30% failures
        overallStatus = UssdHealthStatus.RED;
        message = 'Critical issues detected';
      }

      const routesHealth = routes.map(route => ({
        routeId: route.id,
        routeCode: route.code,
        status: route.status,
        successRate: route.successRate,
        responseTimeMs: route.avgResponseTimeMs || 0,
      }));

      return {
        status: overallStatus,
        lastChecked: new Date(),
        message,
        responseTimeMs: avgResponseTime,
        successRate,
        totalChecks,
        failedChecks,
        routesHealth,
      };
    } catch (error) {
      this.logger.error('Health check failed', error);
      throw error;
    }
  }

  // ========== ROUTE MANAGEMENT ==========

  /**
   * Create a new USSD route
   */
  async createRoute(createRouteDto: any): Promise<UssdRoute> {
    // Check for existing route
    const existingRoute = await this.ussdRouteRepository.findOne({
      where: { code: createRouteDto.code },
    }) as UssdRoute | null;

    if (existingRoute) {
      throw new BadRequestException(`Route with code ${createRouteDto.code} already exists`);
    }

    // Create and save new route
    const newRoute = this.ussdRouteRepository.create(createRouteDto);
    const savedRoute = await this.ussdRouteRepository.save(newRoute) as UssdRoute;
    return savedRoute;
  }

  /**
   * Find all USSD routes
   */
  async findAllRoutes(): Promise<UssdRoute[]> {
    const routes = await this.ussdRouteRepository.find({
      order: { createdAt: 'DESC' },
    }) as UssdRoute[];
    return routes;
  }

  /**
   * Find a single USSD route by ID
   */
  async findOneRoute(id: string): Promise<UssdRoute> {
    const route = await this.ussdRouteRepository.findOne({
      where: { id },
    }) as UssdRoute | null;

    if (!route) {
      throw new NotFoundException(`Route with ID ${id} not found`);
    }

    return route;
  }

  /**
   * Update an existing USSD route
   */
  async updateRoute(id: string, updateData: any): Promise<UssdRoute> {
    // First find the route
    const existingRoute = await this.findOneRoute(id);
    
    // Update the entity
    Object.assign(existingRoute, updateData);
    
    // Save and return
    const updatedRoute = await this.ussdRouteRepository.save(existingRoute) as UssdRoute;
    return updatedRoute;
  }

  /**
   * Delete a USSD route
   */
  async deleteRoute(id: string): Promise<void> {
    const route = await this.findOneRoute(id);
    await this.ussdRouteRepository.remove(route);
  }

  /**
   * Toggle route active status
   */
  async toggleRouteStatus(id: string): Promise<UssdRoute> {
    const route = await this.findOneRoute(id);
    route.isActive = !route.isActive;
    const updatedRoute = await this.ussdRouteRepository.save(route) as UssdRoute;
    return updatedRoute;
  }

  // ========== ANOMALY MANAGEMENT ==========

  async findAllAnomalies(status?: UssdAnomalyStatus): Promise<UssdAnomaly[]> {
    const where: any = {};
    if (status) where.status = status;

    const anomalies = await this.ussdAnomalyRepository.find({
      where,
      order: { createdAt: 'DESC' },
    }) as UssdAnomaly[];
    return anomalies;
  }

  async resolveAnomaly(id: string, resolution: { notes: string; resolvedBy: string }): Promise<UssdAnomaly> {
    const anomaly = await this.ussdAnomalyRepository.findOne({
      where: { id },
    }) as UssdAnomaly | null;

    if (!anomaly) {
      throw new NotFoundException(`Anomaly with ID ${id} not found`);
    }

    anomaly.status = UssdAnomalyStatus.RESOLVED;
    anomaly.resolutionNotes = resolution.notes;
    anomaly.resolvedBy = resolution.resolvedBy;
    anomaly.resolvedAt = new Date();

    const resolvedAnomaly = await this.ussdAnomalyRepository.save(anomaly) as UssdAnomaly;
    return resolvedAnomaly;
  }

  // ========== SESSION MANAGEMENT ==========

  async getActiveSessions(): Promise<UssdSession[]> {
    const sessions = await this.ussdSessionRepository.find({
      where: { status: UssdSessionStatus.IN_PROGRESS },
      relations: ['route'],
      order: { createdAt: 'DESC' },
    }) as UssdSession[];
    return sessions;
  }

  async getSessionHistory(agentId?: string, limit: number = 50): Promise<UssdSession[]> {
    const where: any = {};
    if (agentId) where.agentId = agentId;

    const sessions = await this.ussdSessionRepository.find({
      where,
      relations: ['route'],
      order: { createdAt: 'DESC' },
      take: limit,
    }) as UssdSession[];
    return sessions;
  }
}