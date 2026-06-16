// bingwa-pro-backend/src/subscriptions/entities/subscription-purchase.entity.ts
// W1 new entity. Renamed from TokenTransaction; purchase-only audit (no
// per-consumption rows per locked decision 3). Per-primer status enum.
import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
} from 'typeorm';

export enum SubscriptionPurchaseStatus {
  PENDING = 'PENDING',
  COMPLETED = 'COMPLETED',
  FAILED = 'FAILED',
  REVERSED = 'REVERSED',
}

@Entity('subscription_purchases')
export class SubscriptionPurchase {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column()
  agentId: string;

  @Index()
  @Column()
  packageId: string;

  // KES paid, whole shillings (matches SubscriptionPackage.price type).
  @Column({ type: 'int' })
  amountPaid: number;

  // M-Pesa receipt / Daraja CheckoutRequestID.
  @Column()
  paymentReference: string;

  @Column({
    type: 'enum',
    enum: SubscriptionPurchaseStatus,
    default: SubscriptionPurchaseStatus.PENDING,
  })
  status: SubscriptionPurchaseStatus;

  @Column({ type: 'jsonb', nullable: true })
  metadata: Record<string, any> | null;

  @CreateDateColumn()
  createdAt: Date;
}
