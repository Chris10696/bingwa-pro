// bingwa-pro-backend/src/transactions/entities/transaction.entity.ts
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { Agent } from '../../agents/entities/agent.entity';

export enum TransactionType {
  AIRTIME = 'airtime',
  DATA = 'data',
  SMS = 'sms',
  TOKEN_PURCHASE = 'token_purchase',
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
export class Transaction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  reference: string;

  // ===== AGENT RELATIONSHIP - FIXED =====
  @Column()
  agentId: string;

  @ManyToOne(() => Agent)
  @JoinColumn({ name: 'agentId' })
  agent: Agent;
  // ======================================

  @Column({
    type: 'enum',
    enum: TransactionType,
  })
  type: TransactionType;

  @Column('decimal', { precision: 15, scale: 2 })
  amount: number;

  // ===== CUSTOMER PHONE FIELD (Fixes the 'customerPhone' error) =====
  @Column({ nullable: true })
  customerPhone: string;
  // ====================================================================

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
  safaricomReference: string; // Alias for safaricomRef

  // ===== PRODUCT FIELDS =====
  @Column({ nullable: true })
  productId: string;

  @Column({ nullable: true })
  productName: string;

  @Column({ nullable: true })
  bundleSize: string;

  @Column({ nullable: true })
  ussdCode: string;

  @Column({ nullable: true })
  ussdResponse: string;
  // ==========================

  // ===== TOKEN FIELDS =====
  @Column({ default: 0 })
  tokenAmount: number;

  @Column('decimal', { precision: 15, scale: 2, default: 0 })
  commission: number;
  // ========================

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
}