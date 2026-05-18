// bingwa-pro-backend/src/offers/offers.service.ts
// W1: renamed from ProductsService. Dropped methods tied to removed Product
// fields (findByType, findPopular, findFeatured, validateProductForPurchase,
// calculateCommission, incrementProductSales, getSafaricomBundles, etc).
// Categories CRUD moved to CategoriesService.
import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like } from 'typeorm';
import { Offer } from './entities/offer.entity';
import { Category } from '../categories/entities/category.entity';
import { CreateOfferDto } from './dto/create-offer.dto';
import { UpdateOfferDto } from './dto/update-offer.dto';
import { OfferFilterDto } from './dto/offer-filter.dto';

@Injectable()
export class OffersService {
  constructor(
    @InjectRepository(Offer)
    private offersRepository: Repository<Offer>,
    @InjectRepository(Category)
    private categoriesRepository: Repository<Category>,
  ) {}

  async createOffer(createOfferDto: CreateOfferDto): Promise<Offer> {
    // Verify category exists
    const category = await this.categoriesRepository.findOne({
      where: { id: createOfferDto.categoryId },
    });
    if (!category) {
      throw new NotFoundException(
        `Category with ID ${createOfferDto.categoryId} not found`,
      );
    }

    const offer = this.offersRepository.create(createOfferDto);
    return this.offersRepository.save(offer);
  }

  async findAllOffers(
    filterDto: OfferFilterDto,
  ): Promise<{ offers: Offer[]; total: number }> {
    const {
      isActive,
      categoryId,
      agentId,
      search,
      page = 1,
      limit = 50,
    } = filterDto;

    const where: any = {};
    if (isActive !== undefined) where.isActive = isActive;
    if (categoryId) where.categoryId = categoryId;
    if (agentId) where.agentId = agentId;
    if (search) where.name = Like(`%${search}%`);

    const [offers, total] = await this.offersRepository.findAndCount({
      where,
      relations: ['category'],
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });
    return { offers, total };
  }

  async findOneOffer(id: string): Promise<Offer> {
    const offer = await this.offersRepository.findOne({
      where: { id },
      relations: ['category'],
    });
    if (!offer) {
      throw new NotFoundException(`Offer with ID ${id} not found`);
    }
    return offer;
  }

  async updateOffer(
    id: string,
    updateOfferDto: UpdateOfferDto,
  ): Promise<Offer> {
    const offer = await this.findOneOffer(id);

    if (updateOfferDto.categoryId) {
      const category = await this.categoriesRepository.findOne({
        where: { id: updateOfferDto.categoryId },
      });
      if (!category) {
        throw new NotFoundException(
          `Category with ID ${updateOfferDto.categoryId} not found`,
        );
      }
    }

    Object.assign(offer, updateOfferDto);
    return this.offersRepository.save(offer);
  }

  async removeOffer(id: string): Promise<void> {
    const offer = await this.findOneOffer(id);
    await this.offersRepository.remove(offer);
  }

  async bulkCreateOffers(offers: CreateOfferDto[]): Promise<Offer[]> {
    const created: Offer[] = [];
    for (const dto of offers) {
      try {
        const offer = await this.createOffer(dto);
        created.push(offer);
      } catch (error) {
        // Skip on validation errors (e.g. invalid categoryId), continue with rest
        continue;
      }
    }
    return created;
  }
}