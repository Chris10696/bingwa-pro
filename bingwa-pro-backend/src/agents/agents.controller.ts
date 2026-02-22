import { 
  Controller, 
  Get, 
  Put, 
  Patch, 
  Param, 
  Body, 
  Query, 
  UseGuards,
  Request,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { AgentsService } from './agents.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('agents')
export class AgentsController {
  constructor(private readonly agentsService: AgentsService) {}

  @Get('me')
  @UseGuards(JwtAuthGuard)
  async getProfile(@Request() req) {
    // The user ID is attached to the request by JwtAuthGuard
    const agentId = req.user.sub;
    return this.agentsService.getProfile(agentId);
  }

  @Get('stats')
  @UseGuards(JwtAuthGuard)
  async getStats(@Request() req) {
    const agentId = req.user.sub;
    return this.agentsService.getStats(agentId);
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  async getAgent(@Param('id') id: string) {
    return this.agentsService.getProfile(id);
  }

  @Get('phone/:phoneNumber')
  @UseGuards(JwtAuthGuard)
  async getAgentByPhone(@Param('phoneNumber') phoneNumber: string) {
    const agent = await this.agentsService.findByPhoneNumber(phoneNumber);
    return {
      id: agent.id,
      fullName: agent.fullName,
      phoneNumber: agent.phoneNumber,
      status: agent.status,
    };
  }

  @Put('profile')
  @UseGuards(JwtAuthGuard)
  async updateProfile(@Request() req, @Body() updateData: any) {
    const agentId = req.user.sub;
    return this.agentsService.updateProfile(agentId, updateData);
  }

  @Patch(':id/status')
  @UseGuards(JwtAuthGuard)
  async updateStatus(
    @Param('id') id: string,
    @Body('status') status: 'ACTIVE' | 'SUSPENDED',
  ) {
    return this.agentsService.updateStatus(id, status);
  }

  @Get()
  @UseGuards(JwtAuthGuard)
  async getAllAgents(
    @Query('page') page: string = '1',
    @Query('limit') limit: string = '10',
    @Query('status') status?: string,
  ) {
    return this.agentsService.getAllAgents(
      parseInt(page),
      parseInt(limit),
      status,
    );
  }

  @Get('search')
  @UseGuards(JwtAuthGuard)
  async searchAgents(@Query('q') query: string) {
    if (!query) {
      return [];
    }
    return this.agentsService.searchAgents(query);
  }
}