// bingwa-pro-backend/src/sitelink/dto/create-site-link.dto.ts
import { IsEnum, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { SiteLinkAccountType } from '../entities/site-link.entity';

export class CreateSiteLinkDto {
  @IsString()
  @MinLength(2)
  @MaxLength(60)
  siteName: string;

  // The public slug. Letters/numbers/underscore only (URL-safe).
  @IsString()
  @MinLength(3)
  @MaxLength(30)
  @Matches(/^[a-zA-Z0-9_]+$/, {
    message: 'Username may only contain letters, numbers and underscores',
  })
  username: string;

  @IsEnum(SiteLinkAccountType)
  accountType: SiteLinkAccountType;

  @IsString()
  @MinLength(5)
  @MaxLength(20)
  accountNumber: string;
}
