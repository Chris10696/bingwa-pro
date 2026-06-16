// bingwa-pro-backend/src/coupons/coupons.service.ts
// W2.B: redeem flow (Q-W2-19). On success, grants the plan via the same
// SubscriptionPlansService.createPlanFromPurchase used by the STK path, and
// records a COMPLETED SubscriptionPurchase (amountPaid=0, paymentReference
// "COUPON:<code>") for audit. Response shape mirrors Hybrid: { name,
// durationHours }.
import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Coupon } from './entities/coupon.entity';
import { CreateCouponDto } from './dto/create-coupon.dto';
import { SubscriptionPlansService } from '../subscriptions/subscription-plans.service';
import { SubscriptionPackagesService } from '../subscriptions/subscription-packages.service';
import { SubscriptionPurchasesService } from '../subscriptions/subscription-purchases.service';
import { SubscriptionPurchaseStatus } from '../subscriptions/entities/subscription-purchase.entity';
import { SubscriptionType } from '../subscriptions/entities/subscription-package.entity';

@Injectable()
export class CouponsService {
  private readonly logger = new Logger(CouponsService.name);

  constructor(
    @InjectRepository(Coupon)
    private couponsRepository: Repository<Coupon>,
    private subscriptionPlansService: SubscriptionPlansService,
    private subscriptionPackagesService: SubscriptionPackagesService,
    private subscriptionPurchasesService: SubscriptionPurchasesService,
  ) {}

  async redeem(agentId: string, rawCode: string) {
    const code = rawCode.trim().toUpperCase(); // D-W2-C

    const coupon = await this.couponsRepository.findOne({
      where: { code, isActive: true },
    });
    if (!coupon) {
      throw new NotFoundException('Invalid coupon code');
    }
    if (coupon.expiresAt && coupon.expiresAt < new Date()) {
      throw new BadRequestException('Coupon has expired');
    }
    if (coupon.usedAt) {
      throw new BadRequestException('Coupon has already been redeemed');
    }

    const pkg = await this.subscriptionPackagesService.findOne(
      coupon.packageId,
    );

    // Mark coupon used first (single-use guard against concurrent redeems).
    coupon.usedAt = new Date();
    coupon.usedByAgentId = agentId;
    await this.couponsRepository.save(coupon);

    // Grant plan (same path as STK success).
    await this.subscriptionPlansService.createPlanFromPurchase(
      agentId,
      coupon.packageId,
    );

    // Audit row.
    await this.subscriptionPurchasesService.recordPurchase({
      agentId,
      packageId: coupon.packageId,
      amountPaid: 0,
      paymentReference: `COUPON:${coupon.code}`,
      status: SubscriptionPurchaseStatus.COMPLETED,
      metadata: { redeemedFromCoupon: coupon.id },
    });

    this.logger.log(
      `Coupon ${coupon.code} redeemed by agent=${agentId} → package=${pkg.name}`,
    );

    // Hybrid response shape: { name, durationHours }.
    const durationHours =
      pkg.type === SubscriptionType.UNLIMITED && pkg.durationMs
        ? Number(pkg.durationMs) / 3600000
        : 0;

    return { name: pkg.name, durationHours };
  }

  async create(dto: CreateCouponDto) {
    const code = dto.code.trim().toUpperCase();
    // Validate package exists (throws if not).
    await this.subscriptionPackagesService.findOne(dto.packageId);

    const existing = await this.couponsRepository.findOne({ where: { code } });
    if (existing) {
      throw new BadRequestException('Coupon code already exists');
    }

    const coupon = this.couponsRepository.create({
      code,
      packageId: dto.packageId,
      expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : null,
      isActive: true,
    });
    return this.couponsRepository.save(coupon);
  }
}
