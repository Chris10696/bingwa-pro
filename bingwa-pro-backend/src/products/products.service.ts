import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like, Between, In } from 'typeorm';
import { Product, ProductType, ProductNetwork } from './entities/product.entity';
import { Category } from './entities/category.entity';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { CreateCategoryDto } from './dto/create-category.dto';
import { ProductFilterDto } from './dto/product-filter.dto';

@Injectable()
export class ProductsService {
  constructor(
    @InjectRepository(Product)
    private productsRepository: Repository<Product>,
    @InjectRepository(Category)
    private categoriesRepository: Repository<Category>,
  ) {}

  // ========== PRODUCT MANAGEMENT ==========

  async createProduct(createProductDto: CreateProductDto): Promise<Product> {
    // Check if product with same code exists
    const existingProduct = await this.productsRepository.findOne({
      where: { code: createProductDto.code },
    });

    if (existingProduct) {
      throw new BadRequestException(`Product with code ${createProductDto.code} already exists`);
    }

    // If categoryId is provided, verify category exists
    if (createProductDto.categoryId) {
      const category = await this.categoriesRepository.findOne({
        where: { id: createProductDto.categoryId },
      });
      if (!category) {
        throw new NotFoundException(`Category with ID ${createProductDto.categoryId} not found`);
      }
    }

    const product = this.productsRepository.create(createProductDto);
    return this.productsRepository.save(product);
  }

  async findAllProducts(filterDto: ProductFilterDto): Promise<{ products: Product[]; total: number }> {
    const { 
      type, 
      network, 
      isActive, 
      isPopular, 
      isFeatured, 
      search, 
      categoryId,
      minPrice,
      maxPrice,
      page = 1, 
      limit = 20,
      sortBy = 'sortOrder',
      sortOrder = 'ASC',
    } = filterDto;

    const where: any = {};

    if (type) where.type = type;
    if (network) where.network = network;
    if (isActive !== undefined) where.isActive = isActive;
    if (isPopular !== undefined) where.isPopular = isPopular;
    if (isFeatured !== undefined) where.isFeatured = isFeatured;
    if (categoryId) where.categoryId = categoryId;

    if (search) {
      where.name = Like(`%${search}%`);
    }

    if (minPrice !== undefined || maxPrice !== undefined) {
      where.price = Between(
        minPrice || 0,
        maxPrice || Number.MAX_SAFE_INTEGER,
      );
    }

    const [products, total] = await this.productsRepository.findAndCount({
      where,
      relations: ['category'],
      skip: (page - 1) * limit,
      take: limit,
      order: { [sortBy]: sortOrder },
    });

    return { products, total };
  }

  async findOneProduct(id: string): Promise<Product> {
    const product = await this.productsRepository.findOne({
      where: { id },
      relations: ['category'],
    });

    if (!product) {
      throw new NotFoundException(`Product with ID ${id} not found`);
    }

    return product;
  }

  async findProductsByType(type: ProductType): Promise<Product[]> {
    return this.productsRepository.find({
      where: { type, isActive: true },
      order: { sortOrder: 'ASC' },
    });
  }

  async findPopularProducts(): Promise<Product[]> {
    return this.productsRepository.find({
      where: { isPopular: true, isActive: true },
      order: { sortOrder: 'ASC' },
      take: 10,
    });
  }

  async findFeaturedProducts(): Promise<Product[]> {
    return this.productsRepository.find({
      where: { isFeatured: true, isActive: true },
      order: { sortOrder: 'ASC' },
      take: 10,
    });
  }

  async updateProduct(id: string, updateProductDto: UpdateProductDto): Promise<Product> {
    const product = await this.findOneProduct(id);

    // If categoryId is being updated, verify new category exists
    if (updateProductDto.categoryId) {
      const category = await this.categoriesRepository.findOne({
        where: { id: updateProductDto.categoryId },
      });
      if (!category) {
        throw new NotFoundException(`Category with ID ${updateProductDto.categoryId} not found`);
      }
    }

    Object.assign(product, updateProductDto);
    return this.productsRepository.save(product);
  }

  async removeProduct(id: string): Promise<void> {
    const product = await this.findOneProduct(id);
    await this.productsRepository.remove(product);
  }

  async toggleProductStatus(id: string): Promise<Product> {
    const product = await this.findOneProduct(id);
    product.isActive = !product.isActive;
    return this.productsRepository.save(product);
  }

