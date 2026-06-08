// bingwa-pro-backend/src/transactions/transactions.service.ts
// W3.G + W3.K + W3.L backend slice — Hybrid parity (D-W3-17):
//
//   - createQuickDial (W3.L): REVISED. Quick Dial now runs through the real
//     device pipeline exactly like the SMS path. The row is born SCHEDULED
//     (was SUCCESS) and the one-token debit happens here at creation, which IS
//     the dial-time debit (the device dials immediately after this response,
//     mirroring Hybrid DialUssdUseCase.invoke's checkIfShouldUpdateTokens BEFORE
//     enqueueing). The device enqueues into UssdExecutionService and PATCHes
//     PROCESSING→SUCCESS/FAILED back via /transactions/:id/status. Unlike the
//     SMS path there is no amount→offer match (the agent picks the offer
//     directly), so QD always returns shouldDial=true on success. Return shape
//     stays a bare Transaction for backward compatibility with the device's
//     createQuickDial repository call (it reads response.data fields to enqueue).
//
//   - createFromSms: writes SCHEDULED on offer match, UNMATCHED on no-match
//     (mirrors Hybrid CreateSmsTransactionUseCase exactly). On UNMATCHED the
//     row is persisted so the agent sees the paid customer in history, and
//     the response carries autoReplyType=OFFER_UNAVAILABLE so the device
//     fires the W3.M auto-reply. Debit is dial-time (SCHEDULED branch only),
//     mirroring DialUssdUseCase.invoke's checkIfShouldUpdateTokens call BEFORE
//     enqueueing. PROCESSING is written later by the device's PreDialHandler.
//
//   - updateTransactionStatus: extended for response text + ownership +
//     completedAt on terminal statuses. NO debit logic here (Hybrid doesn't
//     debit on SUCCESS — already done at dial-time). Backward-compatible
//     signature for legacy positional callers.
//
//   - getTransactionDetails: ownership-checked (closes B4-part-1 flag).
//
//   - recordSmsPayment: unchanged legacy back-compat path.
import {
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan } from 'typeorm';
import {
  Transaction,
  TransactionType,
  TransactionStatus,
} from './entities/transaction.entity';
import { Agent } from '../agents/entities/agent.entity';
import { Wallet } from '../wallets/entities/wallet.entity';
import { Offer } from '../offers/entities/offer.entity';
import { SubscriptionPlansService } from '../subscriptions/subscription-plans.service';
// Terminal statuses — set completedAt when transitioning to one of these.
const TERMINAL_STATUSES: ReadonlySet<TransactionStatus> = new Set([
  TransactionStatus.SUCCESS,
  TransactionStatus.FAILED,
  TransactionStatus.FAILED_ALREADY_RECOMMENDED,
  TransactionStatus.FAILED_OFFER_DEACTIVATED,
  TransactionStatus.BLOCKED,
]);
// Hybrid's AutoReplyType labels, returned to the device alongside an UNMATCHED
// transaction so the device fires the correct auto-reply via W3.M.
// (Kept as a string union here to avoid a circular import with the enums
// module; the device side has the full enum.)
export type AutoReplyHint = 'OFFER_UNAVAILABLE' | null;
export interface SmsCreateResult {
  transaction: Transaction;
  autoReplyType: AutoReplyHint;
  shouldDial: boolean;
}

