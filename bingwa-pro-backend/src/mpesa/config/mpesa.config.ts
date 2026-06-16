//bingwa-pro-backend/src/mpesa/config/mpesa.config.ts

export interface MpesaConfig {
  consumerKey: string;
  consumerSecret: string;
  businessShortCode: string;
  passkey: string;
  environment: 'sandbox' | 'production';
  callbackUrl: string;
  // STK transaction type:
  //   'CustomerPayBillOnline'  → Paybill
  //   'CustomerBuyGoodsOnline' → Till (Buy Goods)
  transactionType: string;
  // The organisation receiving the funds (PartyB).
  //   Paybill: same as businessShortCode.
  //   Till:    the TILL number. businessShortCode stays the store/head-office
  //            number that the passkey was issued against (used in the password).
  partyB: string;
}
export const getMpesaConfig = (): MpesaConfig => ({
  consumerKey: process.env.MPESA_CONSUMER_KEY || '',
  consumerSecret: process.env.MPESA_CONSUMER_SECRET || '',
  businessShortCode: process.env.MPESA_BUSINESS_SHORT_CODE || '174379',
  passkey: process.env.MPESA_PASSKEY || '',
  environment:
    (process.env.MPESA_ENVIRONMENT as 'sandbox' | 'production') || 'sandbox',
  callbackUrl:
    process.env.MPESA_CALLBACK_URL || 'https://your-domain.com/mpesa/callback',
  transactionType:
    process.env.MPESA_TRANSACTION_TYPE || 'CustomerPayBillOnline',
  // Defaults to businessShortCode so Paybill setups need no extra var.
  partyB:
    process.env.MPESA_PARTY_B ||
    process.env.MPESA_BUSINESS_SHORT_CODE ||
    '174379',
});
export const getBaseUrl = (environment: string): string => {
  return environment === 'production'
    ? 'https://api.safaricom.co.ke'
    : 'https://sandbox.safaricom.co.ke';
};
