// bingwa-pro-backend/src/sitelink/entities/site-link.entity.ts
// W5.G — the agent's public ordering store. Matches Hybrid's SiteLink domain model
// (siteName, username→public URL, accountType/accountNumber where payments land, isActive).
// One SiteLink per agent. The public web store (your deployment) renders it via the
// public read endpoint; a paid order comes back as a BHSL SMS the phone already processes.
import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

// Where the customer's payment is collected (Hybrid SiteLinkAccountType).
export enum SiteLinkAccountType {
  TILL = 'TILL',
  MPESA = 'MPESA',
}

@Entity('site_links')
export class SiteLink {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  // One store per agent.
  @Index({ unique: true })
  @Column()
  agentId: string;

  @Column()
  siteName: string;

  // The public slug — globally unique; the customer-facing URL is bingwanexus.com/<username>.
  @Index({ unique: true })
  @Column()
  username: string;

  @Column({
    type: 'enum',
    enum: SiteLinkAccountType,
    default: SiteLinkAccountType.TILL,
  })
  accountType: SiteLinkAccountType;

  @Column()
  accountNumber: string;

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
