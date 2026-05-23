// bingwa-pro-backend/src/offers/entities/offer.entity.ts
// W2.A: Category relation dropped (D-W2-1), validityLabel dropped (D-W2-3),
// ussdTemplate renamed to ussdCode (D-W2-F). Added OfferType enum + the 8
// Hybrid retry/reschedule fields (Q-W2-1, data layer only — the OfferSettings
// UI that edits them ships in W3). agentId retained (Q-W2-17 per-agent).
import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

// Hybrid's offer category, modeled as an enum on the offer rather than a
// separate Category table (D-W2-1). Client display labels:
//   NONE → "All", DATA → "Data", VOICE → "Minutes", SMS → "SMS".
export enum OfferType {
  NONE = 'NONE',
  VOICE = 'VOICE',
  DATA = 'DATA',
  SMS = 'SMS',
}

@Entity('offers')
export class Offer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  // USSD code with BH placeholder for the customer phone. Format:
  // *180*5*2*BH*1*1# (Hybrid convention). Renamed from ussdTemplate (D-W2-F).
  @Column()
  ussdCode: string;

  // KES whole shillings, NOT decimal (Hybrid uses int).
  @Column({ type: 'int' })
  price: number;

  // Hybrid's category-equivalent. Replaces W1's categoryId FK (D-W2-1).
  @Column({ type: 'enum', enum: OfferType, default: OfferType.DATA })
  type: OfferType;

  @Column({ default: true })
  isActive: boolean;

  // Offers belong to an agent (Q-W2-17, strict per-agent ownership).
  @Index()
  @Column()
  agentId: string;

  // ===== Hybrid retry/reschedule config (Q-W2-1) =====
  // Data layer only in W2; defaults match a freshly-created Hybrid offer.
  // The simple Create Offer form does not set these — W3's OfferSettings does.
  @Column({ default: false })
  autoReschedule: boolean;

  @Column({ type: 'varchar', nullable: true })
  autoRescheduleRunTime: string | null;

  @Column({ default: false })
  autoRetry: boolean;

  @Column({ default: false })
  autoRetryConnectionProblems: boolean;

  @Column({ type: 'int', default: 0 })
  numberOfRetries: number;

  @Column({ type: 'int', default: 5 })
  retryIntervalMins: number;

  @Column({ type: 'varchar', nullable: true })
  relayDevice: string | null;

  // Hybrid models this as Long. A USSD timeout never exceeds int range
  // (int4 max ≈ 24 days in ms), so we use int to avoid TypeORM's
  // bigint-returns-as-string footgun that W3 would otherwise trip over.
  @Column({ type: 'int', default: 60000 })
  ussdTimeoutMillis: number;
  // ===================================================

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}