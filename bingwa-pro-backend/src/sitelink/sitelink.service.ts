// bingwa-pro-backend/src/sitelink/sitelink.service.ts
// W5.G — SiteLink store: agent-side catalog management + a public read for the web store.
// Offers published to the store reference the agent's Offer rows (single source of truth);
// the offer's relayDevice (existing Offer column) is the device that dials it when ordered.
import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { SiteLink } from './entities/site-link.entity';
import { SiteLinkOffer } from './entities/site-link-offer.entity';
import { Device } from './entities/device.entity';
import { Offer } from '../offers/entities/offer.entity';
import { CreateSiteLinkDto } from './dto/create-site-link.dto';
import { UpdateSiteLinkDto } from './dto/update-site-link.dto';
import { RegisterDeviceDto } from './dto/register-device.dto';

const SITE_BASE_URL = 'https://bingwanexus.com';

@Injectable()
export class SitelinkService {
  constructor(
    @InjectRepository(SiteLink)
    private readonly siteLinks: Repository<SiteLink>,
    @InjectRepository(SiteLinkOffer)
    private readonly siteLinkOffers: Repository<SiteLinkOffer>,
    @InjectRepository(Offer)
    private readonly offers: Repository<Offer>,
    @InjectRepository(Device)
    private readonly devices: Repository<Device>,
  ) {}

  private urlFor(username: string): string {
    return `${SITE_BASE_URL}/${username}`;
  }

  private toResponse(sl: SiteLink) {
    return {
      id: sl.id,
      siteName: sl.siteName,
      username: sl.username,
      url: this.urlFor(sl.username),
      accountType: sl.accountType,
      accountNumber: sl.accountNumber,
      isActive: sl.isActive,
    };
  }

  private async requireMine(agentId: string): Promise<SiteLink> {
    const sl = await this.siteLinks.findOne({ where: { agentId } });
    if (!sl) throw new NotFoundException('No SiteLink found');
    return sl;
  }

  // ── SiteLink ────────────────────────────────────────────────────────────────────
  async getMySiteLink(agentId: string) {
    const sl = await this.siteLinks.findOne({ where: { agentId } });
    return sl ? this.toResponse(sl) : null;
  }

  async checkUsernameAvailability(username: string, agentId?: string) {
    const existing = await this.siteLinks.findOne({ where: { username } });
    const available = !existing || existing.agentId === agentId;
    return {
      available,
      message: available ? 'Username is available' : 'Username is not available',
    };
  }

  async createSiteLink(agentId: string, dto: CreateSiteLinkDto) {
    const existing = await this.siteLinks.findOne({ where: { agentId } });
    if (existing) throw new ConflictException('You already have a SiteLink');
    const taken = await this.siteLinks.findOne({
      where: { username: dto.username },
    });
    if (taken) throw new ConflictException('Username is not available');
    const sl = this.siteLinks.create({ ...dto, agentId });
    return this.toResponse(await this.siteLinks.save(sl));
  }

  async updateSiteLink(agentId: string, dto: UpdateSiteLinkDto) {
    const sl = await this.requireMine(agentId);
    if (dto.username && dto.username !== sl.username) {
      const taken = await this.siteLinks.findOne({
        where: { username: dto.username },
      });
      if (taken && taken.agentId !== agentId) {
        throw new ConflictException('Username is not available');
      }
    }
    Object.assign(sl, dto);
    return this.toResponse(await this.siteLinks.save(sl));
  }

  async setActive(agentId: string, isActive: boolean) {
    const sl = await this.requireMine(agentId);
    sl.isActive = isActive;
    return this.toResponse(await this.siteLinks.save(sl));
  }

  async deleteSiteLink(agentId: string) {
    const sl = await this.requireMine(agentId);
    await this.siteLinkOffers.delete({ siteLinkId: sl.id });
    await this.siteLinks.delete({ id: sl.id });
    return { success: true };
  }

  // ── SiteLink offers ───────────────────────────────────────────────────────────────
  async getMyOffers(agentId: string) {
    const sl = await this.requireMine(agentId);
    return this.offersFor(sl);
  }

  private async offersFor(sl: SiteLink) {
    const links = await this.siteLinkOffers.find({
      where: { siteLinkId: sl.id },
      order: { createdAt: 'ASC' },
    });
    if (links.length === 0) return [];
    const offers = await this.offers.find({
      where: { id: In(links.map((l) => l.offerId)) },
    });
    const byId = new Map(offers.map((o) => [o.id, o]));
    return links
      .map((l) => {
        const o = byId.get(l.offerId);
        if (!o) return null;
        return {
          siteLinkOfferId: l.id,
          offerId: o.id,
          name: o.name,
          ussdCode: o.ussdCode,
          price: o.price,
          type: o.type,
          isActive: l.isActive,
          relayDevice: o.relayDevice,
        };
      })
      .filter((x): x is NonNullable<typeof x> => x !== null);
  }

