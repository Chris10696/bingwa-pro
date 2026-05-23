// bingwa-pro-backend/src/subscriptions/subscription-plans.service.ts
// W2.D: added decrementLimitedToken — implements Hybrid's plan-debit priority
// (DialUssdUseCase.checkIfShouldUpdateTokens): UNLIMITED active wins (no debit);
// else debit 1 token from an active LIMITED plan. Everything else unchanged.
import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
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
   * W2.D plan-debit (Hybrid checkIfShouldUpdateTokens):
   *   - If an UNLIMITED plan is active & unexpired → no debit (UNLIMITED wins).
   *   - Else if a LIMITED plan is active with tokens → debit 1.
   *   - Else → no debit (caller should have been blocked by hasUsableTokens).
   * Returns true if a token was debited.
   */
  async decrementLimitedToken(agentId: string): Promise<boolean> {
    const plans = await this.findActivePlansForAgent(agentId);
    const now = new Date();

    const hasUnlimited = plans.some(
      (p) =>
        p.type === SubscriptionType.UNLIMITED &&
        p.expiresAt != null &&
        p.expiresAt > now,
    );
    if (hasUnlimited) return false;

    const limited = plans.find(
      (p) =>
        p.type === SubscriptionType.LIMITED &&
        (p.tokensRemaining ?? 0) > 0,
    );
    if (!limited) {
      this.logger.warn(
        `decrementLimitedToken called for agent=${agentId} with no usable plan.`,
      );
      return false;
    }

    limited.tokensRemaining = (limited.tokensRemaining ?? 0) - 1;
    if (limited.tokensRemaining <= 0) {
      // Optional: deactivate a depleted LIMITED plan immediately.
      limited.tokensRemaining = 0;
    }
    await this.plansRepository.save(limited);
    return true;
  }

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
        pkg.type === SubscriptionType.LIMITED ? pkg.tokenAllowance ?? 0 : null,
      expiresAt:
        pkg.type === SubscriptionType.UNLIMITED
          ? new Date(Date.now() + Number(pkg.durationMs ?? 0))
          : null,
      purchasedAt: new Date(),
      isActive: true,
    });
    return this.plansRepository.save(plan);
  }

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