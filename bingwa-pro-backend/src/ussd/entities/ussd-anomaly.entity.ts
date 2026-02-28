import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';

export enum UssdAnomalySeverity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical',
}

export enum UssdAnomalyStatus {
  DETECTED = 'detected',
  INVESTIGATING = 'investigating',
  RESOLVED = 'resolved',
  IGNORED = 'ignored',
}

@Entity('ussd_anomalies')
export class UssdAnomaly {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  routeId: string;

  @Column({ nullable: true })
  routeCode: string;

  @Column()
  sessionId: string;

  @Column({ nullable: true })
  transactionId: string;

  @Column({ nullable: true })
  agentId: string;

  @Column('text')
  description: string;

  @Column({
    type: 'enum',
    enum: UssdAnomalySeverity,
    default: UssdAnomalySeverity.MEDIUM,
  })
  severity: UssdAnomalySeverity;

  @Column({
    type: 'enum',
    enum: UssdAnomalyStatus,
    default: UssdAnomalyStatus.DETECTED,
  })
  status: UssdAnomalyStatus;

  @Column('simple-json')
  expectedResponse: any;

  @Column('simple-json')
  actualResponse: any;

  @Column('simple-json', { nullable: true })
  context: Record<string, any>; // Additional context (time, network conditions, etc.)

  @Column({ nullable: true })
  suggestedAction: string; // e.g., 'UPDATE_ROUTE', 'BLOCK_ROUTE', 'REVIEW'

  @Column({ nullable: true })
  resolvedBy: string; // Admin who resolved

  @Column({ nullable: true })
  resolvedAt: Date;

  @Column({ nullable: true })
  resolutionNotes: string;

  @Column({ default: false })
  isAutoResolved: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}