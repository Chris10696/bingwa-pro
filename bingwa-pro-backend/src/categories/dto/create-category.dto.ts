// bingwa-pro-backend/src/categories/dto/create-category.dto.ts
// W1: not wired to any endpoint yet; retained for future admin CRUD.
import { IsString } from 'class-validator';

export class CreateCategoryDto {
  @IsString()
  name: string;
}