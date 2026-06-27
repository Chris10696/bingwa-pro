// bingwa-pro-backend/src/sitelink/sitelink.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SitelinkController } from './sitelink.controller';
import { SitelinkService } from './sitelink.service';
import { SiteLink } from './entities/site-link.entity';
import { SiteLinkOffer } from './entities/site-link-offer.entity';
import { Device } from './entities/device.entity';
import { Offer } from '../offers/entities/offer.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([SiteLink, SiteLinkOffer, Device, Offer]),
  ],
  controllers: [SitelinkController],
  providers: [SitelinkService],
  exports: [SitelinkService],
})
export class SitelinkModule {}
