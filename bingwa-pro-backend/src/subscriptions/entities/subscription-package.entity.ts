// bingwa-pro-backend/src/subscriptions/entities/subscription-package.entity.ts
// W1 new entity. Hybrid's overloaded `limit` field is split into two clean
// fields (tokenAllowance for LIMITED, durationMs for UNLIMITED) per primer
// locked decision 2.
import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum SubscriptionType {
  LIMITED = 'LIMITED',
  UNLIMITED = 'UNLIMITED',
}

@Entity('subscription_packages')
export class SubscriptionPackage {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  name: string;

  @Column({ type: 'enum', enum: SubscriptionType })
  type: SubscriptionType;

  // KES, whole shillings (Hybrid uses int, not decimal).
  @Column({ type: 'int' })
  price: number;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  // For LIMITED packages: number of USSD-request tokens granted on purchase.
  // NULL for UNLIMITED packages.
  @Column({ type: 'int', nullable: true })
  tokenAllowance: number | null;

  // For UNLIMITED packages: validity duration in milliseconds.
  // NULL for LIMITED packages.
  @Column({ type: 'bigint', nullable: true })
  durationMs: number | null;

  @Column({ type: 'int', default: 0 })
  sortOrder: number;

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}