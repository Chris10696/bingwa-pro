// bingwa-pro-backend/src/offers/entities/offer.entity.ts
// W1: replaces Product entity. Field list per primer (exactly these, no more):
// id, name, ussdTemplate, price (int), categoryId, validityLabel, isActive,
// agentId, createdAt, updatedAt. All e-commerce fields dropped.
import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Category } from '../../categories/entities/category.entity';

@Entity('offers')
export class Offer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  // USSD template with BH placeholder for customer phone and optional AMT
  // for amount. Format: *180*5*2*BH*1*1# (Hybrid convention).
  @Column()
  ussdTemplate: string;

  // KES whole shillings, NOT decimal (Hybrid uses int).
  @Column({ type: 'int' })
  price: number;

  // Free-text validity label like "3 Hrs", "7 Days", "Until Midnight".
  @Column()
  validityLabel: string;

  @Index()
  @Column()
  categoryId: string;

  @ManyToOne(() => Category)
  @JoinColumn({ name: 'categoryId' })
  category: Category;

  @Column({ default: true })
  isActive: boolean;

  // Offers belong to an agent. FK stored as scalar; no entity-side ManyToOne
  // relation since W1 has no navigation use-case for it. W2 may add the relation
  // if offer-management UI needs to load offers-by-agent often.
  @Index()
  @Column()
  agentId: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}