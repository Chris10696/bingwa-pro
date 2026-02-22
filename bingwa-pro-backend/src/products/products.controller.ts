import { 
  Controller, 
  Get, 
  Post, 
  Put, 
  Patch, 
  Delete, 
  Body, 
  Param, 
  Query, 
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ProductsService } from './products.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { CreateCategoryDto } from './dto/create-category.dto';
import { ProductFilterDto } from './dto/product-filter.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ProductType } from './entities/product.entity';

@Controller('products')
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  // ========== PRODUCT ENDPOINTS ==========

  @Post()
  @UseGuards(JwtAuthGuard)
  async createProduct(@Body() createProductDto: CreateProductDto) {
    return this.productsService.createProduct(createProductDto);
  }

  @Post('bulk')
  @UseGuards(JwtAuthGuard)
  async bulkCreateProducts(@Body() products: CreateProductDto[]) {
    return this.productsService.bulkCreateProducts(products);
  }

  @Get()
  async findAllProducts(@Query() filterDto: ProductFilterDto) {
    return this.productsService.findAllProducts(filterDto);
  }

  @Get('active')
  async findAllActiveProducts() {
    return this.productsService.findAllProducts({ isActive: true, limit: 100 });
  }

  @Get('popular')
  async findPopularProducts() {
    return this.productsService.findPopularProducts();
  }

  @Get('featured')
  async findFeaturedProducts() {
    return this.productsService.findFeaturedProducts();
  }

  @Get('safaricom/bundles')
  async getSafaricomBundles() {
    return this.productsService.getSafaricomBundles();
  }

  @Get('airtime')
  async getAirtimeDenominations() {
    return this.productsService.getAirtimeDenominations();
  }

  @Get('data')
  async getDataBundles() {
    return this.productsService.getDataBundles();
  }

  @Get('sms')
  async getSmsBundles() {
    return this.productsService.getSmsBundles();
  }

  @Get('type/:type')
  async findByType(@Param('type') type: ProductType) {
    return this.productsService.findProductsByType(type);
  }

  @Get(':id')
  async findOneProduct(@Param('id') id: string) {
    return this.productsService.findOneProduct(id);
  }

  @Get(':id/validate')
  async validateProduct(
    @Param('id') id: string,
    @Query('amount') amount?: number,
  ) {
    return this.productsService.validateProductForPurchase(id, amount ? +amount : undefined);
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard)
  async updateProduct(
    @Param('id') id: string,
    @Body() updateProductDto: UpdateProductDto,
  ) {
    return this.productsService.updateProduct(id, updateProductDto);
  }

  @Patch(':id/toggle-status')
  @UseGuards(JwtAuthGuard)
  async toggleProductStatus(@Param('id') id: string) {
    return this.productsService.toggleProductStatus(id);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  async removeProduct(@Param('id') id: string) {
    await this.productsService.removeProduct(id);
  }

  // ========== CATEGORY ENDPOINTS ==========

  @Post('categories')
  @UseGuards(JwtAuthGuard)
  async createCategory(@Body() createCategoryDto: CreateCategoryDto) {
    return this.productsService.createCategory(createCategoryDto);
  }

  @Get('categories')
  async findAllCategories() {
    return this.productsService.findAllCategories();
  }

  @Get('categories/:id')
  async findOneCategory(@Param('id') id: string) {
    return this.productsService.findOneCategory(id);
  }

  @Put('categories/:id')
  @UseGuards(JwtAuthGuard)
  async updateCategory(
    @Param('id') id: string,
    @Body() updateData: Partial<CreateCategoryDto>,
  ) {
    return this.productsService.updateCategory(id, updateData);
  }

  @Delete('categories/:id')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  async removeCategory(@Param('id') id: string) {
    await this.productsService.removeCategory(id);
  }
}