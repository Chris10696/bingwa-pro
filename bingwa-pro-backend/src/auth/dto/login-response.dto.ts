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
  };
  requiresBiometricSetup: boolean;
}