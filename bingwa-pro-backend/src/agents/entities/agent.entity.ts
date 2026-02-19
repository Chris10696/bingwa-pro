import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, OneToOne } from 'typeorm';
import { Wallet } from '../../wallets/entities/wallet.entity';

@Entity('agents')
export class Agent {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  phoneNumber: string;

  @Column()
  fullName: string;

  @Column({ unique: true })
  nationalId: string;

  @Column({ nullable: true })
  email: string;

  @Column()
  pinHash: string;

  @Column({ nullable: true })
  businessName: string;

  @Column({ nullable: true })
  location: string;

  @Column({ 
    type: 'varchar',
    default: 'PENDING' 
  })
  status: 'PENDING' | 'ACTIVE' | 'SUSPENDED';

  @Column()
  deviceId: string;

  @Column({ default: 'android' })
  platform: string;

  @OneToOne(() => Wallet, wallet => wallet.agent, { cascade: true })
  wallet: Wallet;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}