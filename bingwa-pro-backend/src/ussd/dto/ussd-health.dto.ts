export enum UssdHealthStatus {
  GREEN = 'green',
  YELLOW = 'yellow',
  RED = 'red',
}

export class UssdHealthDto {
  status: UssdHealthStatus;
  lastChecked: Date;
  message: string;
  responseTimeMs: number;
  successRate: number;
  totalChecks: number;
  failedChecks: number;
  routesHealth: {
    routeId: string;
    routeCode: string;
    status: string;
    successRate: number;
    responseTimeMs: number;
  }[];
}