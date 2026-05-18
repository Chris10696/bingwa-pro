// bingwa-pro-backend/src/subscriptions/subscription-purchases.service.ts
// W1 new service. Manages the purchase-only audit trail. recordPurchase is
// the entry point for W2's STK-callback success path; in W1 the only caller
// is the (stubbed) mpesa.creditTokensToWallet.
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  SubscriptionPurchase,
  SubscriptionPurchaseStatus,
} from './entities/subscription-purchase.entity';

@Injectable()
export class SubscriptionPurchasesService {
  constructor(
    @InjectRepository(SubscriptionPurchase)
    private purchasesRepository: Repository<SubscriptionPurchase>,
  ) {}

  async findByAgent(
    agentId: string,
    limit: number = 20,
    offset: number = 0,
  ): Promise<SubscriptionPurchase[]> {
    return this.purchasesRepository.find({
      where: { agentId },
      order: { createdAt: 'DESC' },
      take: limit,
      skip: offset,
    });
  }

  async findOne(id: string): Promise<SubscriptionPurchase | null> {
    return this.purchasesRepository.findOne({ where: { id } });
  }

  async recordPurchase(data: {
    agentId: string;
    packageId: string;
    amountPaid: number;
    paymentReference: string;
    status?: SubscriptionPurchaseStatus;
    metadata?: Record<string, any>;
  }): Promise<SubscriptionPurchase> {
    const purchase = this.purchasesRepository.create({
      agentId: data.agentId,
      packageId: data.packageId,
      amountPaid: data.amountPaid,
      paymentReference: data.paymentReference,
      status: data.status ?? SubscriptionPurchaseStatus.PENDING,
      metadata: data.metadata ?? null,
    });
    return this.purchasesRepository.save(purchase);
  }

  async updateStatus(
    id: string,
    status: SubscriptionPurchaseStatus,
  ): Promise<SubscriptionPurchase | null> {
    const purchase = await this.findOne(id);
    if (!purchase) return null;
    purchase.status = status;
    return this.purchasesRepository.save(purchase);
  }
}