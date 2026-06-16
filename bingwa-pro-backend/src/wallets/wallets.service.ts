// bingwa-pro-backend/src/wallets/wallets.service.ts
// W2.B: purchaseSubscription now initiates a real STK push and links the
// SubscriptionPurchase to the M-Pesa transaction via paymentReference ==
// CheckoutRequestID. It records the purchase as PENDING; the plan is granted
// later by MpesaService's callback/simulate grant path (NOT here — single
// grant path). confirmPayment is now real. Added setProcessingMode (Q-W2-21).
import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Wallet, ProcessingMode } from './entities/wallet.entity';
import { Agent } from '../agents/entities/agent.entity';
import { SubscriptionPlansService } from '../subscriptions/subscription-plans.service';
import { SubscriptionPurchasesService } from '../subscriptions/subscription-purchases.service';
import { SubscriptionPackagesService } from '../subscriptions/subscription-packages.service';
import { SubscriptionPurchaseStatus } from '../subscriptions/entities/subscription-purchase.entity';
import { MpesaService } from '../mpesa/mpesa.service';

@Injectable()
export class WalletsService {
  private readonly logger = new Logger(WalletsService.name);

  constructor(
    @InjectRepository(Wallet)
    private walletsRepository: Repository<Wallet>,
    @InjectRepository(Agent)
    private agentsRepository: Repository<Agent>,
    private subscriptionPlansService: SubscriptionPlansService,
    private subscriptionPurchasesService: SubscriptionPurchasesService,
    private subscriptionPackagesService: SubscriptionPackagesService,
    private mpesaService: MpesaService,
  ) {}

  async getWalletByAgentId(agentId: string): Promise<Wallet> {
    const wallet = await this.walletsRepository.findOne({
      where: { agent: { id: agentId } },
      relations: ['agent'],
    });
    if (!wallet) {
      return this.createWalletForAgent(agentId);
    }
    return wallet;
  }

  async createWalletForAgent(agentId: string): Promise<Wallet> {
    const agent = await this.agentsRepository.findOne({
      where: { id: agentId },
    });
    if (!agent) {
      throw new NotFoundException(`Agent ${agentId} not found`);
    }
    const wallet = this.walletsRepository.create({ agent, agentId });
    return this.walletsRepository.save(wallet);
  }

  async getBalance(agentId: string) {
    const wallet = await this.getWalletByAgentId(agentId);
    const plans =
      await this.subscriptionPlansService.findActivePlansForAgent(agentId);
    const hasUsableTokens =
      await this.subscriptionPlansService.hasUsableTokens(agentId);
    return {
      hasUsableTokens,
      plans,
      wallet: {
        processingMode: wallet.processingMode,
        isProcessing: wallet.isProcessing,
        lifetimeTokensPurchased: wallet.lifetimeTokensPurchased,
        lifetimeTokensConsumed: wallet.lifetimeTokensConsumed,
      },
    };
  }

  async getPurchases(agentId: string, limit: number, offset: number) {
    return this.subscriptionPurchasesService.findByAgent(
      agentId,
      limit,
      offset,
    );
  }