  async incrementProductSales(id: string, quantity: number = 1, revenue: number): Promise<void> {
    await this.productsRepository.increment({ id }, 'totalSold', quantity);
    await this.productsRepository.increment({ id }, 'totalRevenue', revenue);
  }

  // ========== CATEGORY MANAGEMENT ==========

  async createCategory(createCategoryDto: CreateCategoryDto): Promise<Category> {
    // Check if category with same name exists
    const existingCategory = await this.categoriesRepository.findOne({
      where: { name: createCategoryDto.name },
    });

    if (existingCategory) {
      throw new BadRequestException(`Category with name ${createCategoryDto.name} already exists`);
    }

    const category = this.categoriesRepository.create(createCategoryDto);
    return this.categoriesRepository.save(category);
  }

  async findAllCategories(): Promise<Category[]> {
    return this.categoriesRepository.find({
      relations: ['products'],
      order: { sortOrder: 'ASC' },
    });
  }

  async findOneCategory(id: string): Promise<Category> {
    const category = await this.categoriesRepository.findOne({
      where: { id },
      relations: ['products'],
    });

    if (!category) {
      throw new NotFoundException(`Category with ID ${id} not found`);
    }

    return category;
  }

  async updateCategory(id: string, updateData: Partial<CreateCategoryDto>): Promise<Category> {
    const category = await this.findOneCategory(id);
    Object.assign(category, updateData);
    return this.categoriesRepository.save(category);
  }

  async removeCategory(id: string): Promise<void> {
    const category = await this.findOneCategory(id);
    
    // Check if category has products
    if (category.products && category.products.length > 0) {
      throw new BadRequestException('Cannot delete category that has products');
    }

    await this.categoriesRepository.remove(category);
  }

  // ========== UTILITY METHODS ==========

  async getSafaricomBundles(): Promise<Product[]> {
    return this.productsRepository.find({
      where: { 
        network: ProductNetwork.SAFARICOM,
        isActive: true,
        type: In([ProductType.DATA, ProductType.AIRTIME, ProductType.SMS]),
      },
      order: { sortOrder: 'ASC' },
    });
  }

  async getAirtimeDenominations(): Promise<Product[]> {
    return this.productsRepository.find({
      where: { 
        type: ProductType.AIRTIME,
        isActive: true,
      },
      order: { price: 'ASC' },
    });
  }

  async getDataBundles(): Promise<Product[]> {
    return this.productsRepository.find({
      where: { 
        type: ProductType.DATA,
        isActive: true,
      },
      order: { price: 'ASC' },
    });
  }

  async getSmsBundles(): Promise<Product[]> {
    return this.productsRepository.find({
      where: { 
        type: ProductType.SMS,
        isActive: true,
      },
      order: { price: 'ASC' },
    });
  }

  async validateProductForPurchase(productId: string, amount?: number): Promise<{ valid: boolean; message?: string }> {
    try {
      const product = await this.findOneProduct(productId);

      if (!product.isActive) {
        return { valid: false, message: 'Product is not active' };
      }

      if (product.startDate && new Date(product.startDate) > new Date()) {
        return { valid: false, message: 'Product is not yet available' };
      }

      if (product.endDate && new Date(product.endDate) < new Date()) {
        return { valid: false, message: 'Product has expired' };
      }

      if (amount) {
        if (product.minPurchase && amount < product.minPurchase) {
          return { valid: false, message: `Minimum purchase is ${product.minPurchase}` };
        }
        if (product.maxPurchase && amount > product.maxPurchase) {
          return { valid: false, message: `Maximum purchase is ${product.maxPurchase}` };
        }
      }

      return { valid: true };
    } catch (error) {
      return { valid: false, message: 'Product not found' };
    }
  }

  async calculateCommission(productId: string, amount: number): Promise<number> {
    const product = await this.findOneProduct(productId);
    
    if (product.commissionFixed > 0) {
      return product.commissionFixed;
    }
    
    return (amount * product.commissionRate) / 100;
  }

  async bulkCreateProducts(products: CreateProductDto[]): Promise<Product[]> {
    const createdProducts: Product[] = [];
    
    for (const productDto of products) {
      try {
        const product = await this.createProduct(productDto);
        createdProducts.push(product);
      } catch (error) {
        // Skip duplicates and continue
        continue;
      }
    }
    
    return createdProducts;
  }
}