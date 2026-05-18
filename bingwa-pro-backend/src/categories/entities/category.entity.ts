// bingwa-pro-backend/src/categories/entities/category.entity.ts
// W1: relocated from src/products/entities/. Simplified — fixed list of three
// rows, no need for description/icon/color/sortOrder cosmetic fields.
import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('categories')
export class Category {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  name: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}