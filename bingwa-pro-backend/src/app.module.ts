// bingwa-pro-backend/src/app.module.ts
// W1: ProductsModule → OffersModule. Adds CategoriesModule and
// SubscriptionsModule. Entity auto-discovery (`__dirname + '/**/*.entity{.ts,.js}'`)
// picks up the new entities (Offer, Category, SubscriptionPackage,
// SubscriptionPlan, SubscriptionPurchase) automatically — no entities array
// edit needed.
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { AgentsModule } from './agents/agents.module';
import { AuthModule } from './auth/auth.module';
import { WalletsModule } from './wallets/wallets.module';
import { TransactionsModule } from './transactions/transactions.module';
import { OffersModule } from './offers/offers.module';
import { CategoriesModule } from './categories/categories.module';
import { SubscriptionsModule } from './subscriptions/subscriptions.module';
import { UssdModule } from './ussd/ussd.module';
import { MpesaModule } from './mpesa/mpesa.module';
import { HttpModule } from '@nestjs/axios';

@Module({
  imports: [
    HttpModule.register({
      timeout: 30000,
      maxRedirects: 5,
    }),
    ThrottlerModule.forRoot([
      {
        ttl: 60000,
        limit: 100,
      },
    ]),
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        host: configService.get('DB_HOST'),
        port: configService.get('DB_PORT'),
        username: configService.get('DB_USER'),
        password: configService.get('DB_PASSWORD'),
        database: configService.get('DB_NAME'),
        entities: [__dirname + '/**/*.entity{.ts,.js}'],
        synchronize: true, // W1: stays true. Migration switchover deferred to pre-prod.
      }),
    }),
    AgentsModule,
    AuthModule,
    WalletsModule,
    TransactionsModule,
    OffersModule,
    CategoriesModule,
    SubscriptionsModule,
    UssdModule,
    MpesaModule,
  ],
})
export class AppModule {}