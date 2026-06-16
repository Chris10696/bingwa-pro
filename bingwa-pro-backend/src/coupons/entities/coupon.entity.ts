// bingwa-pro-backend/src/coupons/entities/coupon.entity.ts
// W2.B: coupon redemption (Q-W2-19). A coupon grants a SubscriptionPackage's
// plan for free when redeemed. Single-use: usedAt/usedByAgentId set on redeem.
import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

@Entity('coupons')
export class Coupon {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  // Stored uppercase-normalized (D-W2-C). Unique.
  @Index({ unique: true })
  @Column()
  code: string;

  // The package whose plan this coupon grants.
  @Column({ type: 'uuid' })
  packageId: string;

  @Column({ default: true })
  isActive: boolean;

  // NULL = never expires.
  @Column({ type: 'timestamp', nullable: true })
  expiresAt: Date | null;

  // Set when redeemed (single-use).
  @Column({ type: 'timestamp', nullable: true })
  usedAt: Date | null;

  @Column({ type: 'uuid', nullable: true })
  usedByAgentId: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
