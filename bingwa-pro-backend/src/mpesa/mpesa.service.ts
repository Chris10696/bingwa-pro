import { Injectable, Logger, BadRequestException, HttpException, HttpStatus, NotFoundException } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import * as crypto from 'crypto';
import { MpesaTransaction, MpesaTransactionStatus, MpesaPaymentMethod } from './entities/mpesa-transaction.entity';
import { StkPushRequestDto, MpesaEnvironment } from './dto/stk-push-request.dto';
import { MpesaCallbackDto } from './dto/mpesa-callback.dto';
import { getMpesaConfig, getBaseUrl } from './config/mpesa.config';
import { Wallet } from '../wallets/entities/wallet.entity';
import { Agent } from '../agents/entities/agent.entity';

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
    @InjectRepository(Wallet)
    private walletRepository: Repository<Wallet>,
    @InjectRepository(Agent)
    private agentRepository: Repository<Agent>,
  ) {}

  /**
   * Get OAuth access token from Safaricom
   */
  async getAccessToken(): Promise<string> {
    // Check if we have a valid cached token
    if (this.accessToken && this.tokenExpiry && new Date() < this.tokenExpiry) {
      return this.accessToken;
    }

    const auth = Buffer.from(
      `${this.config.consumerKey}:${this.config.consumerSecret}`,
    ).toString('base64');

    const baseUrl = getBaseUrl(this.config.environment);

    try {
      const response = await firstValueFrom(
        this.httpService.get(`${baseUrl}/oauth/v1/generate?grant_type=client_credentials`, {
          headers: {
            Authorization: `Basic ${auth}`,
          },
        }),
      );

      // Store in local variable first to maintain type safety
      const token = response.data.access_token as string;
      this.accessToken = token;
      // Token expires in 1 hour, cache for 55 minutes to be safe
      this.tokenExpiry = new Date(Date.now() + 55 * 60 * 1000);

      return token; // Return the local variable instead of the class property
    } catch (error) {
      this.logger.error('Failed to get access token', error);
      throw new HttpException(
        'Failed to authenticate with M-Pesa',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Generate password for STK push
   */
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

  /**
   * Initiate STK Push (Lipa Na M-Pesa Online)
   */
  async initiateStkPush(requestDto: StkPushRequestDto, agentId?: string): Promise<any> {
    try {
      const accessToken = await this.getAccessToken();
      const baseUrl = getBaseUrl(this.config.environment);
      const { password, timestamp } = this.generatePassword();

      // Generate unique IDs for the transaction
      const merchantRequestId = `MR${Date.now()}${Math.floor(Math.random() * 1000)}`;
      const checkoutRequestId = `CR${Date.now()}${Math.floor(Math.random() * 1000)}`;

      // Prepare the request payload
      const payload = {
        BusinessShortCode: this.config.businessShortCode,
        Password: password,
        Timestamp: timestamp,
        TransactionType: 'CustomerPayBillOnline',
        Amount: requestDto.amount,
        PartyA: requestDto.phoneNumber,
        PartyB: this.config.businessShortCode,
        PhoneNumber: requestDto.phoneNumber,
        CallBackURL: this.config.callbackUrl,
        AccountReference: requestDto.accountReference || `AGENT${agentId || '000'}`,
        TransactionDesc: requestDto.transactionDesc || 'Token Purchase',
      };

      this.logger.log(`Initiating STK push for amount ${requestDto.amount} to ${requestDto.phoneNumber}`);

      // Save initial transaction record
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

      // Make the API call
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
        // Update transaction with checkout request ID from response
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

        throw new BadRequestException(responseData.ResponseDescription || 'STK push failed');
      }
    } catch (error) {
      this.logger.error(`STK push failed: ${error.message}`, error.stack);
      throw new HttpException(
        error.message || 'Failed to initiate M-Pesa payment',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Handle M-Pesa callback (webhook)
   */
  async handleCallback(callbackDto: MpesaCallbackDto): Promise<void> {
    try {
      const { stkCallback } = callbackDto.Body;
      this.logger.log(`Received M-Pesa callback for CheckoutRequestID: ${stkCallback.checkoutRequestID}`);

      // Find the transaction
      const transaction = await this.mpesaTransactionRepository.findOne({
        where: { checkoutRequestId: stkCallback.checkoutRequestID },
      });

      if (!transaction) {
        this.logger.error(`Transaction not found for CheckoutRequestID: ${stkCallback.checkoutRequestID}`);
        return;
      }

      // Update transaction with callback data
      transaction.stkCallback = callbackDto.Body;
      transaction.resultCode = stkCallback.resultCode.toString();
      transaction.resultDesc = stkCallback.resultDesc;

      // Check if payment was successful (resultCode 0 means success)
      if (stkCallback.resultCode === 0) {
        transaction.status = MpesaTransactionStatus.COMPLETED;

        // Extract metadata from callback
        if (stkCallback.callbackMetadata && stkCallback.callbackMetadata.Item) {
          const items = stkCallback.callbackMetadata.Item;
          
          items.forEach(item => {
            if (item.Name === 'MpesaReceiptNumber') {
              transaction.mpesaReceiptNumber = item.Value as string;
            } else if (item.Name === 'TransactionDate') {
              transaction.transactionDate = new Date(item.Value as number);
            } else if (item.Name === 'PhoneNumber') {
              transaction.phoneNumberUsed = (item.Value as number)?.toString();
            }
          });
        }

        // Credit tokens to agent's wallet
        await this.creditTokensToWallet(transaction);
      } else {
        transaction.status = MpesaTransactionStatus.FAILED;
        transaction.errorMessage = stkCallback.resultDesc;
      }

      await this.mpesaTransactionRepository.save(transaction);
      this.logger.log(`Callback processed for transaction ${transaction.id}`);

    } catch (error) {
      this.logger.error(`Callback handling failed: ${error.message}`, error.stack);
      // Don't throw - just log the error, M-Pesa doesn't need a response
    }
  }

  /**
   * Credit tokens to agent's wallet after successful payment
   */
  private async creditTokensToWallet(transaction: MpesaTransaction): Promise<void> {
    try {
      // Check if already credited
      if (transaction.isTokenCredited) {
        this.logger.log(`Tokens already credited for transaction ${transaction.id}`);
        return;
      }

      // Find agent
      const agent = await this.agentRepository.findOne({
        where: { id: transaction.agentId },
      });

      if (!agent) {
        this.logger.error(`Agent ${transaction.agentId} not found`);
        return;
      }

      // Find or create wallet
      let wallet = await this.walletRepository.findOne({
        where: { agent: { id: agent.id } },
      });

      if (!wallet) {
        wallet = this.walletRepository.create({
          agent,
          tokenBalance: 0,
        });
      }

      // Credit tokens (1:1 conversion - 1 KES = 1 token)
      const tokenAmount = transaction.amount;
      wallet.tokenBalance = Number(wallet.tokenBalance) + tokenAmount;

      await this.walletRepository.save(wallet);

      // Mark transaction as credited
      transaction.isTokenCredited = true;
      // Here you would also create a wallet transaction record

      this.logger.log(`Credited ${tokenAmount} tokens to agent ${agent.id}`);

    } catch (error) {
      this.logger.error(`Failed to credit tokens: ${error.message}`, error.stack);
      // Don't throw - just log, we'll retry later
    }
  }

  /**
   * Query transaction status
   */
  async queryStatus(checkoutRequestId: string): Promise<any> {
    try {
      const transaction = await this.mpesaTransactionRepository.findOne({
        where: { checkoutRequestId },
      });

      if (!transaction) {
        throw new NotFoundException(`Transaction with CheckoutRequestID ${checkoutRequestId} not found`);
      }

      return {
        id: transaction.id,
        checkoutRequestId: transaction.checkoutRequestId,
        status: transaction.status,
        amount: transaction.amount,
        phoneNumber: transaction.phoneNumber,
        mpesaReceiptNumber: transaction.mpesaReceiptNumber,
        resultCode: transaction.resultCode,
        resultDesc: transaction.resultDesc,
        createdAt: transaction.createdAt,
        isTokenCredited: transaction.isTokenCredited,
      };
    } catch (error) {
      this.logger.error(`Query status failed: ${error.message}`, error.stack);
      throw error;
    }
  }

  /**
   * Get transaction by ID
   */
  async getTransaction(id: string): Promise<MpesaTransaction> {
    const transaction = await this.mpesaTransactionRepository.findOne({
      where: { id },
      relations: ['agent'],
    });

    if (!transaction) {
      throw new NotFoundException(`Transaction with ID ${id} not found`);
    }

    return transaction;
  }

  /**
   * Get transactions by agent
   */
  async getAgentTransactions(agentId: string, limit: number = 50): Promise<MpesaTransaction[]> {
    return this.mpesaTransactionRepository.find({
      where: { agentId },
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }

  /**
   * Simulate callback (for testing in sandbox)
   */
  async simulateCallback(transactionId: string, success: boolean = true): Promise<any> {
    if (this.config.environment !== 'sandbox') {
      throw new BadRequestException('Simulation only available in sandbox mode');
    }

    const transaction = await this.getTransaction(transactionId);

    const mockCallback: MpesaCallbackDto = {
      Body: {
        stkCallback: {
          merchantRequestID: transaction.merchantRequestId,
          checkoutRequestID: transaction.checkoutRequestId,
          resultCode: success ? 0 : 1,
          resultDesc: success ? 'The service request is processed successfully.' : 'Transaction failed',
          callbackMetadata: success ? {
            Item: [
              {
                Name: 'Amount',
                Value: transaction.amount,
              },
              {
                Name: 'MpesaReceiptNumber',
                Value: `MOCK${Math.floor(Math.random() * 1000000)}`,
              },
              {
                Name: 'TransactionDate',
                Value: Date.now(),
              },
              {
                Name: 'PhoneNumber',
                Value: parseInt(transaction.phoneNumber),
              },
            ],
          } : undefined,
        },
      },
    };

    await this.handleCallback(mockCallback);

    return {
      message: 'Callback simulated successfully',
      transactionId: transaction.id,
      status: success ? 'completed' : 'failed',
    };
  }
}