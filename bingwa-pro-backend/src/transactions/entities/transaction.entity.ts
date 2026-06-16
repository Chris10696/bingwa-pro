// bingwa-pro-backend/src/transactions/entities/transaction.entity.ts
// W2.A: TransactionType replaced with Hybrid's 6 trigger-source values
// (Q-W2-2). TransactionStatus replaced with Hybrid's 10 values (Q-W2-3).
// Added 7 Hybrid runtime fields. Existing W1 fields retained (additive only;
// removing them is churn with no behavioral benefit — D-W2-2).
// NOTE: enum value strings change — transactions table is dropped/recreated
// on deploy (see Batch 1 deploy SQL).
import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Agent } from '../../agents/entities/agent.entity';
import { SubscriptionPlan } from '../../subscriptions/entities/subscription-plan.entity';

// Hybrid classifies transactions by how they were triggered (payment source),
// not by what was purchased — the product is captured by the linked Offer.
export enum TransactionType {
  TILL = 'TILL',
  MPESA = 'MPESA',
  SITE_LINK = 'SITE_LINK',
  SUBSCRIPTION_RENEWAL = 'SUBSCRIPTION_RENEWAL',
  QUICK_DIAL = 'QUICK_DIAL',
  AIRTIME_BALANCE_CHECK = 'AIRTIME_BALANCE_CHECK',
}

// Hybrid's full 10-state lifecycle. W2 actively writes SCHEDULED, PROCESSING,
// SUCCESS, FAILED, PAUSED; the rest are written by W3's pipeline.
export enum TransactionStatus {
  UNMATCHED = 'UNMATCHED',
  SCHEDULED = 'SCHEDULED',
  PROCESSING = 'PROCESSING',
  SUCCESS = 'SUCCESS',
  FAILED = 'FAILED',
  FAILED_ALREADY_RECOMMENDED = 'FAILED_ALREADY_RECOMMENDED',
  FAILED_OFFER_DEACTIVATED = 'FAILED_OFFER_DEACTIVATED',
  RESCHEDULED = 'RESCHEDULED',
  PAUSED = 'PAUSED',
  BLOCKED = 'BLOCKED',
}

// Postgres returns DECIMAL/NUMERIC as strings to preserve precision; this
// transformer hands TypeORM real numbers so JSON carries 49, not "49.00"
// (which the Flutter models cast as `num`).
const decimalToNumber = {
  to: (value?: number | null) => value,
  from: (value?: string | null) =>
    value === null || value === undefined ? value : parseFloat(value),
};

@Entity('transactions')
@Unique(['mpesaTransactionId', 'agentId'])
export class Transaction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  reference: string;

  @Column()
  agentId: string;

  @ManyToOne(() => Agent)
  @JoinColumn({ name: 'agentId' })
  agent: Agent;

  @Column({ type: 'enum', enum: TransactionType })
  type: TransactionType;

  @Column('decimal', { precision: 15, scale: 2, transformer: decimalToNumber })
  amount: number;

  @Column({ nullable: true })
  customerPhone: string;

  @Column({ nullable: true })
  recipientPhone: string;

  @Column({
    type: 'enum',
    enum: TransactionStatus,
    default: TransactionStatus.SCHEDULED,
  })
  status: TransactionStatus;

  @Column({ nullable: true })
  description: string;

  @Column({ nullable: true })
  errorMessage: string;

  @Column({ nullable: true })
  safaricomRef: string;

  @Column({ nullable: true })
  safaricomReference: string;

  // ===== OFFER FIELDS =====
  @Column({ nullable: true })
  offerId: string;

  @Column({ nullable: true })
  offerName: string;

  @Column({ nullable: true })
  ussdCode: string;

  @Column({ nullable: true })
  ussdResponse: string;
  // ========================

  // ===== SUBSCRIPTION PLAN ATTRIBUTION (W1, Q5) =====
  @Column({ type: 'uuid', nullable: true })
  subscriptionPlanId: string | null;

  @ManyToOne(() => SubscriptionPlan, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'subscriptionPlanId' })
  subscriptionPlan: SubscriptionPlan | null;
  // ==================================================

  // ===== W2 Hybrid runtime fields (additive) =====
  // Retries within the current dial session (W3 increments).
  @Column({ type: 'int', default: 0 })
  internalRetries: number;

  // Re-queued retries across sessions (W3 increments).
  @Column({ type: 'int', default: 0 })
  externalRetries: number;

  // Dual-SIM target hint (W3 uses).
  @Column({ type: 'int', nullable: true })
  recommendedSimForDialing: number | null;

  // When status=SCHEDULED, holds { scheduledFor, isRecurring, daysRemaining }.
  // Auto-renewals are scheduled transactions, not a separate entity (D-W2-5).
  @Column({ type: 'jsonb', nullable: true })
  rescheduleInfo: Record<string, any> | null;

  // M-Pesa receipt code (W4 SMS flow populates).
  @Column({ type: 'varchar', nullable: true })
  mpesaCode: string | null;

  // Full M-Pesa SMS text preserved for audit (W4).
  @Column({ type: 'text', nullable: true })
  mpesaMessage: string | null;

  // USSD response text from Safaricom (W3 populates).
  @Column({ type: 'text', nullable: true })
  responseMessage: string | null;
  // ===============================================

  @Column({ default: 0 })
  tokenAmount: number;

  @Column('decimal', {
    precision: 15,
    scale: 2,
    default: 0,
    transformer: decimalToNumber,
  })
  commission: number;

  @Column('jsonb', { nullable: true })
  metadata: Record<string, any>;

  @Column('decimal', {
    precision: 15,
    scale: 2,
    nullable: true,
    transformer: decimalToNumber,
  })
  balanceBefore: number;

  @Column('decimal', {
    precision: 15,
    scale: 2,
    nullable: true,
    transformer: decimalToNumber,
  })
  balanceAfter: number;

  @Column({ nullable: true })
  errorCode: string;

  @Column({ nullable: true })
  initiatedBy: string;

  @Column({ nullable: true })
  deviceId: string;

  @Column({ nullable: true })
  ipAddress: string;

  @Column({ default: false })
  isAutoRetry: boolean;

  @Column({ default: 0 })
  retryCount: number;

  @Column({ nullable: true })
  parentTransactionId: string;

  @Column('jsonb', { nullable: true })
  auditLogs: Record<string, any>;

  @Column({ nullable: true })
  completedAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @Column({ nullable: true, unique: false })
  mpesaTransactionId: string;
}
