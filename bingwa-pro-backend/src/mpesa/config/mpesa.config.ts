export interface MpesaConfig {
  consumerKey: string;
  consumerSecret: string;
  businessShortCode: string;
  passkey: string;
  environment: 'sandbox' | 'production';
  callbackUrl: string;
}

export const getMpesaConfig = (): MpesaConfig => ({
  consumerKey: process.env.MPESA_CONSUMER_KEY || '',
  consumerSecret: process.env.MPESA_CONSUMER_SECRET || '',
  businessShortCode: process.env.MPESA_BUSINESS_SHORT_CODE || '174379',
  passkey: process.env.MPESA_PASSKEY || '',
  environment: (process.env.MPESA_ENVIRONMENT as 'sandbox' | 'production') || 'sandbox',
  callbackUrl: process.env.MPESA_CALLBACK_URL || 'https://your-domain.com/mpesa/callback',
});

export const getBaseUrl = (environment: string): string => {
  return environment === 'production'
    ? 'https://api.safaricom.co.ke'
    : 'https://sandbox.safaricom.co.ke';
};