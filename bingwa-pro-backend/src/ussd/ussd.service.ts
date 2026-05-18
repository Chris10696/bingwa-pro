// bingwa-pro-backend/src/ussd/ussd.service.ts
// W1: full module body stubbed. Pre-W1 implementation referenced dropped
// Wallet fields (tokenBalanceInt, tokensConsumed, lifetimeTokens), dropped
// TransactionType values (AIRTIME, TOKEN_PURCHASE), and dropped Transaction
// fields (productName, bundleSize). Primer locks the full USSD pipeline port
// from Hybrid as W3 work (chain-of-responsibility handlers, Success/Failure/
// Timeout chains, etc.). Rather than patch field-by-field (which would paper
// over semantics that W3 will rewrite anyway), the whole module is stubbed.
//
// Each method logs a [W1-STUB] notice and returns a sensible default. The
// only method that returns a real-looking response is getHealthStatus() —
// client's transaction_repository.getUssdHealthStatus() actively calls it
// per Q3 lock, and a green stub keeps the dashboard's health indicator quiet.
//
// TODO(wave-3): rewrite this entire service per Hybrid's USSD pipeline.
import { Injectable, Logger } from '@nestjs/common';
import { ExecuteUssdDto } from './dto/execute-ussd.dto';
import { CreateUssdRouteDto } from './dto/create-ussd-route.dto';
import { UssdAnomalyStatus } from './entities/ussd-anomaly.entity';

@Injectable()
export class UssdService {
  private readonly logger = new Logger(UssdService.name);

  // ─── Africa's Talking callback (public) ──────────────────────────────
  async handleAfricaTalkingCallback(body: any): Promise<string> {
    this.logger.log('[W1-STUB] handleAfricaTalkingCallback — W3 wiring deferred');
    return 'END Service temporarily unavailable. Please try again later.';
  }

  // ─── USSD execution (internal) ───────────────────────────────────────
  async executeUssd(executeDto: ExecuteUssdDto): Promise<any> {
    this.logger.log('[W1-STUB] executeUssd — W3 wiring deferred');
    return {
      success: false,
      message: 'USSD execution stubbed for W1. Full pipeline ships in W3.',
    };
  }

  // ─── Health & monitoring ─────────────────────────────────────────────
  /**
   * Preserved per Q3 lock — client's transaction_repository.getUssdHealthStatus
   * still calls /ussd/health, and the dashboard reads it to decide whether to
   * show the system-alert banner. Returns a "green" stub so the banner stays
   * hidden in W1.
   */
  async getHealthStatus() {
    return {
      status: 'green',
      lastChecked: new Date(),
      message: 'USSD module operational (W1 stub — full pipeline in W3)',
      responseTimeMs: 0,
      successRate: 1.0,
      totalChecks: 0,
      failedChecks: 0,
      details: { stub: true, wave: 'W1' },
    };
  }

  async getActiveSessions(): Promise<any[]> {
    this.logger.log('[W1-STUB] getActiveSessions — W3 wiring deferred');
    return [];
  }

  async getSessionHistory(
    agentId?: string,
    limit: number = 50,
  ): Promise<any[]> {
    this.logger.log(
      `[W1-STUB] getSessionHistory(agentId=${agentId}, limit=${limit}) — W3 wiring deferred`,
    );
    return [];
  }

  // ─── Anomaly management ──────────────────────────────────────────────
  async findAllAnomalies(status?: UssdAnomalyStatus): Promise<any[]> {
    this.logger.log(
      `[W1-STUB] findAllAnomalies(status=${status}) — W3 wiring deferred`,
    );
    return [];
  }

  async resolveAnomaly(
    id: string,
    resolution: { notes: string; resolvedBy: string },
  ): Promise<any> {
    this.logger.log(
      `[W1-STUB] resolveAnomaly(${id}, by=${resolution.resolvedBy}) — W3 wiring deferred`,
    );
    return {
      id,
      resolved: false,
      message: 'Anomaly resolution stubbed for W1',
    };
  }

  // ─── Route management ────────────────────────────────────────────────
  async createRoute(createRouteDto: CreateUssdRouteDto): Promise<any> {
    this.logger.log('[W1-STUB] createRoute — W3 wiring deferred');
    return {
      success: false,
      message: 'Route creation stubbed for W1',
    };
  }

  async findAllRoutes(): Promise<any[]> {
    this.logger.log('[W1-STUB] findAllRoutes — W3 wiring deferred');
    return [];
  }

  async findOneRoute(id: string): Promise<any> {
    this.logger.log(`[W1-STUB] findOneRoute(${id}) — W3 wiring deferred`);
    return null;
  }

  async updateRoute(id: string, updateData: any): Promise<any> {
    this.logger.log(`[W1-STUB] updateRoute(${id}) — W3 wiring deferred`);
    return {
      id,
      updated: false,
      message: 'Route update stubbed for W1',
    };
  }

  async toggleRouteStatus(id: string): Promise<any> {
    this.logger.log(`[W1-STUB] toggleRouteStatus(${id}) — W3 wiring deferred`);
    return {
      id,
      toggled: false,
      message: 'Route toggle stubbed for W1',
    };
  }

  async deleteRoute(id: string): Promise<void> {
    this.logger.log(`[W1-STUB] deleteRoute(${id}) — W3 wiring deferred`);
    return;
  }
}