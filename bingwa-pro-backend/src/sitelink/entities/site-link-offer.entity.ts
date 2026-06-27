// bingwa-pro-backend/src/sitelink/entities/site-link-offer.entity.ts
// W5.G — a publish-link: one of the agent's Offers published to their SiteLink store.
// The offer's content (name/ussdCode/price/type/relayDevice) lives on the Offer (single
// source of truth — Offer already carries relayDevice since W2/W3); this row only records
// that the offer is on the store and whether it's currently shown there (isActive).
import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

@Entity('site_link_offers')
@Index(['siteLinkId', 'offerId'], { unique: true })
export class SiteLinkOffer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column()
  siteLinkId: string;

  @Column()
  offerId: string;

  // Whether this offer is shown on the public store right now.
  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
