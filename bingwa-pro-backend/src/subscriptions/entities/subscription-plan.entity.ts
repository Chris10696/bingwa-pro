// bingwa-pro-backend/src/subscriptions/entities/subscription-plan.entity.ts
// W1 new entity. Active grant per agent. Type-narrowed fields per locked
// decision 2: tokensRemaining for LIMITED, expiresAt for UNLIMITED.
//
// Partial unique index per Q4: at most one active plan per (agentId, type).
// TypeORM 0.3.28's `where` clause for partial indexes on Postgres can be
// flaky under `synchronize: true`. App-level enforcement also lives in
// SubscriptionPlansService.createPlanFromPurchase as a clearer-error layer.
// TODO(pre-production): verify the partial index actually created in psql
// with `\d subscription_plans`; if not, add a proper migration.
import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
} from 'typeorm';

export enum SubscriptionType {
  LIMITED = 'LIMITED',
  UNLIMITED = 'UNLIMITED',
}

@Index('UQ_active_plan_per_agent_type', ['agentId', 'type'], {
  unique: true,
  where: '"isActive" = true',
})
@Entity('subscription_plans')
export class SubscriptionPlan {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column()
  agentId: string;

  // Nullable to allow coupon-redeemed grants with no originating package.
  @Column({ type: 'uuid', nullable: true })
  subscriptionPackageId: string | null;

  @Column({ type: 'enum', enum: SubscriptionType })
  type: SubscriptionType;

  // For LIMITED plans: decrements per consumed USSD request (W3+).
  @Column({ type: 'int', nullable: true })
  tokensRemaining: number | null;

  // For UNLIMITED plans: timestamp at which the plan becomes inactive.
  @Column({ type: 'timestamp', nullable: true })
  expiresAt: Date | null;

  @CreateDateColumn()
  purchasedAt: Date;

  @Column({ default: true })
  isActive: boolean;
}