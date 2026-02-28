import { IsString } from 'class-validator';

export class QueryStatusDto {
  @IsString()
  checkoutRequestId: string;
}