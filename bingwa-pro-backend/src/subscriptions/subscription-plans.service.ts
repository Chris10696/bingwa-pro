// bingwa-pro-backend/src/subscriptions/subscription-plans.service.ts
// W1 new service. Owns the active-plan state model: findActivePlansForAgent,
// hasUsableTokens (per-primer SQL semantics), and the midnight cron that
// flips expired UNLIMITED plans to inactive. createPlanFromPurchase exists
// for W2 STK-callback wiring but is currently uncalled (mpesa stub in W1).
import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan } from 'typeorm';
import { Cron, CronExpression } from '@nestjs/schedule';
import {
  SubscriptionPlan,
  SubscriptionType,
} from './entities/subscription-plan.entity';
import { SubscriptionPackage } from './entities/subscription-package.entity';

@Injectable()
export class SubscriptionPlansService {
  private readonly logger = new Logger(SubscriptionPlansService.name);

  constructor(
    @InjectRepository(SubscriptionPlan)
    private plansRepository: Repository<SubscriptionPlan>,
    @InjectRepository(SubscriptionPackage)
    private packagesRepository: Repository<SubscriptionPackage>,
  ) {}

  async findActivePlansForAgent(agentId: string): Promise<SubscriptionPlan[]> {
    return this.plansRepository.find({
      where: { agentId, isActive: true },
      order: { purchasedAt: 'DESC' },
    });
  }

  /**
   * Primer SQL semantics (locked):
   *   EXISTS (SELECT 1 FROM subscription_plan WHERE agentId = ? AND isActive = true AND (
   *     (type = 'LIMITED' AND tokensRemaining > 0)
   *     OR (type = 'UNLIMITED' AND expiresAt > NOW())
   *   ))
   */
  async hasUsableTokens(agentId: string): Promise<boolean> {
    const count = await this.plansRepository
      .createQueryBuilder('plan')
      .where('plan.agentId = :agentId', { agentId })
      .andWhere('plan.isActive = :isActive', { isActive: true })
      .andWhere(
        `((plan.type = :limited AND plan.tokensRemaining > 0) OR (plan.type = :unlimited AND plan.expiresAt > NOW()))`,
        {
          limited: SubscriptionType.LIMITED,
          unlimited: SubscriptionType.UNLIMITED,
        },
      )
      .getCount();
    return count > 0;
  }

  /**
   * Creates a SubscriptionPlan from a confirmed purchase. Called by W2's
   * STK-callback success path. Not invoked in W1 (mpesa.creditTokensToWallet
   * is stubbed per primer).
   *
   * App-level uniqueness check: only one active plan per (agentId, type) at a
   * time. If a same-type active plan exists, this method extends it rather
   * than creating a duplicate row. The DB partial unique index in the entity
   * is the source of truth; this check provides a clearer error than a raw
   * Postgres constraint violation.
   */
  async createPlanFromPurchase(
    agentId: string,
    packageId: string,
  ): Promise<SubscriptionPlan> {
    const pkg = await this.packagesRepository.findOne({
      where: { id: packageId },
    });
    if (!pkg) {
      throw new Error(`SubscriptionPackage ${packageId} not found`);
    }

    const existing = await this.plansRepository.findOne({
      where: { agentId, type: pkg.type, isActive: true },
    });

    if (existing) {
      // Stack onto existing same-type plan.
      if (pkg.type === SubscriptionType.LIMITED) {
        existing.tokensRemaining =
          (existing.tokensRemaining ?? 0) + (pkg.tokenAllowance ?? 0);
      } else {
        const base =
          existing.expiresAt && existing.expiresAt > new Date()
            ? existing.expiresAt
            : new Date();
        existing.expiresAt = new Date(
          base.getTime() + Number(pkg.durationMs ?? 0),
        );
      }
      return this.plansRepository.save(existing);
    }

    const plan = this.plansRepository.create({
      agentId,
      subscriptionPackageId: packageId,
      type: pkg.type,
      tokensRemaining:
        pkg.type === SubscriptionType.LIMITED
          ? pkg.tokenAllowance ?? 0
          : null,
      expiresAt:
        pkg.type === SubscriptionType.UNLIMITED
          ? new Date(Date.now() + Number(pkg.durationMs ?? 0))
          : null,
      purchasedAt: new Date(),
      isActive: true,
    });
    return this.plansRepository.save(plan);
  }

  /**
   * Daily midnight cron: deactivates expired UNLIMITED plans.
   * Per primer: UPDATE subscription_plan SET isActive = false WHERE
   * type = 'UNLIMITED' AND expiresAt < NOW() AND isActive = true.
   */
  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async deactivateExpiredUnlimitedPlans() {
    const result = await this.plansRepository
      .createQueryBuilder()
      .update(SubscriptionPlan)
      .set({ isActive: false })
      .where('type = :type', { type: SubscriptionType.UNLIMITED })
      .andWhere('expiresAt < NOW()')
      .andWhere('isActive = :isActive', { isActive: true })
      .execute();

    if (result.affected && result.affected > 0) {
      this.logger.log(
        `Deactivated ${result.affected} expired UNLIMITED plan(s).`,
      );
    }
  }
}