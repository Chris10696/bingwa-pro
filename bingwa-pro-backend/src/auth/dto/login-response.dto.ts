// bingwa-pro-backend/src/auth/dto/login-response.dto.ts
// W1: tokenBalance dropped from agent block. Clients fetch balance via
// /wallet/balance which now returns plan-based state.
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
  };
  requiresBiometricSetup: boolean;
}
