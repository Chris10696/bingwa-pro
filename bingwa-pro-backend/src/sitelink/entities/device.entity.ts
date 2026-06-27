// bingwa-pro-backend/src/sitelink/entities/device.entity.ts
// W5.G.2 — a registry of the agent's phones (Hybrid Device{connectId, appState, deviceModel}),
// so the SiteLink fleet picker can assign which device dials each offer.
//
// ARCH NOTE: HybridConnect issues ONE Connect ID per agent (F.1), so a device needs its own
// stable identity for the fleet case. `deviceId` is that stable per-phone id (the client sends
// it, e.g. ANDROID_ID); an offer's relayDevice stores this `deviceId`. The connectId is kept
// (nullable) for forward-compat with socket routing, but per-device ORDER ROUTING is the web
// deployment's job (locked: order/payment live there), so it isn't required here.
import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

@Entity('devices')
@Index(['agentId', 'deviceId'], { unique: true })
export class Device {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column()
  agentId: string;

  // Stable per-phone identifier the client provides (relayDevice points at this).
  @Column()
  deviceId: string;

  @Column({ type: 'varchar', nullable: true })
  deviceModel: string | null;

  @Column({ type: 'varchar', nullable: true })
  connectId: string | null;

  @Column({ type: 'varchar', nullable: true })
  appState: string | null;

  @Column({ type: 'timestamp', nullable: true })
  lastSeenAt: Date | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
