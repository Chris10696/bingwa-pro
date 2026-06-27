// bingwa-pro-backend/src/sitelink/dto/update-site-link.dto.ts
import { PartialType } from '@nestjs/mapped-types';
import { IsBoolean } from 'class-validator';
import { CreateSiteLinkDto } from './create-site-link.dto';

export class UpdateSiteLinkDto extends PartialType(CreateSiteLinkDto) {}

export class SetSiteLinkActiveDto {
  @IsBoolean()
  isActive: boolean;
}
