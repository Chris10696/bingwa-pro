// bingwa-pro-backend/src/wallets/entities/wallet.entity.ts
// W1: drastically simplified per primer. "Do I have tokens?" reads from
// SubscriptionPlan, NOT from Wallet. Wallet now only tracks processing state
// and lifetime counters for analytics.
import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  OneToOne,
  JoinColumn,
} from 'typeorm';
import { Agent } from '../../agents/entities/agent.entity';

export enum ProcessingMode {
  EXPRESS = 'express',
  ADVANCED = 'advanced',
}

@Entity('wallets')
export class Wallet {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @OneToOne(() => Agent, (agent) => agent.wallet)
  @JoinColumn()
  agent: Agent;

  @Column()
  agentId: string;

  @Column({
    type: 'enum',
    enum: ProcessingMode,
    default: ProcessingMode.EXPRESS,
  })
  processingMode: ProcessingMode;

  @Column({ default: false })
  isProcessing: boolean;

  @Column({ type: 'timestamp', nullable: true })
  processingStartedAt: Date | null;

  @Column({ type: 'timestamp', nullable: true })
  processingPausedAt: Date | null;

  // Running totals for analytics only. Not used for "can the agent consume?"
  // decisions — that question reads from SubscriptionPlan.
  @Column({ type: 'int', default: 0 })
  lifetimeTokensPurchased: number;

  @Column({ type: 'int', default: 0 })
  lifetimeTokensConsumed: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