@Injectable()
export class TransactionsService {
  private readonly logger = new Logger(TransactionsService.name);
  constructor(
    @InjectRepository(Transaction)
    private transactionsRepository: Repository<Transaction>,
    @InjectRepository(Agent)
    private agentsRepository: Repository<Agent>,
    @InjectRepository(Wallet)
    private walletsRepository: Repository<Wallet>,
    @InjectRepository(Offer)
    private offersRepository: Repository<Offer>,
    private subscriptionPlansService: SubscriptionPlansService,
  ) {}
  async getTransactionHistory(
    agentId: string,
    filter: {
      startDate?: Date;
      endDate?: Date;
      types?: TransactionType[];
      statuses?: TransactionStatus[];
      customerPhone?: string;
      minAmount?: number;
      maxAmount?: number;
      reference?: string;
      page: number;
      pageSize: number;
      sortBy: string;
      sortDesc: boolean;
    },
  ): Promise<{
    transactions: Transaction[];
    total: number;
    page: number;
    pageSize: number;
  }> {
    const queryBuilder = this.transactionsRepository
      .createQueryBuilder('transaction')
      .leftJoinAndSelect('transaction.agent', 'agent')
      .where('agent.id = :agentId', { agentId })
      .skip((filter.page - 1) * filter.pageSize)
      .take(filter.pageSize);
    if (filter.startDate) {
      queryBuilder.andWhere('transaction.createdAt >= :startDate', {
        startDate: filter.startDate,
      });
    }
    if (filter.endDate) {
      queryBuilder.andWhere('transaction.createdAt <= :endDate', {
        endDate: filter.endDate,
      });
    }
    if (filter.types && filter.types.length > 0) {
      queryBuilder.andWhere('transaction.type IN (:...types)', {
        types: filter.types,
      });
    }
    if (filter.statuses && filter.statuses.length > 0) {
      queryBuilder.andWhere('transaction.status IN (:...statuses)', {
        statuses: filter.statuses,
      });
    }
    if (filter.customerPhone) {
      queryBuilder.andWhere('transaction.recipientPhone LIKE :phone', {
        phone: `%${filter.customerPhone}%`,
      });
    }
    if (filter.minAmount) {
      queryBuilder.andWhere('transaction.amount >= :minAmount', {
        minAmount: filter.minAmount,
      });
    }
    if (filter.maxAmount) {
      queryBuilder.andWhere('transaction.amount <= :maxAmount', {
        maxAmount: filter.maxAmount,
      });
    }
    if (filter.reference) {
      queryBuilder.andWhere('transaction.reference LIKE :ref', {
        ref: `%${filter.reference}%`,
      });
    }
    const order = filter.sortDesc ? 'DESC' : 'ASC';
    queryBuilder.orderBy(`transaction.${filter.sortBy}`, order);
    const [transactions, total] = await queryBuilder.getManyAndCount();
    return {
      transactions,
      total,
      page: filter.page,
      pageSize: filter.pageSize,
    };
  }

  /**
   * W3.L Quick Dial — REVISED for Hybrid parity (D-W3-17). Quick Dial now runs
   * through the real device pipeline exactly like the SMS path:
   *
   *   1. 402-guard via hasUsableTokens.
   *   2. Offer lookup + ownership check (the agent picks the offer directly, so
   *      there is NO amount→offer match — unlike createFromSms).
   *   3. Persist SCHEDULED (was SUCCESS) with ussdCode + offer fields.
   *   4. Debit one LIMITED token here — this IS the dial-time debit (the device
   *      dials immediately after this response, mirroring DialUssdUseCase.invoke
   *      calling checkIfShouldUpdateTokens BEFORE enqueueing). FAILED dials still
   *      consume the token (Hybrid's per-attempt economics).
   *
   * The device then enqueues into UssdExecutionService and PATCHes
   * PROCESSING→SUCCESS/FAILED via /transactions/:id/status. Returns the bare
   * SCHEDULED Transaction (the device reads response.data {id, ussdCode,
   * customerPhone, offerId, amount} to build the DialRequest).
   */
  async createQuickDial(
    agentId: string,
    data: { offerId: string; customerPhone: string },
  ): Promise<Transaction> {
    const usable = await this.subscriptionPlansService.hasUsableTokens(agentId);
    if (!usable) {
      throw new HttpException(
        'No active subscription. Please subscribe to a plan.',
        HttpStatus.PAYMENT_REQUIRED,
      );
    }
    const offer = await this.offersRepository.findOne({
      where: { id: data.offerId },
    });
    if (!offer) {
      throw new NotFoundException('Offer not found');
    }
    if (offer.agentId !== agentId) {
      throw new ForbiddenException('Offer does not belong to this agent');
    }
    const reference = `TXN${Date.now()}${Math.floor(Math.random() * 1000)}`;
    const transaction = this.transactionsRepository.create({
      agentId,
      reference,
      type: TransactionType.QUICK_DIAL,
      // W3.L: SCHEDULED (was SUCCESS). The device pipeline drives
      // PROCESSING→SUCCESS/FAILED from here on.
      status: TransactionStatus.SCHEDULED,
      amount: offer.price,
      offerId: offer.id,
      offerName: offer.name,
      customerPhone: data.customerPhone,
      ussdCode: offer.ussdCode,
    });
    const saved = await this.transactionsRepository.save(transaction);
    // Dial-time debit (D-W3-17, Hybrid parity). Same placement as
    // createFromSms's SCHEDULED branch: the device dials immediately after this
    // response, so debiting here mirrors DialUssdUseCase.invoke's pre-enqueue
    // checkIfShouldUpdateTokens. FAILED dials still consume the token.
    const debited = await this.subscriptionPlansService.decrementLimitedToken(
      agentId,
    );
    if (debited) {
      const wallet = await this.walletsRepository.findOne({
        where: { agentId },
      });
      if (wallet) {
        wallet.lifetimeTokensConsumed += 1;
        await this.walletsRepository.save(wallet);
      }
    }
    this.logger.log(
      `QUICK_DIAL SCHEDULED — agent=${agentId} offer=${offer.name} txn=${saved.id} debited=${debited}`,
    );
    return saved;
  }

