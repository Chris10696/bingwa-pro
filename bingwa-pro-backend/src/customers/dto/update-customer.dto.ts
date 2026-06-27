import { IsString, IsOptional, IsNumber } from 'class-validator';

export class UpdateCustomerDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsNumber()
  accountBalance?: number;
}
