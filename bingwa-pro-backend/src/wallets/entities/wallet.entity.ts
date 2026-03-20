// bingwa-pro-backend/src/wallets/entities/wallet.entity.ts
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, OneToOne, JoinColumn } from 'typeorm';
import { Agent } from '../../agents/entities/agent.entity';

@Entity('wallets')
export class Wallet {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @OneToOne(() => Agent, agent => agent.wallet)
  @JoinColumn()
  agent: Agent;

  @Column()
  agentId: string;

  @Column({ 
    type: 'decimal', 
    precision: 15, 
    scale: 2, 
    default: 0,
    transformer: {
      to: (value: number) => value,
      from: (value: string) => parseFloat(value)
    }
  })
  tokenBalance: number; // Keep as decimal for KES, but tokens are whole numbers

  @Column({ type: 'int', default: 0 })
  tokenBalanceInt: number; // Add integer token balance for precise counting

  @Column({ type: 'int', default: 0 })
  lifetimeTokens: number; // Total tokens ever purchased

  @Column({ type: 'int', default: 0 })
  tokensConsumed: number; // Total tokens used

  @Column({ nullable: true })
  lastTopupAt: Date;

  @Column({ nullable: true })
  lastConsumptionAt: Date;

  @Column({ default: false })
  isProcessing: boolean; // Whether USSD processing is active

  @Column({ nullable: true })
  processingStartedAt: Date;

  @Column({ nullable: true })
  processingPausedAt: Date;

  @Column({ default: 'express' })
  processingMode: string; // 'express' or 'advanced'

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}