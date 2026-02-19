import { IsString, Matches, MinLength, IsNotEmpty } from 'class-validator';

export class LoginAgentDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/^07\d{8}$/, { message: 'Phone number must be a valid Safaricom number starting with 07' })
  phoneNumber: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(4, { message: 'PIN must be at least 4 characters' })
  pin: string;

  @IsString()
  @IsNotEmpty()
  deviceId: string;

  @IsString()
  @IsNotEmpty()
  platform: string;
}