  /**
   * W3.K backend-first SMS create — REVISED for Hybrid parity (D-W3-17).
   *
   * Flow (mirrors Hybrid's SmsProcessor → CreateSmsTransactionUseCase →
   * DialUssdUseCase ordering):
   *
   *   1. 402-guard via hasUsableTokens — agent has no plan → 402.
   *
   *   2. Idempotency check on (mpesaTransactionId, agentId). Duplicate → 409
   *      with the existing transaction id; device MUST NOT dial.
   *
   *   3. Offer match by (agentId, price, isActive=true). Branches:
   *
   *      a) MATCH → persist SCHEDULED with ussdCode + offer fields, then
   *         debit one LIMITED token (dial-time debit, Hybrid parity:
   *         DialUssdUseCase.invoke calls checkIfShouldUpdateTokens BEFORE
   *         enqueueing to the dialer queue). Return shouldDial=true.
   *
   *      b) NO MATCH → persist UNMATCHED (no ussdCode, no offer fields),
   *         do NOT debit, return autoReplyType=OFFER_UNAVAILABLE so the
   *         device fires the W3.M auto-reply. Return shouldDial=false.
   *
   *   4. The device then either dials (SCHEDULED) or sends the auto-reply
   *      (UNMATCHED) and is done. Status transitions to PROCESSING happen
   *      device-side via PreDialHandler; SUCCESS/FAILED come back via
   *      PATCH /transactions/:id/status.
   */
  async createFromSms(
    agentId: string,
    data: {
      mpesaTransactionId: string;
      amount: number;
      customerPhone: string;
      mpesaMessage?: string;
    },
  ): Promise<SmsCreateResult> {
    // 1. Entitlement gate.
    const usable = await this.subscriptionPlansService.hasUsableTokens(agentId);
    if (!usable) {
      throw new HttpException(
        'No active subscription. Customer payment received but agent has no plan.',
        HttpStatus.PAYMENT_REQUIRED,
      );
    }
    // 2. Idempotency pre-check (DB unique constraint is the race-safe backstop).
    const existing = await this.transactionsRepository.findOne({
      where: { mpesaTransactionId: data.mpesaTransactionId, agentId },
    });
    if (existing) {
      throw new ConflictException({
        message: 'Payment already recorded',
        existingTransactionId: existing.id,
        status: existing.status,
      });
    }
    // 3. Offer match (whole shillings).
    const offer = await this.offersRepository.findOne({
      where: {
        agentId,
        price: Math.round(data.amount),
        isActive: true,
      },
    });

    // 3b. NO MATCH → persist UNMATCHED, no debit, return OFFER_UNAVAILABLE hint.
    if (!offer) {
      const reference = `UMC${Date.now()}${Math.floor(Math.random() * 1000)}`;
      const unmatched = this.transactionsRepository.create({
        agentId,
        reference,
        type: TransactionType.MPESA,
        status: TransactionStatus.UNMATCHED,
        amount: Math.round(data.amount),
        customerPhone: data.customerPhone,
        mpesaTransactionId: data.mpesaTransactionId,
        mpesaMessage: data.mpesaMessage ?? null,
        errorMessage: `No active offer matches amount KES ${data.amount}`,
      });
      let saved: Transaction;
      try {
        saved = await this.transactionsRepository.save(unmatched);
      } catch (err: any) {
        if (err?.code === '23505') {
          // Race with a concurrent insert — surface the winner.
          const ex = await this.transactionsRepository.findOne({
            where: { mpesaTransactionId: data.mpesaTransactionId, agentId },
          });
          throw new ConflictException({
            message: 'Payment already recorded',
            existingTransactionId: ex?.id,
            status: ex?.status,
          });
        }
        throw err;
      }
      this.logger.log(
        `UNMATCHED — agent=${agentId} amount=${data.amount} mpesa=${data.mpesaTransactionId} txn=${saved.id}`,
      );
      return {
        transaction: saved,
        autoReplyType: 'OFFER_UNAVAILABLE',
        shouldDial: false,
      };
    }
    // 3a. MATCH → persist SCHEDULED with full offer wiring.
    const reference = `SMS${Date.now()}${Math.floor(Math.random() * 1000)}`;
    const scheduled = this.transactionsRepository.create({
      agentId,
      reference,
      type: TransactionType.MPESA,
      status: TransactionStatus.SCHEDULED,
      amount: offer.price,
      offerId: offer.id,
      offerName: offer.name,
      customerPhone: data.customerPhone,
      ussdCode: offer.ussdCode,
      mpesaTransactionId: data.mpesaTransactionId,
      mpesaMessage: data.mpesaMessage ?? null,
    });
    let saved: Transaction;
    try {
      saved = await this.transactionsRepository.save(scheduled);
    } catch (err: any) {
      if (err?.code === '23505') {
        const ex = await this.transactionsRepository.findOne({
          where: { mpesaTransactionId: data.mpesaTransactionId, agentId },
        });
        throw new ConflictException({
          message: 'Payment already recorded',
          existingTransactionId: ex?.id,
          status: ex?.status,
        });
      }
      throw err;
    }

    // Dial-time debit (D-W3-17, Hybrid parity). The dial happens device-side
    // immediately after this response; debiting here is the closest backend
    // equivalent to DialUssdUseCase.invoke's pre-enqueue debit. FAILED dials
    // still consume a token — matches Hybrid's per-attempt economics.
    const debited = await this.subscriptionPlansService.decrementLimitedToken(
      agentId,
    );
    if (debited) {
      const wallet = await this.walletsRepository.findOne({
        where: { agentId },
      });
      if (wallet) {
        wallet.lifetimeTokensConsumed += 1;
        await this.walletsRepository.save(wallet);
      }
    }
    this.logger.log(
      `SCHEDULED — agent=${agentId} offer=${offer.name} mpesa=${data.mpesaTransactionId} txn=${saved.id} debited=${debited}`,
    );
    return {
      transaction: saved,
      autoReplyType: null,
      shouldDial: true,
    };
  }
  /**
   * W2.F auto-renewals (unchanged): list SCHEDULED transactions sorted by
   * rescheduleInfo.scheduledFor.
   *
   * NOTE: SCHEDULED is now ALSO the initial status for matched SMS
   * transactions (D-W3-17) and Quick Dial (W3.L), but those rows do not carry
   * a rescheduleInfo, so they naturally sort first (empty string < any ISO
   * date string) — which is correct: pending immediate dials before future
   * renewals. The auto-renewals UI filters by rescheduleInfo presence client-
   * side already; W3.E will tighten this if needed.
   */
  async findScheduled(agentId: string): Promise<Transaction[]> {
    const rows = await this.transactionsRepository.find({
      where: { agentId, status: TransactionStatus.SCHEDULED },
    });
    return rows.sort((a, b) => {
      const aT = a.rescheduleInfo?.scheduledFor ?? '';
      const bT = b.rescheduleInfo?.scheduledFor ?? '';
      return aT < bT ? -1 : aT > bT ? 1 : 0;
    });
  }

