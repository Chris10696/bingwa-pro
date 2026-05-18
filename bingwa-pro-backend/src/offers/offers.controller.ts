// bingwa-pro-backend/src/offers/offers.controller.ts
// W1: renamed from ProductsController. Dropped endpoints that referenced
// dropped Product fields (network, type filtering, popular/featured, validate).
// Category endpoints split into CategoriesController.
import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { OffersService } from './offers.service';
import { CreateOfferDto } from './dto/create-offer.dto';
import { UpdateOfferDto } from './dto/update-offer.dto';
import { OfferFilterDto } from './dto/offer-filter.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('offers')
export class OffersController {
  constructor(private readonly offersService: OffersService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  async createOffer(@Body() createOfferDto: CreateOfferDto) {
    return this.offersService.createOffer(createOfferDto);
  }

  // TODO(wave-3): review whether bulk-create is still needed when seeding moves
  // out of the seed file and into agent-driven creation flows.
  @Post('bulk')
  @UseGuards(JwtAuthGuard)
  async bulkCreateOffers(@Body() offers: CreateOfferDto[]) {
    return this.offersService.bulkCreateOffers(offers);
  }

  @Get()
  async findAllOffers(@Query() filterDto: OfferFilterDto) {
    return this.offersService.findAllOffers(filterDto);
  }

  @Get(':id')
  async findOneOffer(@Param('id') id: string) {
    return this.offersService.findOneOffer(id);
  }

  // PATCH handles both full update (body has any of name, price, ussdTemplate,
  // validityLabel, categoryId, isActive) and lightweight toggle (body has only
  // {isActive: bool}). Single endpoint per Q10.
  @Patch(':id')
  @UseGuards(JwtAuthGuard)
  async updateOffer(
    @Param('id') id: string,
    @Body() updateOfferDto: UpdateOfferDto,
  ) {
    return this.offersService.updateOffer(id, updateOfferDto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  async removeOffer(@Param('id') id: string) {
    await this.offersService.removeOffer(id);
  }
}