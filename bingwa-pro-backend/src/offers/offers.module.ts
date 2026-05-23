// bingwa-pro-backend/src/offers/offers.module.ts
// W2.A: Category dependency removed (D-W2-1). OffersSeed dropped from providers
// — per-agent default offers are now cloned at registration (D-W2-D); the
// standalone auto-seed no longer runs. The clone data/helper live in
// offers.seed.ts (exported, not auto-run). Unused Agent forFeature dropped.
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { OffersController } from './offers.controller';
import { OffersService } from './offers.service';
import { Offer } from './entities/offer.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Offer])],
  controllers: [OffersController],
  providers: [OffersService],
  exports: [OffersService],
})
export class OffersModule {}