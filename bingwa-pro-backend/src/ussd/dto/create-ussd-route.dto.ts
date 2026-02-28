import { IsString, IsEnum, IsArray, IsOptional, IsNumber, IsObject, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { UssdProcessingMode } from '../entities/ussd-route.entity';

class ExpectedResponseDto {
  @IsNumber()
  step: number;

  @IsString()
  pattern: string; // Regex pattern

  @IsString()
  @IsOptional()
  nextAction?: string;
}

class ResponseMappingDto {
  @IsString()
  field: string;

  @IsString()
  pattern: string; // Regex to extract

  @IsNumber()
  step: number;
}

export class CreateUssdRouteDto {
  @IsString()
  code: string;

  @IsString()
  name: string;

  @IsString()
  description: string;

  @IsString()
  ussdString: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ExpectedResponseDto)
  @IsOptional()
  expectedResponses?: ExpectedResponseDto[];

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ResponseMappingDto)
  @IsOptional()
  responseMapping?: ResponseMappingDto[];

  @IsEnum(UssdProcessingMode)
  @IsOptional()
  processingMode?: UssdProcessingMode;

  @IsArray()
  @IsNumber({}, { each: true })
  @IsOptional()
  requiredSteps?: number[];

  @IsObject()
  @IsOptional()
  metadata?: Record<string, any>;
}