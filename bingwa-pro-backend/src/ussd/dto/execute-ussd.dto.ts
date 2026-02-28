import { IsString, IsOptional, IsEnum, IsNumber, IsUUID, IsObject } from 'class-validator';

export enum UssdAction {
  INITIATE = 'initiate',
  RESPOND = 'respond',
  CANCEL = 'cancel',
}

export class ExecuteUssdDto {
  @IsEnum(UssdAction)
  action: UssdAction;

  @IsString()
  routeCode: string; // Which USSD route to execute

  @IsString()
  agentPhone: string; // Agent's phone number to execute USSD from

  @IsString()
  customerPhone: string; // Customer's phone number for the transaction

  @IsUUID()
  @IsOptional()
  agentId?: string; // Agent ID (from JWT)

  @IsString()
  @IsOptional()
  sessionId?: string; // For continuing an existing session

  @IsString()
  @IsOptional()
  input?: string; // User input for current step

  @IsNumber()
  @IsOptional()
  amount?: number; // Transaction amount

  @IsString()
  @IsOptional()
  productCode?: string; // Product code being purchased

  @IsUUID()
  @IsOptional()
  transactionId?: string; // Related transaction ID

  @IsObject()
  @IsOptional()
  parameters?: Record<string, any>; // Additional parameters for USSD

  @IsEnum(['express', 'advanced'])
  @IsOptional()
  processingMode?: 'express' | 'advanced';
}