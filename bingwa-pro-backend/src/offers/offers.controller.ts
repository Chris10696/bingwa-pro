// bingwa-pro-backend/src/offers/offers.controller.ts
// W2.A: controller-level JwtAuthGuard — all endpoints agent-scoped (Q-W2-17).
// create/update/remove pass req.user.sub; findAll scoped to the authed agent.
// Bulk-create endpoint removed (unused; referenced the old category path).
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
  Request,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { OffersService } from './offers.service';
import { CreateOfferDto } from './dto/create-offer.dto';
import { UpdateOfferDto } from './dto/update-offer.dto';
import { OfferFilterDto } from './dto/offer-filter.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('offers')
@UseGuards(JwtAuthGuard)
export class OffersController {
  constructor(private readonly offersService: OffersService) {}

  @Post()
  async createOffer(@Request() req, @Body() createOfferDto: CreateOfferDto) {
    return this.offersService.createOffer(req.user.sub, createOfferDto);
  }

  @Get()
  async findAllOffers(@Request() req, @Query() filterDto: OfferFilterDto) {
    return this.offersService.findAllOffers(req.user.sub, filterDto);
  }

  @Get(':id')
  async findOneOffer(@Param('id') id: string) {
    return this.offersService.findOneOffer(id);
  }

  @Patch(':id')
  async updateOffer(
    @Request() req,
    @Param('id') id: string,
    @Body() updateOfferDto: UpdateOfferDto,
  ) {
    return this.offersService.updateOffer(id, req.user.sub, updateOfferDto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async removeOffer(@Request() req, @Param('id') id: string) {
    await this.offersService.removeOffer(id, req.user.sub);
  }
}