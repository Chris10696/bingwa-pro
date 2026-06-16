// bingwa-pro-backend/src/agents/entities/agent.entity.ts
// W2.A: till/paybill fields dropped entirely (D-W2-4) — Hybrid has no such
// concept; agent payment identity is SIM-based (W4). Dropped: tillNumber,
// paybillNumber, paybillAccount, tillNumberVerified, tillNumberVerifiedAt,
// tillNumberStatus, defaultPaymentMethod, paymentSettings. (Columns are
// removed in-place by synchronize; agent rows are preserved.)
import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  OneToOne,
} from 'typeorm';
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
  pinHash: string;

  @Column({ nullable: true })
  agentCode: string;

  @Column({ nullable: true })
  businessName: string;

  @Column({ nullable: true })
  location: string;

  @Column({
    type: 'enum',
    enum: AgentStatus,
    default: AgentStatus.PENDING,
  })
  status: AgentStatus;

  @Column()
  deviceId: string;

  @Column({ default: 'android' })
  platform: string;

  @OneToOne(() => Wallet, (wallet) => wallet.agent)
  wallet: Wallet;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
