// bingwa-pro-backend/src/offers/entities/offer.entity.ts
// W3.H prep: autoRetry default flipped to TRUE to match the Hybrid Offer
// Settings screenshot (locked B4-part-2). Single-column-default change;
// `synchronize:true` updates the column DEFAULT in DDL but does NOT rewrite
// existing rows, so this is safe additive behavior — new offers get
// autoRetry=true; existing offers keep whatever they were saved with.
//
// All other fields unchanged from W2.A. The 7 retry/reschedule fields are
// still data-layer-only at this commit; W3.H's UI ships next.
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

// Per-offer dial-mode override (client request — a deliberate divergence from Hybrid, which
// uses a single GLOBAL Express/Advanced toggle). NULL = use the agent's global processing
// mode; otherwise this offer is always dialed in the chosen mode.
export enum OfferProcessingMode {
  EXPRESS = 'EXPRESS',
  ADVANCED = 'ADVANCED',
}
// Postgres returns DECIMAL as a string; hand TypeORM a number so JSON carries 5, not "5.00".
const decimalToNumber = {
  to: (value?: number | null) => value,
  from: (value?: string | null) =>
    value === null || value === undefined ? value : parseFloat(value),
};
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

  // Per-offer Express/Advanced override; NULL = use the agent's global processing mode.
  @Column({ type: 'enum', enum: OfferProcessingMode, nullable: true })
  processingMode: OfferProcessingMode | null;

  @Column({ default: true })
  isActive: boolean;

  // W5.A — agent commission as a PERCENT of the sale (e.g. 5 = 5%). Re-added (dropped in W1,
  // deferred to W5). On SUCCESS the backend sets transaction.commission = round(amount × rate/100).
  @Column('decimal', {
    precision: 5,
    scale: 2,
    default: 0,
    transformer: decimalToNumber,
  })
  commissionRate: number;

  // Offers belong to an agent (Q-W2-17, strict per-agent ownership).
  @Index()
  @Column()
  agentId: string;

  // ===== Hybrid retry/reschedule config (Q-W2-1) =====
  // Data layer only in W2; W3.H's OfferSettings UI edits these.
  // Defaults match a freshly-created Hybrid offer (per screenshot).
  @Column({ default: false })
  autoReschedule: boolean;

  @Column({ type: 'varchar', nullable: true })
  autoRescheduleRunTime: string | null;

  // W3 lock: default flipped FALSE → TRUE to match Hybrid Offer Settings
  // screenshot (Auto Retry shown ON for a fresh offer).
  @Column({ default: true })
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
