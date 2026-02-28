export class StkCallbackDto {
  merchantRequestID: string;
  checkoutRequestID: string;
  resultCode: number;
  resultDesc: string;
  callbackMetadata?: {
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