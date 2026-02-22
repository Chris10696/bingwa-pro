import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { Category } from './category.entity';

export enum ProductType {
  AIRTIME = 'airtime',
  DATA = 'data',
  SMS = 'sms',
  MINUTES = 'minutes',
  BUNDLE = 'bundle',
}

export enum ProductNetwork {
  SAFARICOM = 'SAFARICOM',
  AIRTEL = 'AIRTEL',
  TELKOM = 'TELKOM',
  ALL = 'ALL',
}

@Entity('products')
export class Product {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  code: string; // Internal product code (e.g., 'SAF_1GB_DAILY')

  @Column()
  name: string; // Display name (e.g., '1GB Daily Bundle')

  @Column({
    type: 'enum',
    enum: ProductType,
  })
  type: ProductType;

  @Column({
    type: 'enum',
    enum: ProductNetwork,
    default: ProductNetwork.SAFARICOM,
  })
  network: ProductNetwork;

  @Column('decimal', { precision: 15, scale: 2 })
  price: number; // Selling price in KES

  @Column('decimal', { precision: 15, scale: 2, nullable: true })
  costPrice: number; // Cost price (for commission calculation)

  @Column()
  value: string; // e.g., "1GB", "100 minutes", "100 SMS"

  @Column({ nullable: true })
  validityDays: number; // Number of days the product is valid

  @Column({ nullable: true })
  validityHours: number; // Alternative validity in hours

  @Column({ nullable: true })
  ussdCode: string; // USSD code to activate

  @Column({ nullable: true })
  description: string;

  @Column('simple-array', { nullable: true })
  tags: string[]; // For categorization and search

  @Column('decimal', { precision: 5, scale: 2, default: 0 })
  commissionRate: number; // Commission rate percentage

  @Column('decimal', { precision: 15, scale: 2, default: 0 })
  commissionFixed: number; // Fixed commission amount

  @Column({ default: true })
  isActive: boolean;

  @Column({ default: false })
  isPopular: boolean;

  @Column({ default: false })
  isFeatured: boolean;

  @Column({ nullable: true })
  imageUrl: string;

  @Column({ default: 0 })
  sortOrder: number; // For custom ordering

  @Column('jsonb', { nullable: true })
  metadata: Record<string, any>; // Additional product-specific data

  @Column('simple-json', { nullable: true })
  bundleComponents: {
    type: ProductType;
    value: string;
    quantity: number;
  }[]; // For composite bundles

  @ManyToOne(() => Category, { nullable: true })
  @JoinColumn({ name: 'categoryId' })
  category: Category;

  @Column({ nullable: true })
  categoryId: string;

  @Column({ nullable: true })
  minPurchase: number; // Minimum quantity

  @Column({ nullable: true })
  maxPurchase: number; // Maximum quantity

  @Column({ default: false })
  requiresVerification: boolean; // Whether transaction requires additional verification

  @Column({ nullable: true })
  startDate: Date; // For time-limited offers

  @Column({ nullable: true })
  endDate: Date; // For time-limited offers

  @Column({ default: 0 })
  totalSold: number; // Total units sold

  @Column({ default: 0 })
  totalRevenue: number; // Total revenue from this product

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}