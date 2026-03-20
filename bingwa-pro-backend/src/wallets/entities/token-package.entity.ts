// bingwa-pro-backend/src/wallets/entities/token-package.entity.ts
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('token_packages')
export class TokenPackage {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string; // 'Daily Trial', 'Weekly Starter', etc.

  @Column({ type: 'int' })
  tokens: number; // Number of tokens provided

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  price: number; // Price in KES

  @Column({ type: 'int' })
  validityDays: number; // 1, 7, 30

  @Column({ default: true })
  isActive: boolean;

  @Column({ nullable: true })
  description: string;

  @Column({ type: 'json', nullable: true })
  features: string[]; // ['Express Mode', 'Advanced Mode', 'Priority Support']

  @Column({ default: 0 })
  sortOrder: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}