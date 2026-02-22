import { IsEnum, IsOptional, IsBoolean, IsString, IsNumber, Min, IsUUID } from 'class-validator';
import { Type } from 'class-transformer';
import { ProductType, ProductNetwork } from '../entities/product.entity';

export class ProductFilterDto {
  @IsEnum(ProductType)
  @IsOptional()
  type?: ProductType;

  @IsEnum(ProductNetwork)
  @IsOptional()
  network?: ProductNetwork;

  @IsBoolean()
  @IsOptional()
  @Type(() => Boolean)
  isActive?: boolean;

  @IsBoolean()
  @IsOptional()
  @Type(() => Boolean)
  isPopular?: boolean;

  @IsBoolean()
  @IsOptional()
  @Type(() => Boolean)
  isFeatured?: boolean;

  @IsString()
  @IsOptional()
  search?: string;

  @IsUUID()
  @IsOptional()
  categoryId?: string;

  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  @Min(0)
  minPrice?: number;

  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  @Min(0)
  maxPrice?: number;

  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  @Min(1)
  page?: number = 1;

  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  @Min(1)
  limit?: number = 20;

  @IsString()
  @IsOptional()
  sortBy?: string = 'sortOrder';

  @IsString()
  @IsOptional()
  sortOrder?: 'ASC' | 'DESC' = 'ASC';
}