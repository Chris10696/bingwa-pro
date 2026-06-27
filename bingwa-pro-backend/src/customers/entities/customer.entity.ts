// bingwa-pro-backend/src/customers/entities/customer.entity.ts
// W4-batch-3 — Hybrid-minimal Customer (decompiled `customers` table parity):
// id, name, phone, accountBalance, lastPurchaseTime, isSavedInContacts, isBlackListed.
// Scoped per-agent (agentId + Unique(agentId, phone)) — Pro's backend-record model
// (D-W2-2) replacing Hybrid's on-phone Room table. synchronize:true creates the table.
import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Agent } from '../../agents/entities/agent.entity';

// Postgres returns DECIMAL as a string; hand TypeORM a real number so JSON carries 50, not "50.00".
const decimalToNumber = {
  to: (value?: number | null) => value,
  from: (value?: string | null) =>
    value === null || value === undefined ? value : parseFloat(value),
};

@Entity('customers')
@Unique(['agentId', 'phone'])
export class Customer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  agentId: string;

  @ManyToOne(() => Agent)
  @JoinColumn({ name: 'agentId' })
  agent: Agent;

  @Column({ default: '' })
  name: string;

  @Column()
  phone: string;

  @Column('decimal', {
    precision: 15,
    scale: 2,
    default: 0,
    transformer: decimalToNumber,
  })
  accountBalance: number;

  @Column({ type: 'timestamp', nullable: true })
  lastPurchaseTime: Date | null;

  @Column({ default: false })
  isSavedInContacts: boolean;

  @Column({ default: false })
  isBlackListed: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
