// bingwa-pro-backend/src/agents/entities/agent.entity.ts
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, OneToOne } from 'typeorm';
import { Wallet } from '../../wallets/entities/wallet.entity';

export enum AgentStatus {
  PENDING = 'pending',
  ACTIVE = 'active',
  SUSPENDED = 'suspended',  
  TERMINATED = 'terminated',
  PENDING_VERIFICATION = 'pending_verification',
}

@Entity('agents')
export class Agent {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  fullName: string;

  @Column({ unique: true })
  phoneNumber: string;

  @Column({ unique: true })
  nationalId: string;

  @Column({ unique: true, nullable: true })
  email: string;

  @Column()
  pinHash: string; // CHANGED FROM 'pin' TO 'pinHash' to match database

  @Column({ nullable: true })
  agentCode: string;

  @Column({ nullable: true })
  businessName: string;

  @Column({ nullable: true })
  location: string;

  @Column({
    type: 'enum',
    enum: AgentStatus,
    default: AgentStatus.PENDING
  })
  status: AgentStatus;

  // ADD THESE FIELDS - they exist in database but missing in entity
  @Column()
  deviceId: string;

  @Column({ default: 'android' })
  platform: string;

  // TILL NUMBER FIELDS
  @Column({ nullable: true })
  tillNumber: string;

  @Column({ nullable: true })
  paybillNumber: string;

  @Column({ nullable: true })
  paybillAccount: string;

  @Column({ default: false })
  tillNumberVerified: boolean;

  @Column({ nullable: true })
  tillNumberVerifiedAt: Date;

  @Column({ default: 'pending' })
  tillNumberStatus: string;

  @Column({ nullable: true })
  defaultPaymentMethod: string;

  @Column({ type: 'json', nullable: true })
  paymentSettings: {
    autoDetectPayments: boolean;
    notifyOnPayment: boolean;
    minAmount: number;
    maxAmount: number;
  };

  @OneToOne(() => Wallet, wallet => wallet.agent)
  wallet: Wallet;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}