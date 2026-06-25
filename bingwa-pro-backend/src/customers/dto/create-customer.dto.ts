import { IsString, IsOptional, IsNumber } from 'class-validator';

export class CreateCustomerDto {
  @IsString()
  phone: string;

  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsNumber()
  accountBalance?: number;
}
