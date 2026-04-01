// bingwa-pro-backend/src/ussd/entities/ussd-session.entity.ts
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { UssdRoute } from './ussd-route.entity';
import { Agent } from '../../agents/entities/agent.entity';

export enum UssdSessionStatus {
  INITIATED = 'initiated',
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
  FAILED = 'failed',
  TIMEOUT = 'timeout',
  ABORTED = 'aborted',
}

@Entity('ussd_sessions')
export class UssdSession {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  sessionId: string; // The actual USSD session ID from telco

  @Column({ nullable: true })
  agentId: string; // Agent performing the transaction

  // ===== ADD AGENT RELATION (Fixes the 'agent' property error) =====
  @ManyToOne(() => Agent)
  @JoinColumn({ name: 'agentId' })
  agent: Agent;
  // =================================================================

  @Column({ nullable: true })
  transactionId: string; // Related transaction

  @ManyToOne(() => UssdRoute)
  @JoinColumn({ name: 'routeId' })
  route: UssdRoute;

  @Column({ nullable: true })
  routeId: string;

  @Column()
  phoneNumber: string; // Customer phone number

  @Column({ nullable: true })
  msisdn: string; // Agent's MSISDN (phone number used for USSD)

  @Column('simple-json', { nullable: true })
  requestHistory: {
    step: number;
    request: string;
    response: string;
    timestamp: Date;
    durationMs: number;
  }[];

  @Column('simple-json', { nullable: true })
  extractedData: Record<string, any>; // Data extracted from responses

  // ===== ADD METADATA FIELD (Fixes the 'metadata' property error) =====
  @Column('jsonb', { nullable: true })
  metadata: Record<string, any>; // For storing session-specific data (menu level, action, customerPhone, etc.)
  // ====================================================================

  @Column({
    type: 'enum',
    enum: UssdSessionStatus,
    default: UssdSessionStatus.INITIATED,
  })
  status: UssdSessionStatus;

  @Column({ nullable: true })
  currentStep: number;

  @Column({ nullable: true })
  errorMessage: string;

  @Column({ nullable: true })
  completedAt: Date;

  @Column({ default: false })
  isAnomaly: boolean;

  @Column({ nullable: true })
  anomalyId: string;

  @Column('jsonb', { nullable: true })
  rawResponses: string[]; // Full raw responses for audit

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}