// bingwa-pro-backend/src/auth/auth.module.ts
// W2.B: Offer added to forFeature so register() can clone the 8 default offers
// inside its registration transaction (D-W2-D).
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PassportModule } from '@nestjs/passport';
import { AuthService } from './auth.service';
import { AuthController } from './controllers/auth.controller';
import { JwtStrategy } from './strategies/jwt.strategy';
import { Agent } from '../agents/entities/agent.entity';
import { Wallet } from '../wallets/entities/wallet.entity';
import { Offer } from '../offers/entities/offer.entity';
import { AgentsModule } from '../agents/agents.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Agent, Wallet, Offer]),
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get('JWT_SECRET') || 'your-secret-key-change-this',
        signOptions: { expiresIn: '7d' },
      }),
    }),
    AgentsModule,
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy],
  exports: [JwtStrategy, PassportModule],
})
export class AuthModule {}