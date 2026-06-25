// bingwa-pro-backend/src/customers/customers.service.ts
// W4-batch-3 — Hybrid-minimal customer records, per-agent. Mirrors Hybrid's
// GetOrCreateCustomerUseCase / CustomerDao operations; the SMS pipeline calls
// getOrCreate + isBlacklisted, the management UI calls list/update/blacklist/delete.
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ILike, Repository } from 'typeorm';
import { Customer } from './entities/customer.entity';

@Injectable()
export class CustomersService {
  constructor(
    @InjectRepository(Customer)
    private readonly customersRepository: Repository<Customer>,
  ) {}

  /** Find by (agent, phone) or create. Backfills a blank name if one is now known. */
  async getOrCreate(
    agentId: string,
    phone: string,
    name?: string,
  ): Promise<Customer> {
    let customer = await this.customersRepository.findOne({
      where: { agentId, phone },
    });
    if (!customer) {
      customer = await this.customersRepository.save(
        this.customersRepository.create({
          agentId,
          phone,
          name: name?.trim() || '',
        }),
      );
    } else if (name?.trim() && !customer.name) {
      customer.name = name.trim();
      customer = await this.customersRepository.save(customer);
    }
    return customer;
  }

  /** True if this agent has blacklisted this phone (read-only gate for the SMS pipeline). */
  async isBlacklisted(agentId: string, phone: string): Promise<boolean> {
    const c = await this.customersRepository.findOne({
      where: { agentId, phone },
    });
    return c?.isBlackListed ?? false;
  }

  /** Stamp lastPurchaseTime = now (a payment for this customer just arrived). */
  async recordPurchase(agentId: string, phone: string): Promise<void> {
    const c = await this.customersRepository.findOne({
      where: { agentId, phone },
    });
    if (!c) return;
    c.lastPurchaseTime = new Date();
    await this.customersRepository.save(c);
  }

  async list(
    agentId: string,
    opts: { search?: string; blacklisted?: boolean },
  ): Promise<Customer[]> {
    const base: Record<string, unknown> = { agentId };
    if (opts.blacklisted !== undefined) base.isBlackListed = opts.blacklisted;
    const order = { lastPurchaseTime: 'DESC', createdAt: 'DESC' } as const;
    if (opts.search?.trim()) {
      const q = `%${opts.search.trim()}%`;
      return this.customersRepository.find({
        where: [
          { ...base, name: ILike(q) },
          { ...base, phone: ILike(q) },
        ],
        order,
        take: 200,
      });
    }
    return this.customersRepository.find({ where: base, order, take: 200 });
  }

  async findOne(agentId: string, id: string): Promise<Customer> {
    const c = await this.customersRepository.findOne({ where: { id, agentId } });
    if (!c) throw new NotFoundException('Customer not found');
    return c;
  }

  async create(
    agentId: string,
    dto: { phone: string; name?: string; accountBalance?: number },
  ): Promise<Customer> {
    const c = await this.getOrCreate(agentId, dto.phone, dto.name);
    if (dto.accountBalance !== undefined) {
      c.accountBalance = dto.accountBalance;
      return this.customersRepository.save(c);
    }
    return c;
  }

  async update(
    agentId: string,
    id: string,
    dto: { name?: string; accountBalance?: number },
  ): Promise<Customer> {
    const c = await this.findOne(agentId, id);
    if (dto.name !== undefined) c.name = dto.name;
    if (dto.accountBalance !== undefined) c.accountBalance = dto.accountBalance;
    return this.customersRepository.save(c);
  }

  async setBlacklist(
    agentId: string,
    id: string,
    blacklisted: boolean,
  ): Promise<Customer> {
    const c = await this.findOne(agentId, id);
    c.isBlackListed = blacklisted;
    return this.customersRepository.save(c);
  }

  /** W4-batch-4 auto-save-to-contacts marker (set after a successful phonebook write). */
  async markSavedInContacts(
    agentId: string,
    phone: string,
    saved: boolean,
  ): Promise<void> {
    const c = await this.customersRepository.findOne({
      where: { agentId, phone },
    });
    if (!c) return;
    c.isSavedInContacts = saved;
    await this.customersRepository.save(c);
  }

  async remove(agentId: string, id: string): Promise<void> {
    const c = await this.findOne(agentId, id);
    await this.customersRepository.remove(c);
  }
}