  /**
   * W2.F schedule (unchanged). Device arms a WorkManager one-shot keyed by
   * the returned transaction id (W3.E device work, separate batch).
   */
  async schedule(
    agentId: string,
    data: {
      offerId: string;
      customerPhone: string;
      scheduledFor: string;
      isRecurring: boolean;
      daysToRecur?: number;
    },
  ): Promise<Transaction> {
    const offer = await this.offersRepository.findOne({
      where: { id: data.offerId },
    });
    if (!offer) {
      throw new NotFoundException('Offer not found');
    }
    if (offer.agentId !== agentId) {
      throw new ForbiddenException('Offer does not belong to this agent');
    }
    const reference = `SCH${Date.now()}${Math.floor(Math.random() * 1000)}`;
    const transaction = this.transactionsRepository.create({
      agentId,
      reference,
      type: TransactionType.SUBSCRIPTION_RENEWAL,
      status: TransactionStatus.SCHEDULED,
      amount: offer.price,
      offerId: offer.id,
      offerName: offer.name,
      customerPhone: data.customerPhone,
      ussdCode: offer.ussdCode,
      rescheduleInfo: {
        scheduledFor: data.scheduledFor,
        isRecurring: data.isRecurring,
        daysRemaining: data.isRecurring ? data.daysToRecur ?? null : null,
      },
    });
    return this.transactionsRepository.save(transaction);
  }
  async cancelScheduled(agentId: string, id: string): Promise<void> {
    const txn = await this.transactionsRepository.findOne({ where: { id } });
    if (!txn || txn.agentId !== agentId) {
      throw new NotFoundException('Scheduled transaction not found');
    }
    if (txn.status !== TransactionStatus.SCHEDULED) {
      throw new ForbiddenException('Transaction is not scheduled');
    }
    await this.transactionsRepository.remove(txn);
  }
  async createTransaction(
    agentId: string,
    data: {
      type: TransactionType;
      amount: number;
      recipientPhone?: string;
      description?: string;
      metadata?: Record<string, any>;
    },
  ): Promise<Transaction> {
    const agent = await this.agentsRepository.findOne({
      where: { id: agentId },
    });
    if (!agent) {
      throw new NotFoundException('Agent not found');
    }
    const reference = `TXN${Date.now()}${Math.floor(Math.random() * 1000)}`;
    const transaction = this.transactionsRepository.create({
      agent,
      reference,
      type: data.type,
      amount: data.amount,
      recipientPhone: data.recipientPhone,
      description: data.description,
      metadata: data.metadata,
      status: TransactionStatus.SCHEDULED,
    });
    return this.transactionsRepository.save(transaction);
  }

