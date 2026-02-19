import { IsString, IsEmail, IsNotEmpty, MinLength, Matches, IsOptional } from 'class-validator';

export class RegisterAgentDto {
  @IsString()
  @IsNotEmpty({ message: 'Full name is required' })
  fullName: string;

  @IsString()
  @Matches(/^07\d{8}$/, { message: 'Phone number must be a valid Safaricom number starting with 07 (e.g., 0712345678)' })
  phoneNumber: string;

  @IsString()
  @IsNotEmpty({ message: 'National ID is required' })
  nationalId: string;

  @IsEmail()
  @IsOptional()
  email?: string;

  @IsString()
  @MinLength(4, { message: 'PIN must be at least 4 characters' })
  pin: string;

  @IsString()
  @MinLength(4)
  confirmPin: string;

  @IsString()
  @IsOptional()
  businessName?: string;

  @IsString()
  @IsOptional()
  location?: string;

  @IsString()
  @IsNotEmpty()
  deviceId: string;

  @IsString()
  @IsNotEmpty()
  platform: string;
}