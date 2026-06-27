// bingwa-pro-backend/src/hybrid-connect/hybrid-connect.service.ts
// W5.F — Connect ID issuance for HybridConnect/Portal. The agent generates a Connect ID, shares
// it with the web portal, and both the phone and the portal join the socket "room" for that ID.
//
// Store is IN-MEMORY for now (resets on server restart → the agent re-generates, matching Hybrid's
// "Generate Connect ID" UX). Persist to Postgres or Redis (ioredis is already a dep) before
// production so a Connect ID survives restarts. NOTE(prod): persist + verify the phone's JWT on
// the socket handshake (W5.F hardening).
import { Injectable } from '@nestjs/common';

@Injectable()
export class HybridConnectService {
  private readonly agentToConnectId = new Map<string, string>();
  private readonly connectIdToAgent = new Map<string, string>();

  /** Stable per agent: reuse the existing Connect ID, or mint one. */
  generate(agentId: string): string {
    const existing = this.agentToConnectId.get(agentId);
    if (existing) return existing;
    const id = this.mint();
    this.agentToConnectId.set(agentId, id);
    this.connectIdToAgent.set(id, agentId);
    return id;
  }

  current(agentId: string): string | null {
    return this.agentToConnectId.get(agentId) ?? null;
  }

  /** The owning agent for a Connect ID, or null if it was never generated. */
  agentFor(connectId: string): string | null {
    return this.connectIdToAgent.get(connectId) ?? null;
  }

  private mint(): string {
    return Math.random().toString(36).slice(2, 10).toUpperCase();
  }
}
