// bingwa-pro-backend/src/categories/categories.seed.ts
// W1 seed: exactly three categories per primer (Data, Minutes, SMS). Airtime
// is NOT a category — confirmed from Hybrid Image 2.
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Category } from './entities/category.entity';

const CATEGORY_NAMES = ['Data', 'Minutes', 'SMS'] as const;

@Injectable()
export class CategoriesSeed implements OnModuleInit {
  private readonly logger = new Logger(CategoriesSeed.name);

  constructor(
    @InjectRepository(Category)
    private categoriesRepository: Repository<Category>,
  ) {}

  async onModuleInit() {
    await this.seed();
  }

  async seed() {
    const existingCount = await this.categoriesRepository.count();
    if (existingCount >= CATEGORY_NAMES.length) {
      this.logger.log(
        `Categories table already populated (${existingCount} rows). Skipping seed.`,
      );
      return;
    }

    // Insert only categories that don't already exist (idempotent on partial state).
    for (const name of CATEGORY_NAMES) {
      const existing = await this.categoriesRepository.findOne({
        where: { name },
      });
      if (!existing) {
        await this.categoriesRepository.save(
          this.categoriesRepository.create({ name }),
        );
        this.logger.log(`Seeded category: ${name}`);
      }
    }
  }
}