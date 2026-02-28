import { 
  Controller, 
  Get, 
  Post, 
  Put, 
  Patch, 
  Delete, 
  Body, 
  Param, 
  Query, 
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { UssdService } from './ussd.service';
import { ExecuteUssdDto } from './dto/execute-ussd.dto';
import { CreateUssdRouteDto } from './dto/create-ussd-route.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UssdAnomalyStatus } from './entities/ussd-anomaly.entity';

@Controller('ussd')
export class UssdController {
  constructor(private readonly ussdService: UssdService) {}

  // ========== USSD EXECUTION ==========

  @Post('execute')
  @UseGuards(JwtAuthGuard)
  async executeUssd(@Body() executeDto: ExecuteUssdDto) {
    return this.ussdService.executeUssd(executeDto);
  }

  // ========== HEALTH & MONITORING ==========

  @Get('health')
  async getHealthStatus() {
    return this.ussdService.getHealthStatus();
  }

  @Get('sessions/active')
  @UseGuards(JwtAuthGuard)
  async getActiveSessions() {
    return this.ussdService.getActiveSessions();
  }

  @Get('sessions/history')
  @UseGuards(JwtAuthGuard)
  async getSessionHistory(
    @Query('agentId') agentId?: string,
    @Query('limit') limit?: string,
  ) {
    return this.ussdService.getSessionHistory(agentId, limit ? parseInt(limit) : 50);
  }

  // ========== ANOMALY MANAGEMENT ==========

  @Get('anomalies')
  @UseGuards(JwtAuthGuard)
  async findAllAnomalies(@Query('status') status?: UssdAnomalyStatus) {
    return this.ussdService.findAllAnomalies(status);
  }

  @Post('anomalies/:id/resolve')
  @UseGuards(JwtAuthGuard)
  async resolveAnomaly(
    @Param('id') id: string,
    @Body() resolution: { notes: string; resolvedBy: string },
  ) {
    return this.ussdService.resolveAnomaly(id, resolution);
  }

  // ========== ROUTE MANAGEMENT ==========

  @Post('routes')
  @UseGuards(JwtAuthGuard)
  async createRoute(@Body() createRouteDto: CreateUssdRouteDto) {
    return this.ussdService.createRoute(createRouteDto);
  }

  @Get('routes')
  async findAllRoutes() {
    return this.ussdService.findAllRoutes();
  }

  @Get('routes/:id')
  async findOneRoute(@Param('id') id: string) {
    return this.ussdService.findOneRoute(id);
  }

  @Put('routes/:id')
  @UseGuards(JwtAuthGuard)
  async updateRoute(@Param('id') id: string, @Body() updateData: any) {
    return this.ussdService.updateRoute(id, updateData);
  }

  @Patch('routes/:id/toggle')
  @UseGuards(JwtAuthGuard)
  async toggleRouteStatus(@Param('id') id: string) {
    return this.ussdService.toggleRouteStatus(id);
  }

  @Delete('routes/:id')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteRoute(@Param('id') id: string) {
    await this.ussdService.deleteRoute(id);
  }
}