  /**
   * W3.G: extended for the device pipeline — REVISED for Hybrid parity
   * (D-W3-17). Accepts captured response text + safaricom reference + an
   * optional agent-ownership check. Writes completedAt on terminal statuses.
   *
   * NO debit logic here. Hybrid debits at dial-time (DialUssdUseCase.invoke,
   * before enqueueing), which the backend mirrors in createFromSms's and
   * createQuickDial's SCHEDULED creation. Status transitions here are purely
   * informational — a FAILED transition still consumes the already-debited
   * token (matches Hybrid's per-attempt economics).
   *
   * Backward-compatible: legacy positional callers (id, status, errorMessage?,
   * safaricomRef?) keep working via overload.
   */
  async updateTransactionStatus(
    transactionId: string,
    status: TransactionStatus,
    optionsOrErrorMessage?:
      | string
      | {
          errorMessage?: string;
          ussdResponse?: string;
          safaricomReference?: string;
          agentId?: string;
        },
    legacySafaricomRef?: string,
  ): Promise<Transaction> {
    const opts =
      typeof optionsOrErrorMessage === 'string'
        ? {
            errorMessage: optionsOrErrorMessage,
            safaricomReference: legacySafaricomRef,
          }
        : optionsOrErrorMessage ?? {};
    const transaction = await this.transactionsRepository.findOne({
      where: { id: transactionId },
      relations: ['agent'],
    });
    if (!transaction) {
      throw new NotFoundException('Transaction not found');
    }
    // Ownership guard (B4-part-1 flag, closed here). The route layer always
    // supplies agentId; legacy internal callers may omit it.
    if (opts.agentId && transaction.agentId !== opts.agentId) {
      throw new NotFoundException('Transaction not found');
    }
    transaction.status = status;
    if (opts.errorMessage !== undefined) {
      transaction.errorMessage = opts.errorMessage;
    }
    if (opts.ussdResponse !== undefined) {
      // Entity has two columns for the same data; write both so existing
      // and W3-era readers both see it.
      transaction.ussdResponse = opts.ussdResponse;
      transaction.responseMessage = opts.ussdResponse;
    }
    if (opts.safaricomReference !== undefined) {
      transaction.safaricomReference = opts.safaricomReference;
      transaction.safaricomRef = opts.safaricomReference;
    }
    if (TERMINAL_STATUSES.has(status) && !transaction.completedAt) {
      transaction.completedAt = new Date();
    }
    return this.transactionsRepository.save(transaction);
  }

