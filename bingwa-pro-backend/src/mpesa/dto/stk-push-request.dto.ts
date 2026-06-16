// bingwa-pro-backend/src/mpesa/dto/stk-push-request.dto.ts
// W2.B/E: phoneNumber validator relaxed from @IsPhoneNumber('KE') to @IsString()
// — WalletsService now passes Daraja's 2547######## form, which @IsPhoneNumber
// rejects. The global ValidationPipe (W2.E) would otherwise 400 the request.
import {
  IsString,
  IsNumber,
  IsOptional,
  Min,
  Max,
  IsEnum,
} from 'class-validator';

export enum MpesaEnvironment {
  SANDBOX = 'sandbox',
  PRODUCTION = 'production',
}

export class StkPushRequestDto {
  @IsString()
  phoneNumber: string;

  @IsNumber()
  @Min(10)
  @Max(150000)
  amount: number;

  @IsString()
  @IsOptional()
  accountReference?: string;

  @IsString()
  @IsOptional()
  transactionDesc?: string;

  @IsString()
  @IsOptional()
  agentId?: string;

  @IsEnum(MpesaEnvironment)
  @IsOptional()
  environment?: MpesaEnvironment;
}
