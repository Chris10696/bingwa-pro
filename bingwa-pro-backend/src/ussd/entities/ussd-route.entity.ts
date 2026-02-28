import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';

export enum UssdProcessingMode {
  EXPRESS = 'express', // Single-step USSD
  ADVANCED = 'advanced', // Multi-step USSD with navigation
}

export enum UssdRouteStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
  DEGRADED = 'degraded',
  FAILED = 'failed',
}

@Entity('ussd_routes')
export class UssdRoute {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  code: string; // Internal code (e.g., 'SAF_AIRTIME', 'SAF_DATA_1GB')

  @Column()
  name: string; // Display name

  @Column()
  description: string;

  @Column()
  ussdString: string; // The actual USSD string with placeholders

  @Column('simple-json', { nullable: true })
  expectedResponses: {
    step: number;
    pattern: string; // Regex pattern to match expected response
    nextAction?: string; // Next USSD action
  }[];

  @Column('simple-json', { nullable: true })
  responseMapping: {
    field: string; // e.g., 'balance', 'reference'
    pattern: string; // Regex to extract value
    step: number;
  }[];

  @Column({
    type: 'enum',
    enum: UssdProcessingMode,
    default: UssdProcessingMode.EXPRESS,
  })
  processingMode: UssdProcessingMode;

  @Column('simple-array', { nullable: true })
  requiredSteps: number[]; // For advanced mode, list of steps required

  @Column({ default: 0 })
  successCount: number;

  @Column({ default: 0 })
  failureCount: number;

  @Column({ default: 0 })
  anomalyCount: number;

  @Column('decimal', { precision: 5, scale: 2, default: 100 })
  successRate: number; // Percentage

  @Column({ nullable: true })
  avgResponseTimeMs: number;

  @Column({
    type: 'enum',
    enum: UssdRouteStatus,
    default: UssdRouteStatus.ACTIVE,
  })
  status: UssdRouteStatus;

  @Column({ default: true })
  isActive: boolean;

  @Column('jsonb', { nullable: true })
  metadata: Record<string, any>;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}