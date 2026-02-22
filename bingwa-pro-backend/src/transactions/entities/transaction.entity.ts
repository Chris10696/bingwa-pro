import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, ManyToOne } from 'typeorm';
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

  @ManyToOne(() => Agent)
  agent: Agent;

  @Column({
    type: 'enum',
    enum: TransactionType,
  })
  type: TransactionType;

  @Column('decimal', { precision: 15, scale: 2 })
  amount: number;

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

  @Column('jsonb', { nullable: true })
  metadata: Record<string, any>;

  @Column('decimal', { precision: 15, scale: 2, nullable: true })
  balanceBefore: number;

  @Column('decimal', { precision: 15, scale: 2, nullable: true })
  balanceAfter: number;

  @CreateDateColumn()
  createdAt: Date;
}