import { 
  IsString, 
  IsEnum, 
  IsNumber, 
  IsOptional, 
  IsBoolean, 
  IsArray, 
  IsUUID,
  Min,
  Max,
  ValidateNested,
  IsDateString,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ProductType, ProductNetwork } from '../entities/product.entity';

export class BundleComponentDto {
  @IsEnum(ProductType)
  type: ProductType;

  @IsString()
  value: string;

  @IsNumber()
  @Min(1)
  quantity: number;
}

export class CreateProductDto {
  @IsString()
  code: string;

  @IsString()
  name: string;

  @IsEnum(ProductType)
  type: ProductType;

  @IsEnum(ProductNetwork)
  @IsOptional()
  network?: ProductNetwork;

  @IsNumber()
  @Min(0)
  price: number;

  @IsNumber()
  @IsOptional()
  @Min(0)
  costPrice?: number;

  @IsString()
  value: string;

  @IsNumber()
  @IsOptional()
  @Min(1)
  validityDays?: number;

  @IsNumber()
  @IsOptional()
  @Min(1)
  validityHours?: number;

  @IsString()
  @IsOptional()
  ussdCode?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  tags?: string[];

  @IsNumber()
  @IsOptional()
  @Min(0)
  @Max(100)
  commissionRate?: number;

  @IsNumber()
  @IsOptional()
  @Min(0)
  commissionFixed?: number;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsBoolean()
  @IsOptional()
  isPopular?: boolean;

  @IsBoolean()
  @IsOptional()
  isFeatured?: boolean;

  @IsString()
  @IsOptional()
  imageUrl?: string;

  @IsNumber()
  @IsOptional()
  sortOrder?: number;

  @IsOptional()
  metadata?: Record<string, any>;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BundleComponentDto)
  @IsOptional()
  bundleComponents?: BundleComponentDto[];

  @IsUUID()
  @IsOptional()
  categoryId?: string;

  @IsNumber()
  @IsOptional()
  @Min(1)
  minPurchase?: number;

  @IsNumber()
  @IsOptional()
  @Min(1)
  maxPurchase?: number;

  @IsBoolean()
  @IsOptional()
  requiresVerification?: boolean;

  @IsDateString()
  @IsOptional()
  startDate?: Date;

  @IsDateString()
  @IsOptional()
  endDate?: Date;
}