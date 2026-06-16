// bingwa-pro-backend/src/mpesa/mpesa.service.ts
// W2.B: creditTokensToWallet unstubbed — it now resolves the SubscriptionPurchase
// linked by paymentReference == checkoutRequestId, grants the plan via
// SubscriptionPlansService.createPlanFromPurchase, and marks the purchase
// COMPLETED. This is the SINGLE plan-grant path, reached by both the real
// Daraja callback and the simulate endpoint. The failure branch of
// handleCallback also marks the linked purchase FAILED.
import {
  Injectable,
  Logger,
  BadRequestException,
  HttpException,
  HttpStatus,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import {
  MpesaTransaction,
  MpesaTransactionStatus,
  MpesaPaymentMethod,
} from './entities/mpesa-transaction.entity';
import { StkPushRequestDto } from './dto/stk-push-request.dto';
import { MpesaCallbackDto } from './dto/mpesa-callback.dto';
import { getMpesaConfig, getBaseUrl } from './config/mpesa.config';
import { Agent } from '../agents/entities/agent.entity';
import { SubscriptionPlansService } from '../subscriptions/subscription-plans.service';
import { SubscriptionPurchasesService } from '../subscriptions/subscription-purchases.service';
import { SubscriptionPurchaseStatus } from '../subscriptions/entities/subscription-purchase.entity';
import axios from 'axios';
@Injectable()
export class MpesaService {
  private readonly logger = new Logger(MpesaService.name);
  private readonly config = getMpesaConfig();
  private accessToken: string | null = null;
  private tokenExpiry: Date | null = null;
  constructor(
    private httpService: HttpService,
    @InjectRepository(MpesaTransaction)
    private mpesaTransactionRepository: Repository<MpesaTransaction>,
    @InjectRepository(Agent)
    private agentRepository: Repository<Agent>,
    private subscriptionPlansService: SubscriptionPlansService,
    private subscriptionPurchasesService: SubscriptionPurchasesService,
  ) {}
  async getAccessToken(): Promise<string> {
    if (this.accessToken && this.tokenExpiry && new Date() < this.tokenExpiry) {
      return this.accessToken;
    }
    const auth = Buffer.from(
      `${this.config.consumerKey}:${this.config.consumerSecret}`,
    ).toString('base64');
    const baseUrl = getBaseUrl(this.config.environment);
    try {
      const response = await firstValueFrom(
        this.httpService.get(
          `${baseUrl}/oauth/v1/generate?grant_type=client_credentials`,
          { headers: { Authorization: `Basic ${auth}` } },
        ),
      );
      const token = response.data.access_token as string;
      this.accessToken = token;
      this.tokenExpiry = new Date(Date.now() + 55 * 60 * 1000);
      return token;
    } catch (error) {
      this.logger.error('Failed to get access token', error);
      throw new HttpException(
        'Failed to authenticate with M-Pesa',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
  generatePassword(): { password: string; timestamp: string } {
    const timestamp = new Date()
      .toISOString()
      .replace(/[^0-9]/g, '')
      .slice(0, -3);
    const password = Buffer.from(
      `${this.config.businessShortCode}${this.config.passkey}${timestamp}`,
    ).toString('base64');
    return { password, timestamp };
  }

  async initiateStkPush(
    requestDto: StkPushRequestDto,
    agentId?: string,
  ): Promise<any> {
    try {
      const accessToken = await this.getAccessToken();
      const baseUrl = getBaseUrl(this.config.environment);
      const { password, timestamp } = this.generatePassword();
      const merchantRequestId = `MR${Date.now()}${Math.floor(Math.random() * 1000)}`;
      const checkoutRequestId = `CR${Date.now()}${Math.floor(Math.random() * 1000)}`;
      const payload = {
        BusinessShortCode: this.config.businessShortCode,
        Password: password,
        Timestamp: timestamp,
        TransactionType: this.config.transactionType,
        Amount: requestDto.amount,
        PartyA: requestDto.phoneNumber,
        PartyB: this.config.partyB,
        PhoneNumber: requestDto.phoneNumber,
        CallBackURL: this.config.callbackUrl,
        AccountReference:
          requestDto.accountReference || `AGENT${agentId || '000'}`,
        TransactionDesc: requestDto.transactionDesc || 'Subscription Purchase',
      };
      this.logger.log(
        `Initiating STK push for amount ${requestDto.amount} to ${requestDto.phoneNumber}`,
      );
      const transaction = this.mpesaTransactionRepository.create({
        merchantRequestId,
        checkoutRequestId,
        agentId: agentId || 'system',
        phoneNumber: requestDto.phoneNumber,
        amount: requestDto.amount,
        accountReference: payload.AccountReference,
        transactionDesc: payload.TransactionDesc,
        status: MpesaTransactionStatus.INITIATED,
        paymentMethod: MpesaPaymentMethod.STK_PUSH,
        requestMetadata: payload,
      });
      await this.mpesaTransactionRepository.save(transaction);
      const response = await firstValueFrom(
        this.httpService.post(
          `${baseUrl}/mpesa/stkpush/v1/processrequest`,
          payload,
          {
            headers: {
              Authorization: `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
          },
        ),
      );
      const responseData = response.data;
      if (responseData.ResponseCode === '0') {
        transaction.checkoutRequestId = responseData.CheckoutRequestID;
        transaction.status = MpesaTransactionStatus.PENDING;
        await this.mpesaTransactionRepository.save(transaction);
        return {
          success: true,
          message: 'STK push initiated successfully',
          checkoutRequestId: responseData.CheckoutRequestID,
          merchantRequestId: responseData.MerchantRequestID,
          responseDescription: responseData.ResponseDescription,
          amount: requestDto.amount,
          phoneNumber: requestDto.phoneNumber,
        };
      } else {
        transaction.status = MpesaTransactionStatus.FAILED;
        transaction.errorMessage = responseData.ResponseDescription;
        await this.mpesaTransactionRepository.save(transaction);
        throw new BadRequestException(
          responseData.ResponseDescription || 'STK push failed',
        );
      }
    } catch (error) {
      if (axios.isAxiosError(error)) {
        this.logger.error(`M-Pesa failed: ${error.message}`, error.stack);
        throw error;
      }
      throw new Error(String(error));
    }
  }

  // FIX: Daraja sends the inner stkCallback fields in PascalCase
  // (CheckoutRequestID, ResultCode, ResultDesc, CallbackMetadata). The previous
  // camelCase reads were always undefined, so the lookup failed and the plan was
  // never granted (and `.resultCode.toString()` would have thrown on undefined).
  // Bound as `any` because the controller now passes the raw webhook body.
  async handleCallback(callbackBody: any): Promise<void> {
    try {
      const stkCallback = callbackBody?.Body?.stkCallback;
      if (!stkCallback) {
        this.logger.warn('M-Pesa callback missing Body.stkCallback; ignoring.');
        return;
      }
      const checkoutRequestId: string = stkCallback.CheckoutRequestID;
      const resultCode = Number(stkCallback.ResultCode);
      const resultDesc: string = stkCallback.ResultDesc;
      this.logger.log(
        `Received M-Pesa callback for CheckoutRequestID: ${checkoutRequestId} (ResultCode=${resultCode})`,
      );
      const transaction = await this.mpesaTransactionRepository.findOne({
        where: { checkoutRequestId },
      });
      if (!transaction) {
        // D-W2-A: unknown CheckoutRequestID — log and swallow. Controller
        // returns Success to Daraja regardless to prevent callback retries.
        this.logger.warn(
          `Callback for unknown CheckoutRequestID: ${checkoutRequestId}. Ignoring.`,
        );
        return;
      }
      transaction.stkCallback = callbackBody.Body;
      transaction.resultCode = String(resultCode);
      transaction.resultDesc = resultDesc;
      if (resultCode === 0) {
        transaction.status = MpesaTransactionStatus.COMPLETED;
        const items = stkCallback.CallbackMetadata?.Item ?? [];
        for (const item of items) {
          if (item.Name === 'MpesaReceiptNumber') {
            transaction.mpesaReceiptNumber = item.Value as string;
          } else if (item.Name === 'TransactionDate') {
            transaction.transactionDate = this.parseMpesaTimestamp(item.Value);
          } else if (item.Name === 'PhoneNumber') {
            transaction.phoneNumberUsed = String(item.Value);
          }
        }
        await this.mpesaTransactionRepository.save(transaction);
        // Single grant path.
        await this.grantSubscriptionForTransaction(transaction);
      } else {
        transaction.status = MpesaTransactionStatus.FAILED;
        transaction.errorMessage = resultDesc;
        await this.mpesaTransactionRepository.save(transaction);
        // Mark the linked purchase FAILED so the client's poll terminates.
        await this.markPurchaseFailed(transaction);
      }
      this.logger.log(`Callback processed for transaction ${transaction.id}`);
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error));
      this.logger.error(`Callback handling failed: ${err.message}`, err.stack);
    }
  }

  /**
   * Daraja's TransactionDate is YYYYMMDDHHmmss (e.g. 20260606144101), NOT epoch
   * milliseconds — `new Date(20260606144101)` would land in the year ~2612.
   */
  private parseMpesaTimestamp(value: unknown): Date {
    const s = String(value);
    if (/^\d{14}$/.test(s)) {
      const y = +s.slice(0, 4);
      const mo = +s.slice(4, 6) - 1;
      const d = +s.slice(6, 8);
      const h = +s.slice(8, 10);
      const mi = +s.slice(10, 12);
      const se = +s.slice(12, 14);
      return new Date(y, mo, d, h, mi, se);
    }
    const n = Number(value);
    return isNaN(n) ? new Date() : new Date(n);
  }

  /**
   * W2.B SINGLE PLAN-GRANT PATH.
   * Resolves the SubscriptionPurchase linked to this M-Pesa transaction via
   * paymentReference == checkoutRequestId, grants the plan, and marks the
   * purchase COMPLETED. Idempotent: if the purchase is already COMPLETED,
   * it no-ops (guards against duplicate callbacks / simulate-after-callback).
   */
  private async grantSubscriptionForTransaction(
    transaction: MpesaTransaction,
  ): Promise<void> {
    const purchase =
      await this.subscriptionPurchasesService.findByPaymentReference(
        transaction.checkoutRequestId,
      );
    if (!purchase) {
      this.logger.warn(
        `No SubscriptionPurchase linked to checkoutRequestId=${transaction.checkoutRequestId}. ` +
          `Cannot grant plan. (mpesaTxn=${transaction.id})`,
      );
      return;
    }
    if (purchase.status === SubscriptionPurchaseStatus.COMPLETED) {
      this.logger.log(
        `Purchase ${purchase.id} already COMPLETED — skipping duplicate grant.`,
      );
      return;
    }
    await this.subscriptionPlansService.createPlanFromPurchase(
      purchase.agentId,
      purchase.packageId,
    );
    await this.subscriptionPurchasesService.updateStatus(
      purchase.id,
      SubscriptionPurchaseStatus.COMPLETED,
    );
    this.logger.log(
      `Granted plan for purchase ${purchase.id} (agent=${purchase.agentId}, package=${purchase.packageId}).`,
    );
  }
  private async markPurchaseFailed(
    transaction: MpesaTransaction,
  ): Promise<void> {
    const purchase =
      await this.subscriptionPurchasesService.findByPaymentReference(
        transaction.checkoutRequestId,
      );
    if (purchase && purchase.status === SubscriptionPurchaseStatus.PENDING) {
      await this.subscriptionPurchasesService.updateStatus(
        purchase.id,
        SubscriptionPurchaseStatus.FAILED,
      );
    }
  }

  async queryStatus(checkoutRequestId: string): Promise<any> {
    const transaction = await this.mpesaTransactionRepository.findOne({
      where: { checkoutRequestId },
    });
    if (!transaction) {
      throw new NotFoundException(
        `Transaction with CheckoutRequestID ${checkoutRequestId} not found`,
      );
    }
    return {
      checkoutRequestId,
      status: transaction.status,
      amount: transaction.amount,
      mpesaReceiptNumber: transaction.mpesaReceiptNumber,
      transactionDate: transaction.transactionDate,
      errorMessage: transaction.errorMessage,
    };
  }
  async getTransaction(id: string): Promise<MpesaTransaction> {
    const transaction = await this.mpesaTransactionRepository.findOne({
      where: { id },
    });
    if (!transaction) {
      throw new NotFoundException(`M-Pesa transaction ${id} not found`);
    }
    return transaction;
  }
  async getAgentTransactions(
    agentId: string,
    limit: number = 50,
  ): Promise<MpesaTransaction[]> {
    return this.mpesaTransactionRepository.find({
      where: { agentId },
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }

  /**
   * Sandbox/dev: simulate the callback flow without calling Daraja. Reaches
   * the same single grant path as the real callback (W2.B), so it now grants
   * a real plan end-to-end.
   */
  async simulateCallback(
    transactionId: string,
    success: boolean = true,
  ): Promise<any> {
    // PRODUCTION SAFETY: simulate grants a plan WITHOUT a real payment, so it
    // must never be reachable in production (it would be a free-tokens backdoor
    // for any logged-in agent). Sandbox/dev only.
    if (this.config.environment === 'production') {
      throw new ForbiddenException(
        'Payment simulation is disabled in production.',
      );
    }
    const transaction = await this.mpesaTransactionRepository.findOne({
      where: { id: transactionId },
    });
    if (!transaction) {
      throw new NotFoundException(
        `M-Pesa transaction ${transactionId} not found`,
      );
    }
    if (success) {
      transaction.status = MpesaTransactionStatus.COMPLETED;
      transaction.mpesaReceiptNumber = `SIM${Date.now()}`;
      transaction.transactionDate = new Date();
      transaction.resultCode = '0';
      transaction.resultDesc = 'Simulated success';
      await this.mpesaTransactionRepository.save(transaction);
      await this.grantSubscriptionForTransaction(transaction);
    } else {
      transaction.status = MpesaTransactionStatus.FAILED;
      transaction.resultCode = '1';
      transaction.resultDesc = 'Simulated failure';
      transaction.errorMessage = 'Simulated payment failure';
      await this.mpesaTransactionRepository.save(transaction);
      await this.markPurchaseFailed(transaction);
    }
    this.logger.log(
      `Simulated callback for ${transactionId}: ${success ? 'SUCCESS' : 'FAILED'}`,
    );
    return {
      success: true,
      transactionId,
      status: transaction.status,
      message: `Callback simulated as ${success ? 'success' : 'failure'}`,
    };
  }
}
