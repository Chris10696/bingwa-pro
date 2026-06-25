// bingwa-pro-backend/src/customers/customers.controller.ts
// W4-batch-3 — agent-scoped customer + blacklist management (mirrors the client repo's paths).
// NOTE: GET 'search' is declared BEFORE GET ':id' so the static route isn't swallowed by :id.
import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Request,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { CustomersService } from './customers.service';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('customers')
@UseGuards(JwtAuthGuard)
export class CustomersController {
  constructor(private readonly customersService: CustomersService) {}

  @Get()
  async list(
    @Request() req,
    @Query('search') search?: string,
    @Query('blacklisted') blacklisted?: string,
  ) {
    const customers = await this.customersService.list(req.user.sub, {
      search: search || undefined,
      blacklisted:
        blacklisted === undefined ? undefined : blacklisted === 'true',
    });
    return { customers, total: customers.length };
  }

  @Get('search')
  async search(@Request() req, @Query('q') q?: string) {
    const customers = await this.customersService.list(req.user.sub, {
      search: q || '',
    });
    return { customers };
  }

  @Get(':id')
  async findOne(@Request() req, @Param('id') id: string) {
    return this.customersService.findOne(req.user.sub, id);
  }

  @Post()
  async create(@Request() req, @Body() dto: CreateCustomerDto) {
    return this.customersService.create(req.user.sub, dto);
  }

  @Put(':id')
  async update(
    @Request() req,
    @Param('id') id: string,
    @Body() dto: UpdateCustomerDto,
  ) {
    return this.customersService.update(req.user.sub, id, dto);
  }

  @Post(':id/blacklist')
  async blacklist(@Request() req, @Param('id') id: string) {
    return this.customersService.setBlacklist(req.user.sub, id, true);
  }

  @Delete(':id/blacklist')
  async unblacklist(@Request() req, @Param('id') id: string) {
    return this.customersService.setBlacklist(req.user.sub, id, false);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Request() req, @Param('id') id: string) {
    await this.customersService.remove(req.user.sub, id);
  }
}
