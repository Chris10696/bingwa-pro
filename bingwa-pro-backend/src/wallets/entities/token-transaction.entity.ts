// bingwa-pro-backend/src/wallets/entities/token-transaction.entity.ts
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { Agent } from '../../agents/entities/agent.entity';

export enum TokenTransactionType {
  PURCHASE = 'PURCHASE',
  CONSUMPTION = 'CONSUMPTION',
  REFUND = 'REFUND',
  EXPIRY = 'EXPIRY',
  BONUS = 'BONUS',
}

export enum TokenTransactionStatus {
  PENDING = 'PENDING',
  COMPLETED = 'COMPLETED',
  FAILED = 'FAILED',
  REVERSED = 'REVERSED',
}

@Entity('token_transactions')
export class TokenTransaction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Agent)
  @JoinColumn({ name: 'agentId' })
  agent: Agent;

  @Column()
  agentId: string;

  @Column({
    type: 'enum',
    enum: TokenTransactionType,
  })
  type: TokenTransactionType;

  @Column({
    type: 'enum',
    enum: TokenTransactionStatus,
    default: TokenTransactionStatus.COMPLETED,
  })
  status: TokenTransactionStatus;

  @Column({ type: 'int' })
  amount: number; // Positive for purchase, negative for consumption

  @Column({ type: 'int' })
  balanceBefore: number;

  @Column({ type: 'int' })
  balanceAfter: number;

  @Column()
  reference: string; // M-PESA transaction ID or internal reference

  @Column({ nullable: true })
  packageId: string; // For purchases

  @Column({ nullable: true })
  transactionId: string; // Related transaction (for consumption)

  @Column({ nullable: true })
  customerPhone: string; // For consumption transactions

  @Column({ type: 'json', nullable: true })
  metadata: Record<string, any>;

  @Column({ nullable: true })
  expiresAt: Date; // When purchased tokens expire

  @CreateDateColumn()
  createdAt: Date;
}