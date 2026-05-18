// bingwa-pro-backend/src/offers/offers.module.ts
// W1: renamed from ProductsModule; Category moved to standalone CategoriesModule
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { OffersController } from './offers.controller';
import { OffersService } from './offers.service';
import { OffersSeed } from './offers.seed';
import { Offer } from './entities/offer.entity';
import { Agent } from '../agents/entities/agent.entity';
import { Category } from '../categories/entities/category.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Offer, Agent, Category]),
  ],
  controllers: [OffersController],
  providers: [OffersService, OffersSeed],
  exports: [OffersService],
})
export class OffersModule {}