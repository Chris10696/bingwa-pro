// bingwa-pro-backend/src/mpesa/dto/mpesa-callback.dto.ts
// FIX: corrected to Daraja's ACTUAL STK callback shape. The inner stkCallback
// fields are PascalCase (CheckoutRequestID, ResultCode, ResultDesc,
// CallbackMetadata) — the previous camelCase declarations did not match the
// real payload, so the handler read undefined and never granted the plan.
//
// NOTE: the controller now binds this webhook with `@Body() body: any` so the
// global ValidationPipe can't strip these (undecorated) fields. This file now
// documents the shape MpesaService.handleCallback reads.
export class StkCallbackDto {
  MerchantRequestID: string;
  CheckoutRequestID: string;
  ResultCode: number;
  ResultDesc: string;
  CallbackMetadata?: {
    Item: Array<{
      Name: string;
      Value?: string | number;
    }>;
  };
}
export class MpesaCallbackDto {
  Body: {
    stkCallback: StkCallbackDto;
  };
}
