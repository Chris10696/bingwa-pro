// bingwa-pro-backend/src/categories/categories.module.ts
// W1 new module: split out of OffersModule per primer locked decision 4.
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CategoriesController } from './categories.controller';
import { CategoriesService } from './categories.service';
import { CategoriesSeed } from './categories.seed';
import { Category } from './entities/category.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Category])],
  controllers: [CategoriesController],
  providers: [CategoriesService, CategoriesSeed],
  exports: [CategoriesService],
})
export class CategoriesModule {}