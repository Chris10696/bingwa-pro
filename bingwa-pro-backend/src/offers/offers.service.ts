// bingwa-pro-backend/src/offers/offers.service.ts
// W2.A: Category dependency removed (D-W2-1). createOffer takes agentId from
// the JWT (Q-W2-17). findAllOffers is scoped to a single agent. updateOffer
// and removeOffer enforce ownership. All category validation/relations and the
// unused bulkCreateOffers method dropped.
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like } from 'typeorm';
import { Offer } from './entities/offer.entity';
import { CreateOfferDto } from './dto/create-offer.dto';
import { UpdateOfferDto } from './dto/update-offer.dto';
import { OfferFilterDto } from './dto/offer-filter.dto';

@Injectable()
export class OffersService {
  constructor(
    @InjectRepository(Offer)
    private offersRepository: Repository<Offer>,
  ) {}

  async createOffer(
    agentId: string,
    createOfferDto: CreateOfferDto,
  ): Promise<Offer> {
    const offer = this.offersRepository.create({
      ...createOfferDto,
      agentId,
    });
    return this.offersRepository.save(offer);
  }

  async findAllOffers(
    agentId: string,
    filterDto: OfferFilterDto,
  ): Promise<{ offers: Offer[]; total: number }> {
    const { isActive, type, search, page = 1, limit = 50 } = filterDto;

    const where: any = { agentId };
    if (isActive !== undefined) where.isActive = isActive;
    if (type) where.type = type;
    if (search) where.name = Like(`%${search}%`);

    const [offers, total] = await this.offersRepository.findAndCount({
      where,
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });
    return { offers, total };
  }

  async findOneOffer(id: string): Promise<Offer> {
    const offer = await this.offersRepository.findOne({ where: { id } });
    if (!offer) {
      throw new NotFoundException(`Offer with ID ${id} not found`);
    }
    return offer;
  }

  async updateOffer(
    id: string,
    agentId: string,
    updateOfferDto: UpdateOfferDto,
  ): Promise<Offer> {
    const offer = await this.findOneOffer(id);
    // Ownership guard (Q-W2-17): treat another agent's offer as not-found.
    if (offer.agentId !== agentId) {
      throw new NotFoundException(`Offer with ID ${id} not found`);
    }
    Object.assign(offer, updateOfferDto);
    return this.offersRepository.save(offer);
  }

  async removeOffer(id: string, agentId: string): Promise<void> {
    const offer = await this.findOneOffer(id);
    if (offer.agentId !== agentId) {
      throw new NotFoundException(`Offer with ID ${id} not found`);
    }
    await this.offersRepository.remove(offer);
  }
}