  /**
   * W2.B: initiates a real STK push, then records a PENDING SubscriptionPurchase
   * keyed by the Daraja CheckoutRequestID. Does NOT grant the plan — that
   * happens on callback/simulate via MpesaService (single grant path). The
   * client polls /mpesa/status/:checkoutRequestId until COMPLETED/FAILED.
   *
   * Q-W2-12: each call creates a new purchase row (new attempt = new row).
   */
  async purchaseSubscription(
    agentId: string,
    packageId: string,
    phoneNumber?: string,
  ) {
    const pkg = await this.subscriptionPackagesService.findOne(packageId);

    let stkPhone = phoneNumber;
    if (!stkPhone) {
      const agent = await this.agentsRepository.findOne({
        where: { id: agentId },
      });
      stkPhone = agent?.phoneNumber;
    }
    if (!stkPhone) {
      throw new NotFoundException('No phone number available for STK push');
    }

    // Daraja wants 2547######## (12-digit, no leading +). Convert 07######## .
    const darajaPhone = this.toDarajaMsisdn(stkPhone);

    // Initiate the STK push first so we have the real CheckoutRequestID to
    // use as the purchase's paymentReference (the join key).
    const stk = await this.mpesaService.initiateStkPush(
      {
        phoneNumber: darajaPhone,
        amount: pkg.price,
        accountReference: `BingwaPro-${agentId.slice(0, 8)}`,
        transactionDesc: `Bingwa Pro: ${pkg.name}`,
      },
      agentId,
    );

    const purchase = await this.subscriptionPurchasesService.recordPurchase({
      agentId,
      packageId: pkg.id,
      amountPaid: pkg.price,
      paymentReference: stk.checkoutRequestId, // join key to MpesaTransaction
      status: SubscriptionPurchaseStatus.PENDING,
      metadata: {
        stkPhone: darajaPhone,
        merchantRequestId: stk.merchantRequestId,
      },
    });

    this.logger.log(
      `STK initiated — agent=${agentId} package=${pkg.name} checkoutRequestId=${stk.checkoutRequestId}`,
    );

    return {
      purchaseId: purchase.id,
      packageName: pkg.name,
      amount: pkg.price,
      stkPhone: darajaPhone,
      checkoutRequestId: stk.checkoutRequestId,
      status: purchase.status,
    };
  }

  /**
   * W2.B: real manual-confirm fallback. Looks up the purchase; if PENDING,
   * reconciles against the M-Pesa transaction via mpesa.queryStatus. Returns
   * the current status so the client UI can resolve its spinner.
   */
  async confirmPayment(agentId: string, purchaseId: string) {
    const purchase =
      await this.subscriptionPurchasesService.findOne(purchaseId);
    if (!purchase || purchase.agentId !== agentId) {
      return {
        transactionId: purchaseId,
        reference: purchaseId,
        status: 'PENDING',
        timestamp: new Date().toISOString(),
      };
    }

    // If still pending, peek at the M-Pesa side. The callback may have already
    // flipped it; if so, reflect that. (Grant still only happens in the grant
    // path — this is read-only reconciliation.)
    if (purchase.status === SubscriptionPurchaseStatus.PENDING) {
      try {
        const mpesaStatus = await this.mpesaService.queryStatus(
          purchase.paymentReference,
        );
        this.logger.log(
          `confirmPayment reconcile — purchase=${purchase.id} mpesaStatus=${mpesaStatus.status}`,
        );
      } catch (e) {
        // No M-Pesa txn found / transient — fall through with PENDING.
      }
    }

    // Re-read in case the grant path completed it during the poll window.
    const fresh = await this.subscriptionPurchasesService.findOne(purchaseId);
    return {
      transactionId: fresh!.id,
      reference: fresh!.paymentReference,
      status: fresh!.status,
      timestamp: new Date().toISOString(),
      amount: fresh!.amountPaid,
    };
  }

  /**
   * Q-W2-21: persist the agent's processing mode. W4 reads this during SMS
   * handling; for now it just stores the choice.
   */
  async setProcessingMode(agentId: string, mode: ProcessingMode) {
    const wallet = await this.getWalletByAgentId(agentId);
    wallet.processingMode = mode;
    await this.walletsRepository.save(wallet);
    return { processingMode: wallet.processingMode };
  }

  /** 07######## or 2547######## or +2547######## → 2547######## */
  private toDarajaMsisdn(phone: string): string {
    const digits = phone.replace(/\D/g, '');
    if (digits.startsWith('254')) return digits;
    if (digits.startsWith('0')) return '254' + digits.slice(1);
    if (digits.startsWith('7') || digits.startsWith('1')) return '254' + digits;
    return digits;
  }
}
