// bingwa-pro-backend/src/subscriptions/subscriptions.seed.ts
// W1 seed: five SubscriptionPackages matching Hybrid Image 1 (Subscription
// Plans screen). Three UNLIMITED time-based plans + two LIMITED token-based.
//
// NOTE: 600 USSD Requests price is extrapolated from the 300 USSD price (KES
// 50 doubled to KES 100). The Hybrid screenshot was cropped before showing
// the 600 package's price. CONFIRM real price with the client and update.
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  SubscriptionPackage,
  SubscriptionType,
} from './entities/subscription-package.entity';

const ONE_DAY_MS = 24 * 60 * 60 * 1000;
const ONE_WEEK_MS = 7 * ONE_DAY_MS;
const ONE_MONTH_MS = 30 * ONE_DAY_MS;

const seedPackages: Array<Partial<SubscriptionPackage>> = [
  {
    name: 'Daily Subscription',
    type: SubscriptionType.UNLIMITED,
    price: 30,
    description: 'Unlimited use for 24hrs',
    tokenAllowance: null,
    durationMs: ONE_DAY_MS,
    sortOrder: 1,
    isActive: true,
  },
  {
    name: '1 Week Subscription',
    type: SubscriptionType.UNLIMITED,
    price: 200,
    description: 'Unlimited use for 1 Week',
    tokenAllowance: null,
    durationMs: ONE_WEEK_MS,
    sortOrder: 2,
    isActive: true,
  },
  {
    name: '1 Month Subscription',
    type: SubscriptionType.UNLIMITED,
    price: 900,
    description: 'Unlimited use for 1 Month',
    tokenAllowance: null,
    durationMs: ONE_MONTH_MS,
    sortOrder: 3,
    isActive: true,
  },
  {
    name: '300 USSD Requests',
    type: SubscriptionType.LIMITED,
    price: 50,
    description: '1 Ksh = 6 USSDs',
    tokenAllowance: 300,
    durationMs: null,
    sortOrder: 4,
    isActive: true,
  },
  {
    // TODO(verify-price): Hybrid screenshot was cropped before showing 600's
    // price. KES 100 is an extrapolation from the 300-USSD package's KES 50.
    name: '600 USSD Requests',
    type: SubscriptionType.LIMITED,
    price: 100,
    description: '1 Ksh = 6 USSDs',
    tokenAllowance: 600,
    durationMs: null,
    sortOrder: 5,
    isActive: true,
  },
];

@Injectable()
export class SubscriptionsSeed implements OnModuleInit {
  private readonly logger = new Logger(SubscriptionsSeed.name);

  constructor(
    @InjectRepository(SubscriptionPackage)
    private packagesRepository: Repository<SubscriptionPackage>,
  ) {}

  async onModuleInit() {
    await this.seed();
  }

  async seed() {
    const existingCount = await this.packagesRepository.count();
    if (existingCount >= seedPackages.length) {
      this.logger.log(
        `SubscriptionPackages already populated (${existingCount} rows). Skipping seed.`,
      );
      return;
    }

    for (const data of seedPackages) {
      const existing = await this.packagesRepository.findOne({
        where: { name: data.name },
      });
      if (!existing) {
        await this.packagesRepository.save(
          this.packagesRepository.create(data),
        );
        this.logger.log(`Seeded subscription package: ${data.name}`);
      }
    }
  }
}
