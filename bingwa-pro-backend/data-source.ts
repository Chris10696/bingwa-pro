// data-source.ts
import { DataSource } from 'typeorm';
import { config } from 'dotenv';

config(); // Loads variables from .env file

export const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: 5432,
  username: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'ChrisMK@2026#', // Your PostgreSQL password
  database: process.env.DB_NAME || 'bingwa_pro',
  entities: ['dist/**/*.entity.js'],
  migrations: ['dist/db/migrations/*.js'],
  synchronize: false, // KEEP THIS AS FALSE. We use migrations.
});