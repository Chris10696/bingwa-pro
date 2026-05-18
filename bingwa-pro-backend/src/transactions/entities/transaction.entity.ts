// bingwa-pro-backend/src/transactions/entities/transaction.entity.ts
// W1 ripple edit:
//   - productId → offerId, productName → offerName
//   - bundleSize dropped (subsumed by offer's name/validityLabel)
//   - ussdCode + ussdResponse retained (runtime, not offer metadata)
//   - Added subscriptionPlanId FK (ON DELETE SET NULL) per Q5 locked rule
//   - TransactionType: AIRTIME and BUNDLE dropped; TOKEN_PURCHASE renamed to
//     SUBSCRIPTION_PURCHASE; MINUTES added
//   - tokenAmount field retained for now (commission column for W5; deferred)
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

export enum TransactionType {
  DATA = 'data',
  MINUTES = 'minutes',
  SMS = 'sms',
  SUBSCRIPTION_PURCHASE = 'subscription_purchase',
  COMMISSION = 'commission',
}

export enum TransactionStatus {
  INITIATED = 'initiated',
  VALIDATED = 'validated',
  EXECUTING = 'executing',
  SUCCESS = 'success',
  FAILED = 'failed',
  PENDING = 'pending',
  ABORTED = 'aborted',
}

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

  @Column({
    type: 'enum',
    enum: TransactionType,
  })
  type: TransactionType;

  @Column('decimal', { precision: 15, scale: 2 })
  amount: number;

  @Column({ nullable: true })
  customerPhone: string;

  @Column({ nullable: true })
  recipientPhone: string;

  @Column({
    type: 'enum',
    enum: TransactionStatus,
    default: TransactionStatus.INITIATED,
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

  // ===== OFFER FIELDS (renamed from product*) =====
  @Column({ nullable: true })
  offerId: string;

  @Column({ nullable: true })
  offerName: string;

  @Column({ nullable: true })
  ussdCode: string;

  @Column({ nullable: true })
  ussdResponse: string;
  // ================================================

  // ===== SUBSCRIPTION PLAN ATTRIBUTION (per Q5) =====
  // Which active plan was debited for this consumption. Nullable: pre-W1
  // transactions don't have it; W3+ may have transactions that consumed
  // from no plan (e.g. free retries, system-initiated). ON DELETE SET NULL
  // so plan history can be reconstructed even after plan rows are pruned.
  // Not indexed in W1 — revisit in W5 statistics work.
  @Column({ type: 'uuid', nullable: true })
  subscriptionPlanId: string | null;

  @ManyToOne(() => SubscriptionPlan, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'subscriptionPlanId' })
  subscriptionPlan: SubscriptionPlan | null;
  // ==================================================

  @Column({ default: 0 })
  tokenAmount: number;

  @Column('decimal', { precision: 15, scale: 2, default: 0 })
  commission: number;

  @Column('jsonb', { nullable: true })
  metadata: Record<string, any>;

  @Column('decimal', { precision: 15, scale: 2, nullable: true })
  balanceBefore: number;

  @Column('decimal', { precision: 15, scale: 2, nullable: true })
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