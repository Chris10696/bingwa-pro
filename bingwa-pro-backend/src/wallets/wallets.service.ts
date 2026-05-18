// bingwa-pro-backend/src/wallets/wallets.service.ts
// W1: rewritten. All token-balance arithmetic removed. /wallet/balance now
// composes plans + hasUsableTokens from SubscriptionPlansService. The
// purchase flow is stubbed for W1 — it records a PENDING purchase but does
// NOT yet initiate STK push (W2 wiring through MpesaService).
import {
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Wallet } from './entities/wallet.entity';
import { Agent } from '../agents/entities/agent.entity';
import { SubscriptionPlansService } from '../subscriptions/subscription-plans.service';
import { SubscriptionPurchasesService } from '../subscriptions/subscription-purchases.service';
import { SubscriptionPackagesService } from '../subscriptions/subscription-packages.service';

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
    const wallet = this.walletsRepository.create({
      agent,
      agentId,
    });
    return this.walletsRepository.save(wallet);
  }

  /**
   * Returns the composite balance payload per primer:
   *   { hasUsableTokens, plans, wallet: {processingMode, isProcessing,
   *     lifetimeTokensPurchased, lifetimeTokensConsumed} }
   * Plans and hasUsableTokens are sourced from SubscriptionPlansService.
   */
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
   * W1 stub: records a PENDING SubscriptionPurchase and returns its ID.
   * The real STK-push flow lands in W2 when mpesa.creditTokensToWallet is
   * unstubbed and wired through to SubscriptionPlansService.createPlanFromPurchase.
   *
   * For W1, agents see "purchase submitted" but no plan is granted. This
   * matches primer's "Temporary regression accepted: between W1 ship and W2
   * ship, agents have no way to execute a transaction."
   */
  async purchaseSubscription(
    agentId: string,
    packageId: string,
    phoneNumber?: string,
  ) {
    // Verify package exists (throws if not)
    const pkg = await this.subscriptionPackagesService.findOne(packageId);

    // Use agent's registered phone if caller didn't override
    let stkPhone = phoneNumber;
    if (!stkPhone) {
      const agent = await this.agentsRepository.findOne({
        where: { id: agentId },
      });
      stkPhone = agent?.phoneNumber;
    }

    const purchase = await this.subscriptionPurchasesService.recordPurchase({
      agentId,
      packageId: pkg.id,
      amountPaid: pkg.price,
      paymentReference: `W1-STUB-${Date.now()}`, // W2: replaced by Daraja CheckoutRequestID
      metadata: {
        stkPhone,
        note: 'SUBSCRIPTION_PURCHASE_PENDING_W2',
      },
    });

    this.logger.log(
      `SUBSCRIPTION_PURCHASE_PENDING_W2 — agent=${agentId} package=${pkg.name} amount=${pkg.price}`,
    );

    // TODO(wave-2): replace this stub with mpesaService.initiateStkPush(...)
    // and return the real CheckoutRequestID. The current return shape is
    // compatible — the client polls /wallet/purchases until status flips.
    return {
      purchaseId: purchase.id,
      packageName: pkg.name,
      amount: pkg.price,
      stkPhone,
      status: purchase.status,
    };
  }

  /**
   * W1 stub: manual payment confirmation. Returns synthetic data matching the
   * PaymentConfirmation shape the client expects. Doesn't actually grant a plan
   * (mpesa.creditTokensToWallet is stubbed).
   *
   * TODO(wave-2): real implementation should:
   *   1. Look up SubscriptionPurchase by id, verify ownership by agentId
   *   2. If status is COMPLETED, return its data
   *   3. If status is PENDING, call mpesa.queryStatus and update accordingly
   *   4. If status is FAILED, return failure shape
   */
  async confirmPayment(agentId: string, purchaseId: string) {
    this.logger.log(
      `SUBSCRIPTION_PAYMENT_CONFIRM_PENDING_W2 — agent=${agentId} purchase=${purchaseId}`,
    );

    // Verify the purchase exists and belongs to this agent.
    const purchase = await this.subscriptionPurchasesService.findOne(purchaseId);
    if (!purchase || purchase.agentId !== agentId) {
      // Return a "still pending" shape rather than throwing — client treats
      // non-SUCCESS as "still waiting" and keeps the spinner up. Throwing
      // would crash the client's freezed deserialization.
      return {
        transactionId: purchaseId,
        reference: purchaseId,
        status: 'PENDING',
        timestamp: new Date().toISOString(),
      };
    }

    return {
      transactionId: purchase.id,
      reference: purchase.paymentReference,
      status: purchase.status, // PENDING / COMPLETED / FAILED / REVERSED
      timestamp: new Date().toISOString(),
      amount: purchase.amountPaid,
    };
  }
}