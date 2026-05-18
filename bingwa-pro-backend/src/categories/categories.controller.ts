// bingwa-pro-backend/src/categories/categories.controller.ts
// W1 new controller. Read-only for now; categories are seeded fixed (Data,
// Minutes, SMS) and W1 has no agent-facing flow to add new ones.
import { Controller, Get, Param } from '@nestjs/common';
import { CategoriesService } from './categories.service';

@Controller('categories')
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  @Get()
  async findAll() {
    return this.categoriesService.findAll();
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.categoriesService.findOne(id);
  }
}