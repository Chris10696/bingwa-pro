// bingwa-pro-backend/src/subscriptions/subscription-packages.service.ts
// W1 new service. Read-only public surface; package creation handled by seed.
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SubscriptionPackage } from './entities/subscription-package.entity';

@Injectable()
export class SubscriptionPackagesService {
  constructor(
    @InjectRepository(SubscriptionPackage)
    private packagesRepository: Repository<SubscriptionPackage>,
  ) {}

  async findAll(
    includeInactive: boolean = false,
  ): Promise<SubscriptionPackage[]> {
    const where = includeInactive ? {} : { isActive: true };
    return this.packagesRepository.find({
      where,
      order: { sortOrder: 'ASC', price: 'ASC' },
    });
  }

  async findOne(id: string): Promise<SubscriptionPackage> {
    const pkg = await this.packagesRepository.findOne({ where: { id } });
    if (!pkg) {
      throw new NotFoundException(
        `SubscriptionPackage with ID ${id} not found`,
      );
    }
    return pkg;
  }
}
