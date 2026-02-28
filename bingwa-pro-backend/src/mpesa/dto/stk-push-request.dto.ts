import { IsString, IsNumber, IsOptional, IsPhoneNumber, Min, Max, IsEnum } from 'class-validator';

export enum MpesaEnvironment {
  SANDBOX = 'sandbox',
  PRODUCTION = 'production',
}

export class StkPushRequestDto {
  @IsString()
  @IsPhoneNumber('KE')
  phoneNumber: string; // Customer's phone number

  @IsNumber()
  @Min(10)
  @Max(150000)
  amount: number; // Amount to pay

  @IsString()
  @IsOptional()
  accountReference?: string; // Your account reference (default: agent ID)

  @IsString()
  @IsOptional()
  transactionDesc?: string; // Description (default: 'Token Purchase')

  @IsString()
  @IsOptional()
  agentId?: string; // Agent ID (from JWT)

  @IsEnum(MpesaEnvironment)
  @IsOptional()
  environment?: MpesaEnvironment; // Sandbox or production
}