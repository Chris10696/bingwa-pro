// bingwa-pro-backend/src/account-health/account-health.service.ts
// W5.C (D-W5-5) — STUB. Always returns HEALTHY until a real account-standing policy is defined.
// The full client model + dial/UI gate + native block are wired against this; when a policy
// exists (e.g. unpaid plan → PAYMENT_PENDING, abuse → RESTRICTED), implement it here only.
import { Injectable } from '@nestjs/common';

export type AccountHealthStatus =
  | 'HEALTHY'
  | 'EXPIRED'
  | 'PAYMENT_PENDING'
  | 'RESTRICTED'
  | 'SUSPENDED'
  | 'BANNED'
  | 'TERMINATED'
  | 'FRAUD_SUSPECTED';

@Injectable()
export class AccountHealthService {
  getHealth(_agentId: string): {
    healthStatus: AccountHealthStatus;
    serverTime: string;
  } {
    return { healthStatus: 'HEALTHY', serverTime: new Date().toISOString() };
  }
}
