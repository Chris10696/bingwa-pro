import { UssdSessionStatus } from '../entities/ussd-session.entity';

export class UssdResponseDto {
  success: boolean;
  sessionId: string;
  status: UssdSessionStatus;
  message: string;
  requiresInput: boolean;
  currentStep?: number;
  totalSteps?: number;
  extractedData?: Record<string, any>;
  transactionId?: string;
  reference?: string;
  errorMessage?: string;
  processingMode?: 'express' | 'advanced';
}