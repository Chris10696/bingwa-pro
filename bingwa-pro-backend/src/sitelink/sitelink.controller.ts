// bingwa-pro-backend/src/sitelink/sitelink.controller.ts
// W5.G — SiteLink store endpoints. All agent routes are JWT-guarded (per-method, so the
// public store-read endpoint stays open). The public endpoint is what your web deployment
// calls to render a customer's store; everything else is agent self-management.
import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { SitelinkService } from './sitelink.service';
import { CreateSiteLinkDto } from './dto/create-site-link.dto';
import {
  SetSiteLinkActiveDto,
  UpdateSiteLinkDto,
} from './dto/update-site-link.dto';
import {
  AddSiteLinkOfferDto,
  SetOfferActiveDto,
  UpdateRelayDeviceDto,
} from './dto/site-link-offer.dto';
import { RegisterDeviceDto } from './dto/register-device.dto';

@Controller('sitelink')
export class SitelinkController {
  constructor(private readonly service: SitelinkService) {}

  // PUBLIC — the web store reads a customer-facing catalog by username (no auth).
  @Get('public/:username')
  getPublic(@Param('username') username: string) {
    return this.service.getPublicByUsername(username);
  }

  @Get()
  @UseGuards(JwtAuthGuard)
  getMine(@Request() req) {
    return this.service.getMySiteLink(req.user.sub);
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  create(@Request() req, @Body() dto: CreateSiteLinkDto) {
    return this.service.createSiteLink(req.user.sub, dto);
  }

  @Patch()
  @UseGuards(JwtAuthGuard)
  update(@Request() req, @Body() dto: UpdateSiteLinkDto) {
    return this.service.updateSiteLink(req.user.sub, dto);
  }

  @Patch('active')
  @UseGuards(JwtAuthGuard)
  setActive(@Request() req, @Body() body: SetSiteLinkActiveDto) {
    return this.service.setActive(req.user.sub, body.isActive);
  }

  @Delete()
  @UseGuards(JwtAuthGuard)
  remove(@Request() req) {
    return this.service.deleteSiteLink(req.user.sub);
  }

  @Get('username-availability/:username')
  @UseGuards(JwtAuthGuard)
  checkUsername(@Request() req, @Param('username') username: string) {
    return this.service.checkUsernameAvailability(username, req.user.sub);
  }

  // ── devices (fleet picker) ──
  @Get('devices')
  @UseGuards(JwtAuthGuard)
  getDevices(@Request() req) {
    return this.service.getMyDevices(req.user.sub);
  }

  @Post('devices')
  @UseGuards(JwtAuthGuard)
  registerDevice(@Request() req, @Body() dto: RegisterDeviceDto) {
    return this.service.registerDevice(req.user.sub, dto);
  }

  // ── offers on the store ──
  @Get('offers')
  @UseGuards(JwtAuthGuard)
  getOffers(@Request() req) {
    return this.service.getMyOffers(req.user.sub);
  }

  @Post('offers')
  @UseGuards(JwtAuthGuard)
  addOffer(@Request() req, @Body() dto: AddSiteLinkOfferDto) {
    return this.service.addOffer(req.user.sub, dto.offerId);
  }

  @Patch('offers/:id')
  @UseGuards(JwtAuthGuard)
  setOfferActive(
    @Request() req,
    @Param('id') id: string,
    @Body() body: SetOfferActiveDto,
  ) {
    return this.service.setOfferActive(req.user.sub, id, body.isActive);
  }

  @Delete('offers/:id')
  @UseGuards(JwtAuthGuard)
  removeOffer(@Request() req, @Param('id') id: string) {
    return this.service.removeOffer(req.user.sub, id);
  }

  // Fleet: assign which device dials this offer (writes the offer's relayDevice).
  @Patch('offers/:offerId/relay-device')
  @UseGuards(JwtAuthGuard)
  updateRelayDevice(
    @Request() req,
    @Param('offerId') offerId: string,
    @Body() body: UpdateRelayDeviceDto,
  ) {
    return this.service.updateOfferRelayDevice(
      req.user.sub,
      offerId,
      body.relayDevice ?? null,
    );
  }
}
