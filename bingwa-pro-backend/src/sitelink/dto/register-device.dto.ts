// bingwa-pro-backend/src/sitelink/dto/register-device.dto.ts
import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

// The phone upserts itself on startup so it appears in the agent's fleet picker.
export class RegisterDeviceDto {
  @IsString()
  @MinLength(1)
  @MaxLength(128)
  deviceId: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  deviceModel?: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  connectId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  appState?: string;
}
