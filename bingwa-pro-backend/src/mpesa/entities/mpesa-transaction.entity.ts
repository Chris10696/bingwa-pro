import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { Agent } from '../../agents/entities/agent.entity';

export enum MpesaTransactionStatus {
  INITIATED = 'initiated',
  PENDING = 'pending',
  COMPLETED = 'completed',
  FAILED = 'failed',
  CANCELLED = 'cancelled',
  TIMEOUT = 'timeout',
}

export enum MpesaPaymentMethod {
  STK_PUSH = 'stk_push',
  PAYBILL = 'paybill',
  TILL = 'till',
}

@Entity('mpesa_transactions')
export class MpesaTransaction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  merchantRequestId: string;

  @Column({ unique: true })
  checkoutRequestId: string;

  @Column()
  agentId: string;

  @ManyToOne(() => Agent)
  @JoinColumn({ name: 'agentId' })
  agent: Agent;

  @Column()
  phoneNumber: string;

  @Column('decimal', { precision: 15, scale: 2 })
  amount: number;

  @Column({ nullable: true })
  accountReference: string;

  @Column({ nullable: true })
  transactionDesc: string;

  @Column({
    type: 'enum',
    enum: MpesaTransactionStatus,
    default: MpesaTransactionStatus.INITIATED,
  })
  status: MpesaTransactionStatus;

  @Column({
    type: 'enum',
    enum: MpesaPaymentMethod,
    default: MpesaPaymentMethod.STK_PUSH,
  })
  paymentMethod: MpesaPaymentMethod;

  @Column({ nullable: true })
  mpesaReceiptNumber: string;

  @Column({ nullable: true })
  transactionDate: Date;

  @Column({ nullable: true })
  phoneNumberUsed: string; // The actual phone number that paid (may differ from requested)

  @Column('jsonb', { nullable: true })
  stkCallback: Record<string, any>; // Full STK callback data

  @Column('jsonb', { nullable: true })
  requestMetadata: Record<string, any>;

  @Column({ nullable: true })
  resultCode: string;

  @Column({ nullable: true })
  resultDesc: string;

  @Column({ default: false })
  isTokenCredited: boolean; // Whether tokens have been credited

  @Column({ nullable: true })
  tokenTransactionId: string; // Reference to wallet transaction

  @Column({ nullable: true })
  errorMessage: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}