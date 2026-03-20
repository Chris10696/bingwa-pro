import { ExtractJwt, Strategy } from 'passport-jwt';
import { PassportStrategy } from '@nestjs/passport';
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AgentsService } from '../../agents/agents.service';
import { AgentStatus } from '../../agents/entities/agent.entity'; // ADD THIS IMPORT

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private configService: ConfigService,
    private agentsService: AgentsService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get('JWT_SECRET') || 'your-secret-key-change-this',
    });
  }

  async validate(payload: any) {
    // payload contains the data we signed in the JWT
    // { sub: agent.id, phoneNumber: agent.phoneNumber, status: agent.status }
    
    try {
      // Verify the agent still exists and is active
      const agent = await this.agentsService.findById(payload.sub);
      
      if (!agent) {
        throw new UnauthorizedException('Agent not found');
      }
      
      // FIXED: Use enum comparison, not string literal
      if (agent.status !== AgentStatus.ACTIVE) {
        throw new UnauthorizedException(`Account is ${agent.status.toLowerCase()}`);
      }
      
      // Return the user object that will be attached to the request
      return {
        sub: agent.id,
        phoneNumber: agent.phoneNumber,
        status: agent.status,
      };
    } catch (error) {
      throw new UnauthorizedException('Invalid token');
    }
  }
}