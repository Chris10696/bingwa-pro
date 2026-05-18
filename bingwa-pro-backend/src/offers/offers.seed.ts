// bingwa-pro-backend/src/offers/offers.seed.ts
// W1: rewritten with Hybrid-style offer data. USSD templates use the BH
// placeholder format from FormatUssdUseCase. Source data: Hybrid APK
// quick_dial_screen.dart mockProducts (matching Image 2 of the Hybrid UI).
// agentId is set to a system-seed sentinel; in production these would belong
// to a real agent. Seeds only Data offers since they're the only category with
// confirmed Hybrid codes; Minutes/SMS offers come from agents in W2.
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Offer } from './entities/offer.entity';
import { Category } from '../categories/entities/category.entity';

// System sentinel for seed-owned offers. W2 will introduce per-agent ownership.
const SEED_AGENT_ID = '00000000-0000-0000-0000-000000000000';

interface SeedOfferRow {
  name: string;
  ussdTemplate: string;
  price: number;
  validityLabel: string;
  categoryName: string; // resolved to categoryId at seed time
}

const seedOffers: SeedOfferRow[] = [
  // Data offers — codes verified from Hybrid Image 2 / quick_dial_screen.dart
  {
    name: '1.5 GB - 3 Hrs',
    ussdTemplate: '*180*5*2*BH*1*1#',
    price: 50,
    validityLabel: '3 Hrs',
    categoryName: 'Data',
  },
  {
    name: '350 MBS - 7 Days',
    ussdTemplate: '*180*5*2*BH*2*1#',
    price: 49,
    validityLabel: '7 Days',
    categoryName: 'Data',
  },
  {
    name: '2.5GB - 7 Days',
    ussdTemplate: '*180*5*2*BH*3*1#',
    price: 300,
    validityLabel: '7 Days',
    categoryName: 'Data',
  },
  {
    name: '6GB - 7 Days',
    ussdTemplate: '*180*5*2*BH*4*1#',
    price: 700,
    validityLabel: '7 Days',
    categoryName: 'Data',
  },
  {
    name: '1GB - 1Hr',
    ussdTemplate: '*180*5*2*BH*5*1#',
    price: 19,
    validityLabel: '1Hr',
    categoryName: 'Data',
  },
  {
    name: '250MBS - 24 Hrs',
    ussdTemplate: '*180*5*2*BH*6*1#',
    price: 20,
    validityLabel: '24 Hrs',
    categoryName: 'Data',
  },
  {
    name: '1GB - 24 Hrs',
    ussdTemplate: '*180*5*2*BH*7*1#',
    price: 50,
    validityLabel: '24 Hrs',
    categoryName: 'Data',
  },
  {
    name: '1.25GB - Until Midnight',
    ussdTemplate: '*180*5*2*BH*8*1#',
    price: 30,
    validityLabel: 'Until Midnight',
    categoryName: 'Data',
  },
];

@Injectable()
export class OffersSeed implements OnModuleInit {
  private readonly logger = new Logger(OffersSeed.name);

  constructor(
    @InjectRepository(Offer)
    private offersRepository: Repository<Offer>,
    @InjectRepository(Category)
    private categoriesRepository: Repository<Category>,
  ) {}

  async onModuleInit() {
    await this.seed();
  }

  async seed() {
    const existingCount = await this.offersRepository.count();
    if (existingCount > 0) {
      this.logger.log(
        `Offers table already populated (${existingCount} rows). Skipping seed.`,
      );
      return;
    }

    // Resolve category names to IDs
    const categories = await this.categoriesRepository.find();
    if (categories.length === 0) {
      this.logger.warn(
        'No categories found; cannot seed offers. Run CategoriesSeed first.',
      );
      return;
    }
    const categoryByName = new Map(categories.map((c) => [c.name, c.id]));

    const rowsToInsert = seedOffers
      .map((row) => {
        const categoryId = categoryByName.get(row.categoryName);
        if (!categoryId) {
          this.logger.warn(
            `Category "${row.categoryName}" not found, skipping offer "${row.name}"`,
          );
          return null;
        }
        return this.offersRepository.create({
          name: row.name,
          ussdTemplate: row.ussdTemplate,
          price: row.price,
          validityLabel: row.validityLabel,
          categoryId,
          agentId: SEED_AGENT_ID,
          isActive: true,
        });
      })
      .filter((x): x is Offer => x !== null);

    await this.offersRepository.save(rowsToInsert);
    this.logger.log(`Seeded ${rowsToInsert.length} offers.`);
  }
}