  /**
   * Ownership-checked details (B4-part-1 flag, closed). agentId optional for
   * back-compat with internal callers; the route layer always supplies it.
   */
  async getTransactionDetails(
    transactionId: string,
    agentId?: string,
  ): Promise<Transaction> {
    const transaction = await this.transactionsRepository.findOne({
      where: { id: transactionId },
      relations: ['agent'],
    });
    if (!transaction) {
      throw new NotFoundException('Transaction not found');
    }
    if (agentId && transaction.agentId !== agentId) {
      throw new NotFoundException('Transaction not found');
    }
    return transaction;
  }
  async getTransactionSummary(agentId: string, period: string): Promise<any> {
    const now = new Date();
    let startDate: Date;
    switch (period) {
      case 'today':
        startDate = new Date(now.setHours(0, 0, 0, 0));
        break;
      case 'week':
        startDate = new Date(now.setDate(now.getDate() - 7));
        break;
      case 'month':
        startDate = new Date(now.setMonth(now.getMonth() - 1));
        break;
      default:
        startDate = new Date(0);
    }
    const transactions = await this.transactionsRepository.find({
      where: { agent: { id: agentId }, createdAt: MoreThan(startDate) },
    });
    const total = transactions.length;
    const successful = transactions.filter(
      (t) => t.status === TransactionStatus.SUCCESS,
    ).length;
    const failed = transactions.filter(
      (t) => t.status === TransactionStatus.FAILED,
    ).length;
    const pending = transactions.filter(
      (t) =>
        t.status === TransactionStatus.PROCESSING ||
        t.status === TransactionStatus.SCHEDULED,
    ).length;
    const totalAmount = transactions
      .filter((t) => t.status === TransactionStatus.SUCCESS)
      .reduce((sum, t) => sum + Number(t.amount), 0);
    return { total, successful, failed, pending, totalAmount, period };
  }

  /**
   * Legacy device-autonomous SMS record path. Kept unchanged so the current
   * native MpesaMessageListener (B1) keeps working until W3.K device code
   * migrates to /sms-create. Will be removed after migration.
   *
   * NOTE: this path creates in SUCCESS and does NOT debit (W2 behavior).
   * The new /sms-create path (D-W3-17) is the Hybrid-parity replacement.
   */
  async recordSmsPayment(data: any, agentId: string) {
    const existing = await this.transactionsRepository.findOne({
      where: { mpesaTransactionId: data.mpesaTransactionId, agentId },
    });
    if (existing) {
      throw new ConflictException('Payment already processed');
    }
    const tx = this.transactionsRepository.create({
      ...data,
      agentId,
      status: TransactionStatus.SUCCESS,
      reference: data.mpesaTransactionId,
    });
    return this.transactionsRepository.save(tx);
  }
}