  async addOffer(agentId: string, offerId: string) {
    const sl = await this.requireMine(agentId);
    const offer = await this.offers.findOne({ where: { id: offerId } });
    if (!offer || offer.agentId !== agentId) {
      throw new NotFoundException('Offer not found');
    }
    const exists = await this.siteLinkOffers.findOne({
      where: { siteLinkId: sl.id, offerId },
    });
    if (exists) {
      throw new ConflictException('Offer already added to your SiteLink');
    }
    await this.siteLinkOffers.save(
      this.siteLinkOffers.create({ siteLinkId: sl.id, offerId, isActive: true }),
    );
    return this.offersFor(sl);
  }

  async setOfferActive(
    agentId: string,
    siteLinkOfferId: string,
    isActive: boolean,
  ) {
    const sl = await this.requireMine(agentId);
    const link = await this.siteLinkOffers.findOne({
      where: { id: siteLinkOfferId, siteLinkId: sl.id },
    });
    if (!link) throw new NotFoundException('SiteLink offer not found');
    link.isActive = isActive;
    await this.siteLinkOffers.save(link);
    return this.offersFor(sl);
  }

  async removeOffer(agentId: string, siteLinkOfferId: string) {
    const sl = await this.requireMine(agentId);
    const link = await this.siteLinkOffers.findOne({
      where: { id: siteLinkOfferId, siteLinkId: sl.id },
    });
    if (!link) throw new NotFoundException('SiteLink offer not found');
    await this.siteLinkOffers.delete({ id: link.id });
    return this.offersFor(sl);
  }

  // Assign which device dials this offer (fleet support). Writes the existing Offer.relayDevice.
  async updateOfferRelayDevice(
    agentId: string,
    offerId: string,
    relayDevice: string | null,
  ) {
    const sl = await this.requireMine(agentId);
    const link = await this.siteLinkOffers.findOne({
      where: { siteLinkId: sl.id, offerId },
    });
    if (!link) throw new NotFoundException('SiteLink offer not found');
    const offer = await this.offers.findOne({ where: { id: offerId } });
    if (!offer || offer.agentId !== agentId) {
      throw new NotFoundException('Offer not found');
    }
    const target = relayDevice && relayDevice.length > 0 ? relayDevice : null;
    if (target) {
      // Must be one of the agent's registered devices.
      const dev = await this.devices.findOne({
        where: { agentId, deviceId: target },
      });
      if (!dev) throw new NotFoundException('Device not found');
    }
    offer.relayDevice = target;
    await this.offers.save(offer);
    return this.offersFor(sl);
  }

  // ── Devices (fleet picker) ────────────────────────────────────────────────────────
  private toDeviceResponse(d: Device) {
    return {
      id: d.id,
      deviceId: d.deviceId,
      deviceModel: d.deviceModel,
      connectId: d.connectId,
      appState: d.appState,
      lastSeenAt: d.lastSeenAt,
    };
  }

  // The phone upserts itself on startup (keyed by agentId + deviceId).
  async registerDevice(agentId: string, dto: RegisterDeviceDto) {
    let device = await this.devices.findOne({
      where: { agentId, deviceId: dto.deviceId },
    });
    if (!device) {
      device = this.devices.create({ agentId, deviceId: dto.deviceId });
    }
    device.deviceModel = dto.deviceModel ?? device.deviceModel ?? null;
    device.connectId = dto.connectId ?? device.connectId ?? null;
    device.appState = dto.appState ?? device.appState ?? null;
    device.lastSeenAt = new Date();
    return this.toDeviceResponse(await this.devices.save(device));
  }

  async getMyDevices(agentId: string) {
    const list = await this.devices.find({
      where: { agentId },
      order: { lastSeenAt: 'DESC' },
    });
    return list.map((d) => this.toDeviceResponse(d));
  }

  // ── PUBLIC (no auth) — the web store reads the catalog by username ─────────────────
  async getPublicByUsername(username: string) {
    const sl = await this.siteLinks.findOne({ where: { username } });
    if (!sl || !sl.isActive) throw new NotFoundException('Store not found');
    const offers = (await this.offersFor(sl)).filter((o) => o.isActive);
    return {
      siteDetails: {
        siteName: sl.siteName,
        isActive: sl.isActive,
        url: this.urlFor(sl.username),
      },
      offers,
    };
  }
}
