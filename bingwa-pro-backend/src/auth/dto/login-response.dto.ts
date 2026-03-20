export class LoginResponseDto {
  accessToken: string;
  refreshToken: string;
  expiresAt: Date;
  agent: {
    id: string;
    fullName: string;
    phoneNumber: string;
    email: string;
    status: string;
    tokenBalance: number;
    // Add these if you want them in the response
    tillNumber?: string;
    paybillNumber?: string;
    tillNumberVerified?: boolean;
    tillNumberStatus?: string;
  };
  requiresBiometricSetup: boolean;
}