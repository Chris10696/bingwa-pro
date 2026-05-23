// bingwa-pro-backend/src/offers/offers.seed.ts
// W2.A: repurposed from an auto-running OnModuleInit seed into a plain data
// source + clone helper. Per Q-W2-17 / D-W2-D, every new agent gets these 8
// default Data offers cloned at registration. validityLabel + categoryName
// dropped; type is OfferType.DATA. Prices for "1GB - 24 Hrs" (99) and
// "1.25GB - Until Midnight" (55) corrected against the Hybrid My Offers
// screenshots — the W1 seed had 50/30 which did not match the app.
import { Repository } from 'typeorm';
import { Offer, OfferType } from './entities/offer.entity';

export interface DefaultOfferRow {
  name: string;
  ussdCode: string;
  price: number;
  type: OfferType;
}

// The 8 Hybrid default Data offers (Hybrid "My Offers" screen).
export const DEFAULT_OFFERS: DefaultOfferRow[] = [
  { name: '1.5 GB - 3 Hrs', ussdCode: '*180*5*2*BH*1*1#', price: 50, type: OfferType.DATA },
  { name: '350 MBS - 7 Days', ussdCode: '*180*5*2*BH*2*1#', price: 49, type: OfferType.DATA },
  { name: '2.5GB - 7 Days', ussdCode: '*180*5*2*BH*3*1#', price: 300, type: OfferType.DATA },
  { name: '6GB - 7 Days', ussdCode: '*180*5*2*BH*4*1#', price: 700, type: OfferType.DATA },
  { name: '1GB - 1Hr', ussdCode: '*180*5*2*BH*5*1#', price: 19, type: OfferType.DATA },
  { name: '250MBS - 24 Hrs', ussdCode: '*180*5*2*BH*6*1#', price: 20, type: OfferType.DATA },
  { name: '1GB - 24 Hrs', ussdCode: '*180*5*2*BH*7*1#', price: 99, type: OfferType.DATA },
  { name: '1.25GB - Until Midnight', ussdCode: '*180*5*2*BH*8*1#', price: 55, type: OfferType.DATA },
];

/**
 * Clones the default offers into a new agent's account. Called from
 * AuthService.register() inside the registration transaction (D-W2-D). Pass a
 * repository bound to the active query-runner manager so the inserts
 * participate in that transaction.
 */
export async function cloneDefaultOffersForAgent(
  offersRepository: Repository<Offer>,
  agentId: string,
): Promise<void> {
  const rows = DEFAULT_OFFERS.map((row) =>
    offersRepository.create({
      name: row.name,
      ussdCode: row.ussdCode,
      price: row.price,
      type: row.type,
      agentId,
      isActive: true,
    }),
  );
  await offersRepository.save(rows);
}