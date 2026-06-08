// bingwa-pro-backend/src/transactions/dto/update-transaction-status.dto.ts
// W3.G: payload for PATCH /transactions/:id/status. The device pipeline
// (UssdDialerService) calls this when a transaction settles — SUCCESS,
// FAILED, FAILED_ALREADY_RECOMMENDED, RESCHEDULED, PAUSED, BLOCKED.
//
// `ussdResponse` carries the captured response text from sendUssdRequest
// (Express) or the final accessibility dialog (Advanced). `responseMessage`
// is an alias surface for the same data — the entity has BOTH columns;
// W3 writes to both so existing readers don't break.
//
// `safaricomReference` reconciles the entity's twin columns (safaricomRef
// vs safaricomReference) — write both, read either; W6 picks one.
import {
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { TransactionStatus } from '../entities/transaction.entity';

export class UpdateTransactionStatusDto {
  @IsEnum(TransactionStatus)
  status: TransactionStatus;

  // Captured USSD response text. Trimmed to a reasonable cap to prevent
  // pathological writes; Safaricom USSD responses are typically < 500 chars.
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  ussdResponse?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  errorMessage?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  safaricomReference?: string;
}